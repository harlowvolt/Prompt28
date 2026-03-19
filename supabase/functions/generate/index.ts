// Supabase Edge Function: generate
// Receives a GenerateRequest from the iOS app and returns a GenerateResponse.
//
// Required Supabase secret (set via CLI or dashboard):
//   OPENAI_API_KEY   — your OpenAI API key
//
// Request body (matches iOS GenerateRequest):
//   { input: string, refinement?: string, mode: "ai" | "human", systemPrompt?: string }
//
// Response body (matches iOS GenerateResponse / EdgeGenerateResponse):
//   { professional: string, template: string }
//
// Deploy:
//   supabase functions deploy generate --no-verify-jwt
//
// Note: --no-verify-jwt lets the function handle auth itself (or be open).
// If you want strict JWT verification, remove the flag and the JWT check below.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

interface GenerateRequest {
  input: string;
  refinement?: string | null;
  mode: "ai" | "human";
  systemPrompt?: string | null;
}

interface GenerateResponse {
  professional: string;
  template: string;
}

const defaultSystemPrompts: Record<string, string> = {
  ai: "You are an expert AI prompt engineer. Transform the user's raw spoken idea into a precise, structured prompt optimised for AI language models. Maximise clarity, specificity, and instructional detail.",
  human:
    "You are an expert communicator and copywriter. Transform the user's raw spoken idea into clear, compelling, human-centred communication. Use natural language, conversational tone, and emotional clarity.",
};

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

  try {
    // ── Parse request body ────────────────────────────────────────────────────
    const body = (await req.json()) as GenerateRequest;
    const { input, refinement, mode, systemPrompt } = body;

    if (!input || input.trim().length < 3) {
      return errorResponse("Input too short.", 400);
    }

    // ── Auth: verify user JWT (optional but recommended) ─────────────────────
    // The supabase-swift SDK sends the user's JWT as Bearer automatically.
    // We verify it here so only authenticated users can call this function.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return errorResponse("Unauthorized.", 401);
    }

    if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });
      const token = authHeader.replace("Bearer ", "");
      const { error: authError } = await supabase.auth.getUser(token);
      if (authError) {
        return errorResponse("Invalid or expired session.", 401);
      }
    }

    // ── Build the OpenAI prompt ───────────────────────────────────────────────
    const resolvedSystemPrompt =
      (systemPrompt && systemPrompt.trim().length > 0)
        ? systemPrompt.trim()
        : (defaultSystemPrompts[mode] ?? defaultSystemPrompts.ai);

    // Build user message — include refinement context when provided
    let userMessage = input.trim();
    if (refinement && refinement.trim().length > 0) {
      userMessage = `Original prompt:\n${input.trim()}\n\nRefinement request:\n${refinement.trim()}\n\nPlease refine the original prompt based on the refinement request.`;
    }

    // ── Call OpenAI ───────────────────────────────────────────────────────────
    if (!OPENAI_API_KEY) {
      return errorResponse("OpenAI API key not configured.", 500);
    }

    const openAIResponse = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: resolvedSystemPrompt },
            {
              role: "user",
              content:
                `Transform this into a polished, structured prompt. Return a JSON object with exactly two keys:\n- "professional": the full, refined prompt\n- "template": a shorter, fill-in-the-blank template version with [PLACEHOLDER] tokens where appropriate\n\nInput: ${userMessage}`,
            },
          ],
          response_format: { type: "json_object" },
          temperature: 0.7,
          max_tokens: 1000,
        }),
      },
    );

    if (!openAIResponse.ok) {
      const errText = await openAIResponse.text();
      console.error("OpenAI error:", openAIResponse.status, errText);
      return errorResponse("AI service error. Please try again.", 502);
    }

    const openAIData = await openAIResponse.json();
    const rawContent = openAIData?.choices?.[0]?.message?.content;

    if (!rawContent) {
      return errorResponse("Empty response from AI service.", 502);
    }

    // ── Parse JSON from OpenAI ────────────────────────────────────────────────
    let parsed: { professional?: string; template?: string };
    try {
      parsed = JSON.parse(rawContent);
    } catch {
      // Fallback: use the raw content as professional, derive a simple template
      parsed = {
        professional: rawContent.trim(),
        template: rawContent.trim(),
      };
    }

    const professional = (parsed.professional ?? rawContent).trim();
    const template = (parsed.template ?? professional).trim();

    if (!professional) {
      return errorResponse("AI returned empty result.", 502);
    }

    const result: GenerateResponse = { professional, template };

    return new Response(JSON.stringify(result), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (err) {
    console.error("Edge Function unhandled error:", err);
    return errorResponse("Internal server error.", 500);
  }
});

function errorResponse(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
