-- ============================================================
-- EAM Platform - Migration 010   (run after 009)
-- Adds: IT purchase bills from the vendor (PCs and parts sent
--       with client machines), their serial numbers and warranty.
--
--   purchase_vendors     the shops we buy from
--   purchase_bills       one row per vendor bill
--   purchase_bill_items  bill lines (description, qty, price, warranty)
--   purchase_item_serials one row per serial; machine_id links the
--                        part to the client machine it went into
--   purchase_warranty_status view: warranty end date + status per serial
--
-- Prices are confidential: only admins and super admins can read
-- any of these tables. Admins add and edit; only super admins delete.
-- Data is loaded by 011_purchase_data.sql.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.purchase_vendors (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL UNIQUE,
  address    TEXT,
  phone      TEXT,
  email      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_name TEXT,
  updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by_name TEXT
);

CREATE TABLE IF NOT EXISTS public.purchase_bills (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id    UUID NOT NULL REFERENCES public.purchase_vendors(id),
  bill_no      TEXT NOT NULL,
  bill_date    DATE NOT NULL,
  payment_type TEXT,                    -- Credit / Cash, as printed
  sold_by      TEXT,
  total        NUMERIC(12,2) NOT NULL,  -- printed bill total
  net_paid     NUMERIC(12,2),           -- only when returns/discounts changed what was paid
  notes        TEXT,                    -- handwritten notes: purpose, client, cheque
  source_page  INT,                     -- page in the scanned bills PDF
  ref_no       INT,                     -- circled number on the paper bill
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_name TEXT,
  updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by_name TEXT,
  -- the vendor reused one bill number on two dates
  UNIQUE (vendor_id, bill_no, bill_date)
);

CREATE TABLE IF NOT EXISTS public.purchase_bill_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id           UUID NOT NULL REFERENCES public.purchase_bills(id) ON DELETE CASCADE,
  line_no           INT NOT NULL,
  description       TEXT NOT NULL,
  qty               INT NOT NULL CHECK (qty > 0),
  unit_price        NUMERIC(12,2) NOT NULL,
  amount            NUMERIC(12,2) GENERATED ALWAYS AS (qty * unit_price) STORED,
  warranty_months   INT,                -- NULL = no warranty printed
  lifetime_warranty BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (bill_id, line_no)
);

CREATE TABLE IF NOT EXISTS public.purchase_item_serials (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_item_id UUID NOT NULL REFERENCES public.purchase_bill_items(id) ON DELETE CASCADE,
  serial_no    TEXT NOT NULL,
  -- set in the app; a deleted machine leaves the part unassigned
  machine_id   UUID REFERENCES public.installed_machines(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by_name TEXT
);
-- not unique: a few serials appear on two bills (see purchase_bills.notes)
CREATE INDEX IF NOT EXISTS purchase_item_serials_serial_idx
  ON public.purchase_item_serials (upper(serial_no));
CREATE INDEX IF NOT EXISTS purchase_item_serials_machine_idx
  ON public.purchase_item_serials (machine_id);
CREATE INDEX IF NOT EXISTS purchase_bill_items_bill_idx
  ON public.purchase_bill_items (bill_id);

-- ── updated_at + audit triggers ──────────────────────────────

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['purchase_vendors', 'purchase_bills',
                           'purchase_bill_items', 'purchase_item_serials']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_%s_updated_at ON public.%I', t, t);
    EXECUTE format('CREATE TRIGGER set_%s_updated_at BEFORE UPDATE ON public.%I
                      FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at()', t, t);
  END LOOP;

  FOREACH t IN ARRAY ARRAY['purchase_vendors', 'purchase_bills']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_%s_audit ON public.%I', t, t);
    EXECUTE format('CREATE TRIGGER set_%s_audit BEFORE INSERT OR UPDATE ON public.%I
                      FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields()', t, t);
  END LOOP;
END;
$$;

-- Serials only record who last changed them (who assigned the machine).
CREATE OR REPLACE FUNCTION public.set_updated_by_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    NEW.updated_by := auth.uid();
    SELECT coalesce(nullif(trim(full_name), ''), email)
      INTO NEW.updated_by_name
      FROM public.profiles
     WHERE id = auth.uid();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_purchase_item_serials_updated_by ON public.purchase_item_serials;
CREATE TRIGGER set_purchase_item_serials_updated_by
  BEFORE INSERT OR UPDATE ON public.purchase_item_serials
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_by_fields();

-- ── Policies: admins + super admins only ─────────────────────

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['purchase_vendors', 'purchase_bills',
                           'purchase_bill_items', 'purchase_item_serials']
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);

    EXECUTE format('DROP POLICY IF EXISTS "Admins can read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Admins can read" ON public.%I
                      FOR SELECT TO authenticated
                      USING ((SELECT public.is_admin_or_super()))', t);

    EXECUTE format('DROP POLICY IF EXISTS "Admins can insert" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Admins can insert" ON public.%I
                      FOR INSERT TO authenticated
                      WITH CHECK ((SELECT public.is_admin_or_super()))', t);

    EXECUTE format('DROP POLICY IF EXISTS "Admins can update" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Admins can update" ON public.%I
                      FOR UPDATE TO authenticated
                      USING ((SELECT public.is_admin_or_super()))
                      WITH CHECK ((SELECT public.is_admin_or_super()))', t);

    EXECUTE format('DROP POLICY IF EXISTS "Super admins can delete" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Super admins can delete" ON public.%I
                      FOR DELETE TO authenticated
                      USING ((SELECT public.is_super_admin()))', t);

    -- Active-session rule (see 005)
    EXECUTE format('DROP POLICY IF EXISTS "Require active session" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Require active session" ON public.%I
                      AS RESTRICTIVE FOR ALL TO authenticated
                      USING ((SELECT public.session_is_active()))
                      WITH CHECK ((SELECT public.session_is_active()))', t);
  END LOOP;
END;
$$;

-- ── Warranty view ────────────────────────────────────────────
-- security_invoker: the caller's policies apply, so it is admin-only too.
-- One row per serial, or per line when the bill printed no serial.

DROP VIEW IF EXISTS public.purchase_warranty_status;
CREATE VIEW public.purchase_warranty_status
WITH (security_invoker = on) AS
SELECT
  s.id          AS serial_id,
  s.serial_no,
  s.machine_id,
  i.id          AS bill_item_id,
  i.description,
  i.qty,
  i.unit_price,
  b.id          AS bill_id,
  b.bill_no,
  b.bill_date,
  v.name        AS vendor,
  i.warranty_months,
  i.lifetime_warranty,
  CASE WHEN NOT i.lifetime_warranty AND i.warranty_months IS NOT NULL
       THEN (b.bill_date + make_interval(months => i.warranty_months))::date
  END AS warranty_until,
  CASE
    WHEN i.lifetime_warranty       THEN 'lifetime'
    WHEN i.warranty_months IS NULL THEN 'none'
    WHEN b.bill_date + make_interval(months => i.warranty_months) >= current_date THEN 'active'
    ELSE 'expired'
  END AS status
FROM public.purchase_bill_items i
JOIN public.purchase_bills   b ON b.id = i.bill_id
JOIN public.purchase_vendors v ON v.id = b.vendor_id
LEFT JOIN public.purchase_item_serials s ON s.bill_item_id = i.id;

REVOKE ALL ON public.purchase_warranty_status FROM anon, public;
GRANT SELECT ON public.purchase_warranty_status TO authenticated;
