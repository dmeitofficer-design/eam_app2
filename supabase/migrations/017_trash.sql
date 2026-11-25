-- ============================================================
-- EAM Platform - Migration 017   (run after 016)
-- Adds: a Trash for everything deleted, plus editing and deleting
--       purchase bills.
--   - trash: a BEFORE DELETE trigger copies each deleted row (as
--     jsonb) with who deleted it. Rows deleted in one transaction
--     share a batch and are restored together (a machine with its
--     parts and engineers, a bill with its items and serials).
--   - child rows (parts, engineer links, bill items, serials) are
--     kept only when their parent is deleted in the same transaction,
--     so the app's "replace all parts on edit" does not fill the trash
--   - restore_trash(batch): super admin; puts the rows back with
--     their original ids, bill numbers and "added by"
--   - purge_trash(): pg_cron, hourly; deletes batches older than
--     app_settings.trash_retention_days (default 3, super admin sets it)
--   - update_purchase_bill(): edit a whole bill in one transaction,
--     keeping each serial's machine link
--   - deletion requests may now target purchase bills
-- Safe to run again.
-- ============================================================

-- ── Settings ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.app_settings (
  key             TEXT PRIMARY KEY,
  value           JSONB NOT NULL,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_name TEXT
);
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_settings FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.app_settings FROM authenticated;

DROP POLICY IF EXISTS "Signed-in users can read settings" ON public.app_settings;
CREATE POLICY "Signed-in users can read settings"
  ON public.app_settings FOR SELECT TO authenticated USING (true);

INSERT INTO public.app_settings (key, value)
VALUES ('trash_retention_days', '3')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.trash_retention_days()
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT coalesce((SELECT (value #>> '{}')::int FROM public.app_settings
                    WHERE key = 'trash_retention_days'), 3);
$$;

CREATE OR REPLACE FUNCTION public.set_trash_retention_days(days int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only a super admin can change the trash period' USING ERRCODE = '42501';
  END IF;
  IF days IS NULL OR days < 1 OR days > 90 THEN
    RAISE EXCEPTION 'Keep deleted items for 1 to 90 days' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.app_settings (key, value, updated_at, updated_by_name)
  VALUES ('trash_retention_days', to_jsonb(days), now(),
          (SELECT coalesce(nullif(trim(full_name), ''), email)
             FROM public.profiles WHERE id = auth.uid()))
  ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value,
        updated_at = EXCLUDED.updated_at,
        updated_by_name = EXCLUDED.updated_by_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.set_trash_retention_days(int) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.set_trash_retention_days(int) TO authenticated;

-- ── Trash table ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.trash (
  id              BIGSERIAL PRIMARY KEY,
  batch           BIGINT NOT NULL,           -- txid of the delete
  table_name      TEXT NOT NULL,
  row_id          UUID,
  label           TEXT NOT NULL,
  row_data        JSONB NOT NULL,
  extra           JSONB,                     -- e.g. purchase serials linked to a machine
  is_top          BOOLEAN NOT NULL,          -- false for child rows of a top row
  deleted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  deleted_by_name TEXT
);
CREATE INDEX IF NOT EXISTS trash_batch_idx ON public.trash (batch);
CREATE INDEX IF NOT EXISTS trash_deleted_at_idx ON public.trash (deleted_at);

ALTER TABLE public.trash ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.trash FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.trash FROM authenticated;
DROP POLICY IF EXISTS "Super admins can read trash" ON public.trash;
CREATE POLICY "Super admins can read trash"
  ON public.trash FOR SELECT TO authenticated
  USING ((SELECT public.is_super_admin()));
DROP POLICY IF EXISTS "Require active session" ON public.trash;
CREATE POLICY "Require active session" ON public.trash
  AS RESTRICTIVE FOR ALL TO authenticated
  USING ((SELECT public.session_is_active()))
  WITH CHECK ((SELECT public.session_is_active()));

-- ── Copy rows into the trash on delete ───────────────────────

CREATE OR REPLACE FUNCTION public.trash_row()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_row   jsonb := to_jsonb(OLD);
  v_top   boolean := TG_ARGV[0] = 'top';
  v_label text;
  v_extra jsonb;
BEGIN
  -- Child rows only travel with a parent deleted in this transaction.
  IF NOT v_top AND NOT EXISTS (
       SELECT 1 FROM public.trash WHERE batch = txid_current() AND is_top) THEN
    RETURN OLD;
  END IF;

  v_label := CASE TG_TABLE_NAME
    WHEN 'hospital_clients'   THEN v_row ->> 'name'
    WHEN 'installed_machines' THEN concat_ws(' ', v_row ->> 'brand', v_row ->> 'model',
                                             '(' || (v_row ->> 'serial_number') || ')')
    WHEN 'engineers'          THEN v_row ->> 'name'
    WHEN 'machine_config'     THEN concat_ws(': ', v_row ->> 'config_type', v_row ->> 'value')
    WHEN 'purchase_bills'     THEN concat_ws(' · ', v_row ->> 'dme_no', 'bill ' || (v_row ->> 'bill_no'))
    WHEN 'purchase_bill_items' THEN v_row ->> 'description'
    WHEN 'purchase_item_serials' THEN v_row ->> 'serial_no'
    WHEN 'machine_parts'      THEN concat_ws(' ', v_row ->> 'part_name', v_row ->> 'serial_number')
    ELSE TG_TABLE_NAME
  END;

  -- Deleting a machine unlinks its purchased parts (ON DELETE SET NULL);
  -- remember them so a restore links them again.
  IF TG_TABLE_NAME = 'installed_machines' THEN
    SELECT jsonb_build_object('serial_ids', jsonb_agg(id))
      INTO v_extra
      FROM public.purchase_item_serials
     WHERE machine_id = OLD.id
    HAVING count(*) > 0;
  END IF;

  INSERT INTO public.trash
    (batch, table_name, row_id, label, row_data, extra, is_top, deleted_by, deleted_by_name)
  VALUES (
    txid_current(), TG_TABLE_NAME, (v_row ->> 'id')::uuid,
    coalesce(nullif(v_label, ''), TG_TABLE_NAME), v_row, v_extra, v_top, auth.uid(),
    (SELECT coalesce(nullif(trim(full_name), ''), email) FROM public.profiles WHERE id = auth.uid())
  );
  RETURN OLD;
END;
$$;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['hospital_clients', 'installed_machines', 'engineers',
                           'machine_config', 'purchase_bills']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trash_row ON public.%I', t);
    EXECUTE format('CREATE TRIGGER trash_row BEFORE DELETE ON public.%I
                      FOR EACH ROW EXECUTE FUNCTION public.trash_row(''top'')', t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['machine_parts', 'machine_engineers', 'installing_engineers',
                           'purchase_bill_items', 'purchase_item_serials']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trash_row ON public.%I', t);
    EXECUTE format('CREATE TRIGGER trash_row BEFORE DELETE ON public.%I
                      FOR EACH ROW EXECUTE FUNCTION public.trash_row(''child'')', t);
  END LOOP;
END;
$$;

-- ── Audit trigger fix ────────────────────────────────────────
-- 008's version reads NEW.approval_status, which purchase tables do
-- not have, so every signed-in edit of a bill or vendor failed.

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
    -- Approving or rejecting is not an edit: keep "updated by" as is.
    IF to_jsonb(NEW) ->> 'approval_status' IS DISTINCT FROM to_jsonb(OLD) ->> 'approval_status' THEN
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

-- ── Bill numbers survive a restore ───────────────────────────

CREATE OR REPLACE FUNCTION public.set_purchase_bill_dme_no()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.dme_no IS NULL OR coalesce(current_setting('app.restoring', true), '') <> 'on' THEN
      NEW.dme_no := public.format_dme_no(nextval('public.purchase_bill_dme_no_seq'));
    END IF;
  ELSE
    NEW.dme_no := OLD.dme_no;
  END IF;
  RETURN NEW;
END;
$$;

-- ── Restore / delete for good / purge ────────────────────────

CREATE OR REPLACE FUNCTION public.restore_trash(p_batch bigint)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  r      public.trash%ROWTYPE;
  v_cols text;
  n      int := 0;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only a super admin can restore from the trash' USING ERRCODE = '42501';
  END IF;

  -- Without a signed-in user the audit, approval and pin triggers keep
  -- the stored values (original "added by", approval state, pin stamp).
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('app.restoring', 'on', true);

  -- Parents before children.
  FOR r IN
    SELECT * FROM public.trash WHERE batch = p_batch
     ORDER BY CASE table_name
                WHEN 'hospital_clients' THEN 0 WHEN 'engineers' THEN 0
                WHEN 'machine_config' THEN 0 WHEN 'purchase_bills' THEN 0
                WHEN 'installed_machines' THEN 1 WHEN 'purchase_bill_items' THEN 1
                ELSE 2 END,
              id
  LOOP
    SELECT string_agg(quote_ident(attname), ', ' ORDER BY attnum)
      INTO v_cols
      FROM pg_catalog.pg_attribute
     WHERE attrelid = ('public.' || quote_ident(r.table_name))::regclass
       AND attnum > 0 AND NOT attisdropped AND attgenerated = '';

    BEGIN
      EXECUTE format(
        'INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1)',
        r.table_name, v_cols, v_cols, r.table_name)
      USING r.row_data;
    EXCEPTION
      WHEN unique_violation THEN
        RAISE EXCEPTION '"%" cannot be restored: it already exists again.', r.label;
      WHEN foreign_key_violation THEN
        RAISE EXCEPTION '"%" cannot be restored: what it belonged to was deleted for good.', r.label;
    END;

    IF r.extra ? 'serial_ids' THEN
      UPDATE public.purchase_item_serials
         SET machine_id = r.row_id
       WHERE machine_id IS NULL
         AND id IN (SELECT (jsonb_array_elements_text(r.extra -> 'serial_ids'))::uuid);
    END IF;
    n := n + 1;
  END LOOP;

  IF n = 0 THEN
    RAISE EXCEPTION 'Nothing to restore: it was already restored or deleted for good.';
  END IF;
  DELETE FROM public.trash WHERE batch = p_batch;
  RETURN n;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.restore_trash(bigint) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.restore_trash(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_trash_batch(p_batch bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only a super admin can empty the trash' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.trash WHERE batch = p_batch;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.delete_trash_batch(bigint) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.delete_trash_batch(bigint) TO authenticated;

-- A batch goes when its newest row is past the retention period.
CREATE OR REPLACE FUNCTION public.purge_trash()
RETURNS int
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH old AS (
    SELECT batch FROM public.trash GROUP BY batch
    HAVING max(deleted_at) < now() - make_interval(days => public.trash_retention_days())
  ), gone AS (
    DELETE FROM public.trash t USING old WHERE t.batch = old.batch RETURNING 1
  )
  SELECT count(*)::int FROM gone;
$$;
REVOKE EXECUTE ON FUNCTION public.purge_trash() FROM anon, authenticated, public;

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
SELECT cron.schedule('purge-trash', '17 * * * *', 'SELECT public.purge_trash()');

-- ── Purchase bills: deletion requests, edit ──────────────────

ALTER TABLE public.deletion_requests
  DROP CONSTRAINT IF EXISTS deletion_requests_target_table_check;
ALTER TABLE public.deletion_requests
  ADD CONSTRAINT deletion_requests_target_table_check CHECK (target_table IN
    ('hospital_clients', 'installed_machines', 'machine_config', 'engineers', 'purchase_bills'));

-- Same as 008, but a machine's parts and engineers go by cascade, after
-- the machine, so they land in the trash with it.
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

-- Replaces a bill's header and items. Serials keep their machine link
-- when the same serial number is still on the bill.
CREATE OR REPLACE FUNCTION public.update_purchase_bill(bill_id uuid, bill jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER  -- replacing items needs delete rights only super admins have
SET search_path = ''
AS $$
DECLARE
  v_vendor    text := nullif(trim(bill ->> 'vendor'), '');
  v_bill_no   text := nullif(trim(bill ->> 'bill_no'), '');
  v_items     jsonb := coalesce(bill -> 'items', '[]'::jsonb);
  v_vendor_id uuid;
  v_item_id   uuid;
  v_item      jsonb;
  v_line      int := 0;
  v_links     jsonb;
BEGIN
  IF NOT (public.can_manage_purchases() AND public.session_is_active()) THEN
    RAISE EXCEPTION 'Only admins and accountants can edit purchase bills' USING ERRCODE = '42501';
  END IF;
  IF v_vendor IS NULL OR v_bill_no IS NULL OR nullif(bill ->> 'bill_date', '') IS NULL THEN
    RAISE EXCEPTION 'Vendor, bill no and date are required';
  END IF;
  IF jsonb_array_length(v_items) = 0 THEN
    RAISE EXCEPTION 'Add at least one item';
  END IF;

  SELECT id INTO v_vendor_id FROM public.purchase_vendors WHERE lower(name) = lower(v_vendor);
  IF v_vendor_id IS NULL THEN
    INSERT INTO public.purchase_vendors (name) VALUES (v_vendor) RETURNING id INTO v_vendor_id;
  END IF;

  BEGIN
    UPDATE public.purchase_bills
       SET vendor_id    = v_vendor_id,
           bill_no      = v_bill_no,
           bill_date    = (bill ->> 'bill_date')::date,
           payment_type = nullif(trim(bill ->> 'payment_type'), ''),
           sold_by      = nullif(trim(bill ->> 'sold_by'), ''),
           total        = coalesce((bill ->> 'total')::numeric, total),
           notes        = nullif(trim(bill ->> 'notes'), '')
     WHERE id = bill_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Bill % from % on % already exists', v_bill_no, v_vendor, bill ->> 'bill_date';
  END;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'This bill no longer exists';
  END IF;

  SELECT jsonb_object_agg(s.serial_no, s.machine_id)
    INTO v_links
    FROM public.purchase_item_serials s
    JOIN public.purchase_bill_items i ON i.id = s.bill_item_id
   WHERE i.bill_id = update_purchase_bill.bill_id AND s.machine_id IS NOT NULL;

  -- Not a delete of the bill, so these do not go to the trash.
  DELETE FROM public.purchase_bill_items WHERE purchase_bill_items.bill_id = update_purchase_bill.bill_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
    v_line := v_line + 1;
    IF nullif(trim(v_item ->> 'description'), '') IS NULL THEN
      RAISE EXCEPTION 'Item % has no description', v_line;
    END IF;

    INSERT INTO public.purchase_bill_items
      (bill_id, line_no, description, qty, unit_price, warranty_months, lifetime_warranty)
    VALUES (
      update_purchase_bill.bill_id,
      v_line,
      trim(v_item ->> 'description'),
      (v_item ->> 'qty')::int,
      coalesce((v_item ->> 'unit_price')::numeric, 0),
      (v_item ->> 'warranty_months')::int,
      coalesce((v_item ->> 'lifetime_warranty')::boolean, false)
    )
    RETURNING id INTO v_item_id;

    INSERT INTO public.purchase_item_serials (bill_item_id, serial_no, machine_id)
    SELECT v_item_id, trim(s), (v_links ->> trim(s))::uuid
      FROM jsonb_array_elements_text(coalesce(v_item -> 'serials', '[]'::jsonb)) s
     WHERE trim(s) <> '';
  END LOOP;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.update_purchase_bill(uuid, jsonb) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.update_purchase_bill(uuid, jsonb) TO authenticated;
