# Supabase setup

Run migrations in order in **Dashboard → SQL Editor**. Each file is safe to
run again.

## Roles (Phase 1)

| Role (`app_role`) | In the app   | Can do |
| ----------------- | ------------ | ------ |
| `user`            | Viewer       | View clients, machines' basic info and warranty |
| `data_entry`      | Data Entry   | Viewer access (submitting data comes in Phase 2) |
| `admin`           | Admin        | Everything except deleting; full machine details; create Viewer / Data Entry users |
| `super_admin`     | Super Admin  | Everything, including deleting data, creating admins, banning and deleting users |

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
