-- ============================================================
-- EAM Platform - Migration 003
-- Adds: district to hospital_clients
--       genre to hospital_clients  
--       installation_engineer_name to installed_machines
--       machine_parts table
-- ============================================================

-- ── hospital_clients additions ───────────────────────────────

ALTER TABLE public.hospital_clients
  ADD COLUMN IF NOT EXISTS district TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS genre    TEXT NOT NULL DEFAULT 'General';

-- Remove the default after adding (so it's required going forward)
ALTER TABLE public.hospital_clients
  ALTER COLUMN district DROP DEFAULT,
  ALTER COLUMN genre    DROP DEFAULT;

-- ── installed_machines additions ─────────────────────────────

ALTER TABLE public.installed_machines
  ADD COLUMN IF NOT EXISTS installation_engineer_name TEXT;

-- ── machine_parts table ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.machine_parts (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  machine_id    UUID NOT NULL REFERENCES public.installed_machines(id) ON DELETE CASCADE,
  part_name     TEXT NOT NULL,
  serial_number TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_machine_parts_machine_id
  ON public.machine_parts(machine_id);

-- RLS for machine_parts
ALTER TABLE public.machine_parts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All authenticated users can read parts"
  ON public.machine_parts FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Admins can insert parts"
  ON public.machine_parts FOR INSERT
  TO authenticated WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "Admins can update parts"
  ON public.machine_parts FOR UPDATE
  TO authenticated USING (public.get_user_role() = 'admin');

CREATE POLICY "Admins can delete parts"
  ON public.machine_parts FOR DELETE
  TO authenticated USING (public.get_user_role() = 'admin');

-- ── machine_models config table (for admin to manage types) ──
-- Admins can add new machine genres/brands/models here and the
-- Add Client form will fetch them dynamically.

CREATE TABLE IF NOT EXISTS public.machine_config (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  config_type TEXT NOT NULL,   -- 'genre' | 'brand' | 'machine_type'
  value       TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (config_type, value)
);

ALTER TABLE public.machine_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All authenticated users can read config"
  ON public.machine_config FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Admins can manage config"
  ON public.machine_config FOR ALL
  TO authenticated USING (public.get_user_role() = 'admin');

-- Seed default genres
INSERT INTO public.machine_config (config_type, value, sort_order) VALUES
  ('genre', 'General',     1),
  ('genre', 'Radiology',   2),
  ('genre', 'Cardiology',  3),
  ('genre', 'Oncology',    4),
  ('genre', 'Pathology',   5),
  ('genre', 'Neurology',   6),
  ('genre', 'Orthopedics', 7),
  ('genre', 'Dental',      8)
ON CONFLICT (config_type, value) DO NOTHING;

-- Seed default machine types
INSERT INTO public.machine_config (config_type, value, sort_order) VALUES
  ('machine_type', 'X-ray',         1),
  ('machine_type', 'Ultrasonogram', 2),
  ('machine_type', 'FPD',           3),
  ('machine_type', 'Printer',       4),
  ('machine_type', 'OPG',           5),
  ('machine_type', 'CT Scanner',    6),
  ('machine_type', 'MRI',           7),
  ('machine_type', 'ECG',           8)
ON CONFLICT (config_type, value) DO NOTHING;

-- Seed default brands
INSERT INTO public.machine_config (config_type, value, sort_order) VALUES
  ('brand', 'DRGEM',      1),
  ('brand', 'GE Healthcare', 2),
  ('brand', 'Siemens',    3),
  ('brand', 'Philips',    4),
  ('brand', 'Mindray',    5),
  ('brand', 'Fujifilm',   6),
  ('brand', 'Samsung',    7),
  ('brand', 'Toshiba',    8)
ON CONFLICT (config_type, value) DO NOTHING;

-- ── Update seed data with district ───────────────────────────
UPDATE public.hospital_clients SET district = 'Dhaka',      genre = 'General'   WHERE id = 'a1000000-0000-0000-0000-000000000001';
UPDATE public.hospital_clients SET district = 'Dhaka',      genre = 'General'   WHERE id = 'a1000000-0000-0000-0000-000000000002';
UPDATE public.hospital_clients SET district = 'Chittagong', genre = 'Radiology' WHERE id = 'a1000000-0000-0000-0000-000000000003';
UPDATE public.hospital_clients SET district = 'Dhaka',      genre = 'General'   WHERE id = 'a1000000-0000-0000-0000-000000000004';
UPDATE public.hospital_clients SET district = 'Rajshahi',   genre = 'General'   WHERE id = 'a1000000-0000-0000-0000-000000000005';
