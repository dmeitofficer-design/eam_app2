// supabase/functions/manage-users/index.ts
//
// User administration that needs the service-role key, which must
// never ship inside the app. The caller's role is checked here.
//
//   create  { email, password, full_name, role }  admin+ (admin role: super admin only)
//   ban     { user_id }                            super admin
//   unban   { user_id }                            super admin
//   delete  { user_id }                            super admin

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const roleLevels: Record<string, number> = {
  user: 1,
  data_entry: 2,
  admin: 3,
  super_admin: 4,
  superadmin: 4,
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    // ── Who is calling? ─────────────────────────────────────
    const token = (req.headers.get("Authorization") ?? "").replace(
      /^Bearer\s+/i,
      "",
    );
    const { data: auth, error: authError } = await admin.auth.getUser(token);
    if (authError || !auth.user) {
      return json({ error: "You are not signed in." }, 401);
    }
    const callerId = auth.user.id;

    const { data: caller } = await admin
      .from("profiles")
      .select("role, is_banned")
      .eq("id", callerId)
      .single();
    const callerLevel = caller && !caller.is_banned
      ? roleLevels[caller.role] ?? 1
      : 0;
    if (callerLevel < 3) {
      return json({ error: "Only admins can manage users." }, 403);
    }

    const body = await req.json();
    const action = body.action as string;

    // ── Create ──────────────────────────────────────────────
    if (action === "create") {
      const email = String(body.email ?? "").trim().toLowerCase();
      const password = String(body.password ?? "");
      const fullName = String(body.full_name ?? "").trim();
      const role = String(body.role ?? "");

      if (!email || !fullName) {
        return json({ error: "Name and email are required." }, 400);
      }
      if (password.length < 8) {
        return json({ error: "Password must be at least 8 characters." }, 400);
      }
      if (!["user", "data_entry", "admin"].includes(role)) {
        return json({ error: "Invalid role." }, 400);
      }
      if (role === "admin" && callerLevel < 4) {
        return json({ error: "Only a super admin can create admins." }, 403);
      }

      const { data: created, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName },
        app_metadata: { role },
      });
      if (error || !created.user) {
        return json({ error: error?.message ?? "Could not create user." }, 400);
      }

      // The signup trigger creates the profile; make sure it is complete.
      const { error: profileError } = await admin.from("profiles").upsert({
        id: created.user.id,
        full_name: fullName,
        role,
        email,
      });
      if (profileError) {
        return json({ error: profileError.message }, 400);
      }

      return json({ id: created.user.id });
    }

    // ── Ban / unban / delete (super admin only) ─────────────
    if (!["ban", "unban", "delete"].includes(action)) {
      return json({ error: "Unknown action." }, 400);
    }
    if (callerLevel < 4) {
      return json({ error: "Only a super admin can do this." }, 403);
    }

    const userId = String(body.user_id ?? "");
    if (!userId) return json({ error: "user_id is required." }, 400);
    if (userId === callerId) {
      return json({ error: "You cannot do this to your own account." }, 400);
    }

    const { data: target } = await admin
      .from("profiles")
      .select("role")
      .eq("id", userId)
      .single();
    if (target && (roleLevels[target.role] ?? 1) >= 4) {
      return json({ error: "Super admin accounts cannot be changed here." }, 403);
    }

    if (action === "ban" || action === "unban") {
      const banned = action === "ban";
      const { error } = await admin.auth.admin.updateUserById(userId, {
        ban_duration: banned ? "876000h" : "none",
      });
      if (error) return json({ error: error.message }, 400);

      await admin.from("profiles").update({ is_banned: banned }).eq(
        "id",
        userId,
      );
      if (banned) {
        await admin.rpc("admin_revoke_user_sessions", {
          target_user_id: userId,
        });
      }
      return json({ ok: true });
    }

    // delete
    await admin.rpc("admin_revoke_user_sessions", { target_user_id: userId });
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
