# Supabase setup

Run migrations in order in **Dashboard → SQL Editor**. Each file is safe to
run again.

## Roles

| Role (`app_role`) | In the app   | Can do |
| ----------------- | ------------ | ------ |
| `user`            | Viewer       | View clients, machines' basic info and warranty |
| `data_entry`      | Data Entry   | Viewer access + add clients, and machines to existing clients. Submissions stay hidden from others until an admin approves them |
| `admin`           | Admin        | Everything except deleting; approves submissions; full machine details; create Viewer / Data Entry users. Deleting sends a request to a super admin |
| `super_admin`     | Super Admin  | Everything, including deleting data, approving deletion requests, creating admins, banning and deleting users |

## One-time steps for Phase 1

1. **Run `006_role_values.sql`, then `007_roles_users_audit.sql`.**
   Run them as two separate runs: 006 must finish before 007 can use the new role values.

2. **Deploy the `manage-users` Edge Function.** It creates, bans and deletes
   users with the service-role key, which must never be inside the app.
   - Dashboard → **Edge Functions** → **Deploy a new function** → **Via Editor**
   - Name it exactly `manage-users`, paste `functions/manage-users/index.ts`, deploy.
   - Keep "Verify JWT" on (the default).
   - Or, with the Supabase CLI: `supabase functions deploy manage-users`.

3. **Turn off public sign-ups.** Accounts are now created only from the app's
   **Users** page. Dashboard → **Authentication → Sign In / Providers** →
   turn off **Allow new users to sign up**. Creating users from the app
   still works.

4. **Put the reset code in the password-reset email.** The app's
   "Forgot password?" asks for a code. Dashboard → **Authentication →
   Emails → Reset Password**, and add the code to the template, e.g.:

   ```html
   <h2>Reset your password</h2>
   <p>Your reset code is: <strong>{{ .Token }}</strong></p>
   <p>Enter it in the DME Client Manager app. It expires soon.</p>
   ```

5. **Make sure you are a super admin.** Find your user id under
   Authentication → Users, then:

   ```sql
   update public.profiles set role = 'super_admin' where id = '<your-user-id>';
   ```

## Phase 2: approvals and notifications

Run `008_approvals_notifications.sql` (after 007). It adds:

- `approval_status` on clients and machines. Everything that already exists
  stays `approved`; data entry submissions start as `pending`.
- `notifications`: the in-app inbox (bell icon). Rows are written by
  database triggers only; the app checks for new ones every 30 seconds.
- `deletion_requests` and `review_deletion_request()`: admins request,
  super admins approve (which deletes the record) or reject.
- A storage rule letting data entry operators upload the invoice PDF of
  their own pending machine.

## Phase 3: IT purchase bills

Run `010_purchases.sql`, then `011_purchase_data.sql` (after 009). Both are
safe to run again. They add:

- `purchase_vendors`, `purchase_bills`, `purchase_bill_items`,
  `purchase_item_serials`: the vendor bills for the PCs and parts sent with
  client machines, 72 bills loaded from the scanned bills PDF.
- `purchase_item_serials.machine_id`: links a part to the client machine it
  went into. Empty until assigned in the app; deleting the machine clears it.
- `purchase_warranty_status` view: warranty end date and status per serial.
- Admins and super admins only (prices are confidential). Admins add and
  edit; super admins delete. Viewers and data entry operators see nothing.

`011` is generated from `C:\VSCODE\IT Purchases\data\bills.jsonl` by
`python scripts/build_seed.py` in that folder. Fix bill data there and
regenerate, rather than editing `011` by hand.

## Phase 4: Add bill (manual, OCR scan, AI-fill)

1. Run `012_create_purchase_bill.sql` (after 010). It adds
   `create_purchase_bill()`, which the app's Add bill form uses to save a
   whole bill in one transaction. Admins and super admins only.

2. **AI-fill only** (Manual and OCR scan work without this):
   - Create a free API key in Google AI Studio (https://aistudio.google.com),
     signed in with the company Google account.
   - Deploy the `scan-bill` Edge Function: Dashboard → **Edge Functions** →
     **Deploy a new function** → **Via Editor**, name it exactly `scan-bill`,
     paste `functions/scan-bill/index.ts`, deploy. Keep "Verify JWT" on.
     Or with the CLI: `supabase functions deploy scan-bill`.
   - Dashboard → **Edge Functions** → **Secrets**: add `GEMINI_API_KEY`
     with the key. Optional: `GEMINI_MODEL` (default `gemini-flash-latest`)
     if Google retires that name.

   On the free tier Google may use the bill images to improve its
   products. The app shows these terms and asks for agreement before every
   AI-fill.

OCR scan uses Google ML Kit on the phone (offline, nothing uploaded). It
runs on Android only; on Windows the option is shown as unavailable.

## Phase 5: smartHr bridge (client map pins)

1. `016_client_location.sql` adds `latitude`, `longitude`,
   `location_set_at`, `location_set_by` to `hospital_clients`. Both
   coordinates or neither, inside Bangladesh. In the app only admins can
   set, move or clear a pin (client detail → Map pin).
2. `smarthr-bridge` Edge Function (`supabase functions deploy smarthr-bridge --no-verify-jwt`):
   smartHr searches approved clients and fills an **empty** pin. It never
   overwrites one. Contract: `smartHr/docs/eam-clients-integration.md`.
3. Secret, same value in both projects:
   `supabase secrets set SMARTHR_BRIDGE_SECRET=…` here, `EAM_BRIDGE_SECRET` in smartHr.
   Until it is set, the bridge refuses every request.

Tests: `deno test supabase/functions/smarthr-bridge/` and
`supabase test db --linked` (needs Docker running).

### Service history (EAM ← smartHr)

`smarthr-history` Edge Function (JWT verified, data entry and above) reads a
client's visits and jobs from smartHr's `eam-history` with the same shared
secret. Secret `SMARTHR_HISTORY_URL` holds that function's URL. Contract:
`docs/smarthr-service-history.md`.
