-- ==========================================
-- SEED DATA & SETUP INSTRUCTIONS
-- ==========================================

-- 1. Insert Default Sites
INSERT INTO public.sites (site_name, site_code, client_name, address, latitude, longitude, description, status)
VALUES
  ('Downtown Plaza Refit', 'DP-101', 'Acme Corporation', '123 Main St, New York, NY 10001', 40.712776, -74.005974, 'Commercial electrical refitting, main switchboard installation, and ethernet line routing.', 'active'),
  ('Westside Residential Upgrade', 'WR-202', 'Jane Miller', '584 Oak Ave, Los Angeles, CA 90001', 34.052234, -118.243684, 'Complete home rewire, panel upgrade to 200A, and smart home lighting integration.', 'active'),
  ('North Industrial Warehouse', 'NIP-303', 'Logistics Plus', '8900 Industrial Pkwy, Chicago, IL 60601', 41.878113, -87.629798, 'High-bay LED lighting retrofit and emergency backup generator wiring.', 'paused'),
  ('East Coast Power Station', 'ECP-404', 'Metropolitan Grid', '101 Grid Road, Boston, MA 02108', 42.360082, -71.058880, 'Substation transformer maintenance and circuit breaker testing.', 'completed')
ON CONFLICT (site_code)
DO UPDATE SET
  site_name = EXCLUDED.site_name,
  client_name = EXCLUDED.client_name,
  address = EXCLUDED.address,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  description = EXCLUDED.description,
  status = EXCLUDED.status;