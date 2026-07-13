/**
 * Supabase client configuration and initialization for Workforce Manager application.
 */

const ENV_SUPABASE_URL = "https://ictjmuadjdlgnmbbhgtz.supabase.co";
const ENV_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImljdGptdWFkamRsZ25tYmJoZ3R6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4NDQ1MjIsImV4cCI6MjA5NzQyMDUyMn0.y8dEJEYMTbAiVfjr0Hfew3Z-H0T5CRVCT_uXUisreKc";

function getSupabaseConfig() {
  const savedUrl = localStorage.getItem('SUPABASE_URL');
  const savedKey = localStorage.getItem('SUPABASE_ANON_KEY');

  return {
    url: savedUrl !== null ? savedUrl.trim() : ENV_SUPABASE_URL,
    key: savedKey !== null ? savedKey.trim() : ENV_SUPABASE_ANON_KEY
  };
}

function isSupabaseConfigured() {
  const { url, key } = getSupabaseConfig();
  return !!(url && key && url.startsWith('https://') && key.length > 20);
}

function saveSupabaseConfig(url, key) {
  if (!url || !key) return false;
  localStorage.setItem('SUPABASE_URL', url.trim());
  localStorage.setItem('SUPABASE_ANON_KEY', key.trim());
  return true;
}

function clearSupabaseConfig() {
  localStorage.removeItem('SUPABASE_URL');
  localStorage.removeItem('SUPABASE_ANON_KEY');
}

// Global client instance
let supabaseClient = null;

const { url, key } = getSupabaseConfig();
if (url && key && typeof window.supabase !== 'undefined') {
  try {
    supabaseClient = window.supabase.createClient(url, key);
  } catch (error) {
    console.error("Failed to initialize Supabase client:", error);
  }
}

// Export to window scope
window.supabaseInstance = supabaseClient;
window.getSupabaseConfig = getSupabaseConfig;
window.isSupabaseConfigured = isSupabaseConfigured;
window.saveSupabaseConfig = saveSupabaseConfig;
window.clearSupabaseConfig = clearSupabaseConfig;
