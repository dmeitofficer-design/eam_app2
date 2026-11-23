// deno test supabase/functions/smarthr-history/
import { assertEquals } from "jsr:@std/assert@1";
import { type Deps, handle } from "./handler.ts";

const CLIENT = "a1000000-0000-0000-0000-000000000001";
const entry = { kind: "job", id: "x", date: "2026-11-20", staff: ["Rafiq Hasan"], title: "PM" };

function deps(over: Partial<Deps> = {}): Deps & { called: string[] } {
  const called: string[] = [];
  return {
    called,
    roleLevel: () => Promise.resolve(2),
    canSeeClient: () => Promise.resolve(true),
    fetchHistory: (id) => {
      called.push(id);
      return Promise.resolve(Response.json({ entries: [entry] }));
    },
    ...over,
  };
}

const call = (d: Deps, body: unknown = { client_id: CLIENT }, token = "jwt") =>
  handle(
    new Request("http://x", {
      method: "POST",
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      body: JSON.stringify(body),
    }),
    d,
  );

Deno.test("passes smartHr entries through", async () => {
  const d = deps();
  const res = await call(d);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { entries: [entry] });
  assertEquals(d.called, [CLIENT]);
});

Deno.test("no token → 401, bad id → 400; smartHr never asked", async () => {
  const d = deps();
  assertEquals((await call(d, { client_id: CLIENT }, "")).status, 401);
  assertEquals((await call(d, { client_id: "nope" })).status, 400);
  assertEquals(d.called, []);
});

Deno.test("viewers and accountants (level 1) → 403", async () => {
  const d = deps({ roleLevel: () => Promise.resolve(1) });
  assertEquals((await call(d)).status, 403);
  assertEquals(d.called, []);
});

Deno.test("a client the caller cannot see → 404", async () => {
  const d = deps({ canSeeClient: () => Promise.resolve(false) });
  assertEquals((await call(d)).status, 404);
  assertEquals(d.called, []);
});

Deno.test("smartHr down or not deployed → 502", async () => {
  const notFound = deps({ fetchHistory: () => Promise.resolve(new Response("nf", { status: 404 })) });
  assertEquals(await (await call(notFound)).json(), { error: "smarthr_unavailable" });
  const offline = deps({ fetchHistory: () => Promise.reject(new TypeError("offline")) });
  assertEquals((await call(offline)).status, 502);
});
