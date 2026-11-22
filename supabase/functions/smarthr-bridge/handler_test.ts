// deno test supabase/functions/smarthr-bridge/
import { assertEquals } from "jsr:@std/assert@1";
import { type Client, type Db, handle } from "./handler.ts";

const SECRET = "test-secret";
const ID1 = "a1000000-0000-0000-0000-000000000001";
const ID2 = "a1000000-0000-0000-0000-000000000002";

// In-memory stand-in for hospital_clients, same rules as index.ts.
function fakeDb(): Db & { rows: Client[]; lastLimit: number } {
  const rows: Client[] = [
    { id: ID1, name: "Square Hospital", district: "Dhaka", approval_status: "approved", latitude: null, longitude: null },
    { id: ID2, name: "Square Pending", district: "Dhaka", approval_status: "pending", latitude: null, longitude: null },
    ...Array.from({ length: 80 }, (_, i) => ({
      id: `b1000000-0000-0000-0000-${String(i).padStart(12, "0")}`,
      name: `Clinic ${i}`, district: "Sylhet", approval_status: "approved", latitude: null, longitude: null,
    })),
  ];
  const approved = () => rows.filter((r) => r.approval_status === "approved");
  return {
    rows,
    lastLimit: 0,
    search(q, limit) {
      this.lastLimit = limit;
      const s = q.toLowerCase();
      return Promise.resolve(approved()
        .filter((r) => `${r.name} ${r.district}`.toLowerCase().includes(s))
        .slice(0, limit));
    },
    get: (ids) => Promise.resolve(approved().filter((r) => ids.includes(r.id as string))),
    setLocationIfEmpty(id, lat, lng, setBy) {
      const r = approved().find((r) => r.id === id && r.latitude === null);
      if (!r) return Promise.resolve(null);
      Object.assign(r, { latitude: lat, longitude: lng, location_set_by: setBy });
      return Promise.resolve(r);
    },
  };
}

const call = (db: Db, body: unknown, secret = SECRET) =>
  handle(
    new Request("http://x/smarthr-bridge", {
      method: "POST",
      headers: { "x-bridge-secret": secret },
      body: JSON.stringify(body),
    }),
    db,
    SECRET,
  );

Deno.test("bad or missing secret → 401", async () => {
  const db = fakeDb();
  assertEquals((await call(db, { action: "search", q: "squ" }, "wrong")).status, 401);
  const noHeader = new Request("http://x", { method: "POST", body: "{}" });
  assertEquals((await handle(noHeader, db, SECRET)).status, 401);
  // An unset secret on the server refuses everyone, even an empty header.
  assertEquals((await handle(noHeader, db, "")).status, 401);
});

Deno.test("search: under 3 characters → query_too_short", async () => {
  const res = await call(fakeDb(), { action: "search", q: "  sq  " });
  assertEquals(res.status, 400);
  assertEquals(await res.json(), { error: "query_too_short" });
});

Deno.test("search: approved only, case-insensitive", async () => {
  const res = await call(fakeDb(), { action: "search", q: "SQU" });
  assertEquals((await res.json()).clients.map((c: Client) => c.id), [ID1]);
});

Deno.test("search: never more than 50 rows", async () => {
  const db = fakeDb();
  const body = await (await call(db, { action: "search", q: "clinic", limit: 500 })).json();
  assertEquals(body.clients.length, 50);
  assertEquals(db.lastLimit, 50);
  await call(db, { action: "search", q: "clinic" });
  assertEquals(db.lastLimit, 20); // contract default
});

Deno.test("get: approved only, at most 100 ids", async () => {
  const db = fakeDb();
  const body = await (await call(db, { action: "get", ids: [ID1, ID2] })).json();
  assertEquals(body.clients.map((c: Client) => c.id), [ID1]);
  const tooMany = Array.from({ length: 101 }, () => ID1);
  assertEquals((await call(db, { action: "get", ids: tooMany })).status, 400);
  assertEquals((await call(db, { action: "get", ids: ["not-a-uuid"] })).status, 400);
});

Deno.test("set_location twice → second is updated:false, pin kept", async () => {
  const db = fakeDb();
  const first = await (await call(db, {
    action: "set_location", id: ID1, latitude: 23.75, longitude: 90.38, set_by: "Rafiq Hasan (smartHr)",
  })).json();
  assertEquals(first.updated, true);
  assertEquals(first.client.latitude, 23.75);

  const second = await (await call(db, {
    action: "set_location", id: ID1, latitude: 24.0, longitude: 91.0, set_by: "Someone else",
  })).json();
  assertEquals(second.updated, false);
  assertEquals(second.client.latitude, 23.75);
  assertEquals(second.client.location_set_by, "Rafiq Hasan (smartHr)");
});

Deno.test("set_location: outside Bangladesh, unknown or pending client", async () => {
  const db = fakeDb();
  const at = (id: string, latitude: unknown, longitude: unknown) =>
    call(db, { action: "set_location", id, latitude, longitude });
  assertEquals((await at(ID1, 51.5, -0.1)).status, 400);
  assertEquals((await at(ID1, "23.7", 90.3)).status, 400);
  assertEquals((await at(ID2, 23.7, 90.3)).status, 404); // pending
  assertEquals((await at("c1000000-0000-0000-0000-000000000000", 23.7, 90.3)).status, 404);
});

Deno.test("unknown action → 400", async () => {
  const res = await call(fakeDb(), { action: "drop" });
  assertEquals(await res.json(), { error: "unknown_action" });
});
