-- ============================================================
-- EAM Platform - Migration 007   (run after 006)
-- Adds: role levels + helpers (viewer / data_entry / admin / super_admin)
--       profiles.email, profiles.is_banned, profile column guard
--       safe handle_new_user (role can no longer be self-assigned)
--       created_by / updated_by audit columns on clients + machines
--       installed_machines_view: technical details for admins only
--       admin_revoke_user_sessions() for the manage-users function
-- ============================================================

-- ── profiles columns ─────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email     TEXT,
  ADD COLUMN IF NOT EXISTS is_banned BOOLEAN NOT NULL DEFAULT false;

UPDATE public.profiles p
   SET email = u.email
  FROM auth.users u
 WHERE u.id = p.id
   AND p.email IS DISTINCT FROM u.email;

-- Deleting a user from the app must also remove their profile.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_id_fkey,
  ADD CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ── Role helpers ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.role_level(r public.app_role)
RETURNS int
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE r::text
           WHEN 'super_admin' THEN 4
           WHEN 'superadmin'  THEN 4
           WHEN 'admin'       THEN 3
           WHEN 'data_entry'  THEN 2
           ELSE 1
         END;
$$;

-- 0 = not signed in or banned.
CREATE OR REPLACE FUNCTION public.current_role_level()
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT coalesce(
    (SELECT public.role_level(role)
       FROM public.profiles
      WHERE id = auth.uid()
        AND NOT is_banned),
    0);
$$;

CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_role_level() >= 3;
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_role_level() = 4;
$$;

-- Banned users lose database access immediately.
CREATE OR REPLACE FUNCTION public.session_is_active()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
           SELECT 1
             FROM auth.sessions
            WHERE id = nullif(auth.jwt() ->> 'session_id', '')::uuid
              AND user_id = auth.uid()
         )
     AND NOT EXISTS (
           SELECT 1
             FROM public.profiles
            WHERE id = auth.uid()
              AND is_banned
         );
$$;

-- ── New users ────────────────────────────────────────────────
-- The role comes from app_metadata, which only the service role
-- (the manage-users Edge Function) can set. The old version read
-- user_metadata, which anyone signing up could fill in.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text := NEW.raw_app_meta_data ->> 'role';
BEGIN
  IF v_role IS NULL OR v_role NOT IN ('user', 'data_entry', 'admin') THEN
    v_role := 'user';
  END IF;

  INSERT INTO public.profiles (id, full_name, role, email)
  VALUES (
    NEW.id,
    nullif(trim(NEW.raw_user_meta_data ->> 'full_name'), ''),
    v_role::public.app_role,
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ── profiles policies ────────────────────────────────────────

DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
CREATE POLICY "Admins can read all profiles"
  ON public.profiles FOR SELECT
  TO authenticated USING (public.is_admin_or_super());

DROP POLICY IF EXISTS "Admins can update profiles" ON public.profiles;
CREATE POLICY "Admins can update profiles"
  ON public.profiles FOR UPDATE
  TO authenticated USING (public.is_admin_or_super());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ── profiles column guard ────────────────────────────────────
-- Everyone may edit their own name; admins may edit users below
-- them; super admins anyone. Role and ban changes:
--   admin       → only users below admin, and only to viewer/data_entry
--   super_admin → anyone except themselves
-- Requests without a user (service role, SQL editor) are trusted.

CREATE OR REPLACE FUNCTION public.guard_profile_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller int;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id OR NEW.email IS DISTINCT FROM OLD.email THEN
    RAISE EXCEPTION 'Profile id and email cannot be changed here'
      USING ERRCODE = '42501';
  END IF;

  v_caller := public.current_role_level();

  -- Admins can only manage users below them.
  IF NEW.id <> auth.uid() AND v_caller < 4
     AND v_caller <= public.role_level(OLD.role) THEN
    RAISE EXCEPTION 'You are not allowed to edit this user'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.role IS NOT DISTINCT FROM OLD.role
     AND NEW.is_banned IS NOT DISTINCT FROM OLD.is_banned THEN
    RETURN NEW;
  END IF;

  IF NEW.id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot change your own role or ban status'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.is_banned IS DISTINCT FROM OLD.is_banned AND v_caller < 4 THEN
    RAISE EXCEPTION 'Only a super admin can ban users'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role AND v_caller < 4 AND (
       v_caller < 3
       OR public.role_level(OLD.role) >= 3
       OR public.role_level(NEW.role) >= 3
     ) THEN
    RAISE EXCEPTION 'You are not allowed to assign this role'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_profile_update ON public.profiles;
CREATE TRIGGER guard_profile_update
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_update();

-- ── Audit columns ────────────────────────────────────────────
-- Names are copied in so every role can see them (profiles are
-- private) and they survive the user being deleted.

ALTER TABLE public.hospital_clients
  ADD COLUMN IF NOT EXISTS created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by_name TEXT,
  ADD COLUMN IF NOT EXISTS updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_by_name TEXT;

ALTER TABLE public.installed_machines
  ADD COLUMN IF NOT EXISTS created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by_name TEXT,
  ADD COLUMN IF NOT EXISTS updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_by_name TEXT;

CREATE OR REPLACE FUNCTION public.set_audit_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_name text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT coalesce(nullif(trim(full_name), ''), email)
    INTO v_name
    FROM public.profiles
   WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    NEW.created_by      := auth.uid();
    NEW.created_by_name := v_name;
  ELSE
    NEW.created_by      := OLD.created_by;
    NEW.created_by_name := OLD.created_by_name;
  END IF;
  NEW.updated_by      := auth.uid();
  NEW.updated_by_name := v_name;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_hospital_clients_audit ON public.hospital_clients;
CREATE TRIGGER set_hospital_clients_audit
  BEFORE INSERT OR UPDATE ON public.hospital_clients
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

DROP TRIGGER IF EXISTS set_installed_machines_audit ON public.installed_machines;
CREATE TRIGGER set_installed_machines_audit
  BEFORE INSERT OR UPDATE ON public.installed_machines
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

-- ── Machine visibility ───────────────────────────────────────
-- Full rows (technical config, parts, invoice) are admin-only.
-- Viewers and data entry operators read installed_machines_view,
-- which blanks the technical columns for them.

DROP POLICY IF EXISTS "Authenticated users can read machines" ON public.installed_machines;
DROP POLICY IF EXISTS "All authenticated users can read machines" ON public.installed_machines;
DROP POLICY IF EXISTS "Admins can read machines" ON public.installed_machines;
CREATE POLICY "Admins can read machines"
  ON public.installed_machines FOR SELECT
  TO authenticated USING (public.is_admin_or_super());

DROP POLICY IF EXISTS "Authenticated users can read parts" ON public.machine_parts;
DROP POLICY IF EXISTS "Admins can read parts" ON public.machine_parts;
CREATE POLICY "Admins can read parts"
  ON public.machine_parts FOR SELECT
  TO authenticated USING (public.is_admin_or_super());

DROP POLICY IF EXISTS "Authenticated users can read machine engineers" ON public.machine_engineers;
DROP POLICY IF EXISTS "Admins can read machine engineers" ON public.machine_engineers;
CREATE POLICY "Admins can read machine engineers"
  ON public.machine_engineers FOR SELECT
  TO authenticated USING (public.is_admin_or_super());

-- Same JSON shape as the old embedded select
-- ('*, machine_engineers(engineers(*)), machine_parts(*)'), so the
-- app parses it unchanged. Runs as the view owner, hence the
-- explicit signed-in + active-session filter.
DROP VIEW IF EXISTS public.installed_machines_view;
CREATE VIEW public.installed_machines_view AS
SELECT
  m.id,
  m.hospital_id,
  m.machine_type,
  m.brand,
  m.model,
  m.serial_number,
  m.installation_engineer_id,
  m.installation_date,
  m.warranty_period,
  m.status,
  m.created_at,
  m.updated_at,
  m.created_by_name,
  m.updated_by_name,
  CASE WHEN a.full_access THEN m.invoice_url            END AS invoice_url,
  CASE WHEN a.full_access THEN m.notes                  END AS notes,
  CASE WHEN a.full_access THEN m.pc_cpu                 END AS pc_cpu,
  CASE WHEN a.full_access THEN m.pc_ram                 END AS pc_ram,
  CASE WHEN a.full_access THEN m.pc_storage             END AS pc_storage,
  CASE WHEN a.full_access THEN m.pc_os                  END AS pc_os,
  CASE WHEN a.full_access THEN m.pc_mobo                END AS pc_mobo,
  CASE WHEN a.full_access THEN m.pc_lan_ports           END AS pc_lan_ports,
  CASE WHEN a.full_access THEN m.assigned_ips           END AS assigned_ips,
  CASE WHEN a.full_access THEN m.printer_ae             END AS printer_ae,
  CASE WHEN a.full_access THEN m.printer_ip1            END AS printer_ip1,
  CASE WHEN a.full_access THEN m.printer_ip2            END AS printer_ip2,
  CASE WHEN a.full_access THEN m.printer_port           END AS printer_port,
  CASE WHEN a.full_access THEN m.printer_pc_version     END AS printer_pc_version,
  CASE WHEN a.full_access THEN m.printer_mb_version     END AS printer_mb_version,
  CASE WHEN a.full_access THEN m.printer_imager_version END AS printer_imager_version,
  CASE WHEN a.full_access THEN m.xray_console_sl        END AS xray_console_sl,
  CASE WHEN a.full_access THEN m.xray_tube_sl           END AS xray_tube_sl,
  CASE WHEN a.full_access THEN m.xray_generator_sl      END AS xray_generator_sl,
  CASE WHEN a.full_access THEN m.fpd_acq_id             END AS fpd_acq_id,
  CASE WHEN a.full_access THEN m.fpd_software           END AS fpd_software,
  CASE WHEN a.full_access THEN m.fpd_version            END AS fpd_version,
  CASE WHEN a.full_access THEN m.fpd_module             END AS fpd_module,
  CASE WHEN a.full_access THEN m.fpd_license            END AS fpd_license,
  CASE WHEN a.full_access THEN m.fpd_license_type       END AS fpd_license_type,
  CASE WHEN a.full_access THEN m.fpd_dongle_serial      END AS fpd_dongle_serial,
  CASE WHEN a.full_access THEN m.custom_metadata        END AS custom_metadata,
  coalesce(
    (SELECT jsonb_agg(jsonb_build_object('engineers', to_jsonb(e)) ORDER BY e.name)
       FROM public.machine_engineers me
       JOIN public.engineers e ON e.id = me.engineer_id
      WHERE me.machine_id = m.id),
    '[]'::jsonb
  ) AS machine_engineers,
  CASE WHEN a.full_access THEN
    coalesce(
      (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at)
         FROM public.machine_parts p
        WHERE p.machine_id = m.id),
      '[]'::jsonb)
  ELSE '[]'::jsonb
  END AS machine_parts
FROM public.installed_machines m
CROSS JOIN LATERAL (SELECT public.is_admin_or_super() AS full_access) a
WHERE auth.uid() IS NOT NULL
  AND public.session_is_active();

REVOKE ALL ON public.installed_machines_view FROM anon, public;
GRANT SELECT ON public.installed_machines_view TO authenticated;

-- ── Session revocation for the manage-users function ─────────

CREATE OR REPLACE FUNCTION public.admin_revoke_user_sessions(target_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  DELETE FROM auth.sessions WHERE user_id = target_user_id;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_revoke_user_sessions(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.admin_revoke_user_sessions(uuid) TO service_role;
