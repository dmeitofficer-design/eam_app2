// supabase/functions/smarthr-bridge/index.ts
//
// Lets smartHr (a separate Supabase project) search EAM clients and
// fill an empty map pin. Deployed with --no-verify-jwt: smartHr has no
// EAM accounts, so the only key is the shared x-bridge-secret header
// (secret SMARTHR_BRIDGE_SECRET here, EAM_BRIDGE_SECRET in smartHr).
// The service role never leaves this function.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { CLIENT_COLUMNS, type Db, handle } from "./handler.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const clients = () =>
  admin.from("hospital_clients").select(CLIENT_COLUMNS).eq(
    "approval_status",
    "approved",
  );

const db: Db = {
  async search(q, limit) {
    // Characters that are wildcards or syntax in a PostgREST or-filter.
    const term = q.replace(/[,()"\\%_*:]/g, " ");
    const { data, error } = await clients()
      .or(
        `name.ilike.*${term}*,address.ilike.*${term}*,district.ilike.*${term}*`,
      )
      .order("name")
      .limit(limit);
    if (error) throw error;
    return data;
  },

  async get(ids) {
    const { data, error } = await clients().in("id", ids);
    if (error) throw error;
    return data;
  },

  async setLocationIfEmpty(id, lat, lng, setBy) {
    // One UPDATE … WHERE latitude IS NULL RETURNING: a pin is never overwritten.
    // updated_by_name is the app's "Updated by" audit line for client edits.
    const { data, error } = await admin
      .from("hospital_clients")
      .update({
        latitude: lat,
        longitude: lng,
        location_set_at: new Date().toISOString(),
        location_set_by: setBy,
        updated_by: null,
        updated_by_name: setBy,
      })
      .eq("id", id)
      .eq("approval_status", "approved")
      .is("latitude", null)
      .select(CLIENT_COLUMNS);
    if (error) throw error;
    return data[0] ?? null;
  },
};

Deno.serve((req) => handle(req, db, Deno.env.get("SMARTHR_BRIDGE_SECRET") ?? ""));
