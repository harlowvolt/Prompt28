// Supabase Edge Function: generate
// Receives a GenerateRequest from the iOS app and returns a GenerateResponse.
//
// Phase 5 additions:
//   • Intent classifier — keyword-based, zero-latency, routes to specialized system prompts
//   • Returns intent_category + latency_ms in every response for analytics + iOS display
//   • MCP web-context — for intents that benefit from live data (business, technical, general
//     queries phrased as questions), fetches a brief web snippet via Brave Search API and
//     injects it as grounding context before generation. iOS stays a thin client — no changes
//     needed on the iOS side. Opt-in: only fires when BRAVE_API_KEY secret is set.
//
// Required Supabase secret — set ONE of these:
//   GEMINI_API_KEY      — preferred (get from aistudio.google.com)
//   ANTHROPIC_API_KEY   — fallback 1 (get from console.anthropic.com)
//   OPENAI_API_KEY      — fallback 2 (get from platform.openai.com)
//
// Optional Supabase secret (enables web-context enrichment via Brave Search):
//   BRAVE_API_KEY       — get from api.search.brave.com (free tier: 2 000 req/mo)
//
// Built-in Supabase secrets (auto-available in Edge Functions):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//
// Deploy:
//   supabase functions deploy generate --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const BRAVE_API_KEY = Deno.env.get("BRAVE_API_KEY");

const FREE_MONTHLY_LIMIT = 10;

// ── Intent categories ─────────────────────────────────────────────────────────

type IntentCategory =
  | "work"
  | "school"
  | "business"
  | "fitness"
  | "technical"
  | "creative"
  | "general";

/**
 * Keyword-based intent classifier.
 * Zero LLM calls — runs in <1 ms on the Edge.
 * Returns the highest-scored category, or "general" when no strong match.
 */
function classifyIntent(input: string): IntentCategory {
  const text = input.toLowerCase();

  const scores: Record<IntentCategory, number> = {
    work: 0,
    school: 0,
    business: 0,
    fitness: 0,
    technical: 0,
    creative: 0,
    general: 0,
  };

  // Work / Professional communication
  const workKeywords = [
    "email", "meeting", "slack", "colleague", "boss", "manager", "team",
    "report", "agenda", "presentation", "feedback", "performance review",
    "project", "deadline", "stakeholder", "onboarding", "offboarding",
    "hr", "resume", "cover letter", "linkedin", "salary", "promotion",
  ];
  // School / Academic
  const schoolKeywords = [
    "essay", "thesis", "research paper", "homework", "assignment", "exam",
    "study", "lecture", "professor", "university", "college", "student",
    "academic", "literature review", "citation", "bibliography", "grade",
    "class", "syllabus", "dissertation", "coursework", "tutoring",
  ];
  // Business / Strategy / Marketing
  const businessKeywords = [
    "startup", "business plan", "pitch deck", "investor", "revenue", "profit",
    "market", "customer", "sales", "marketing", "brand", "product launch",
    "strategy", "growth", "acquisition", "valuation", "b2b", "b2c", "saas",
    "executive", "board", "competitive analysis", "go-to-market", "gtm",
  ];
  // Fitness / Health / Nutrition
  const fitnessKeywords = [
    "workout", "exercise", "gym", "fitness", "weight loss", "muscle", "training",
    "cardio", "nutrition", "diet", "calories", "protein", "supplements",
    "running", "marathon", "yoga", "pilates", "hiit", "strength", "recovery",
    "meal plan", "bulking", "cutting", "body", "health",
  ];
  // Technical / Code / Engineering
  const technicalKeywords = [
    "code", "programming", "function", "api", "database", "sql", "python",
    "javascript", "swift", "typescript", "bug", "debug", "algorithm",
    "system design", "architecture", "docker", "kubernetes", "cloud",
    "server", "frontend", "backend", "fullstack", "devops", "git", "pull request",
    "unit test", "refactor", "deploy", "ci/cd", "machine learning", "ai model",
  ];
  // Creative / Writing / Art
  const creativeKeywords = [
    "story", "poem", "script", "novel", "character", "plot", "dialogue",
    "creative writing", "fiction", "blog post", "article", "social media",
    "caption", "tweet", "copywriting", "ad copy", "headline", "tagline",
    "song", "lyrics", "screenplay", "worldbuilding", "short story",
  ];

  const keywordSets: Array<[IntentCategory, string[]]> = [
    ["work",      workKeywords],
    ["school",    schoolKeywords],
    ["business",  businessKeywords],
    ["fitness",   fitnessKeywords],
    ["technical", technicalKeywords],
    ["creative",  creativeKeywords],
  ];

  for (const [category, keywords] of keywordSets) {
    for (const kw of keywords) {
      if (text.includes(kw)) {
        scores[category] += kw.includes(" ") ? 2 : 1; // phrases score higher
      }
    }
  }

  // Pick highest-scoring category with a minimum threshold
  let best: IntentCategory = "general";
  let bestScore = 1; // minimum score to override "general"
  for (const [cat, score] of Object.entries(scores) as [IntentCategory, number][]) {
    if (cat !== "general" && score > bestScore) {
      bestScore = score;
      best = cat;
    }
  }
  return best;
}

// ── Intent-specialized system prompts ─────────────────────────────────────────

const intentSystemPrompts: Record<IntentCategory, Record<string, string>> = {
  work: {
    ai: "You are an expert professional communications coach and AI prompt engineer. Transform the user's rough idea into a precise, structured prompt optimised for AI language models in a workplace context. Emphasise clarity, professional tone, and actionable output.",
    human: "You are an expert workplace communicator and executive coach. Transform the user's rough idea into polished, professional communication — whether email, slack message, performance feedback, or meeting agenda. Use clear, respectful, and empathetic language.",
  },
  school: {
    ai: "You are an expert academic AI prompt engineer. Transform the user's rough idea into a rigorous, well-structured prompt designed for academic writing, research, or study assistance. Emphasise intellectual depth, citation awareness, and structured argumentation.",
    human: "You are an expert academic writing tutor. Transform the user's rough idea into clear, well-structured academic communication — essay drafts, study guides, research summaries, or exam prep. Use precise language and scholarly tone.",
  },
  business: {
    ai: "You are an expert business strategy and marketing AI prompt engineer. Transform the user's rough idea into a precise prompt for business planning, market analysis, go-to-market strategy, or pitch decks. Emphasise data-driven thinking, strategic clarity, and investor-ready language.",
    human: "You are an expert business writer and strategist. Transform the user's rough idea into compelling, investor-ready business communication — pitch decks, executive summaries, market analyses, or sales copy. Be persuasive, concise, and metrics-focused.",
  },
  fitness: {
    ai: "You are an expert fitness and nutrition AI prompt engineer. Transform the user's rough idea into a precise, evidence-based prompt for workout plans, nutrition guides, or health coaching programs. Emphasise safety, progressive overload principles, and personalisation.",
    human: "You are an expert personal trainer and nutrition coach. Transform the user's rough idea into a motivating, safe, and science-backed fitness or nutrition plan. Use clear, encouraging language with specific sets, reps, and measurable goals.",
  },
  technical: {
    ai: "You are an expert software engineering and technical AI prompt engineer. Transform the user's rough idea into a precise, unambiguous technical prompt for code generation, system design, debugging, or architecture review. Emphasise correctness, edge cases, and engineering best practices.",
    human: "You are an expert software engineer and technical communicator. Transform the user's rough idea into clear, actionable technical documentation, code comments, PR descriptions, or engineering specs. Use precise technical terminology and structured formatting.",
  },
  creative: {
    ai: "You are an expert creative director and AI prompt engineer. Transform the user's rough idea into a vivid, structured creative brief for AI-generated stories, scripts, art direction, or copywriting. Emphasise originality, emotional resonance, and sensory detail.",
    human: "You are an expert creative writer, copywriter, and storyteller. Transform the user's rough idea into compelling, original creative content — whether fiction, poetry, blog posts, social captions, or ad copy. Prioritise voice, rhythm, and emotional impact.",
  },
  general: {
    ai: "You are an expert AI prompt engineer. Transform the user's raw idea into a precise, structured prompt optimised for AI language models. Maximise clarity, specificity, and instructional detail.",
    human: "You are an expert communicator and copywriter. Transform the user's raw idea into clear, compelling, human-centred communication. Use natural language, conversational tone, and emotional clarity.",
  },
};

function resolveSystemPrompt(
  intent: IntentCategory,
  mode: string,
  override?: string | null,
): string {
  if (override?.trim()) return override.trim();
  const intentPrompts = intentSystemPrompts[intent] ?? intentSystemPrompts.general;
  return intentPrompts[mode] ?? intentPrompts.ai;
}

// ── Temporal context ──────────────────────────────────────────────────────────

/**
 * Returns a concise temporal context string injected into every generation.
 * Gives the model awareness of "now" so time-sensitive prompts (weekly plans,
 * seasonal recipes, upcoming holidays, etc.) produce relevant output without
 * the user having to specify the date themselves.
 *
 * Example: "Today is Thursday, 19 March 2026 (week 12). Season: Spring (Northern Hemisphere)."
 */
function buildTemporalContext(): string {
  const now = new Date();

  const dayName  = now.toLocaleDateString("en-US", { weekday: "long",  timeZone: "UTC" });
  const dayNum   = now.toLocaleDateString("en-US", { day: "numeric",   timeZone: "UTC" });
  const month    = now.toLocaleDateString("en-US", { month: "long",    timeZone: "UTC" });
  const year     = now.getUTCFullYear();

  // ISO week number
  const startOfYear = new Date(Date.UTC(year, 0, 1));
  const weekNum  = Math.ceil(
    ((now.getTime() - startOfYear.getTime()) / 86_400_000 + startOfYear.getUTCDay() + 1) / 7,
  );

  // Northern Hemisphere seasons
  const m = now.getUTCMonth(); // 0-based
  const season =
    m < 2 || m === 11 ? "Winter" :
    m < 5             ? "Spring" :
    m < 8             ? "Summer" : "Autumn";

  return `[Context: Today is ${dayName}, ${dayNum} ${month} ${year} (week ${weekNum}). Season: ${season} (Northern Hemisphere).]`;
}

// ── Web-context enrichment (Phase 5) ──────────────────────────────────────────
// Brave Search API — lightweight grounding, not MCP.

/**
 * Intents that benefit from live web context.
 * "work", "school", "fitness", "creative" are self-contained — no web fetch needed.
 * "business", "technical", "general" often involve current events, pricing, docs, or news.
 */
const WEB_CONTEXT_INTENTS = new Set<IntentCategory>(["business", "technical", "general"]);

/**
 * Returns true when the query looks like a question or references recency.
 * Avoids burning the Brave quota on obviously self-contained prompts.
 */
function needsWebContext(input: string, intent: IntentCategory): boolean {
  if (!BRAVE_API_KEY) return false;
  if (!WEB_CONTEXT_INTENTS.has(intent)) return false;

  const t = input.toLowerCase();
  const questionWords = ["what", "how", "why", "when", "where", "who", "which", "is there", "can i", "should i"];
  const recencyWords = ["latest", "current", "today", "now", "recent", "2024", "2025", "2026", "news", "update", "release"];

  return questionWords.some(w => t.includes(w)) || recencyWords.some(w => t.includes(w));
}

/**
 * Fetches the top Brave Search web snippet for the given query.
 * Returns a brief grounding string or null on any error (fails silently — never blocks generation).
 * Max timeout: 2 seconds. Extracts up to 3 description snippets (~400 chars total).
 */
async function fetchWebContext(query: string): Promise<string | null> {
  if (!BRAVE_API_KEY) return null;
  try {
    const url = new URL("https://api.search.brave.com/res/v1/web/search");
    url.searchParams.set("q", query.slice(0, 200));
    url.searchParams.set("count", "3");
    url.searchParams.set("text_decorations", "false");
    url.searchParams.set("safesearch", "moderate");

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2000);

    const res = await fetch(url.toString(), {
      headers: {
        "Accept": "application/json",
        "Accept-Encoding": "gzip",
        "X-Subscription-Token": BRAVE_API_KEY,
      },
      signal: controller.signal,
    });

    clearTimeout(timeout);

    if (!res.ok) return null;

    const data = await res.json();
    const results: Array<{ title?: string; description?: string }> = data?.web?.results ?? [];

    const snippets = results
      .slice(0, 3)
      .map(r => r.description?.trim())
      .filter((d): d is string => !!d && d.length > 20);

    if (snippets.length === 0) return null;

    const combined = snippets.join(" | ").slice(0, 500);
    return `[Web context: ${combined}]`;
  } catch {
    // Network error, timeout, parse error — silently ignore, never block generation.
    return null;
  }
}

// ── Request / Response interfaces ─────────────────────────────────────────────

interface GenerateRequest {
  input: string;
  refinement?: string | null;
  mode: "ai" | "human";
  systemPrompt?: string | null;
}

interface GenerateResponse {
  professional: string;
  template: string;
  prompts_used: number;
  prompts_remaining: number | null;
  plan: string;
  intent_category: IntentCategory;  // Phase 5: returned to iOS for display + analytics
  latency_ms: number;               // Phase 5: total generation latency in ms
  web_context_used: boolean;        // Phase 5 MCP: true when a web snippet was injected
}

// ── Main handler ──────────────────────────────────────────────────────────────

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

  const requestStart = Date.now();

  try {
    // ── Parse body ───────────────────────────────────────────────────────────────
    const body = (await req.json()) as GenerateRequest;
    const { input, refinement, mode, systemPrompt } = body;

    if (!input || input.trim().length < 3) {
      return errorResponse("Input too short.", 400);
    }

    // ── Phase 5: Classify intent before hitting auth (fast, free) ────────────
    const intentCategory = classifyIntent(input);

    // ── Auth: verify Supabase JWT & extract user ──────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return errorResponse("Unauthorized.", 401);
    }

    let userPlan = "starter"; // default — overridden by user_metadata if set
    let promptsUsedBefore = 0; // pre-generation count for this billing period

    if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });
      const token = authHeader.replace("Bearer ", "");
      const { data: { user }, error: authError } = await supabase.auth.getUser(token);
      if (authError || !user) {
        return errorResponse("Invalid or expired session.", 401);
      }

      // Plan override: StoreManager.syncPlanToSupabase() writes this after IAP
      const metaPlan = user.user_metadata?.plan as string | undefined;
      if (metaPlan === "pro" || metaPlan === "unlimited") {
        userPlan = metaPlan;
      }

      // ── Server-side usage metering (starter plan only) ─────────────────────
      if (userPlan === "starter") {
        const periodStart = new Date();
        periodStart.setUTCDate(1);
        periodStart.setUTCHours(0, 0, 0, 0);

        const { count, error: countError } = await supabase
          .from("prompts")
          .select("id", { count: "exact", head: true })
          .eq("user_id", user.id)
          .gte("created_at", periodStart.toISOString());

        if (!countError && count !== null && count >= FREE_MONTHLY_LIMIT) {
          return errorResponse(
            "Monthly generation limit reached. Upgrade to Pro for unlimited prompts.",
            429,
          );
        }

        promptsUsedBefore = count ?? 0;
      }
    }

    // ── Phase 5: web-context enrichment via Brave Search (optional, parallel-safe) ──
    // Fired concurrently with auth. Only when BRAVE_API_KEY is set and query needs
    // live grounding. Fails silently — never blocks generation.
    const webContextPromise = needsWebContext(input, intentCategory)
      ? fetchWebContext(input)
      : Promise.resolve(null);

    // ── Resolve system prompt (intent-specialized) ─────────────────────────
    const resolvedSystem = resolveSystemPrompt(intentCategory, mode, systemPrompt);

    // ── Build user message ─────────────────────────────────────────────────
    // Phase 5: prepend temporal context + optional web-context snippet so the
    // model knows "now" and has live grounding without MCP round-trips on the iOS side.
    const temporalContext = buildTemporalContext();
    const webContext = await webContextPromise;

    let userMessage = input.trim();
    if (refinement?.trim()) {
      const contextHeader = [temporalContext, webContext].filter(Boolean).join("\n");
      userMessage =
        `${contextHeader}\n\nOriginal prompt:\n${input.trim()}\n\nRefinement request:\n${refinement.trim()}\n\nRefine the original prompt based on the refinement request.`;
    } else {
      const contextHeader = [temporalContext, webContext].filter(Boolean).join("\n");
      userMessage = `${contextHeader}\n\n${input.trim()}`;
    }

    const taskInstruction =
      `${userMessage}\n\nReturn ONLY a JSON object with exactly two keys — no markdown, no explanation:\n{"professional":"<full polished prompt>","template":"<fill-in-the-blank version with [PLACEHOLDER] tokens>"}`;

    // ── Route to available AI provider ────────────────────────────────────────
    let rawContent: string | null = null;
    let lastError: Error | null = null;

    const providers = [
      { name: "Gemini",    key: GEMINI_API_KEY,    call: callGemini },
      { name: "Anthropic", key: ANTHROPIC_API_KEY, call: callAnthropic },
      { name: "OpenAI",    key: OPENAI_API_KEY,    call: callOpenAI },
    ];

    for (const provider of providers) {
      if (provider.key) {
        try {
          console.log(`Attempting generation with ${provider.name}...`);
          rawContent = await provider.call(resolvedSystem, taskInstruction);
          console.log(`Generation successful with ${provider.name}.`);
          break; // Success, exit the loop
        } catch (err) {
          console.error(`Generation failed with ${provider.name}:`, err.message);
          lastError = err;
          
          // Fail fast on invalid keys so the real error isn't masked by the fallback chain
          if (err instanceof APIError && err.message.includes("Invalid")) {
            throw err;
          }
        }
      }
    }

    if (rawContent === null) {
      if (lastError) throw lastError; // Re-throw the last error to be handled by the outer catch block
      return errorResponse(
        "No AI API key configured. Set GEMINI_API_KEY, ANTHROPIC_API_KEY or OPENAI_API_KEY in Supabase secrets.",
        500,
      );
    }

    // ── Parse JSON from AI response ───────────────────────────────────────────
    const cleaned = rawContent
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/```\s*$/i, "")
      .trim();

    let parsed: { professional?: string; template?: string } = {};
    try {
      parsed = JSON.parse(cleaned);
    } catch {
      parsed = { professional: cleaned, template: cleaned };
    }

    const professional = (parsed.professional ?? cleaned).trim();
    const template = (parsed.template ?? professional).trim();

    if (!professional) {
      return errorResponse("AI returned an empty result. Please try again.", 502);
    }

    // ── Build response ─────────────────────────────────────────────────────────
    const promptsUsed = userPlan === "starter" ? promptsUsedBefore + 1 : 0;
    const promptsRemaining = userPlan === "starter"
      ? Math.max(0, FREE_MONTHLY_LIMIT - promptsUsed)
      : null;

    const latencyMs = Date.now() - requestStart;

    const result: GenerateResponse = {
      professional,
      template,
      prompts_used: promptsUsed,
      prompts_remaining: promptsRemaining,
      plan: userPlan,
      intent_category: intentCategory,
      latency_ms: latencyMs,
      web_context_used: webContext !== null,
    };

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

// ── Gemini ────────────────────────────────────────────────────────────────────
async function callGemini(system: string, userMsg: string): Promise<string> {
  // Ensure no hidden newline characters break the URL
  const cleanKey = GEMINI_API_KEY?.trim() ?? "";
  
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${cleanKey}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: userMsg }] }],
      generationConfig: {
        temperature: 0.7,
        responseMimeType: "application/json"
      }
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("Gemini error:", res.status, text);
    if (res.status === 400 && text.includes("API_KEY_INVALID")) throw new APIError("Invalid Gemini API key. Check GEMINI_API_KEY in Supabase secrets.", 500);
    if (res.status === 429) throw new APIError("Generation quota reached. Please try again in a moment.", 429);
    
    // Extract the actual error message so the app shows exactly what went wrong
    let detail = `Gemini error ${res.status}`;
    try {
      const errBody = JSON.parse(text);
      if (errBody?.error?.message) detail = `Gemini: ${errBody.error.message}`;
    } catch {
      if (text && text.length < 300) detail = `Gemini ${res.status}: ${text}`;
    }
    throw new APIError(detail, 502);
  }

  const data = await res.json();
  const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!content) throw new APIError("Empty response from Gemini.", 502);
  return content;
}

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
      model: "claude-3-haiku-20240307",
      max_tokens: 1024,
      system,
      messages: [{ role: "user", content: userMsg }],
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("Anthropic error:", res.status, text);
    if (res.status === 401) throw new APIError("Invalid Anthropic API key. Check ANTHROPIC_API_KEY in Supabase secrets.", 500);
    if (res.status === 429) throw new APIError("Generation quota reached. Please try again in a moment.", 429);
    // Extract the actual Anthropic error message so iOS can display it
    // and so it appears clearly in Supabase Function logs.
    let detail = `Anthropic error ${res.status}`;
    try {
      const errBody = JSON.parse(text);
      if (errBody?.error?.message) detail = `Anthropic: ${errBody.error.message}`;
    } catch { /* non-JSON body — use raw text if short */
      if (text && text.length < 300) detail = `Anthropic ${res.status}: ${text}`;
    }
    throw new APIError(detail, 502);
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
    if (res.status === 401) throw new APIError("Invalid OpenAI API key. Check OPENAI_API_KEY in Supabase secrets.", 500);
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
