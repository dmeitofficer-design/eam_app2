// supabase/functions/smarthr-history/index.ts
//
// EAM → smartHr, read-only: a client's visits, jobs and unplanned visits.
// Deployed with JWT verification on. Secrets: SMARTHR_BRIDGE_SECRET (shared
// with smartHr as EAM_BRIDGE_SECRET) and SMARTHR_HISTORY_URL.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { handle } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

// Runs as the caller, so EAM's RLS (approval, active session) decides access.
const asCaller = (token: string) =>
  createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

Deno.serve((req) =>
  handle(req, {
    async roleLevel(token) {
      const { data, error } = await asCaller(token).rpc("current_role_level");
      return error ? 0 : Number(data ?? 0);
    },
    async canSeeClient(token, clientId) {
      const { data, error } = await asCaller(token)
        .from("hospital_clients")
        .select("id")
        .eq("id", clientId)
        .maybeSingle();
      return !error && data != null;
    },
    fetchHistory(clientId) {
      return fetch(Deno.env.get("SMARTHR_HISTORY_URL")!, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-bridge-secret": Deno.env.get("SMARTHR_BRIDGE_SECRET") ?? "",
        },
        body: JSON.stringify({ client_id: clientId, limit: 50 }),
        signal: AbortSignal.timeout(15000),
      });
    },
  })
);
