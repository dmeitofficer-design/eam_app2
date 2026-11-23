# Service history from smartHr (eam_app2 ← smartHr)

Status: **EAM side built 2026-11-23; smartHr side not built.** The EAM client page shows a "Service history" panel: who from smartHr visited the client, when, why and what was done. smartHr already stores `eam_client_id` on `visit_plan_items`, `field_duty_assignments` and `unplanned_visits` (smartHr migration 0033).

It is the reverse of `smarthr-bridge` (smartHr `docs/eam-clients-integration.md`), read-only.

```
EAM app (signed in to EAM, data entry or above)
   │
   ▼
EAM Edge Function  smarthr-history       ← verifies the EAM JWT; caller must see the client (RLS) and be data entry+
   │  HTTPS + the same shared secret (SMARTHR_BRIDGE_SECRET in EAM = EAM_BRIDGE_SECRET in smartHr)
   ▼
smartHr Edge Function  eam-history        ← checks the secret; reads with smartHr's own service role
   │
   ▼
smartHr: visit_plan_items (+ visit_plans), field_duty_assignments, unplanned_visits
```

The secret never ships in the EAM app; only the EAM function holds it. No EAM user gets a smartHr account.

## The contract (both sides build to this)

`POST https://yhoeyrpxlhxcggtxjcyq.supabase.co/functions/v1/eam-history` (deployed `--no-verify-jwt`), header `x-bridge-secret: <secret>`, JSON body. Errors are `{ "error": "<code>" }` with 4xx: `401 unauthorized` (bad or missing secret, constant-time compare), `400 invalid_client_id`.

Request: `{ "client_id": "uuid", "limit": 50 }` (`limit` 1–100, default 50).

Answer: `{ "entries": [Entry] }`, newest first (by `date`), at most `limit`, for rows whose `eam_client_id = client_id`.

`Entry`:
```json
{
  "kind": "visit",              // "visit" | "job" | "unplanned"
  "id": "uuid",                 // the smartHr row id
  "date": "2026-11-20",         // visit: plan_date; job: start_date; unplanned: visit_date
  "end_date": null,             // job: end_date when it differs from date; else null
  "staff": ["Rafiq Hasan"],     // who went: visit plan owner / job assignees / unplanned employee
  "title": "Quarterly PM",      // visit: purpose (or place); job: title; unplanned: reason
  "job_type": "Service",        // job type name for jobs; null otherwise
  "status": "approved",         // smartHr's own status text, shown as is
  "report": "Replaced tube…",   // job: report_text; visit: outcome/notes if smartHr keeps one; else null
  "reported_at": null           // job: reported_at; else null
}
```

Leave out what never happened: drafts, and visit plans / unplanned visits that were rejected or withdrawn. No photos (they are private storage). Only these fields: no phone numbers, salaries or other HR data.

## EAM side (built)

- `supabase/functions/smarthr-history` (JWT verified): `{ "client_id" }` → the smartHr answer, passed through. Refuses callers below data entry (`403 forbidden`) and clients the caller cannot see (`404 not_found`). Secrets: `SMARTHR_BRIDGE_SECRET` (already set), `SMARTHR_HISTORY_URL` = the URL above.
- Client page: "Service history" panel for data entry and above (same people who see Engineers). Shows "smartHr has not been connected yet" until `eam-history` answers.

## Paste this to the smartHr session

> EAM now shows a "Service history" panel on each client page, read from smartHr. Please build the smartHr side in `eam_app2/docs/smarthr-service-history.md` (contract below):
> 1. **Edge Function `eam-history`** (`--no-verify-jwt`): refuse any request whose `x-bridge-secret` header is not `Deno.env.get("EAM_BRIDGE_SECRET")` (constant-time compare, 401). Body `{ "client_id": uuid, "limit": 1–100, default 50 }`. Answer `{ "entries": [Entry] }`, newest first, from `visit_plan_items` (with `visit_plans` for date, owner and status), `field_duty_assignments` (with its assignees) and `unplanned_visits`, where `eam_client_id = client_id`. Entry: `kind` (visit | job | unplanned), `id`, `date`, `end_date`, `staff` (names), `title`, `job_type`, `status`, `report`, `reported_at`, exactly as in the doc. Leave out drafts and rejected/withdrawn visits; no photos, phones or other HR data. Service role inside the function only.
> 2. Deno tests: bad secret → 401, bad `client_id` → 400, limit capped at 100, newest first, other clients' rows never returned.
> 3. Deploy: `supabase functions deploy eam-history --no-verify-jwt`. It uses the existing `EAM_BRIDGE_SECRET`; nothing new to set.
> Tell the user when it is deployed.
