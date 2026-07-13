-- Enable pgcrypto extension for crypt and gen_salt functions (typically active in Supabase)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'worker')),
    full_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    joining_date DATE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Sites Table
CREATE TABLE IF NOT EXISTS public.sites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_name TEXT NOT NULL,
    site_code TEXT UNIQUE,
    client_name TEXT,
    address TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    description TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Worker Assignments Table
CREATE TABLE IF NOT EXISTS public.worker_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (worker_id, site_id)
);

-- 4. Attendance Table
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    site_id UUID REFERENCES public.sites(id) ON DELETE SET NULL,
    check_in_time TIMESTAMP WITH TIME ZONE,
    check_out_time TIMESTAMP WITH TIME ZONE,
    latitude NUMERIC,
    longitude NUMERIC,
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT DEFAULT 'present' CHECK (status IN ('present', 'absent', 'half_day')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Photo Uploads Table
CREATE TABLE IF NOT EXISTS public.photo_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    site_id UUID REFERENCES public.sites(id) ON DELETE SET NULL,
    image_url TEXT NOT NULL,
    caption TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Location Logs Table
CREATE TABLE IF NOT EXISTS public.location_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    site_id UUID REFERENCES public.sites(id) ON DELETE SET NULL,
    latitude NUMERIC,
    longitude NUMERIC,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger to automatically create a profile when a new user registers in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (auth_user_id, role, full_name, email, status)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'role', 'worker'),
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    'active'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind trigger to auth.users (run after insert)
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger to delete public profile and assignments when an auth.user is deleted
CREATE OR REPLACE FUNCTION public.handle_deleted_user()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.profiles WHERE auth_user_id = old.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_deleted
  AFTER DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_deleted_user();

-- Secure RPC function for admin to create worker user
CREATE OR REPLACE FUNCTION public.create_worker_user(
  email_param TEXT,
  password_param TEXT,
  full_name_param TEXT,
  phone_param TEXT,
  address_param TEXT,
  joining_date_param DATE
) RETURNS UUID AS $$
DECLARE
  new_user_id UUID;
  new_profile_id UUID;
BEGIN
  -- Security check: only admins can create workers
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied: Only administrators can create workers.';
  END IF;

  -- Prevent duplicate worker emails
  IF EXISTS (
    SELECT 1 FROM auth.users WHERE email = email_param
  ) THEN
    RAISE EXCEPTION 'A user with this email already exists. Delete the broken user or use a different email.';
  END IF;

  -- Insert user into auth.users (which triggers handle_new_user)
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) VALUES (
    (SELECT id FROM auth.instances LIMIT 1),
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    email_param,
    crypt(password_param, gen_salt('bf')),
    now(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object('full_name', full_name_param, 'role', 'worker'),
    now(),
    now()
  ) RETURNING id INTO new_user_id;

  -- Insert identities row to allow standard email login
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    new_user_id,
    jsonb_build_object('sub', new_user_id, 'email', email_param, 'provider', 'email'),
    'email',
    email_param,
    now(),
    now(),
    now()
  );

  -- Update profile (which was auto-created by handle_new_user trigger)
  UPDATE public.profiles
  SET
    phone = phone_param,
    address = address_param,
    joining_date = joining_date_param
  WHERE auth_user_id = new_user_id
  RETURNING id INTO new_profile_id;

  RETURN new_profile_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Secure RPC function for admin to update worker credentials & profile
CREATE OR REPLACE FUNCTION public.update_worker_user(
  worker_profile_id UUID,
  email_param TEXT,
  password_param TEXT,
  full_name_param TEXT,
  phone_param TEXT,
  address_param TEXT,
  joining_date_param DATE
) RETURNS VOID AS $$
DECLARE
  target_auth_user_id UUID;
BEGIN
  -- Security check: only admins
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied: Only administrators can update workers.';
  END IF;

  -- Get auth_user_id from profile
  SELECT auth_user_id INTO target_auth_user_id
  FROM public.profiles
  WHERE id = worker_profile_id;

  IF target_auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Worker profile not found.';
  END IF;

  -- Update profiles
  UPDATE public.profiles
  SET
    full_name = full_name_param,
    phone = phone_param,
    email = email_param,
    address = address_param,
    joining_date = joining_date_param
  WHERE id = worker_profile_id;

  -- Update auth.users
  UPDATE auth.users
  SET
    email = email_param,
    encrypted_password = CASE WHEN password_param IS NOT NULL AND password_param <> '' THEN crypt(password_param, gen_salt('bf')) ELSE encrypted_password END,
    raw_user_meta_data = raw_user_meta_data || jsonb_build_object('full_name', full_name_param),
    updated_at = now()
  WHERE id = target_auth_user_id;

  -- Update auth.identities
  UPDATE auth.identities
  SET
    identity_data = jsonb_build_object('sub', target_auth_user_id, 'email', email_param),
    provider_id = email_param,
    updated_at = now()
  WHERE user_id = target_auth_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Secure RPC function for admin to toggle worker status (active/inactive)
CREATE OR REPLACE FUNCTION public.toggle_worker_status(
  worker_profile_id UUID,
  status_param TEXT
) RETURNS VOID AS $$
DECLARE
  target_auth_user_id UUID;
BEGIN
  -- Security check: only admins
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied: Only administrators can update worker status.';
  END IF;

  -- Update profile status
  UPDATE public.profiles
  SET status = status_param
  WHERE id = worker_profile_id
  RETURNING auth_user_id INTO target_auth_user_id;

  -- If status is inactive, ban the user from logging in
  IF status_param = 'inactive' THEN
    UPDATE auth.users
    SET banned_until = '3000-01-01 00:00:00+00'::timestamp with time zone
    WHERE id = target_auth_user_id;
  ELSE
    UPDATE auth.users
    SET banned_until = NULL
    WHERE id = target_auth_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Secure RPC function for admin dashboard statistics
CREATE OR REPLACE FUNCTION public.get_admin_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  total_workers INT;
  active_workers INT;
  total_sites INT;
  today_attendance INT;
  today_uploads INT;
  result JSONB;
BEGIN
  -- Security check
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied.';
  END IF;

  SELECT COUNT(*) INTO total_workers FROM public.profiles WHERE role = 'worker';
  SELECT COUNT(*) INTO active_workers FROM public.profiles WHERE role = 'worker' AND status = 'active';
  SELECT COUNT(*) INTO total_sites FROM public.sites;
  SELECT COUNT(*) INTO today_attendance FROM public.attendance WHERE attendance_date = CURRENT_DATE;
  SELECT COUNT(*) INTO today_uploads FROM public.photo_uploads WHERE uploaded_at::DATE = CURRENT_DATE;

  result := jsonb_build_object(
    'total_workers', total_workers,
    'active_workers', active_workers,
    'total_sites', total_sites,
    'today_attendance', today_attendance,
    'today_uploads', today_uploads
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- Attendance report views & helper functions
-- ==========================================

-- Monthly summary view per worker
CREATE OR REPLACE VIEW public.attendance_monthly_summary AS
SELECT
  worker_id,
  date_trunc('month', attendance_date)::date AS month_start,
  count(*) FILTER (WHERE status = 'present') AS present_days,
  count(*) FILTER (WHERE status = 'absent') AS absent_days,
  count(*) FILTER (WHERE status = 'half_day') AS half_day_count,
  count(DISTINCT attendance_date) AS total_records
FROM public.attendance
GROUP BY worker_id, month_start
ORDER BY worker_id, month_start;

-- Function to return last N months of monthly summaries for a worker
CREATE OR REPLACE FUNCTION public.get_attendance_reports(worker_uuid UUID, months INT)
RETURNS TABLE(
  month_start DATE,
  present_days INT,
  absent_days INT,
  half_day_count INT,
  total_records INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    date_trunc('month', attendance_date)::date AS month_start,
    count(*) FILTER (WHERE status = 'present') AS present_days,
    count(*) FILTER (WHERE status = 'absent') AS absent_days,
    count(*) FILTER (WHERE status = 'half_day') AS half_day_count,
    count(DISTINCT attendance_date) AS total_records
  FROM public.attendance
  WHERE worker_id = worker_uuid
    AND attendance_date >= (date_trunc('month', current_date) - (months - 1) * INTERVAL '1 month')
  GROUP BY month_start
  ORDER BY month_start DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Convenience wrappers for common ranges
CREATE OR REPLACE FUNCTION public.get_attendance_1_month(worker_uuid UUID)
RETURNS TABLE(month_start DATE, present_days INT, absent_days INT, half_day_count INT, total_records INT)
AS $$ BEGIN RETURN QUERY SELECT * FROM public.get_attendance_reports(worker_uuid, 1); END; $$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION public.get_attendance_6_months(worker_uuid UUID)
RETURNS TABLE(month_start DATE, present_days INT, absent_days INT, half_day_count INT, total_records INT)
AS $$ BEGIN RETURN QUERY SELECT * FROM public.get_attendance_reports(worker_uuid, 6); END; $$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION public.get_attendance_12_months(worker_uuid UUID)
RETURNS TABLE(month_start DATE, present_days INT, absent_days INT, half_day_count INT, total_records INT)
AS $$ BEGIN RETURN QUERY SELECT * FROM public.get_attendance_reports(worker_uuid, 12); END; $$ LANGUAGE plpgsql STABLE;

