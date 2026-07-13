/**
 * Tejal Enterprises Common Javascript Utilities
 * Handles Auth Guarding, Layout Injections, Toast Notifications, and Geolocation/Camera adapters.
 */

// Helper to determine path prefix for multi-folder navigation
const isSubDir = window.location.pathname.includes('/owner/') || window.location.pathname.includes('/worker/');
const pathPrefix = isSubDir ? '../' : '';

// 1. Toast Notifications System
function showToast(message, type = 'success') {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    container.className = 'fixed top-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-full px-4 md:px-0';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  // Dynamic tailwind styles for premium looks
  const bgStyles = type === 'success' ? 'bg-emerald-500' : type === 'error' ? 'bg-rose-500' : 'bg-amber-500';
  const icon = type === 'success' ? 'check-circle' : type === 'error' ? 'alert-triangle' : 'info';

  toast.className = `flex items-center gap-3 ${bgStyles} text-white px-4 py-3 rounded-lg shadow-xl transform translate-y-2 opacity-0 transition-all duration-300 ease-out`;
  toast.innerHTML = `
    <i data-lucide="${icon}" class="w-5 h-5 flex-shrink-0"></i>
    <span class="font-medium text-sm">${message}</span>
  `;

  container.appendChild(toast);
  if (typeof lucide !== 'undefined') lucide.createIcons();

  // Animate in
  setTimeout(() => {
    toast.classList.remove('translate-y-2', 'opacity-0');
  }, 10);

  // Auto remove
  setTimeout(() => {
    toast.classList.add('opacity-0', 'scale-95');
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

// 2. Auth Guarding & Redirection
async function checkAuthAndRedirect() {
  const isLoginPage = window.location.pathname === '/' || window.location.pathname.endsWith('index.html');

  if (!window.supabaseInstance) {
    if (!isLoginPage) {
      window.location.href = pathPrefix + 'index.html';
    }
    return;
  }

  const { data: { session }, error } = await window.supabaseInstance.auth.getSession();

  if (error || !session) {
    if (!isLoginPage) {
      window.location.href = pathPrefix + 'index.html';
    }
    return;
  }

  let profile;
  try {
    profile = JSON.parse(sessionStorage.getItem('user_profile'));
  } catch (err) {
    profile = null;
  }

  if (!profile || profile.auth_user_id !== session.user.id) {
    const { data, error: profileError } = await window.supabaseInstance
      .from('profiles')
      .select('*')
      .eq('auth_user_id', session.user.id)
      .maybeSingle();

    if (profileError || !data) {
      await window.supabaseInstance.auth.signOut();
      sessionStorage.clear();
      if (!isLoginPage) {
        window.location.href = pathPrefix + 'index.html';
      }
      return;
    }

    profile = data;
    sessionStorage.setItem('user_profile', JSON.stringify(profile));
  }

  if (profile.status === 'inactive') {
    showToast("This account is inactive. Please contact the administrator.", "error");
    await window.supabaseInstance.auth.signOut();
    sessionStorage.clear();
    setTimeout(() => {
      window.location.href = pathPrefix + 'index.html';
    }, 2000);
    return;
  }

  if (isLoginPage) {
    if (profile.role === 'admin') {
      window.location.href = 'owner/dashboard.html';
    } else {
      window.location.href = 'worker/dashboard.html';
    }
    return;
  }

  const isOwnerPath = window.location.pathname.includes('/owner/');
  const isWorkerPath = window.location.pathname.includes('/worker/');

  if (profile.role === 'worker') {
    if (isOwnerPath) {
      window.location.href = pathPrefix + 'worker/dashboard.html';
      return;
    }
    if (isWorkerPath) {
      return;
    }
    window.location.href = pathPrefix + 'worker/dashboard.html';
    return;
  }

  if (profile.role === 'admin') {
    if (isWorkerPath) {
      window.location.href = pathPrefix + 'owner/dashboard.html';
      return;
    }
    if (isOwnerPath) {
      return;
    }
    window.location.href = pathPrefix + 'owner/dashboard.html';
    return;
  }
}

// 3. Injected Navigation Layouts
function injectNavigation() {
  const profileJson = sessionStorage.getItem('user_profile');
  if (!profileJson) return;
  const profile = JSON.parse(profileJson);
  const currentPath = window.location.pathname;

  if (profile.role === 'admin') {
    // Inject Admin Side Navigation and Topbar
    const header = document.createElement('header');
    header.className = 'w-full bg-slate-900 text-white z-40';
    
    // Admin Topbar
    header.innerHTML = `
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <div class="flex items-center gap-3">
            <div class="bg-blue-600 p-2 rounded-lg text-white">
              <i data-lucide="zap" class="w-6 h-6"></i>
            </div>
            <span class="font-bold text-lg tracking-wider text-white">Tejal Enterprises</span>
            <span class="hidden sm:inline bg-slate-800 text-xs px-2.5 py-0.5 rounded-full font-semibold border border-slate-700 text-slate-300">ADMIN</span>
          </div>
          
          <div class="flex items-center gap-4">
            <div class="hidden md:flex flex-col text-right">
              <span class="text-sm font-semibold text-slate-200">${profile.full_name}</span>
              <span class="text-xs text-slate-400">${profile.email}</span>
            </div>
            
            <button onclick="handleSignOut()" class="text-slate-400 hover:text-white hover:bg-slate-800 p-2 rounded-lg transition" title="Logout">
              <i data-lucide="log-out" class="w-5 h-5"></i>
            </button>
          </div>
        </div>
      </div>
      
      <!-- Sub-navigation links for owner -->
      <div class="bg-slate-800 border-t border-slate-700">
        <div class="max-w-7xl mx-auto px-4 overflow-x-auto whitespace-nowrap flex gap-1 sm:gap-2 py-1 scrollbar-none">
          <a href="${pathPrefix}owner/dashboard.html" class="nav-link py-2.5 px-3.5 rounded-md text-sm font-medium transition flex items-center gap-2 ${currentPath.includes('dashboard') ? 'bg-slate-950 text-blue-400' : 'text-slate-300 hover:bg-slate-700 hover:text-white'}">
            <i data-lucide="layout-dashboard" class="w-4 h-4"></i> Dashboard
          </a>
          <a href="${pathPrefix}owner/workers.html" class="nav-link py-2.5 px-3.5 rounded-md text-sm font-medium transition flex items-center gap-2 ${currentPath.includes('workers') ? 'bg-slate-950 text-blue-400' : 'text-slate-300 hover:bg-slate-700 hover:text-white'}">
            <i data-lucide="users" class="w-4 h-4"></i> Workers
          </a>
          <a href="${pathPrefix}owner/sites.html" class="nav-link py-2.5 px-3.5 rounded-md text-sm font-medium transition flex items-center gap-2 ${currentPath.includes('sites') ? 'bg-slate-950 text-blue-400' : 'text-slate-300 hover:bg-slate-700 hover:text-white'}">
            <i data-lucide="map-pin" class="w-4 h-4"></i> Sites
          </a>
          <a href="${pathPrefix}owner/attendance.html" class="nav-link py-2.5 px-3.5 rounded-md text-sm font-medium transition flex items-center gap-2 ${currentPath.includes('attendance') ? 'bg-slate-950 text-blue-400' : 'text-slate-300 hover:bg-slate-700 hover:text-white'}">
            <i data-lucide="calendar" class="w-4 h-4"></i> Attendance
          </a>
          <a href="${pathPrefix}owner/locations.html" class="nav-link py-2.5 px-3.5 rounded-md text-sm font-medium transition flex items-center gap-2 ${currentPath.includes('locations') ? 'bg-slate-950 text-blue-400' : 'text-slate-300 hover:bg-slate-700 hover:text-white'}">
            <i data-lucide="navigation" class="w-4 h-4"></i> Live Map
          </a>
          <a href="${pathPrefix}owner/photos.html" class="nav-link py-2.5 px-3.5 rounded-md text-sm font-medium transition flex items-center gap-2 ${currentPath.includes('photos') ? 'bg-slate-950 text-blue-400' : 'text-slate-300 hover:bg-slate-700 hover:text-white'}">
            <i data-lucide="image" class="w-4 h-4"></i> Photo Feed
          </a>
        </div>
      </div>
    `;
    
    document.body.prepend(header);
  } else if (profile.role === 'worker') {
    // Inject Worker Topbar
    const header = document.createElement('header');
    header.className = 'w-full bg-slate-900 text-white sticky top-0 z-40 shadow-md';
    header.innerHTML = `
      <div class="px-4 py-3 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="bg-blue-600 p-1.5 rounded-md text-white">
            <i data-lucide="zap" class="w-5 h-5"></i>
          </div>
          <span class="font-bold tracking-tight text-white">Tejal Enterprises</span>
        </div>
        <div class="flex items-center gap-3">
          <span class="text-xs font-semibold bg-slate-800 border border-slate-700 text-slate-300 px-2 py-0.5 rounded-full">${profile.full_name.split(' ')[0]}</span>
          <button onclick="handleSignOut()" class="text-slate-400 hover:text-white p-1 rounded-md transition" title="Logout">
            <i data-lucide="log-out" class="w-5 h-5"></i>
          </button>
        </div>
      </div>
    `;
    document.body.prepend(header);

    // Inject Worker Bottom Navigation Bar for Mobile-first feeling
    const footer = document.createElement('nav');
    footer.className = 'fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 shadow-2xl z-50 md:max-w-md md:mx-auto md:rounded-t-2xl';
    footer.innerHTML = `
      <div class="flex items-center justify-around py-2">
        <a href="${pathPrefix}worker/dashboard.html" class="flex flex-col items-center gap-0.5 px-3 py-1 rounded-lg transition ${currentPath.includes('dashboard') ? 'text-blue-600' : 'text-slate-400 hover:text-slate-700'}">
          <i data-lucide="home" class="w-6 h-6"></i>
          <span class="text-[10px] font-semibold">Home</span>
        </a>
        <a href="${pathPrefix}worker/attendance.html" class="flex flex-col items-center gap-0.5 px-3 py-1 rounded-lg transition ${currentPath.includes('attendance') ? 'text-blue-600' : 'text-slate-400 hover:text-slate-700'}">
          <i data-lucide="calendar" class="w-6 h-6"></i>
          <span class="text-[10px] font-semibold">Register</span>
        </a>
        <a href="${pathPrefix}worker/upload.html" class="flex flex-col items-center gap-0.5 px-3 py-1 rounded-lg transition ${currentPath.includes('upload') ? 'text-blue-600' : 'text-slate-400 hover:text-slate-700'}">
          <i data-lucide="camera" class="w-6 h-6"></i>
          <span class="text-[10px] font-semibold">Upload</span>
        </a>
        <a href="${pathPrefix}worker/profile.html" class="flex flex-col items-center gap-0.5 px-3 py-1 rounded-lg transition ${currentPath.includes('profile') ? 'text-blue-600' : 'text-slate-400 hover:text-slate-700'}">
          <i data-lucide="user" class="w-6 h-6"></i>
          <span class="text-[10px] font-semibold">Profile</span>
        </a>
      </div>
    `;
    document.body.appendChild(footer);
    
    // Add extra padding to the bottom of the body so bottom navbar doesn't cover content
    document.body.classList.add('pb-20');
  }

  // Refresh icons
  if (typeof lucide !== 'undefined') lucide.createIcons();
}

// 4. Geolocation API Helper
function getCurrentLocation() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error("Your browser does not support geolocation."));
      return;
    }

    const options = {
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 0
    };

    navigator.geolocation.getCurrentPosition(
      (position) => {
        resolve({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy
        });
      },
      (error) => {
        let msg = "Failed to acquire location. ";
        switch (error.code) {
          case error.PERMISSION_DENIED:
            msg += "Please enable location services in your browser settings.";
            break;
          case error.POSITION_UNAVAILABLE:
            msg += "Location information is unavailable.";
            break;
          case error.TIMEOUT:
            msg += "Location request timed out.";
            break;
        }
        reject(new Error(msg));
      },
      options
    );
  });
}

// 5. Sign Out Handler
async function handleSignOut() {
  if (!window.supabaseInstance) return;

  try {
    const { error } = await window.supabaseInstance.auth.signOut();
    if (error) throw error;
  } catch (error) {
    console.error("Signout error:", error);
  } finally {
    sessionStorage.clear();
    showToast("Logged out successfully.");
    setTimeout(() => {
      window.location.href = pathPrefix + 'index.html';
    }, 500);
  }
}

// Initialize Auth Checking & Navbar Injection
document.addEventListener('DOMContentLoaded', async () => {
  // Add a nice fading skeleton screen until loaded
  document.body.style.opacity = '0.9';
  await checkAuthAndRedirect();
  injectNavigation();
  document.body.style.opacity = '1';
});
