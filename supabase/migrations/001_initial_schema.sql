-- ============================================================
-- EAM Platform - Full Schema Migration
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE machine_type AS ENUM (
  'X-ray',
  'Ultrasonogram',
  'FPD',
  'Printer',
  'OPG'
);

CREATE TYPE division_type AS ENUM (
  'Dhaka',
  'Chattogram',
  'Rajshahi',
  'Khulna',
  'Barishal',
  'Sylhet',
  'Mymensingh',
  'Rangpur'
);

CREATE TYPE facility_type AS ENUM (
  'Hospital',
  'Clinic',
  'Diagnostic Center'
);

CREATE TYPE engineer_status AS ENUM (
  'Available',
  'On Assignment',
  'On Leave'
);

CREATE TYPE app_role AS ENUM (
  'admin',
  'user'
);

-- ============================================================
-- PROFILES TABLE (extends Supabase auth.users)
-- ============================================================

CREATE TABLE public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT,
  role        app_role NOT NULL DEFAULT 'user',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    COALESCE((NEW.raw_user_meta_data->>'role')::app_role, 'user')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- HOSPITAL CLIENTS TABLE
-- ============================================================

CREATE TABLE public.hospital_clients (
  id                        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                      TEXT NOT NULL,
  address                   TEXT NOT NULL,
  division                  division_type NOT NULL,
  facility_type             facility_type NOT NULL DEFAULT 'Hospital',
  contact_person_name       TEXT NOT NULL,
  contact_person_designation TEXT NOT NULL,
  contact_person_phone      TEXT NOT NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INSTALLED MACHINES TABLE
-- ============================================================

CREATE TABLE public.installed_machines (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  hospital_id       UUID NOT NULL REFERENCES public.hospital_clients(id) ON DELETE CASCADE,
  machine_type      machine_type NOT NULL,
  brand             TEXT NOT NULL,
  model             TEXT NOT NULL,
  serial_number     TEXT,
  installation_date DATE NOT NULL,
  warranty_period   INTEGER NOT NULL, -- in months
  invoice_url       TEXT,             -- Supabase Storage path
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Computed column helper function for warranty left (in months)
CREATE OR REPLACE FUNCTION public.warranty_expiry_date(machine installed_machines)
RETURNS DATE AS $$
BEGIN
  RETURN (machine.installation_date + (machine.warranty_period * INTERVAL '1 month'))::DATE;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- INSTALLING ENGINEERS TABLE
-- ============================================================

CREATE TABLE public.installing_engineers (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  machine_id    UUID NOT NULL REFERENCES public.installed_machines(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  designation   TEXT NOT NULL,
  status        engineer_status NOT NULL DEFAULT 'Available',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_hospital_clients_updated_at
  BEFORE UPDATE ON public.hospital_clients
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_installed_machines_updated_at
  BEFORE UPDATE ON public.installed_machines
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_installing_engineers_updated_at
  BEFORE UPDATE ON public.installing_engineers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY (RBAC)
-- ============================================================

ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_clients  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installed_machines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installing_engineers ENABLE ROW LEVEL SECURITY;

-- Helper: get current user role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS app_role AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- PROFILES policies
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Admins can read all profiles"
  ON public.profiles FOR SELECT
  USING (public.get_user_role() = 'admin');

CREATE POLICY "Admins can update profiles"
  ON public.profiles FOR UPDATE
  USING (public.get_user_role() = 'admin');

-- HOSPITAL CLIENTS policies
CREATE POLICY "All authenticated users can read clients"
  ON public.hospital_clients FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Admins can insert clients"
  ON public.hospital_clients FOR INSERT
  TO authenticated WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "Admins can update clients"
  ON public.hospital_clients FOR UPDATE
  TO authenticated USING (public.get_user_role() = 'admin');

CREATE POLICY "Admins can delete clients"
  ON public.hospital_clients FOR DELETE
  TO authenticated USING (public.get_user_role() = 'admin');

-- INSTALLED MACHINES policies
CREATE POLICY "All authenticated users can read machines"
  ON public.installed_machines FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Admins can insert machines"
  ON public.installed_machines FOR INSERT
  TO authenticated WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "Admins can update machines"
  ON public.installed_machines FOR UPDATE
  TO authenticated USING (public.get_user_role() = 'admin');

CREATE POLICY "Admins can delete machines"
  ON public.installed_machines FOR DELETE
  TO authenticated USING (public.get_user_role() = 'admin');

-- INSTALLING ENGINEERS policies
CREATE POLICY "All authenticated users can read engineers"
  ON public.installing_engineers FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Admins can insert engineers"
  ON public.installing_engineers FOR INSERT
  TO authenticated WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "Admins can update engineers"
  ON public.installing_engineers FOR UPDATE
  TO authenticated USING (public.get_user_role() = 'admin');

CREATE POLICY "Admins can delete engineers"
  ON public.installing_engineers FOR DELETE
  TO authenticated USING (public.get_user_role() = 'admin');

-- ============================================================
-- STORAGE BUCKET FOR INVOICES
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'invoices',
  'invoices',
  false,
  52428800, -- 50MB
  ARRAY['application/pdf']
);

-- Storage RLS: all authenticated users can read invoices
CREATE POLICY "Authenticated users can read invoices"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'invoices');

-- Only admins can upload invoices
CREATE POLICY "Admins can upload invoices"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'invoices'
    AND public.get_user_role() = 'admin'
  );

CREATE POLICY "Admins can delete invoices"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'invoices'
    AND public.get_user_role() = 'admin'
  );

-- ============================================================
-- ANALYTICS VIEW (for Dashboard)
-- ============================================================

CREATE OR REPLACE VIEW public.dashboard_analytics AS
SELECT
  (SELECT COUNT(*)  FROM public.hospital_clients)                AS total_clients,
  (SELECT COUNT(DISTINCT brand) FROM public.installed_machines)  AS active_brands,
  (SELECT COUNT(DISTINCT division) FROM public.hospital_clients) AS total_divisions,
  (SELECT COUNT(*) FROM public.installing_engineers
   WHERE status = 'Available')                                   AS available_engineers,
  (SELECT COUNT(*) FROM public.installed_machines)               AS total_machines;

GRANT SELECT ON public.dashboard_analytics TO authenticated;

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_hospital_clients_division      ON public.hospital_clients(division); 
CREATE INDEX idx_hospital_clients_facility_type ON public.hospital_clients(facility_type);
CREATE INDEX idx_hospital_clients_name          ON public.hospital_clients USING GIN (to_tsvector('simple', name));
CREATE INDEX idx_installed_machines_hospital_id ON public.installed_machines(hospital_id);
CREATE INDEX idx_installing_engineers_machine_id ON public.installing_engineers(machine_id);
