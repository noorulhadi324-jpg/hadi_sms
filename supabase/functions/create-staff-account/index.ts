import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !anon || !service) return json({ success: false, error: "Supabase environment variables are missing." }, 500);

    const authorization = req.headers.get("Authorization");
    if (!authorization) return json({ success: false, error: "Unauthorized." }, 401);

    const userClient = createClient(url, anon, { global: { headers: { Authorization: authorization } } });
    const admin = createClient(url, service, { auth: { autoRefreshToken: false, persistSession: false } });

    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData.user) return json({ success: false, error: "Invalid user session." }, 401);

    const { data: caller, error: callerError } = await admin
      .from("profiles")
      .select("id,school_id,role,is_active")
      .eq("id", authData.user.id)
      .maybeSingle();
    if (callerError) throw new Error(callerError.message);

    const callerRole = String(caller?.role ?? "").toLowerCase();
    if (!caller || caller.is_active === false || !["principal", "staff"].includes(callerRole)) {
      return json({ success: false, error: "Only school administration can create staff accounts." }, 403);
    }
    if (caller.school_id == null) return json({ success: false, error: "Your account is not linked to a school." }, 403);

    const body = await req.json();
    const fullName = String(body?.full_name ?? "").trim();
    const email = String(body?.email ?? "").trim().toLowerCase();
    const phone = String(body?.phone ?? "").trim();
    const gender = String(body?.gender ?? "male").trim();
    const cnic = String(body?.cnic ?? "").trim();
    const staffRole = String(body?.staff_role ?? "").trim();

    if (!fullName || !email.includes("@") || !staffRole) {
      return json({ success: false, error: "Name, valid email and staff role are required." }, 400);
    }

    const { data: existing } = await admin
      .from("profiles")
      .select("id,school_id,role")
      .ilike("email", email)
      .maybeSingle();
    if (existing) return json({ success: false, error: "A user with this email already exists." }, 409);

    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
      redirectTo: "hadi-sms://reset-password",
      data: {
        full_name: fullName,
        phone: phone || null,
        gender,
        role: "staff",
        school_id: String(caller.school_id),
        cnic: cnic || null,
        staff_role: staffRole,
      },
    });

    if (inviteError || !invited.user) {
      throw new Error(inviteError?.message ?? "Unable to send staff invitation email.");
    }

    const { error: profileError } = await admin.from("profiles").upsert({
      id: invited.user.id,
      full_name: fullName,
      email,
      phone: phone || null,
      gender,
      role: "staff",
      staff_role: staffRole,
      school_id: caller.school_id,
      is_active: true,
      cnic: cnic || null,
    }, { onConflict: "id" });

    if (profileError) {
      await admin.auth.admin.deleteUser(invited.user.id);
      throw new Error(profileError.message);
    }

    return json({
      success: true,
      user_id: invited.user.id,
      role: "staff",
      password_sent_to_principal: false,
      message: "Staff account created. An invitation email was sent to the staff member to set their own password.",
    });
  } catch (error) {
    console.error("create-staff-account:", error);
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
