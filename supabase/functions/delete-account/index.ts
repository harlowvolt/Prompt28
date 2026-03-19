// Supabase Edge Function: delete-account
//
// Deletes the authenticated user's account completely:
//   1. Verifies the caller's Supabase JWT
//   2. Deletes all rows in `prompts` table for this user (CASCADE also handles it,
//      but explicit deletion gives a clear audit trail)
//   3. Calls supabase.auth.admin.deleteUser() — requires service role key
//
// The `prompts` table has `ON DELETE CASCADE` from auth.users, so step 2 is
// belt-and-suspenders; the auth deletion alone would clean up child rows.
//
// Required built-in secrets (auto-available in Edge Functions):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//
// Deploy:
//   supabase functions deploy delete-account --no-verify-jwt
//
// iOS call site: SettingsViewModel.deleteAccount()
//   supabase.functions.invoke("delete-account", options: FunctionInvokeOptions())

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

Deno.serve(async (req: Request) => {
  // ── CORS preflight ──────────────────────────────────────────────────────────
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse("Server configuration error.", 500);
  }

  try {
    // ── Auth: verify JWT & extract user ID ───────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return errorResponse("Unauthorized.", 401);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return errorResponse("Invalid or expired session.", 401);
    }

    const userId = user.id;

    // ── Step 1: delete all prompt records for this user ──────────────────────
    // auth.users ON DELETE CASCADE would handle this, but explicit deletion
    // ensures the `prompts` table is clean before auth row removal and avoids
    // any FK constraint timing issues on some Postgres configurations.
    const { error: promptsError } = await supabase
      .from("prompts")
      .delete()
      .eq("user_id", userId);

    if (promptsError) {
      console.error("Failed to delete prompts for user:", userId, promptsError);
      // Non-fatal — proceed to auth deletion; CASCADE will clean up residuals.
    }

    // ── Step 2: delete the auth user (service role required) ─────────────────
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error("Failed to delete auth user:", userId, deleteError);
      return errorResponse("Account deletion failed. Please try again.", 500);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (err) {
    console.error("delete-account unhandled error:", err);
    return errorResponse("Internal server error.", 500);
  }
});

function errorResponse(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });
}
