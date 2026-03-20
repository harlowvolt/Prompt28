# CODEX_HANDOFF_v3_2 — Orion Orb (Prompt28)

**Version:** v3.3
**Date:** 2026-03-19
**Branch:** `orion-upgrade-main`
**Supabase project:** `jzwerkqoczhtkyhigigf`
**Bundle ID:** `com.prompt28.prompt28`
**Target iOS:** 17.0+

---

## What This File Is

A compact, token-efficient reference for the next AI agent picking up this project.
Read this file first. Then read `AGENTS.md`. Do not re-read the full codebase unless a step requires it.

---

## Current State (v3.2)

All Phases 1–5 (iOS side) are implemented in code. Railway is fully retired. Supabase is the only backend.

### Backend
| Component | Status |
|-----------|--------|
| Supabase Auth | ✅ Active (email, Google, Apple) |
| `generate` Edge Function | ✅ Deployed — Anthropic Claude primary, OpenAI fallback, Phase 5 intent classifier + temporal context |
| `delete-account` Edge Function | ✅ Deployed — deletes `auth.users` + `prompts` via service role |
| `prompts` table | ✅ Schema defined (`20240101000000_core_tables.sql`) — run migration if not yet applied |
| `events` table | ✅ Schema defined (`20240101000000_core_tables.sql`) |
| `telemetry_errors` table | ✅ Schema defined (`20240101000000_core_tables.sql`) |
| `prompt_feedback` table | ✅ Schema defined (`20240601000000_prompt_feedback.sql`) |
| `trending_prompts` table | ✅ Schema defined (`20240602000000_trending_prompts.sql`) |

### iOS App — Key Systems
| System | File | Status |
|--------|------|--------|
| Root state machine | `App/RootView.swift` | ✅ privacy → auth → onboarding → tabs |
| Dependency injection | `App/AppEnvironment.swift` | ✅ `@Observable @MainActor`, all services wired |
| Auth | `Core/Auth/AuthManager.swift` | ✅ Supabase-only; plan from `user_metadata.plan` |
| History sync | `Core/Storage/HistoryStore.swift` | ✅ JSON local + Supabase two-way, owner-bound cache |
| Generation | `Features/Home/ViewModels/GenerateViewModel.swift` | ✅ Edge Function only; no Railway |
| Orb UI | `Features/Home/Views/OrbView.swift` | ✅ branches on `is_metal_orb_enabled` flag |
| Metal Orb | `Features/Home/Views/MetalOrbView.swift` | ✅ MTKView + `Orb.metal`; behind feature flag |
| StoreKit 2 | `Core/Store/StoreManager.swift` | ✅ `activePlan`, `syncPlanToSupabase()` wired |
| Usage metering | `Core/Store/UsageTracker.swift` | ✅ Keychain-backed; server-side enforced in Edge Function |
| Analytics | `Core/Utils/AnalyticsService.swift` | ✅ UserDefaults queue → `events` table |
| Telemetry | `Core/Utils/TelemetryService.swift` | ✅ UserDefaults queue → `telemetry_errors` table |
| Trending | `Features/Trending/ViewModels/TrendingViewModel.swift` | ✅ Supabase query + Realtime channel |
| Feedback | `Features/Home/Views/ResultView.swift` | ✅ thumbs up/down → `prompt_feedback` |
| Share cards | `Features/Home/Views/ShareCardView.swift` | ✅ `ImageRenderer` → PNG → `ShareLink` |
| Admin panel | `Features/Admin/` | ✅ admin key gated; Railway settings still used here only |

### APIClient scope (Railway — admin only)
Only these 7 methods remain in `APIClientProtocol`:
`settings`, `promptsTrending`, `adminVerify`, `adminSettings`, `adminUpdateSettings`, `adminPrompts`, `adminUpdatePrompts`

All user-facing Railway methods (`register`, `login`, `me`, `generate`, `updatePlan`, etc.) are permanently deleted.

---

## Files Changed Since v3.0 (this session)

| File | Change |
|------|--------|
| `Prompt28.xcodeproj/project.pbxproj` | Added `MetalOrbView.swift` to Xcode target (fixes "Cannot find 'MetalOrbView' in scope") |
| `supabase/migrations/20240101000000_core_tables.sql` | **NEW** — `prompts`, `events`, `telemetry_errors` schemas + RLS + indexes |
| `supabase/functions/generate/index.ts` | Phase 5 MCP: `BRAVE_API_KEY` secret, `needsWebContext()`, `fetchWebContext()`, `web_context_used` in response |
| `Models/API/GenerateModels.swift` | Added `web_context_used: Bool?` to `GenerateResponse` |
| `Features/Home/ViewModels/GenerateViewModel.swift` | Added `web_context_used` to `EdgeGenerateResponse`, mapping, `restoreFromHistory` stub, analytics call |
| `Core/Utils/AnalyticsService.swift` | Added `webContextUsed` param to `generateSuccess` event + properties |
| `CODEX_HANDOFF_v3_2.md` | **NEW** — this file |
| `CURRENT_STATE_CLEAN_ROADMAP.md` | Version bumped to v3.3, v3.2 + v3.3 changelog entries added |

---

## Pending Manual Steps (require developer account)

| Task | Where |
|------|-------|
| Run `20240101000000_core_tables.sql` | Supabase Dashboard → SQL Editor |
| Run `20240601000000_prompt_feedback.sql` | Supabase Dashboard → SQL Editor |
| Run `20240602000000_trending_prompts.sql` | Supabase Dashboard → SQL Editor |
| Create 4 IAP products | App Store Connect → In-App Purchases |
| Configure Apple Sign In | Apple Developer Portal + Supabase Auth → Providers → Apple |
| Deploy Edge Functions | `supabase functions deploy generate --no-verify-jwt` |
| Device test: generation → paywall → upgrade → delete | Physical iPhone |

---

## Phase 5 — Code Complete, Not Yet Live

**What "Phase 5" actually means here:** Keyword-based intent classification + temporal context + optional web-context enrichment via Brave Search API. This is NOT true MCP (Model Context Protocol). It is a lightweight server-side enrichment step where the Edge Function fetches top search snippets and injects them as grounding text before generation.

**iOS (code complete ✅):** `EdgeGenerateResponse` decodes `intent_category`, `latency_ms`, `web_context_used`. `ResultView` shows intent badge. `AnalyticsService.generateSuccess` logs all three fields.

**Edge Function (code complete ✅, not yet live ⏳):** Intent classifier, temporal context, intent-specialized system prompts, Brave Search enrichment for `business`/`technical`/`general` intents on question/recency queries. `web_context_used` in response. **Requires redeploy + `BRAVE_API_KEY` secret to activate web enrichment.**

**To go live:**
1. `supabase functions deploy generate --no-verify-jwt`
2. Set `BRAVE_API_KEY` in Supabase Dashboard → Settings → Edge Functions → Secrets (free tier: 2 000 req/mo at api.search.brave.com)
3. Web enrichment is opt-in — if secret is absent, generation works normally without it

**Optional future extensions:**
- iOS `web_context_used` badge in `ResultView`
- Broader enrichment intents (work, school)
- Confidence score from intent classifier

---

## Critical Rules

1. **Never reintroduce Railway for user-facing calls.** Admin panel only.
2. **Never reintroduce SwiftData or CloudKit.** Codable JSON + Supabase is permanent.
3. **Never hardcode API keys.** All config from `Info.plist` (Supabase URL, anon key, function name).
4. **Plan tier source of truth:** `user_metadata.plan` written by `StoreManager.syncPlanToSupabase()` after IAP verification. Both iOS and Edge Function read this field.
5. **NavigationStack rule:** Every view owning a `NavigationStack` must have `PromptPremiumBackground().ignoresSafeArea()` as the first child of its top-level `ZStack`.
6. **Metal Orb rollout:** Set `is_metal_orb_enabled = true` in Admin Dashboard `@AppStorage` to enable. Off by default.
7. **Simulator:** Use only `Prompt28-iPhone17` / UDID `06B488AD-877C-4EC1-A472-E2053BD31DB9`.

---

## Architecture in One Diagram

```
OrionOrbApp (@main)
  └─ AppEnvironment (@Observable @MainActor)
       ├─ supabase: SupabaseClient         ← all DB/auth/functions/realtime
       ├─ authManager: AuthManager         ← Supabase JWT, plan from user_metadata
       ├─ historyStore: HistoryStore       ← JSON disk + Supabase two-way sync
       ├─ storeManager: StoreManager       ← StoreKit 2 receipts, syncPlanToSupabase
       ├─ usageTracker: UsageTracker       ← Keychain monthly counter
       ├─ apiClient: APIClient             ← Railway (admin panel only)
       ├─ AnalyticsService.shared          ← UserDefaults queue → events table
       └─ TelemetryService.shared          ← UserDefaults queue → telemetry_errors

RootView state machine:
  hasAcceptedPrivacy? → didBootstrap? → isAuthenticated? → hasSeenOnboarding? → mainTabs

Generation path:
  OrbView (voice) / TypePromptView (text)
    → GenerateViewModel.generate()
    → supabase.functions.invoke("generate", body: {input, mode, refinement})
    → Edge Function: classifyIntent → resolveSystemPrompt → Anthropic/OpenAI → JSON
    → GenerateResponse { professional, template, intent_category, latency_ms }
    → HistoryStore.add() + AnalyticsService.track("promptGenerated")
    → ResultView (share, feedback, favorite)
```

---

## Quick Reference: Info.plist Keys

| Key | Purpose |
|-----|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase publishable anon key |
| `SUPABASE_GENERATE_FUNCTION` | Edge Function name (e.g. `"generate"`) |
| `RAILWAY_BASE_URL` | Legacy Railway URL (admin panel only) |
