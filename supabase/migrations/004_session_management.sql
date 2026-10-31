-- ============================================================
-- EAM Platform - Migration 004
-- Adds: active_user_sessions view (Device security tab)
--       terminate_session() RPC
-- ============================================================

-- ── active_user_sessions ─────────────────────────────────────
-- Lists the signed-in user's own sessions. last_active only changes
-- when the session's token is refreshed (roughly hourly).

CREATE OR REPLACE VIEW public.active_user_sessions AS
  SELECT id         AS session_id,
         user_id,
         created_at AS login_time,
         updated_at AS last_active
    FROM auth.sessions
   WHERE user_id = auth.uid()
   ORDER BY updated_at DESC;

REVOKE ALL ON public.active_user_sessions FROM anon, public;
GRANT SELECT ON public.active_user_sessions TO authenticated;

-- ── terminate_session ────────────────────────────────────────
-- Deletes one of the caller's sessions; refresh tokens cascade.
-- The evicted device is logged out by the app's next session check.

CREATE OR REPLACE FUNCTION public.terminate_session(target_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM auth.sessions
   WHERE id = target_session_id
     AND user_id = auth.uid();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.terminate_session(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.terminate_session(uuid) TO authenticated;
