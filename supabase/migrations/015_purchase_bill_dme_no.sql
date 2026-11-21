-- ============================================================
-- EAM Platform - Migration 015   (run after 014)
-- Adds: purchase_bills.dme_no - our own bill ID (DMEB001, DMEB002…),
--       separate from the seller's bill_no.
--   - existing bills are numbered oldest first (bill date, then
--     when they were entered)
--   - new bills get the next number from a sequence in a trigger,
--     so the app never sends it and nobody can change it later
--   - numbers past 999 grow a digit (DMEB1000); a failed insert can
--     leave a gap, which is normal for sequences
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS public.purchase_bill_dme_no_seq;
REVOKE ALL ON SEQUENCE public.purchase_bill_dme_no_seq FROM anon, authenticated, public;

ALTER TABLE public.purchase_bills
  ADD COLUMN IF NOT EXISTS dme_no TEXT;

CREATE OR REPLACE FUNCTION public.format_dme_no(n bigint)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT 'DMEB' || lpad(n::text, greatest(3, length(n::text)), '0');
$$;

-- Backfill bills that don't have one yet, after any already numbered.
WITH last AS (
  SELECT coalesce(max(substring(dme_no FROM 5)::bigint), 0) AS n
    FROM public.purchase_bills
   WHERE dme_no IS NOT NULL
), todo AS (
  SELECT id, row_number() OVER (ORDER BY bill_date, created_at, id) AS rn
    FROM public.purchase_bills
   WHERE dme_no IS NULL
)
UPDATE public.purchase_bills b
   SET dme_no = public.format_dme_no(last.n + todo.rn)
  FROM todo, last
 WHERE b.id = todo.id;

-- Continue the sequence after the highest number used.
SELECT setval(
  'public.purchase_bill_dme_no_seq',
  greatest((SELECT max(substring(dme_no FROM 5)::bigint) FROM public.purchase_bills), 1),
  EXISTS (SELECT 1 FROM public.purchase_bills)
);

ALTER TABLE public.purchase_bills
  ALTER COLUMN dme_no SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'purchase_bills_dme_no_key') THEN
    ALTER TABLE public.purchase_bills ADD CONSTRAINT purchase_bills_dme_no_key UNIQUE (dme_no);
  END IF;
END;
$$;

-- Assigned on insert, frozen on update. SECURITY DEFINER so callers
-- need no rights on the sequence.
CREATE OR REPLACE FUNCTION public.set_purchase_bill_dme_no()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.dme_no := public.format_dme_no(nextval('public.purchase_bill_dme_no_seq'));
  ELSE
    NEW.dme_no := OLD.dme_no;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_purchase_bill_dme_no ON public.purchase_bills;
CREATE TRIGGER set_purchase_bill_dme_no
  BEFORE INSERT OR UPDATE ON public.purchase_bills
  FOR EACH ROW EXECUTE FUNCTION public.set_purchase_bill_dme_no();
