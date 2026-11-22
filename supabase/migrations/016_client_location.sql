-- ============================================================
-- EAM Platform - Migration 016   (run after 015)
-- Adds: a map pin on hospital_clients, filled by smartHr through
--       the smarthr-bridge Edge Function (only while empty) or by
--       an admin in the app (set, move, clear).
--   - both coordinates are set together, inside Bangladesh
--   - in the app only admins may change the pin; the trigger
--     stamps location_set_at / location_set_by for them
--   - the service role (the bridge) has no auth.uid() and passes
--     its own location_set_by ("Name (smartHr)")
-- Safe to run again.
-- ============================================================

ALTER TABLE public.hospital_clients
  ADD COLUMN IF NOT EXISTS latitude        DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude       DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_set_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS location_set_by TEXT;

-- IS NOT NULL is spelled out: a CHECK that evaluates to NULL passes.
ALTER TABLE public.hospital_clients
  DROP CONSTRAINT IF EXISTS hospital_clients_location_check;
ALTER TABLE public.hospital_clients
  ADD CONSTRAINT hospital_clients_location_check
  CHECK (
    (latitude IS NULL AND longitude IS NULL)
    OR (latitude IS NOT NULL AND longitude IS NOT NULL
        AND latitude  BETWEEN 20 AND 27
        AND longitude BETWEEN 88 AND 93)
  );

CREATE OR REPLACE FUNCTION public.guard_client_location()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;  -- service role: the bridge sets its own stamp
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.latitude  IS NOT DISTINCT FROM OLD.latitude
     AND NEW.longitude IS NOT DISTINCT FROM OLD.longitude THEN
    NEW.location_set_at := OLD.location_set_at;
    NEW.location_set_by := OLD.location_set_by;
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' AND NEW.latitude IS NULL AND NEW.longitude IS NULL THEN
    NEW.location_set_at := NULL;
    NEW.location_set_by := NULL;
    RETURN NEW;
  END IF;

  IF public.current_role_level() < 3 THEN
    RAISE EXCEPTION 'Only an admin can change a client''s map pin'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.latitude IS NULL THEN
    NEW.location_set_at := NULL;
    NEW.location_set_by := NULL;
  ELSE
    NEW.location_set_at := now();
    SELECT coalesce(nullif(trim(full_name), ''), email)
      INTO NEW.location_set_by
      FROM public.profiles
     WHERE id = auth.uid();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_hospital_clients_location ON public.hospital_clients;
CREATE TRIGGER guard_hospital_clients_location
  BEFORE INSERT OR UPDATE ON public.hospital_clients
  FOR EACH ROW EXECUTE FUNCTION public.guard_client_location();
