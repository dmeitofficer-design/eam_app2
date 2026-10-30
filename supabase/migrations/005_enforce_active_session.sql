-- ============================================================
-- EAM Platform - Migration 005
-- Adds: session_is_active() helper
--       RESTRICTIVE RLS policy on every app table so a session
--       terminated from the Device security tab loses database
--       access immediately, not when its access token expires
--       machine_engineers SELECT policy (was missing)
-- ============================================================

-- ── session_is_active ────────────────────────────────────────
-- True while the session in the caller's JWT still exists.
-- terminate_session() deletes that row, so this flips to false.

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
  );
$$;

REVOKE EXECUTE ON FUNCTION public.session_is_active() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.session_is_active() TO authenticated;

-- ── Restrictive policies ─────────────────────────────────────
-- RESTRICTIVE policies are AND-ed with the existing permissive
-- ones, so current role rules are unchanged. Only the
-- authenticated role is targeted: anon reads of app_versions keep
-- working. The (SELECT ...) wrapper evaluates once per statement.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles',
    'hospital_clients',
    'installed_machines',
    'installing_engineers',
    'machine_parts',
    'machine_config',
    'engineers',
    'machine_engineers',
    'app_versions'
  ]
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

-- ── machine_engineers ────────────────────────────────────────
-- The app embeds machine_engineers when loading machines, but the
-- table had no SELECT policy, so with RLS on the assigned engineers
-- came back empty. Make sure RLS is on and reads are allowed like
-- the other tables.

ALTER TABLE public.machine_engineers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read machine engineers"
  ON public.machine_engineers;
CREATE POLICY "Authenticated users can read machine engineers"
  ON public.machine_engineers FOR SELECT
  TO authenticated USING (true);
