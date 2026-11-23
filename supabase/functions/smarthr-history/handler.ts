// supabase/functions/smarthr-history/handler.ts
//
// A client's service history from smartHr, for EAM users at data entry or
// above. The shared secret stays here, never in the app.
// Contract: docs/smarthr-service-history.md.

export interface Deps {
  /** Caller's role level (0 if not signed in / banned), via their own JWT. */
  roleLevel(token: string): Promise<number>;
  /** Whether the caller can see this client under EAM's RLS. */
  canSeeClient(token: string, clientId: string): Promise<boolean>;
  /** POSTs to smartHr's eam-history with the shared secret. */
  fetchHistory(clientId: string): Promise<Response>;
}

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const err = (code: string, status: number) => json({ error: code }, status);

export async function handle(req: Request, deps: Deps) {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (!token) return err("unauthorized", 401);

    let clientId = "";
    try {
      clientId = String((await req.json())?.client_id ?? "");
    } catch { /* falls through to invalid_client_id */ }
    if (!UUID.test(clientId)) return err("invalid_client_id", 400);

    // Same people who see Engineers (data entry and above).
    if ((await deps.roleLevel(token)) < 2) return err("forbidden", 403);
    if (!(await deps.canSeeClient(token, clientId))) return err("not_found", 404);

    const res = await deps.fetchHistory(clientId);
    if (!res.ok) {
      console.error("smartHr eam-history answered", res.status, await res.text());
      return err("smarthr_unavailable", 502);
    }
    const body = await res.json();
    return json({ entries: Array.isArray(body?.entries) ? body.entries : [] });
  } catch (e) {
    console.error(e);
    return err("smarthr_unavailable", 502);
  }
}
