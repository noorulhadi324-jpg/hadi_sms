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

function randomPassword() {
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  let value = "Hadi@";
  for (const byte of bytes) value += alphabet[byte % alphabet.length];
  return value;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ success: false, error: "Supabase environment variables are missing." }, 500);
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization) return json({ success: false, error: "Unauthorized." }, 401);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData.user) return json({ success: false, error: "Invalid user session." }, 401);

    const { data: caller, error: callerError } = await admin
      .from("profiles")
      .select("id, school_id, role, is_active")
      .eq("id", authData.user.id)
      .maybeSingle();

    if (callerError) throw new Error(callerError.message);
    if (!caller || caller.is_active === false) return json({ success: false, error: "Your account is inactive or profile is missing." }, 403);

    const callerRole = String(caller.role ?? "").toLowerCase();
    if (!['principal', 'staff'].includes(callerRole)) {
      return json({ success: false, error: "Only school administration can create staff, teacher or parent accounts." }, 403);
    }

    let schoolId = caller.school_id;
    if (schoolId == null) {
      const { data: ownedSchool } = await admin
        .from("schools")
        .select("id")
        .eq("created_by", authData.user.id)
        .order("id", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (ownedSchool?.id != null) {
        schoolId = ownedSchool.id;
        await admin.from("profiles").update({ school_id: schoolId }).eq("id", authData.user.id);
      }
    }
    if (schoolId == null) return json({ success: false, error: "Your account is not linked to a school." }, 403);

    const body = await req.json();
    const role = String(body?.role ?? "").trim().toLowerCase();
    if (!['teacher', 'parent'].includes(role)) return json({ success: false, error: "Invalid account role." }, 400);

    const fullName = String(body?.full_name ?? "").trim();
    const email = String(body?.email ?? "").trim().toLowerCase();
    const phone = String(body?.phone ?? "").trim();
    const gender = String(body?.gender ?? "Male").trim();
    const subject = String(body?.subject ?? "").trim();
    const assignedClass = String(body?.assigned_class ?? "").trim();
    const assignedSection = String(body?.assigned_section ?? "").trim();
    const cnic = String(body?.cnic ?? "").trim();
    const isActive = body?.is_active !== false;
    const requestedPassword = String(body?.password ?? "").trim();
    const password = requestedPassword.length >= 6 ? requestedPassword : randomPassword();

    if (!fullName) return json({ success: false, error: "Full name is required." }, 400);
    if (!email.includes("@")) return json({ success: false, error: "A valid email is required." }, 400);
    if (role === 'teacher' && (!subject || !assignedClass)) {
      return json({ success: false, error: "Teacher subject and assigned class are required." }, 400);
    }

    const { data: existingProfile, error: existingError } = await admin
      .from("profiles")
      .select("id, school_id, role, full_name, email")
      .ilike("email", email)
      .maybeSingle();

    if (existingError) throw new Error(existingError.message);
    if (existingProfile) {
      if (existingProfile.school_id !== schoolId) {
        return json({ success: false, error: "This email already belongs to another school." }, 409);
      }
      if (String(existingProfile.role).toLowerCase() !== role) {
        return json({ success: false, error: "This email already belongs to a different account role." }, 409);
      }
      return json({ success: true, existing: true, user_id: existingProfile.id, school_id: schoolId, temporary_password: null, message: `${role} account already exists.` });
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        phone: phone || null,
        gender,
        role,
        school_id: String(schoolId),
        subject: subject || null,
        assigned_class: assignedClass || null,
        assigned_section: assignedSection || null,
        cnic: cnic || null,
      },
    });

    if (createError || !created.user) {
      const message = createError?.message ?? "Unable to create account.";
      const lower = message.toLowerCase();
      if (lower.includes("already") || lower.includes("exists") || lower.includes("duplicate")) {
        return json({ success: false, error: "A user with this email already exists." }, 409);
      }
      throw new Error(message);
    }

    const newUser = created.user;
    await new Promise((resolve) => setTimeout(resolve, 250));

    const profilePayload: Record<string, unknown> = {
      id: newUser.id,
      full_name: fullName,
      email,
      phone: phone || null,
      gender: gender || null,
      role,
      school_id: schoolId,
      is_active: isActive,
    };
    if (role === 'teacher') {
      profilePayload.subject = subject || null;
      profilePayload.assigned_class = assignedClass || null;
      profilePayload.assigned_section = assignedSection || null;
      profilePayload.cnic = cnic || null;
    }

    const { error: profileError } = await admin.from("profiles").upsert(profilePayload, { onConflict: "id" });
    if (profileError) {
      await admin.auth.admin.deleteUser(newUser.id);
      throw new Error(profileError.message);
    }

    return json({
      success: true,
      existing: false,
      user_id: newUser.id,
      school_id: schoolId,
      role,
      temporary_password: password,
      message: `${role === 'teacher' ? 'Teacher' : 'Parent'} account created successfully.`,
    });
  } catch (error) {
    console.error("create-role-account:", error);
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
