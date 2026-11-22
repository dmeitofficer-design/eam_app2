// supabase/functions/smarthr-bridge/handler.ts
//
// Request handling for the smartHr bridge, kept apart from the database
// so it can be tested without one. Contract:
// smartHr/docs/eam-clients-integration.md ("The bridge contract").

export const CLIENT_COLUMNS =
  "id, name, address, district, division, facility_type, " +
  "contact_person_name, contact_person_phone, " +
  "latitude, longitude, location_set_at, location_set_by";

export type Client = Record<string, unknown>;

export interface Db {
  /** Approved clients whose name, address or district contains `q`. */
  search(q: string, limit: number): Promise<Client[]>;
  /** Approved clients with these ids. */
  get(ids: string[]): Promise<Client[]>;
  /** Sets the pin only if the approved client has none; null if nothing was updated. */
  setLocationIfEmpty(
    id: string,
    lat: number,
    lng: number,
    setBy: string,
  ): Promise<Client | null>;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const err = (code: string, status = 400) => json({ error: code }, status);

async function sha256(s: string) {
  return new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)),
  );
}

// Hashing first makes both sides 32 bytes, so the loop never leaks length.
export async function secretMatches(given: string, expected: string) {
  if (!expected) return false;
  const [a, b] = await Promise.all([sha256(given), sha256(expected)]);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export async function handle(req: Request, db: Db, secret: string) {
  if (!(await secretMatches(req.headers.get("x-bridge-secret") ?? "", secret))) {
    return err("unauthorized", 401);
  }
  if (req.method !== "POST") return err("method_not_allowed", 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return err("invalid_json");
  }
  if (!body || typeof body !== "object") return err("invalid_json");

  try {
    switch (body.action) {
      case "search": {
        const q = String(body.q ?? "").trim();
        if (q.length < 3) return err("query_too_short");
        const asked = Number(body.limit ?? 20);
        const limit = Number.isFinite(asked)
          ? Math.min(Math.max(Math.trunc(asked), 1), 50)
          : 20;
        return json({ clients: await db.search(q, limit) });
      }

      case "get": {
        const ids = body.ids;
        if (!Array.isArray(ids) || ids.length > 100) return err("invalid_ids");
        if (!ids.every((id) => typeof id === "string" && UUID.test(id))) {
          return err("invalid_ids");
        }
        return json({ clients: ids.length ? await db.get(ids) : [] });
      }

      case "set_location": {
        const id = String(body.id ?? "");
        const lat = body.latitude, lng = body.longitude;
        if (!UUID.test(id)) return err("invalid_id");
        if (
          typeof lat !== "number" || typeof lng !== "number" ||
          !(lat >= 20 && lat <= 27) || !(lng >= 88 && lng <= 93)
        ) {
          return err("invalid_location");
        }
        const setBy = String(body.set_by ?? "").trim().slice(0, 200) ||
          "smartHr";

        const updated = await db.setLocationIfEmpty(id, lat, lng, setBy);
        if (updated) return json({ client: updated, updated: true });

        const [existing] = await db.get([id]);
        if (!existing) return err("not_found", 404);
        return json({ client: existing, updated: false });
      }

      default:
        return err("unknown_action");
    }
  } catch (e) {
    console.error(e);
    return err("server_error", 500);
  }
}
