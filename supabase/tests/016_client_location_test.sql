-- supabase test db --linked     (runs in a transaction, rolled back)
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(9);

SELECT has_column('public', 'hospital_clients', 'latitude', 'latitude exists');
SELECT has_column('public', 'hospital_clients', 'longitude', 'longitude exists');
SELECT has_column('public', 'hospital_clients', 'location_set_at', 'location_set_at exists');
SELECT has_column('public', 'hospital_clients', 'location_set_by', 'location_set_by exists');

INSERT INTO public.hospital_clients
  (id, name, address, division, contact_person_name,
   contact_person_designation, contact_person_phone, district, genre)
VALUES ('c0160000-0000-0000-0000-000000000001', 'Pin Test', 'Test road',
        'Dhaka', 'X', 'Y', '0', 'Dhaka', 'General');

SELECT lives_ok(
  $$UPDATE public.hospital_clients SET latitude = 23.75, longitude = 90.38
     WHERE id = 'c0160000-0000-0000-0000-000000000001'$$,
  'a pin inside Bangladesh is accepted');

SELECT throws_ok(
  $$UPDATE public.hospital_clients SET latitude = 51.5, longitude = -0.1
     WHERE id = 'c0160000-0000-0000-0000-000000000001'$$,
  '23514', NULL, 'a pin outside Bangladesh is refused');

SELECT throws_ok(
  $$UPDATE public.hospital_clients SET longitude = NULL
     WHERE id = 'c0160000-0000-0000-0000-000000000001'$$,
  '23514', NULL, 'one coordinate alone is refused');

-- The bridge's update: only fills an empty pin.
SELECT is(
  (WITH u AS (UPDATE public.hospital_clients SET latitude = 24, longitude = 91
               WHERE id = 'c0160000-0000-0000-0000-000000000001'
                 AND latitude IS NULL RETURNING 1)
   SELECT count(*)::int FROM u),
  0, 'an existing pin is not overwritten');

-- A signed-in non-admin (no profile → level 0) may not change a pin.
SELECT set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000ff","role":"authenticated"}', true);
SELECT throws_ok(
  $$UPDATE public.hospital_clients SET latitude = NULL, longitude = NULL
     WHERE id = 'c0160000-0000-0000-0000-000000000001'$$,
  '42501', NULL, 'only an admin can change the pin');

SELECT * FROM finish();
ROLLBACK;
