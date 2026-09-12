import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error("Supabase environment variables are missing.");
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization) return response({ success: false, error: "Unauthorized." }, 401);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return response({ success: false, error: "Invalid user session." }, 401);
    }

    const currentUser = userData.user;

    const { data: currentProfile, error: profileError } = await admin
      .from("profiles")
      .select("school_id, role")
      .eq("id", currentUser.id)
      .maybeSingle();

    if (profileError) throw new Error(profileError.message);
    if (!currentProfile) {
      return response({ success: false, error: "Your profile was not found." }, 403);
    }

    let schoolId = currentProfile.school_id;

    if (schoolId == null) {
      const { data: ownedSchool, error: schoolError } = await admin
        .from("schools")
        .select("id")
        .eq("created_by", currentUser.id)
        .order("id", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (schoolError) throw new Error(schoolError.message);

      if (ownedSchool?.id != null) {
        schoolId = ownedSchool.id;
        const { error: linkError } = await admin
          .from("profiles")
          .update({ school_id: schoolId, role: "principal", is_active: true })
          .eq("id", currentUser.id);
        if (linkError) throw new Error(linkError.message);
      }
    }

    if (schoolId == null) {
      return response({ success: false, error: "Your account is not linked to a school." }, 403);
    }

    const body = await req.json();
    const fullName = String(body?.full_name ?? "").trim();
    const email = String(body?.email ?? "").trim().toLowerCase();
    const phone = String(body?.phone ?? "").trim();
    const cnic = String(body?.cnic ?? "").trim();
    const gender = String(body?.gender ?? "male").trim();
    const password = String(body?.password ?? "");
    const isActive = body?.is_active !== false;
    const staffRoles = Array.isArray(body?.staff_roles)
        ? body.staff_roles.map((r: unknown) => String(r).trim()).filter((r: string) => r.length > 0)
        : [];

    if (!fullName) return response({ success: false, error: "Full name is required." }, 400);
    if (!email || !email.includes("@")) return response({ success: false, error: "Invalid email address." }, 400);
    if (password.length < 6) return response({ success: false, error: "Password must be at least 6 characters." }, 400);
    if (staffRoles.length === 0) return response({ success: false, error: "Please select at least one staff role." }, 400);

    const { data: existingProfile, error: existingError } = await admin
      .from("profiles")
      .select("id, school_id, role")
      .eq("email", email)
      .maybeSingle();

    if (existingError) throw new Error(existingError.message);

    if (existingProfile) {
      if (existingProfile.school_id !== schoolId) {
        return response({ success: false, error: "This email already belongs to another school." }, 409);
      }
      return response({ success: false, error: "This staff member already exists. Please edit the existing staff record." }, 409);
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        role: "staff",
        phone,
        cnic,
        gender,
        staff_role: JSON.stringify(staffRoles),
      },
    });

    if (createError || !created.user) {
      const message = createError?.message ?? "Unable to create staff account.";
      const lower = message.toLowerCase();
      if (lower.includes("already") || lower.includes("exists") || lower.includes("duplicate")) {
        return response({ success: false, error: "A user with this email already exists." }, 409);
      }
      throw new Error(message);
    }

    const newUser = created.user;
    await new Promise((resolve) => setTimeout(resolve, 300));

    const { error: profileUpsertError } = await admin.from("profiles").upsert({
      id: newUser.id,
      full_name: fullName,
      email,
      phone: phone || null,
      cnic: cnic || null,
      gender,
      role: "staff",
      school_id: schoolId,
      staff_role: JSON.stringify(staffRoles),
      is_active: isActive,
    }, { onConflict: "id" });

    if (profileUpsertError) {
      await admin.auth.admin.deleteUser(newUser.id);
      throw new Error(profileUpsertError.message);
    }

    const { data: finalProfile, error: finalError } = await admin
      .from("profiles")
      .select("*")
      .eq("id", newUser.id)
      .single();

    if (finalError) throw new Error(finalError.message);

    return response({
      success: true,
      message: "Staff created successfully.",
      user_id: newUser.id,
      school_id: schoolId,
      staff: finalProfile,
    });
  } catch (error) {
    console.error("create-staff:", error);
    return response({
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});
