# Tejal Enetrprises - Electrician Workforce Manager

Tejal Enterprises is a lightweight, production-ready, mobile-first workforce management web application designed for small-to-medium electrician businesses. It replaces paper registers with a modern digital system where field workers can mark attendance, upload on-site work photos, and tag their GPS location, while business owners can manage workers, configure sites, and audit field activity.

---

## ⚡ Tech Stack

- **Frontend**: HTML5, CSS3, Vanilla JavaScript, Tailwind CSS (via CDN)
- **Mapping**: Leaflet.js, OpenStreetMap (no paid API keys required)
- **Icons**: Lucide Icons
- **Backend / Database**: Supabase
  - Database: PostgreSQL
  - Authentication: Supabase Auth
  - Storage: Supabase Storage Buckets (for job site photos)
  - Security: Row Level Security (RLS) policies

---

## 📁 Folder Structure

```text
workforce-manager/
├── index.html                  # Main Login Page
├── owner/
│   ├── dashboard.html          # Admin Dashboard (Stats, Feed)
│   ├── workers.html            # Admin Worker CRUD & Status Control
│   ├── sites.html              # Admin Job Site CRUD & Assignments
│   ├── attendance.html          # Admin Attendance History & Filters
│   ├── locations.html          # Admin Leaflet Live Map Pins
│   └── photos.html             # Admin Photo Audit Feed
│
├── worker/
│   ├── dashboard.html          # Worker Dashboard (Assigned Site, Status)
│   ├── attendance.html          # Worker Check-In / Check-Out
│   ├── upload.html             # Worker Job Photo & Location Tagging
│   └── profile.html            # Worker Profile Details & Editor
│
├── assets/
│   ├── css/
│   │   └── styles.css          # Map pins, scrollbars, and fonts configuration
│   └── js/
│       ├── supabase-client.js  # Supabase client initializer
│       └── common.js           # Security guards, Dynamic Navs, Toasts
│
├── supabase/
│   ├── schema.sql              # Database Tables & Admin-only RPCs
│   ├── policies.sql            # RLS Policies & Bucket Creation
│   └── seed.sql                # Default Sites & Admin Setup Guide
│
└── README.md                   # Installation & Setup Documentation
```

---

## 🚀 Setup Instructions

Follow these step-by-step instructions to get Tejal Enterprises connected to your own Supabase instance.

### 1. Database Initialization
Go to your **Supabase Dashboard** -> **SQL Editor** and run the files in the following order:

1. **[schema.sql](supabase/schema.sql)**: Run the entire schema script. This establishes the tables (`profiles`, `sites`, `worker_assignments`, `attendance`, `photo_uploads`, `location_logs`), triggers, and the core worker creation/modification RPCs.
2. **[policies.sql](supabase/policies.sql)**: Run this script to enable Row Level Security (RLS) on all tables and storage objects, and configuration policies.
3. **[seed.sql](supabase/seed.sql)**: Run this to seed default construction sites.

### 2. Configure Storage Bucket
In your Supabase Dashboard:
1. Go to **Storage**.
2. Ensure there is a bucket named `site-photos` (the SQL policy script creates it automatically, but if not, click "New Bucket", name it `site-photos`, and make it **Public**).
3. The RLS policies in `policies.sql` automatically restrict write operations to workers and full CRUD to admins.

### 3. Create the Administrator Account
Since worker accounts are created by the admin inside the app, the first administrator account must be established manually:

1. Go to **Authentication** -> **Users** -> click **Add User** -> **Create User**.
2. Enter an email (e.g., `admin@electrician.com`) and a secure password.
3. In the **SQL Editor**, run the following query to elevate their role to `admin`:
   ```sql
   UPDATE public.profiles
   SET role = 'admin'
   WHERE email = 'admin@electrician.com';
   ```
4. Update the user metadata in Auth:
   ```sql
   UPDATE auth.users
   SET raw_user_meta_data = raw_user_meta_data || '{"role": "admin"}'::jsonb
   WHERE email = 'admin@electrician.com';
   ```

### 4. Connect Frontend to Supabase
You can connect the app in two ways:

#### Option A: Portable Config (Recommended for Local Testing)
When you open `index.html` for the first time, click the **Settings Cog icon** in the top right. Paste your **Supabase URL** and **Anon Key** and click **Save & Connect**. The app stores them in your browser's local storage.

#### Option B: Hardcoded Production Variables
Edit the [supabase-client.js](file:///C:/Users/ADMN/.gemini/antigravity/scratch/workforce-manager/assets/js/supabase-client.js) file and insert your credentials directly:
```javascript
const ENV_SUPABASE_URL = "https://your-project.supabase.co";
const ENV_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";
```

### 5. Authentication Setup
This project is now production-ready and does not automatically seed demo users.
Create your first administrator account manually in Supabase Auth, then assign the `admin` role in `public.profiles` and update the user's `raw_user_meta_data` to include `{"role":"admin"}`.

Example:
```sql
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'admin@electrician.com';

UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data || '{"role": "admin"}'::jsonb
WHERE email = 'admin@electrician.com';
```

---

## 💻 Local Running Guide

To use the geolocation and camera features, the browser requires the page to be served over a secure origin (`https://` or `localhost`).

Run a local server in the project directory:

**Using Node / npm**:
```bash
npx serve
```
Then open: `http://localhost:3000`

**Using Python**:
```bash
python -m http.server 8000
```
Then open: `http://localhost:8000`

---

## ☁️ Deployment Guide

### Vercel
1. Install Vercel CLI or connect your GitHub repository to Vercel.
2. In the project root, run:
   ```bash
   vercel
   ```
3. Set your project to import as a standard static app. Vercel automatically deploys the HTML files.

### Netlify
1. Log in to Netlify and click **Add new site** -> **Deploy manually**.
2. Drag and drop the `workforce-manager/` folder into the Netlify UI.
3. Once completed, your web app is live!
