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
    if (!url || !anon || !service) return json({success:false,error:"Supabase environment variables are missing."},500);

    const authorization = req.headers.get("Authorization");
    if (!authorization) return json({success:false,error:"Unauthorized."},401);

    const userClient = createClient(url, anon, { global:{headers:{Authorization:authorization}} });
    const admin = createClient(url, service, { auth:{autoRefreshToken:false,persistSession:false} });
    const {data: authData,error: authError} = await userClient.auth.getUser();
    if (authError || !authData.user) return json({success:false,error:"Invalid user session."},401);

    const {data: caller,error: callerError} = await admin.from("profiles").select("id,school_id,role,is_active").eq("id",authData.user.id).maybeSingle();
    if (callerError) throw new Error(callerError.message);
    const callerRole = String(caller?.role ?? "").toLowerCase();
    if (!caller || caller.is_active === false || !["principal","staff"].includes(callerRole)) return json({success:false,error:"Only school administration can manage accounts."},403);

    const body = await req.json();
    const action = String(body?.action ?? "").trim().toLowerCase();
    const targetId = String(body?.user_id ?? "").trim();
    if (!targetId) return json({success:false,error:"User ID is required."},400);

    const {data: target,error: targetError} = await admin.from("profiles").select("id,school_id,role").eq("id",targetId).maybeSingle();
    if (targetError) throw new Error(targetError.message);
    if (!target) return json({success:false,error:"User profile not found."},404);
    if (target.school_id !== caller.school_id) return json({success:false,error:"This user belongs to another school."},403);
    const targetRole = String(target.role ?? "").toLowerCase();
    if (!["teacher","parent","staff"].includes(targetRole)) return json({success:false,error:"This account cannot be managed here."},403);
    if (target.id === caller.id) return json({success:false,error:"You cannot delete your own account here."},400);

    if (action === "delete") {
      const {error: deleteError} = await admin.auth.admin.deleteUser(targetId);
      if (deleteError) throw new Error(deleteError.message);
      await admin.from("profiles").delete().eq("id",targetId);
      return json({success:true,message:"User account deleted successfully."});
    }

    if (action === "deactivate") {
      const {error} = await admin.from("profiles").update({is_active:false}).eq("id",targetId);
      if (error) throw new Error(error.message);
      return json({success:true,message:"User deactivated successfully."});
    }

    if (action === "activate") {
      const {error} = await admin.from("profiles").update({is_active:true}).eq("id",targetId);
      if (error) throw new Error(error.message);
      return json({success:true,message:"User activated successfully."});
    }

    return json({success:false,error:"Invalid action."},400);
  } catch (error) {
    console.error("manage-role-account:",error);
    return json({success:false,error:error instanceof Error ? error.message : String(error)},500);
  }
});
