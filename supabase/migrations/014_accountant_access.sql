-- ============================================================
-- EAM Platform - Migration 014   (run after 013)
-- Accountant role: viewer access + purchase bills.
--   - can_manage_purchases(): admin, super admin or accountant
--   - purchase tables: accountants may read, add and edit
--     (deleting stays super-admin only)
--   - create_purchase_bill() accepts accountants
--   - handle_new_user() accepts the accountant role
-- Accountants sit at role level 1 (same as viewer) everywhere
-- else, so clients / machines access is exactly a viewer's.
-- ============================================================

CREATE OR REPLACE FUNCTION public.can_manage_purchases()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_role_level() >= 3
      OR EXISTS (
           SELECT 1
             FROM public.profiles
            WHERE id = auth.uid()
              AND role::text = 'accountant'
              AND NOT is_banned
         );
$$;

REVOKE EXECUTE ON FUNCTION public.can_manage_purchases() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.can_manage_purchases() TO authenticated;

-- ── New users: allow the accountant role ─────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text := NEW.raw_app_meta_data ->> 'role';
BEGIN
  IF v_role IS NULL OR v_role NOT IN ('user', 'accountant', 'data_entry', 'admin') THEN
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

-- ── Purchase policies: admins + accountants ──────────────────

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['purchase_vendors', 'purchase_bills',
                           'purchase_bill_items', 'purchase_item_serials']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS "Admins can read" ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS "Purchase staff can read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Purchase staff can read" ON public.%I
                      FOR SELECT TO authenticated
                      USING ((SELECT public.can_manage_purchases()))', t);

    EXECUTE format('DROP POLICY IF EXISTS "Admins can insert" ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS "Purchase staff can insert" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Purchase staff can insert" ON public.%I
                      FOR INSERT TO authenticated
                      WITH CHECK ((SELECT public.can_manage_purchases()))', t);

    EXECUTE format('DROP POLICY IF EXISTS "Admins can update" ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS "Purchase staff can update" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Purchase staff can update" ON public.%I
                      FOR UPDATE TO authenticated
                      USING ((SELECT public.can_manage_purchases()))
                      WITH CHECK ((SELECT public.can_manage_purchases()))', t);
  END LOOP;
END;
$$;

-- ── create_purchase_bill: same as 012, accountants allowed ───

CREATE OR REPLACE FUNCTION public.create_purchase_bill(bill jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_vendor  text := nullif(trim(bill ->> 'vendor'), '');
  v_bill_no text := nullif(trim(bill ->> 'bill_no'), '');
  v_items   jsonb := coalesce(bill -> 'items', '[]'::jsonb);
  v_vendor_id uuid;
  v_bill_id   uuid;
  v_item_id   uuid;
  v_item      jsonb;
  v_line      int := 0;
BEGIN
  IF NOT public.can_manage_purchases() THEN
    RAISE EXCEPTION 'Only admins and accountants can add purchase bills' USING ERRCODE = '42501';
  END IF;
  IF v_vendor IS NULL OR v_bill_no IS NULL OR nullif(bill ->> 'bill_date', '') IS NULL THEN
    RAISE EXCEPTION 'Vendor, bill no and date are required';
  END IF;
  IF jsonb_array_length(v_items) = 0 THEN
    RAISE EXCEPTION 'Add at least one item';
  END IF;

  -- Same vendor name in any letter case is the same vendor.
  SELECT id INTO v_vendor_id FROM public.purchase_vendors WHERE lower(name) = lower(v_vendor);
  IF v_vendor_id IS NULL THEN
    INSERT INTO public.purchase_vendors (name) VALUES (v_vendor) RETURNING id INTO v_vendor_id;
  END IF;

  BEGIN
    INSERT INTO public.purchase_bills
      (vendor_id, bill_no, bill_date, payment_type, sold_by, total, net_paid, notes)
    VALUES (
      v_vendor_id,
      v_bill_no,
      (bill ->> 'bill_date')::date,
      nullif(trim(bill ->> 'payment_type'), ''),
      nullif(trim(bill ->> 'sold_by'), ''),
      coalesce((bill ->> 'total')::numeric,
               (SELECT sum((i ->> 'qty')::int * (i ->> 'unit_price')::numeric)
                  FROM jsonb_array_elements(v_items) i)),
      (bill ->> 'net_paid')::numeric,
      nullif(trim(bill ->> 'notes'), '')
    )
    RETURNING id INTO v_bill_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Bill % from % on % already exists', v_bill_no, v_vendor, bill ->> 'bill_date';
  END;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
    v_line := v_line + 1;
    IF nullif(trim(v_item ->> 'description'), '') IS NULL THEN
      RAISE EXCEPTION 'Item % has no description', v_line;
    END IF;

    INSERT INTO public.purchase_bill_items
      (bill_id, line_no, description, qty, unit_price, warranty_months, lifetime_warranty)
    VALUES (
      v_bill_id,
      v_line,
      trim(v_item ->> 'description'),
      (v_item ->> 'qty')::int,
      coalesce((v_item ->> 'unit_price')::numeric, 0),
      (v_item ->> 'warranty_months')::int,
      coalesce((v_item ->> 'lifetime_warranty')::boolean, false)
    )
    RETURNING id INTO v_item_id;

    INSERT INTO public.purchase_item_serials (bill_item_id, serial_no)
    SELECT v_item_id, trim(s)
      FROM jsonb_array_elements_text(coalesce(v_item -> 'serials', '[]'::jsonb)) s
     WHERE trim(s) <> '';
  END LOOP;

  RETURN v_bill_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_purchase_bill(jsonb) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.create_purchase_bill(jsonb) TO authenticated;
