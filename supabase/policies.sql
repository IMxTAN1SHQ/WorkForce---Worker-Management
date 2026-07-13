-- Enable RLS on all public tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.location_logs ENABLE ROW LEVEL SECURITY;

-- Drop old policies first so the script can be reapplied safely
DROP POLICY IF EXISTS admin_all_profiles ON public.profiles;
DROP POLICY IF EXISTS worker_read_profile ON public.profiles;
DROP POLICY IF EXISTS worker_update_profile ON public.profiles;
DROP POLICY IF EXISTS admin_all_sites ON public.sites;
DROP POLICY IF EXISTS worker_read_sites ON public.sites;
DROP POLICY IF EXISTS admin_all_assignments ON public.worker_assignments;
DROP POLICY IF EXISTS worker_read_assignments ON public.worker_assignments;
DROP POLICY IF EXISTS admin_all_attendance ON public.attendance;
DROP POLICY IF EXISTS worker_read_attendance ON public.attendance;
DROP POLICY IF EXISTS worker_insert_attendance ON public.attendance;
DROP POLICY IF EXISTS worker_update_attendance ON public.attendance;
DROP POLICY IF EXISTS admin_all_photos ON public.photo_uploads;
DROP POLICY IF EXISTS worker_read_photos ON public.photo_uploads;
DROP POLICY IF EXISTS worker_insert_photos ON public.photo_uploads;
DROP POLICY IF EXISTS admin_all_locations ON public.location_logs;
DROP POLICY IF EXISTS worker_read_locations ON public.location_logs;
DROP POLICY IF EXISTS worker_insert_locations ON public.location_logs;
DROP POLICY IF EXISTS admin_all_storage ON storage.objects;
DROP POLICY IF EXISTS worker_insert_storage ON storage.objects;
DROP POLICY IF EXISTS worker_read_storage ON storage.objects;

-- Helper function to check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
      AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if current user is worker
CREATE OR REPLACE FUNCTION public.is_worker()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
      AND role = 'worker'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user's profile ID
CREATE OR REPLACE FUNCTION public.get_my_profile_id()
RETURNS UUID AS $$
DECLARE
  pid UUID;
BEGIN
  SELECT id INTO pid FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
  RETURN pid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==========================================
-- POLICIES FOR profiles
-- ==========================================

-- Admins can do everything
CREATE POLICY admin_all_profiles ON public.profiles
  FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Workers can read their own profile
CREATE POLICY worker_read_profile ON public.profiles
  FOR SELECT TO authenticated USING (auth.uid() = auth_user_id AND status = 'active');

-- Workers can update their own profile details
CREATE POLICY worker_update_profile ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = auth_user_id AND status = 'active')
  WITH CHECK (auth.uid() = auth_user_id AND status = 'active');


-- ==========================================
-- POLICIES FOR sites
-- ==========================================

-- Admins can select sites
CREATE POLICY admin_select_sites ON public.sites
  FOR SELECT TO authenticated USING (public.is_admin());

-- Admins can insert new sites
CREATE POLICY admin_insert_sites ON public.sites
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());

-- Admins can update sites
CREATE POLICY admin_update_sites ON public.sites
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Admins can delete sites
CREATE POLICY admin_delete_sites ON public.sites
  FOR DELETE TO authenticated USING (public.is_admin());

-- Workers can read active/paused/completed sites
CREATE POLICY worker_read_sites ON public.sites
  FOR SELECT TO authenticated USING (public.is_worker());


-- ==========================================
-- POLICIES FOR worker_assignments
-- ==========================================

-- Admins can do everything
CREATE POLICY admin_all_assignments ON public.worker_assignments
  FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Workers can read their own assignments
CREATE POLICY worker_read_assignments ON public.worker_assignments
  FOR SELECT TO authenticated USING (worker_id = public.get_my_profile_id());


-- ==========================================
-- POLICIES FOR attendance
-- ==========================================

-- Admins can do everything
CREATE POLICY admin_all_attendance ON public.attendance
  FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Workers can read their own attendance records
CREATE POLICY worker_read_attendance ON public.attendance
  FOR SELECT TO authenticated USING (worker_id = public.get_my_profile_id());

-- Workers can insert their own attendance (check in / check out)
CREATE POLICY worker_insert_attendance ON public.attendance
  FOR INSERT TO authenticated WITH CHECK (worker_id = public.get_my_profile_id());

-- Workers can update their own check-out record
CREATE POLICY worker_update_attendance ON public.attendance
  FOR UPDATE TO authenticated USING (worker_id = public.get_my_profile_id())
  WITH CHECK (worker_id = public.get_my_profile_id());


-- ==========================================
-- POLICIES FOR photo_uploads
-- ==========================================

-- Admins can do everything
CREATE POLICY admin_all_photos ON public.photo_uploads
  FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Workers can read their own uploaded photos
CREATE POLICY worker_read_photos ON public.photo_uploads
  FOR SELECT TO authenticated USING (worker_id = public.get_my_profile_id());

-- Workers can insert their own photo uploads
CREATE POLICY worker_insert_photos ON public.photo_uploads
  FOR INSERT TO authenticated WITH CHECK (worker_id = public.get_my_profile_id());


-- ==========================================
-- POLICIES FOR location_logs
-- ==========================================

-- Admins can do everything
CREATE POLICY admin_all_locations ON public.location_logs
  FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Workers can read their own location logs
CREATE POLICY worker_read_locations ON public.location_logs
  FOR SELECT TO authenticated USING (worker_id = public.get_my_profile_id());

-- Workers can insert their own location logs
CREATE POLICY worker_insert_locations ON public.location_logs
  FOR INSERT TO authenticated WITH CHECK (worker_id = public.get_my_profile_id());


-- ==========================================
-- STORAGE POLICIES (site-photos bucket)
-- ==========================================

-- Ensure storage bucket exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('site-photos', 'site-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Admins can do everything with storage objects
CREATE POLICY admin_all_storage ON storage.objects
  FOR ALL TO authenticated USING (bucket_id = 'site-photos' AND public.is_admin())
  WITH CHECK (bucket_id = 'site-photos' AND public.is_admin());

-- Workers can upload photos to the bucket
CREATE POLICY worker_insert_storage ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (
    bucket_id = 'site-photos' AND
    public.is_worker()
  );

-- Workers can view photos (since it is a public bucket, we also allow read access)
CREATE POLICY worker_read_storage ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'site-photos');
