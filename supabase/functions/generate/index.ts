// Supabase Edge Function: generate
// Receives a GenerateRequest from the iOS app and returns a GenerateResponse.
//
// Required Supabase secret — set ONE of these:
//   ANTHROPIC_API_KEY   — preferred (get from console.anthropic.com)
//   OPENAI_API_KEY      — fallback  (get from platform.openai.com)
//
// Set via CLI:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//
// Deploy:
//   supabase functions deploy generate --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
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
  ai: "You are an expert AI prompt engineer. Transform the user's raw idea into a precise, structured prompt optimised for AI language models. Maximise clarity, specificity, and instructional detail.",
  human:
    "You are an expert communicator and copywriter. Transform the user's raw idea into clear, compelling, human-centred communication. Use natural language, conversational tone, and emotional clarity.",
};

Deno.serve(async (req: Request) => {
  // ── CORS preflight ───────────────────────────────────────────────────────────
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
    // ── Parse body ───────────────────────────────────────────────────────────────
    const body = (await req.json()) as GenerateRequest;
    const { input, refinement, mode, systemPrompt } = body;

    if (!input || input.trim().length < 3) {
      return errorResponse("Input too short.", 400);
    }

    // ── Auth: verify Supabase JWT ─────────────────────────────────────────────
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

    // ── Build prompts ─────────────────────────────────────────────────────────
    const resolvedSystemPrompt =
      systemPrompt?.trim() || defaultSystemPrompts[mode] || defaultSystemPrompts.ai;

    let userMessage = input.trim();
    if (refinement?.trim()) {
      userMessage =
        `Original prompt:\n${input.trim()}\n\nRefinement request:\n${refinement.trim()}\n\nRefine the original prompt based on the refinement request.`;
    }

    const taskInstruction =
      `${userMessage}\n\nReturn ONLY a JSON object with exactly two keys — no markdown, no explanation:\n{"professional":"<full polished prompt>","template":"<fill-in-the-blank version with [PLACEHOLDER] tokens>"}`;

    // ── Route to available AI provider ────────────────────────────────────────
    let rawContent: string;

    if (ANTHROPIC_API_KEY) {
      rawContent = await callAnthropic(resolvedSystemPrompt, taskInstruction);
    } else if (OPENAI_API_KEY) {
      rawContent = await callOpenAI(resolvedSystemPrompt, taskInstruction);
    } else {
      return errorResponse(
        "No AI API key configured. Set ANTHROPIC_API_KEY or OPENAI_API_KEY in Supabase secrets.",
        500,
      );
    }

    // ── Parse JSON from AI response ───────────────────────────────────────────
    // Strip any markdown fences the model may have added despite instructions.
    const cleaned = rawContent
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/```\s*$/i, "")
      .trim();

    let parsed: { professional?: string; template?: string } = {};
    try {
      parsed = JSON.parse(cleaned);
    } catch {
      // If JSON parse fails entirely, use the raw text for both fields.
      parsed = { professional: cleaned, template: cleaned };
    }

    const professional = (parsed.professional ?? cleaned).trim();
    const template = (parsed.template ?? professional).trim();

    if (!professional) {
      return errorResponse("AI returned an empty result. Please try again.", 502);
    }

    const result: GenerateResponse = { professional, template };
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (err) {
    if (err instanceof APIError) {
      return errorResponse(err.message, err.status);
    }
    console.error("Edge Function unhandled error:", err);
    return errorResponse("Internal server error.", 500);
  }
});

// ── Anthropic (Claude) ────────────────────────────────────────────────────────
async function callAnthropic(system: string, userMsg: string): Promise<string> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_API_KEY!,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      system,
      messages: [{ role: "user", content: userMsg }],
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("Anthropic error:", res.status, text);
    if (res.status === 401) throw new APIError("Anthropic API key is invalid. Please contact support.", 500);
    if (res.status === 429) throw new APIError("Generation quota reached. Please try again in a moment.", 429);
    throw new APIError(`Anthropic error ${res.status}`, 502);
  }

  const data = await res.json();
  const content = data?.content?.[0]?.text;
  if (!content) throw new APIError("Empty response from Anthropic.", 502);
  return content;
}

// ── OpenAI (GPT-4o-mini) ──────────────────────────────────────────────────────
async function callOpenAI(system: string, userMsg: string): Promise<string> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      temperature: 0.7,
      max_tokens: 1000,
      messages: [
        { role: "system", content: system },
        { role: "user", content: userMsg },
      ],
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("OpenAI error:", res.status, text);
    if (res.status === 401) throw new APIError("OpenAI API key is invalid. Please contact support.", 500);
    if (res.status === 429) throw new APIError("Generation quota reached. Please try again in a moment.", 429);
    if (res.status === 402) throw new APIError("OpenAI billing issue. Please contact support.", 500);
    throw new APIError(`OpenAI error ${res.status}`, 502);
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) throw new APIError("Empty response from OpenAI.", 502);
  return content;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class APIError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

function errorResponse(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });
}
