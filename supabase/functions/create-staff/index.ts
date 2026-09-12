import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":
    "POST, OPTIONS",
};

Deno.serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    // ----------------------------------------------------------
    // Supabase configuration
    // ----------------------------------------------------------

    const supabaseUrl =
      Deno.env.get("'https://sbjytvbrqjmawhyjwcvy.supabase.co");

    const anonKey =
      Deno.env.get("sb_publishable_8lzNq7-VBuERBSA47Il9ww_bcpBDNH8");

    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (
      !supabaseUrl ||
      !anonKey ||
      !serviceRoleKey
    ) {
      throw new Error(
        "Supabase environment variables are missing.",
      );
    }

    // ----------------------------------------------------------
    // Authorization
    // ----------------------------------------------------------

    const authorization =
      req.headers.get("Authorization");

    if (!authorization) {
      return response(
        {
          success: false,
          error: "Unauthorized.",
        },
        401,
      );
    }

    // Client for current logged-in user
    const userClient =
      createClient(
        supabaseUrl,
        anonKey,
        {
          global: {
            headers: {
              Authorization:
                authorization,
            },
          },
        },
      );

    // Admin client
    const admin =
      createClient(
        supabaseUrl,
        serviceRoleKey,
        {
          auth: {
            autoRefreshToken: false,
            persistSession: false,
          },
        },
      );

    // ----------------------------------------------------------
    // Get current user
    // ----------------------------------------------------------

    const {
      data: userData,
      error: userError,
    } =
      await userClient.auth.getUser();

    if (
      userError ||
      !userData.user
    ) {
      return response(
        {
          success: false,
          error: "Invalid user session.",
        },
        401,
      );
    }

    const currentUser =
      userData.user;

    // ----------------------------------------------------------
    // Get current user's school
    // ----------------------------------------------------------

    const {
      data: currentProfile,
      error: profileError,
    } =
      await admin
        .from("profiles")
        .select(
          "school_id, role",
        )
        .eq(
          "id",
          currentUser.id,
        )
        .maybeSingle();

    if (profileError) {
      throw new Error(
        profileError.message,
      );
    }

    if (!currentProfile) {
      return response(
        {
          success: false,
          error:
            "Your profile was not found.",
        },
        403,
      );
    }

    const schoolId =
      currentProfile.school_id;

    if (schoolId == null) {
      return response(
        {
          success: false,
          error:
            "Your account is not linked to a school.",
        },
        403,
      );
    }

    // ----------------------------------------------------------
    // Read request
    // ----------------------------------------------------------

    const body =
      await req.json();

    const fullName =
      String(
        body?.full_name ?? "",
      ).trim();

    const email =
      String(
        body?.email ?? "",
      )
        .trim()
        .toLowerCase();

    const phone =
      String(
        body?.phone ?? "",
      ).trim();

    const cnic =
      String(
        body?.cnic ?? "",
      ).trim();

    const gender =
      String(
        body?.gender ?? "male",
      ).trim();

    const password =
      String(
        body?.password ?? "",
      );

    const isActive =
      body?.is_active !== false;

    // ----------------------------------------------------------
    // Staff roles
    // ----------------------------------------------------------

    let staffRoles: string[] = [];

    if (
      Array.isArray(
        body?.staff_roles,
      )
    ) {
      staffRoles =
        body.staff_roles
          .map(
            (role: unknown) =>
              String(role).trim(),
          )
          .filter(
            (role: string) =>
              role.length > 0,
          );
    }

    // ----------------------------------------------------------
    // Validation
    // ----------------------------------------------------------

    if (!fullName) {
      return response(
        {
          success: false,
          error:
            "Full name is required.",
        },
        400,
      );
    }

    if (!email) {
      return response(
        {
          success: false,
          error:
            "Email is required.",
        },
        400,
      );
    }

    if (!email.includes("@")) {
      return response(
        {
          success: false,
          error:
            "Invalid email address.",
        },
        400,
      );
    }

    if (password.length < 6) {
      return response(
        {
          success: false,
          error:
            "Password must be at least 6 characters.",
        },
        400,
      );
    }

    if (staffRoles.length === 0) {
      return response(
        {
          success: false,
          error:
            "Please select at least one staff role.",
        },
        400,
      );
    }

    // ----------------------------------------------------------
    // Check existing profile by email
    // ----------------------------------------------------------

    const {
      data: existingProfile,
    } =
      await admin
        .from("profiles")
        .select(
          "id, school_id, role",
        )
        .eq(
          "email",
          email,
        )
        .maybeSingle();

    if (existingProfile) {
      if (
        existingProfile.school_id !=
        schoolId
      ) {
        return response(
          {
            success: false,
            error:
              "This email already belongs to another school.",
          },
          409,
        );
      }

      return response(
        {
          success: false,
          error:
            "This staff member already exists. Please edit the existing staff record.",
        },
        409,
      );
    }

    // ----------------------------------------------------------
    // Create Auth user
    //
    // IMPORTANT:
    // We DO NOT insert into profiles here.
    //
    // The database trigger:
    //
    // auth.users
    //      ↓
    // handle_new_user()
    //      ↓
    // profiles
    //
    // handles profile creation.
    // ----------------------------------------------------------

    const {
      data: created,
      error: createError,
    } =
      await admin.auth.admin.createUser({
        email: email,

        password: password,

        email_confirm: true,

        user_metadata: {
          full_name:
            fullName,

          role:
            "staff",

          school_id:
            schoolId,

          phone:
            phone,

          cnic:
            cnic,

          gender:
            gender,

          staff_role:
            JSON.stringify(
              staffRoles,
            ),
        },
      });

    if (
      createError ||
      !created.user
    ) {
      const message =
        createError?.message ??
        "Unable to create staff account.";

      const lower =
        message.toLowerCase();

      if (
        lower.includes("already") ||
        lower.includes("exists") ||
        lower.includes("duplicate")
      ) {
        return response(
          {
            success: false,
            error:
              "A user with this email already exists.",
          },
          409,
        );
      }

      throw new Error(
        message,
      );
    }

    const newUser =
      created.user;

    // ----------------------------------------------------------
    // Wait for trigger
    // ----------------------------------------------------------

    await new Promise(
      (resolve) =>
        setTimeout(
          resolve,
          300,
        ),
    );

    // ----------------------------------------------------------
    // Get profile created by trigger
    // ----------------------------------------------------------

    const {
      data: newProfile,
      error: newProfileError,
    } =
      await admin
        .from("profiles")
        .select("*")
        .eq(
          "id",
          newUser.id,
        )
        .maybeSingle();

    if (newProfileError) {
      throw new Error(
        newProfileError.message,
      );
    }

    if (!newProfile) {
      // Auth created but profile failed.
      await admin.auth.admin
        .deleteUser(
          newUser.id,
        );

      throw new Error(
        "Staff account was created but profile was not created.",
      );
    }

    // ----------------------------------------------------------
    // Update profile with remaining staff information
    //
    // UPDATE only — never INSERT.
    // ----------------------------------------------------------

    const {
      data: finalProfile,
      error: updateError,
    } =
      await admin
        .from("profiles")
        .update({
          full_name:
            fullName,

          email:
            email,

          phone:
            phone || null,

          cnic:
            cnic || null,

          gender:
            gender,

          role:
            "staff",

          school_id:
            schoolId,

          staff_role:
            JSON.stringify(
              staffRoles,
            ),

          is_active:
            isActive,
        })
        .eq(
          "id",
          newUser.id,
        )
        .select()
        .single();

    if (updateError) {
      throw new Error(
        updateError.message,
      );
    }

    // ----------------------------------------------------------
    // Success
    // ----------------------------------------------------------

    return response(
      {
        success: true,

        message:
          "Staff created successfully.",

        user_id:
          newUser.id,

        school_id:
          schoolId,

        staff:
          finalProfile,
      },
      200,
    );
  } catch (error) {
    console.error(
      "create-staff:",
      error,
    );

    return response(
      {
        success: false,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      },
      500,
    );
  }
});

// ===============================================================
// Response helper
// ===============================================================

function response(
  data: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(data),
    {
      status,

      headers: {
        ...corsHeaders,

        "Content-Type":
          "application/json",
      },
    },
  );
}