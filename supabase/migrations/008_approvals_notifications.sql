-- ============================================================
-- EAM Platform - Migration 008   (run after 007)
-- Adds: approval workflow for clients + machines
--         data_entry inserts start as 'pending', hidden from
--         everyone except the submitter and admins until approved
--       deletion_requests: admins ask, super admins approve
--       notifications: in-app inbox, filled by triggers
-- ============================================================

-- ── Approval columns ─────────────────────────────────────────

ALTER TABLE public.hospital_clients
  ADD COLUMN IF NOT EXISTS approval_status  TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS reviewed_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_by_name TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.installed_machines
  ADD COLUMN IF NOT EXISTS approval_status  TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS reviewed_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_by_name TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

DO $$
BEGIN
  ALTER TABLE public.hospital_clients
    ADD CONSTRAINT hospital_clients_approval_status_check
    CHECK (approval_status IN ('pending', 'approved', 'rejected'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  ALTER TABLE public.installed_machines
    ADD CONSTRAINT installed_machines_approval_status_check
    CHECK (approval_status IN ('pending', 'approved', 'rejected'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_hospital_clients_pending
  ON public.hospital_clients (created_at) WHERE approval_status = 'pending';
CREATE INDEX IF NOT EXISTS idx_installed_machines_pending
  ON public.installed_machines (created_at) WHERE approval_status = 'pending';

-- ── Approval guard ───────────────────────────────────────────
-- Data entry rows always start pending and only admins may change
-- the approval fields. Admin inserts are approved straight away.

CREATE OR REPLACE FUNCTION public.guard_approval_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_is_admin boolean;
  v_name     text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  v_is_admin := public.current_role_level() >= 3;

  IF TG_OP = 'INSERT' THEN
    NEW.approval_status  := CASE WHEN v_is_admin THEN 'approved' ELSE 'pending' END;
    NEW.reviewed_by      := NULL;
    NEW.reviewed_by_name := NULL;
    NEW.reviewed_at      := NULL;
    NEW.rejection_reason := NULL;
    RETURN NEW;
  END IF;

  IF NEW.approval_status  IS NOT DISTINCT FROM OLD.approval_status
     AND NEW.rejection_reason IS NOT DISTINCT FROM OLD.rejection_reason
     AND NEW.reviewed_by  IS NOT DISTINCT FROM OLD.reviewed_by
     AND NEW.reviewed_at  IS NOT DISTINCT FROM OLD.reviewed_at THEN
    RETURN NEW;
  END IF;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Only an admin can approve or reject submissions'
      USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(nullif(trim(full_name), ''), email)
    INTO v_name
    FROM public.profiles
   WHERE id = auth.uid();

  NEW.reviewed_by      := auth.uid();
  NEW.reviewed_by_name := v_name;
  NEW.reviewed_at      := now();
  IF NEW.approval_status <> 'rejected' THEN
    NEW.rejection_reason := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_hospital_clients_approval ON public.hospital_clients;
CREATE TRIGGER guard_hospital_clients_approval
  BEFORE INSERT OR UPDATE ON public.hospital_clients
  FOR EACH ROW EXECUTE FUNCTION public.guard_approval_fields();

DROP TRIGGER IF EXISTS guard_installed_machines_approval ON public.installed_machines;
CREATE TRIGGER guard_installed_machines_approval
  BEFORE INSERT OR UPDATE ON public.installed_machines
  FOR EACH ROW EXECUTE FUNCTION public.guard_approval_fields();

-- Approving or rejecting is not an edit: keep "updated by" as is.
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

  IF TG_OP = 'UPDATE' THEN
    NEW.created_by      := OLD.created_by;
    NEW.created_by_name := OLD.created_by_name;
    IF NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
      NEW.updated_by      := OLD.updated_by;
      NEW.updated_by_name := OLD.updated_by_name;
      RETURN NEW;
    END IF;
  END IF;

  SELECT coalesce(nullif(trim(full_name), ''), email)
    INTO v_name
    FROM public.profiles
   WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    NEW.created_by      := auth.uid();
    NEW.created_by_name := v_name;
  END IF;
  NEW.updated_by      := auth.uid();
  NEW.updated_by_name := v_name;
  RETURN NEW;
END;
$$;

-- ── Helpers ──────────────────────────────────────────────────

-- The caller's own submission that is still waiting for review.
CREATE OR REPLACE FUNCTION public.is_own_pending_machine(target_machine_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.installed_machines
     WHERE id = target_machine_id
       AND created_by = auth.uid()
       AND approval_status = 'pending'
  );
$$;

-- Data entry may add machines to approved clients or to clients
-- they submitted themselves.
CREATE OR REPLACE FUNCTION public.can_add_machine_to(target_client_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_role_level() >= 3
      OR (public.current_role_level() = 2 AND EXISTS (
            SELECT 1
              FROM public.hospital_clients
             WHERE id = target_client_id
               AND (approval_status = 'approved' OR created_by = auth.uid())
          ));
$$;

-- ── hospital_clients policies ────────────────────────────────

DROP POLICY IF EXISTS "Authenticated users can read clients" ON public.hospital_clients;
DROP POLICY IF EXISTS "All authenticated users can read clients" ON public.hospital_clients;
DROP POLICY IF EXISTS "Read approved or own clients" ON public.hospital_clients;
CREATE POLICY "Read approved or own clients"
  ON public.hospital_clients FOR SELECT
  TO authenticated
  USING (approval_status = 'approved'
         OR created_by = auth.uid()
         OR public.is_admin_or_super());

DROP POLICY IF EXISTS "Admins can insert clients" ON public.hospital_clients;
DROP POLICY IF EXISTS "Data entry and admins can insert clients" ON public.hospital_clients;
CREATE POLICY "Data entry and admins can insert clients"
  ON public.hospital_clients FOR INSERT
  TO authenticated
  WITH CHECK (public.current_role_level() >= 2);

DROP POLICY IF EXISTS "Submitters can edit own pending clients" ON public.hospital_clients;
CREATE POLICY "Submitters can edit own pending clients"
  ON public.hospital_clients FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid() AND approval_status = 'pending')
  WITH CHECK (created_by = auth.uid() AND approval_status = 'pending');

DROP POLICY IF EXISTS "Submitters can withdraw own submissions" ON public.hospital_clients;
CREATE POLICY "Submitters can withdraw own submissions"
  ON public.hospital_clients FOR DELETE
  TO authenticated
  USING (created_by = auth.uid() AND approval_status <> 'approved');

-- ── installed_machines policies ──────────────────────────────

DROP POLICY IF EXISTS "Admins can read machines" ON public.installed_machines;
DROP POLICY IF EXISTS "Admins and submitters can read machines" ON public.installed_machines;
CREATE POLICY "Admins and submitters can read machines"
  ON public.installed_machines FOR SELECT
  TO authenticated
  USING (public.is_admin_or_super() OR created_by = auth.uid());

DROP POLICY IF EXISTS "Admins can insert machines" ON public.installed_machines;
DROP POLICY IF EXISTS "Data entry and admins can insert machines" ON public.installed_machines;
CREATE POLICY "Data entry and admins can insert machines"
  ON public.installed_machines FOR INSERT
  TO authenticated
  WITH CHECK (public.can_add_machine_to(hospital_id));

DROP POLICY IF EXISTS "Submitters can edit own pending machines" ON public.installed_machines;
CREATE POLICY "Submitters can edit own pending machines"
  ON public.installed_machines FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid() AND approval_status = 'pending')
  WITH CHECK (created_by = auth.uid() AND approval_status = 'pending');

DROP POLICY IF EXISTS "Submitters can withdraw own machines" ON public.installed_machines;
CREATE POLICY "Submitters can withdraw own machines"
  ON public.installed_machines FOR DELETE
  TO authenticated
  USING (created_by = auth.uid() AND approval_status <> 'approved');

-- ── machine_parts / machine_engineers for own pending machines ──
-- The add-machine form writes parts and engineers after the machine.

DROP POLICY IF EXISTS "Submitters manage parts of own pending machines" ON public.machine_parts;
CREATE POLICY "Submitters manage parts of own pending machines"
  ON public.machine_parts FOR ALL
  TO authenticated
  USING (public.is_own_pending_machine(machine_id))
  WITH CHECK (public.is_own_pending_machine(machine_id));

DROP POLICY IF EXISTS "Submitters manage engineers of own pending machines" ON public.machine_engineers;
CREATE POLICY "Submitters manage engineers of own pending machines"
  ON public.machine_engineers FOR ALL
  TO authenticated
  USING (public.is_own_pending_machine(machine_id))
  WITH CHECK (public.is_own_pending_machine(machine_id));

-- Invoice PDFs live at invoices/machines/<machine id>/<file>.
CREATE OR REPLACE FUNCTION public.is_own_pending_invoice_path(object_name text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_parts text[] := string_to_array(object_name, '/');
BEGIN
  IF array_length(v_parts, 1) < 3
     OR v_parts[1] <> 'machines'
     OR v_parts[2] !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN false;
  END IF;
  RETURN public.is_own_pending_machine(v_parts[2]::uuid);
END;
$$;

DROP POLICY IF EXISTS "Submitters manage invoices of own pending machines" ON storage.objects;
CREATE POLICY "Submitters manage invoices of own pending machines"
  ON storage.objects FOR ALL
  TO authenticated
  USING (bucket_id = 'invoices' AND public.is_own_pending_invoice_path(name))
  WITH CHECK (bucket_id = 'invoices' AND public.is_own_pending_invoice_path(name));

-- ── installed_machines_view ──────────────────────────────────
-- Now also hides other people's unapproved machines, and shows
-- submitters the full details of their own submissions.

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
  END AS machine_parts,
  m.approval_status,
  m.created_by,
  m.rejection_reason,
  m.reviewed_by_name,
  m.reviewed_at
FROM public.installed_machines m
CROSS JOIN LATERAL (SELECT public.is_admin_or_super() AS is_admin) r
CROSS JOIN LATERAL (SELECT r.is_admin OR m.created_by = auth.uid() AS full_access) a
WHERE auth.uid() IS NOT NULL
  AND public.session_is_active()
  AND (m.approval_status = 'approved' OR a.full_access);

REVOKE ALL ON public.installed_machines_view FROM anon, public;
GRANT SELECT ON public.installed_machines_view TO authenticated;

-- ── Notifications ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  body       TEXT,
  link       TEXT,
  is_read    BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
  ON public.notifications (user_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Rows are only created by the triggers below.
DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;
CREATE POLICY "Users read own notifications"
  ON public.notifications FOR SELECT
  TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users mark own notifications read" ON public.notifications;
CREATE POLICY "Users mark own notifications read"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users delete own notifications" ON public.notifications;
CREATE POLICY "Users delete own notifications"
  ON public.notifications FOR DELETE
  TO authenticated USING (user_id = auth.uid());

-- Everyone at or above min_level (except the actor).
CREATE OR REPLACE FUNCTION public.notify_role(
  min_level int, p_title text, p_body text, p_link text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.notifications (user_id, title, body, link)
  SELECT id, p_title, p_body, p_link
    FROM public.profiles
   WHERE public.role_level(role) >= min_level
     AND NOT is_banned
     AND id IS DISTINCT FROM auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.notify_user(
  target_user_id uuid, p_title text, p_body text, p_link text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.notifications (user_id, title, body, link)
  SELECT target_user_id, p_title, p_body, p_link
   WHERE target_user_id IS NOT NULL
     AND target_user_id IS DISTINCT FROM auth.uid();
$$;

REVOKE EXECUTE ON FUNCTION public.notify_role(int, text, text, text) FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.notify_user(uuid, text, text, text) FROM anon, authenticated, public;

-- Submission → admins; review → submitter.
CREATE OR REPLACE FUNCTION public.notify_approval_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_kind  text;
  v_label text;
  v_link  text;
BEGIN
  IF TG_TABLE_NAME = 'hospital_clients' THEN
    v_kind  := 'client';
    v_label := NEW.name;
    v_link  := '/clients/' || NEW.id;
  ELSE
    v_kind  := 'machine';
    SELECT NEW.brand || ' ' || NEW.model || ' at ' || c.name
      INTO v_label
      FROM public.hospital_clients c
     WHERE c.id = NEW.hospital_id;
    v_label := coalesce(v_label, NEW.brand || ' ' || NEW.model);
    v_link  := '/clients/' || NEW.hospital_id || '/machine/' || NEW.id;
  END IF;

  IF TG_OP = 'INSERT' AND NEW.approval_status = 'pending' THEN
    PERFORM public.notify_role(
      3,
      'New ' || v_kind || ' awaiting approval',
      coalesce(NEW.created_by_name, 'Someone') || ' submitted ' || v_label,
      '/approvals');
  ELSIF TG_OP = 'UPDATE'
        AND NEW.approval_status IS DISTINCT FROM OLD.approval_status
        AND NEW.approval_status IN ('approved', 'rejected') THEN
    PERFORM public.notify_user(
      NEW.created_by,
      'Your ' || v_kind || ' was ' || NEW.approval_status,
      v_label || CASE
        WHEN NEW.approval_status = 'rejected' AND coalesce(NEW.rejection_reason, '') <> ''
        THEN ' — ' || NEW.rejection_reason
        ELSE '' END,
      v_link);
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS notify_hospital_clients_approval ON public.hospital_clients;
CREATE TRIGGER notify_hospital_clients_approval
  AFTER INSERT OR UPDATE ON public.hospital_clients
  FOR EACH ROW EXECUTE FUNCTION public.notify_approval_events();

DROP TRIGGER IF EXISTS notify_installed_machines_approval ON public.installed_machines;
CREATE TRIGGER notify_installed_machines_approval
  AFTER INSERT OR UPDATE ON public.installed_machines
  FOR EACH ROW EXECUTE FUNCTION public.notify_approval_events();

-- ── Deletion requests ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.deletion_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_table      TEXT NOT NULL CHECK (target_table IN
                      ('hospital_clients', 'installed_machines', 'machine_config', 'engineers')),
  target_id         UUID NOT NULL,
  target_label      TEXT NOT NULL,
  target_link       TEXT,
  reason            TEXT,
  status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'approved', 'rejected')),
  requested_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_by_name TEXT,
  reviewed_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_by_name  TEXT,
  reviewed_at       TIMESTAMPTZ,
  review_note       TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One open request per record.
CREATE UNIQUE INDEX IF NOT EXISTS uq_deletion_requests_pending
  ON public.deletion_requests (target_table, target_id) WHERE status = 'pending';

ALTER TABLE public.deletion_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read own or all as super admin" ON public.deletion_requests;
CREATE POLICY "Read own or all as super admin"
  ON public.deletion_requests FOR SELECT
  TO authenticated
  USING (requested_by = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS "Admins can request deletions" ON public.deletion_requests;
CREATE POLICY "Admins can request deletions"
  ON public.deletion_requests FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_or_super());

-- Requester can cancel while pending; reviews go through the RPC.
DROP POLICY IF EXISTS "Requesters can cancel pending requests" ON public.deletion_requests;
CREATE POLICY "Requesters can cancel pending requests"
  ON public.deletion_requests FOR DELETE
  TO authenticated
  USING (requested_by = auth.uid() AND status = 'pending');

CREATE OR REPLACE FUNCTION public.prepare_deletion_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.requested_by := auth.uid();
  SELECT coalesce(nullif(trim(full_name), ''), email)
    INTO NEW.requested_by_name
    FROM public.profiles
   WHERE id = auth.uid();
  NEW.status           := 'pending';
  NEW.reviewed_by      := NULL;
  NEW.reviewed_by_name := NULL;
  NEW.reviewed_at      := NULL;
  NEW.review_note      := NULL;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prepare_deletion_request ON public.deletion_requests;
CREATE TRIGGER prepare_deletion_request
  BEFORE INSERT ON public.deletion_requests
  FOR EACH ROW EXECUTE FUNCTION public.prepare_deletion_request();

CREATE OR REPLACE FUNCTION public.notify_deletion_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.notify_role(
    4,
    'Deletion awaiting approval',
    coalesce(NEW.requested_by_name, 'An admin') || ' wants to delete ' || NEW.target_label,
    '/approvals');
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS notify_deletion_request ON public.deletion_requests;
CREATE TRIGGER notify_deletion_request
  AFTER INSERT ON public.deletion_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_deletion_request();

-- Super admin approves (deletes the record) or rejects a request.
CREATE OR REPLACE FUNCTION public.review_deletion_request(
  request_id uuid, approve boolean, note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  r      public.deletion_requests%ROWTYPE;
  v_name text;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only a super admin can review deletion requests'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO r
    FROM public.deletion_requests
   WHERE id = request_id
   FOR UPDATE;
  IF NOT FOUND OR r.status <> 'pending' THEN
    RAISE EXCEPTION 'This request was already handled';
  END IF;

  IF approve THEN
    BEGIN
      IF r.target_table = 'installed_machines' THEN
        DELETE FROM public.machine_parts     WHERE machine_id = r.target_id;
        DELETE FROM public.machine_engineers WHERE machine_id = r.target_id;
      END IF;
      EXECUTE format('DELETE FROM public.%I WHERE id = $1', r.target_table)
        USING r.target_id;
    EXCEPTION WHEN foreign_key_violation THEN
      RAISE EXCEPTION '% is still in use (e.g. a client with machines). Remove those first.',
        r.target_label;
    END;
  END IF;

  SELECT coalesce(nullif(trim(full_name), ''), email)
    INTO v_name
    FROM public.profiles
   WHERE id = auth.uid();

  UPDATE public.deletion_requests
     SET status           = CASE WHEN approve THEN 'approved' ELSE 'rejected' END,
         reviewed_by      = auth.uid(),
         reviewed_by_name = v_name,
         reviewed_at      = now(),
         review_note      = nullif(trim(note), '')
   WHERE id = request_id;

  PERFORM public.notify_user(
    r.requested_by,
    CASE WHEN approve THEN 'Deletion approved' ELSE 'Deletion rejected' END,
    r.target_label || CASE WHEN coalesce(trim(note), '') <> '' THEN ' — ' || trim(note) ELSE '' END,
    CASE WHEN approve THEN NULL ELSE r.target_link END);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.review_deletion_request(uuid, boolean, text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.review_deletion_request(uuid, boolean, text) TO authenticated;

-- ── Active-session rule on the new tables (see 005) ──────────

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['notifications', 'deletion_requests']
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS "Require active session" ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY "Require active session" ON public.%I
         AS RESTRICTIVE FOR ALL TO authenticated
         USING ((SELECT public.session_is_active()))
         WITH CHECK ((SELECT public.session_is_active()))', t);
  END LOOP;
END;
$$;
