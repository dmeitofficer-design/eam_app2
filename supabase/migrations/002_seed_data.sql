-- ============================================================
-- EAM Platform - Seed Data (Development / Testing)
-- Run AFTER 001_initial_schema.sql
-- ============================================================

-- ── Create test users via Supabase Auth ─────────────────────
-- Run these in the Supabase Dashboard → Authentication → Users
-- OR via the service-role API. The profiles are auto-created
-- by the handle_new_user() trigger.
--
-- Admin:    admin@dme.com      / Admin1234!
-- Viewer:   viewer@dme.com     / View1234!
--
-- To set role to admin after creation:
--   UPDATE public.profiles SET role = 'admin'
--   WHERE id = '<admin-user-uuid>';

-- ── Hospital Clients ─────────────────────────────────────────

INSERT INTO public.hospital_clients
  (id, name, address, division, facility_type,
   contact_person_name, contact_person_designation, contact_person_phone)
VALUES
  (
    'a1000000-0000-0000-0000-000000000001',
    'Dhaka Medical College Hospital',
    'Bakshibazar, Dhaka-1000',
    'Dhaka', 'Hospital',
    'Prof. Dr. Kamal Hossain', 'Director', '+8801712345678'
  ),
  (
    'a1000000-0000-0000-0000-000000000002',
    'Ibn Sina Hospital Dhanmondi',
    'House 48, Road 9/A, Dhanmondi, Dhaka-1209',
    'Dhaka', 'Hospital',
    'Dr. Nasrin Sultana', 'Deputy Director', '+8801812345678'
  ),
  (
    'a1000000-0000-0000-0000-000000000003',
    'Popular Diagnostic Centre Chittagong',
    'Nasirabad Housing Society, Chittagong-4000',
    'Chattogram', 'Diagnostic Center',
    'Mr. Rafiqul Islam', 'General Manager', '+8801912345678'
  ),
  (
    'a1000000-0000-0000-0000-000000000004',
    'Green Life Medical College Hospital',
    '32 Bir Uttam Qazi Nuruzzaman Sarak, Dhaka-1205',
    'Dhaka', 'Hospital',
    'Dr. Farzana Ahmed', 'Chief Medical Officer', '+8801612345678'
  ),
  (
    'a1000000-0000-0000-0000-000000000005',
    'Rajshahi Medical College Hospital',
    'Rajshahi Medical College Road, Rajshahi-6000',
    'Rajshahi', 'Hospital',
    'Dr. Abdul Mannan', 'Superintendent', '+8801512345678'
  );

-- ── Installed Machines ───────────────────────────────────────

INSERT INTO public.installed_machines
  (id, hospital_id, machine_type, brand, model, serial_number,
   installation_date, warranty_period, notes)
VALUES
  -- Dhaka Medical
  (
    'b2000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000001',
    'X-ray', 'DRGEM', 'GXR-S', 'SN-2024-001',
    '2024-01-15', 24,
    'Wall-mounted DR unit, Room 204'
  ),
  (
    'b2000000-0000-0000-0000-000000000002',
    'a1000000-0000-0000-0000-000000000001',
    'Ultrasonogram', 'Mindray', 'DC-80', 'SN-2023-112',
    '2023-06-20', 36,
    'Portable ultrasound, Emergency Dept'
  ),
  -- Ibn Sina
  (
    'b2000000-0000-0000-0000-000000000003',
    'a1000000-0000-0000-0000-000000000002',
    'FPD', 'DRGEM', 'GC-90A', 'SN-2022-045',
    '2022-03-10', 24,
    'Flat Panel Detector system, Radiology dept'
  ),
  (
    'b2000000-0000-0000-0000-000000000004',
    'a1000000-0000-0000-0000-000000000002',
    'OPG', 'DRGEM', 'GX-DC10', 'SN-2024-078',
    '2024-04-05', 36,
    'Dental panoramic unit, Dental OPD'
  ),
  -- Popular Diagnostic
  (
    'b2000000-0000-0000-0000-000000000005',
    'a1000000-0000-0000-0000-000000000003',
    'X-ray', 'DRGEM', 'GXR-M', 'SN-2023-201',
    '2023-11-01', 12,
    'Mobile X-ray, ICU floor'
  ),
  -- Green Life
  (
    'b2000000-0000-0000-0000-000000000006',
    'a1000000-0000-0000-0000-000000000004',
    'Printer', 'Fujifilm', 'DryPix Lite', 'SN-2024-033',
    '2024-02-28', 24,
    'Dry laser film printer, PACS room'
  ),
  -- Rajshahi Medical
  (
    'b2000000-0000-0000-0000-000000000007',
    'a1000000-0000-0000-0000-000000000005',
    'X-ray', 'DRGEM', 'GXR-L', 'SN-2021-099',
    '2021-08-12', 24,
    'High-capacity DR — warranty EXPIRED for testing'
  );

-- ── Installing Engineers ──────────────────────────────────────

INSERT INTO public.installing_engineers
  (machine_id, name, designation, status)
VALUES
  ('b2000000-0000-0000-0000-000000000001', 'Md. Rakib Hasan',   'Senior Biomedical Engineer', 'Available'),
  ('b2000000-0000-0000-0000-000000000001', 'Farhana Begum',     'Biomedical Technician',       'On Assignment'),
  ('b2000000-0000-0000-0000-000000000002', 'Shuvo Chakraborty', 'Field Service Engineer',      'Available'),
  ('b2000000-0000-0000-0000-000000000003', 'Tanvir Ahmed',      'Lead Installation Engineer',  'On Leave'),
  ('b2000000-0000-0000-0000-000000000004', 'Nadia Islam',       'Biomedical Engineer',         'Available'),
  ('b2000000-0000-0000-0000-000000000005', 'Imran Chowdhury',   'Service Engineer',            'Available'),
  ('b2000000-0000-0000-0000-000000000006', 'Priya Das',         'Technical Specialist',        'On Assignment'),
  ('b2000000-0000-0000-0000-000000000007', 'Kawsar Ali',        'Senior Field Engineer',       'Available');
