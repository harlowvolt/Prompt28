# Orion Orb — Clean Roadmap (Railway Fully Retired, v3.2)

**Last updated: 2026-03-19**
**Version**: v3.3 (Phase 5 MCP web-context complete — Brave Search grounding injected for business/technical/general intents when BRAVE_API_KEY is set; MetalOrbView added to Xcode target; core Supabase table migrations added)
**Status**: All Phase 3–5 features implemented in code. Device validation and App Store Connect IAP setup are the remaining blockers before TestFlight.

This roadmap separates **current working reality** from **next critical steps** from **long-term vision**. It is grounded in actual code, not aspirations.

---

## Part 1: Current Reality (What Exists in Code Right Now)

### Architecture Foundations (✅ Complete)

- **Entry point**: `OrionOrbApp.swift` (struct `OrionOrbApp`, marked `@main`)
- **Dependency injection**: `AppEnvironment` (@Observable @MainActor) bootstraps all services
- **State machine**: `RootView` gates privacy consent → auth → onboarding → main tabs
- **UI framework**: SwiftUI with `@Observable` (no `@State` for models)
- **Design system**: Unified `PromptTheme` colors, `AppUI` spacing/radii, `PromptPremiumBackground` backgrounds
- **Persistence**: Codable JSON at `Application Support/OrionOrb/history.json` + **Supabase two-way sync** (last-write-wins) with pending delete queue at `Application Support/OrionOrb/history_pending_deletes.json`
- **Authentication**: Supabase Auth (JWT stored in Keychain) with OAuth support (Google, Apple, email/password)
- **Database**: Supabase PostgreSQL (prompts table, events table, telemetry_errors table) with RLS assumptions wired in code
- **Analytics**: `TelemetryService` (errors) and `AnalyticsService` (events) — both upload to Supabase
- **Freemium metering**: `UsageTracker` (Keychain-backed) tracks monthly generation quota; enforced client-side
- **In-app purchases**: StoreKit 2 wired (`StoreManager`) — awaiting App Store Connect setup
- **Voice input**: `SpeechRecognizerService` + `OrbEngine` for animation state machine
- **Metal graphics**: Placeholder in `OrbView` — feature flag `is_metal_orb_enabled` ready to roll out

### Deletion Summary (What's NOT in Code Anymore)

1. **SwiftData removed**: No `@Model`, no `ModelContainer`, no `ModelContext` — replaced by Codable + Supabase
2. **CloudKit removed**: No `CKRecord`, no `NSUbiquitousKeyValueStore` — Supabase is the cloud store
3. **Railway JWT wrapper removed**: `SupabaseClient.swift` wrapper deleted — use native `supabase-swift` SDK
4. **CloudKitService removed**: Entire service deleted — Supabase is the sync engine
5. **Railway user/generate/auth methods removed**: `APIClient` stripped to admin+config only. Removed: `register`, `login`, `googleAuth`, `appleAuth`, `me`, `updatePlan`, `deleteUser`, `resetUsage`, `generate`, `config` methods + matching `APIEndpoint` cases + Railway-only DTOs (`AuthResponse`, `RegisterRequest`, etc.)
6. **`AuthManager.apiClient` removed**: `AuthManager` is Supabase-only; plan is read from `user_metadata.plan`; `syncUserWithServer()` deleted
7. **`GenerateViewModel.apiClient` removed**: Railway fallback branch deleted; missing Edge Function config now gives a clear error

### What's Working

1. ✅ App builds and launches
2. ✅ `RootView` renders with correct native state machine
3. ✅ Privacy consent gate blocks auth flows
4. ✅ Google Sign-In works with Supabase Auth
5. ✅ Apple Sign-In flow exists in code
6. ✅ Supabase SDK initializes from `Info.plist` config
7. ✅ JSON persistence loads/saves to disk
8. ✅ History `items` array is observable in-memory
9. ✅ Best-effort signed-in sync now triggers immediately after `add`, `toggleFavorite`, and `rename`
10. ✅ Launch-time sync runs when a valid Supabase session already exists
11. ✅ Delete propagation exists and pending delete IDs retry on future sync
12. ✅ Signed-out/user-deleted state clears local history to avoid cross-user contamination
13. ✅ Disk-backed history is withheld from public UI state until initial auth/session reconciliation completes, reducing stale wrong-user history exposure during launch and account switching
14. ✅ Local history cache is now explicitly bound to the signed-in owner via `history_owner.txt`, so wrong-user cached history is cleared if a different account session appears
15. ✅ Deferred owned history is still persisted to disk during the initial reconciliation window, preventing early post-launch saves from overwriting the hidden owned cache
16. ✅ Foreground lifecycle observer registration is deduped before re-registration, reducing duplicate retry observer risk in longer app sessions
17. ✅ Ambiguous unowned local history is now cleared on signed-in reconciliation instead of being adopted for the current user, reducing legacy/wrong-user cache leakage risk
18. ✅ All authenticated sync entrypoints now share the same owner-preparation + deferred-history-restore path before syncing
19. ✅ Pending deletes are filtered out of deferred-history restore/persistence, preventing deleted items from resurfacing during the reconciliation window
20. ✅ Generation path now refreshes the Supabase session token before calling the legacy Railway `/api/generate` endpoint and retries once on session-expired responses
21. ✅ Generate failure surfacing now includes raw backend/body text when the legacy Railway response is non-JSON or decodes unexpectedly
22. ✅ `AuthManager.bootstrap()` clears the SDK's internal stale session on restore failure — fixes "session expired" blocking all fresh logins
23. ✅ `UpgradeView` resolves the "Loading plans…" infinite spinner: tracks `productsLoaded` state, shows a real "Plans not available" message when StoreKit returns empty
24. ✅ `UpgradeView` dev section restructured — "Reset Usage Counter" and "Admin key / Activate Dev Plan" are now clearly separated sections with explanatory labels
25. ✅ `GenerateViewModel` Railway 401 now shows "Prompt generation is temporarily unavailable" instead of the misleading "Session expired. Please sign in again."
26. ✅ **Phase 3 foundation wired**: `GenerateViewModel` now checks `SUPABASE_GENERATE_FUNCTION` in Info.plist. When set to a deployed Edge Function name (e.g. `"generate"`), generation routes to `supabase.functions.invoke()` instead of Railway — carrying the Supabase JWT natively and bypassing the Railway auth incompatibility. Currently set to `""` (disabled — Railway fallback active).
27. ✅ `HomeView` and `RootView` thread `SupabaseClient` through to `GenerateViewModel` so Edge Function path works end-to-end when enabled.
28. ✅ `EdgeGenerateResponse` DTO defined — Edge Function only needs to return `{ professional, template }`, usage/plan metadata filled in locally if absent.
29. ✅ **Phase 3 deployed**: `supabase/functions/generate/index.ts` deployed to Supabase project `jzwerkqoczhtkyhigigf`. Uses Anthropic Claude (`claude-haiku-4-5-20251001`) as primary AI provider with OpenAI GPT-4o-mini as fallback. Verifies Supabase JWT server-side.
30. ✅ `SUPABASE_GENERATE_FUNCTION` in Info.plist set to `"generate"` — iOS now routes all generation through the Edge Function (Railway retired as primary).
31. ✅ `StoreManager.activePlan` added — reads StoreKit receipt-backed `purchasedProductIDs` directly, bypassing Railway plan sync failure. Paid users are no longer gated as `.starter`.
32. ✅ `GenerateViewModel.edgeFunctionErrorMessage(from:)` — Mirror-based extraction of `FunctionsError.httpError` data payload, decodes `{ "error": "..." }` JSON body. Meaningful errors shown instead of raw status codes.
33. ✅ Settings red error banner silenced — `loadRemoteSettings()` Railway 401 now logs silently via TelemetryService. AppSettings is cosmetic only.
34. ✅ `deleteAccount()` now calls `delete-account` Edge Function (deletes auth.users row + prompts via service role), then clears local state + logs out. Falls back to local-only clear if function is unreachable.
35-new. ✅ `StoreManager.syncPlanToSupabase()` — writes `user_metadata.plan` immediately after a verified purchase or background transaction update, so Edge Function metering bypass activates without an App Store Server Notifications webhook.
36-new. ✅ `FavoritesView` pull-to-refresh — mirrors HistoryView, calls `viewModel.syncWithRemote()`.
37-new. ✅ Analytics gaps fixed: `generate()` typed path now fires `generateTapped`; `copyPrompt` and `sharePrompt` events wired in `ResultView`.
38-new. ✅ Both Edge Functions (`generate`, `delete-account`) deployed to Supabase project `jzwerkqoczhtkyhigigf`.
35. ✅ `TrendingViewModel` bundled JSON fallback — loads `trending_prompts.json` from app bundle before API attempt, so trending tab never shows blank screen offline.
36. ✅ `HistoryStoring` protocol extended with `isSyncing: Bool` and `func forceSync() async`.
37. ✅ `HistoryViewModel` exposes `isSyncing` and `syncWithRemote()` forwarding to the store.
38. ✅ Pull-to-refresh added to `HistoryView` — calls `viewModel.syncWithRemote()` for manual Supabase sync validation.

**Phase 4 (complete as of v3.0):**

39. ✅ **Thumbs up/down feedback** in `ResultView` — `feedbackSubmitted: Bool?` state drives icon/label animation. Both buttons call `viewModel.submitFeedback(thumbsUp:)` which fires the `promptFeedback` analytics event and inserts to Supabase `prompt_feedback` table. Resets on every new generation.
40. ✅ `prompt_feedback` Supabase table SQL migration (`supabase/migrations/20240601000000_prompt_feedback.sql`) — RLS enforced, user_id FK, history_item_id link, indexed.
41. ✅ **Shareable cards** — `ShareCardView`, `ShareCardRenderer`, `ShareCardFileStore` fully implemented. `ResultView` generates a PNG via `ImageRenderer`, stores to temp file, exposes via `ShareLink` with social preview.
42. ✅ **Metal Orb GPU renderer** — `ExperimentFlags.Orb.metalOrb` (`is_metal_orb_enabled`) flag added to `AppUI.swift`. `OrbView` branches on `@AppStorage` flag: Metal path → `MetalOrbView` → `OrbMTKViewRepresentable` → `OrbMetalRenderer` (MTKViewDelegate). Full `Orb.metal` fragment shader with state-dependent colors, breathing animation, specular highlight, and glow ring. Falls back to SwiftUI orb if Metal unavailable. Enable the flag in AdminDashboard to roll out.
43. ✅ **Supabase Realtime Trending** — `TrendingViewModel` now subscribes to `trending_prompts` Postgres channel via `supabase-swift` Realtime v2. INSERT and UPDATE events trigger a catalog refresh. `TrendingView` passes supabase + apiClient, subscribes on `.task`, unsubscribes on `.onDisappear`. `trending_prompts` table migration at `supabase/migrations/20240602000000_trending_prompts.sql`.
44. ✅ `TypePromptView` glass design system rewrite — custom mode segmented control, TextEditor with glassFill + focus ring animation, gradient Generate button, `.presentationDetents([.medium, .large])`.
45. ✅ `HomeView` double-NavigationStack fix — `TypePromptView` now owns its own NavigationStack; `HomeView` no longer wraps it.
46. ✅ **Trending fetches directly from Supabase** — `TrendingViewModel` now queries `trending_prompts` table (WHERE `is_active = true`, ORDER BY `use_count DESC`) via `supabase-swift`. Groups rows by `category` into the existing `PromptCatalog → PromptCategory → PromptItem` hierarchy. Supabase is tried first; Railway `promptsTrending()` is the fallback if Supabase fails. `TrendingView` passes `scopedSupabase` to both `loadIfNeeded` and `refresh`. Realtime-triggered refreshes also use the Supabase path. Railway is no longer the primary data source for Trending.
47. ✅ **Railway fully retired — dead code removed**:
    - `AuthManager`: removed `apiClient` dependency, removed `syncUserWithServer()` (Railway `/api/me`), `convertSupabaseUserToAppUser` now reads `plan` from `user_metadata.plan` (written by StoreManager after IAP).
    - `GenerateViewModel`: Railway fallback `else` branch removed; `apiClient` property/parameter removed entirely. If `SUPABASE_GENERATE_FUNCTION` is not set, shows a clear config error instead of silently calling dead Railway endpoint.
    - `SettingsViewModel.updatePlan()`: replaced Railway call with `supabase.auth.update(user: UserAttributes(data: ["plan": ...]))`. Dev plan activation now writes Supabase user_metadata directly.
    - `SettingsViewModel.resetUsage()`: replaced Railway call with local `usageTracker.reset()` (synchronous, no async).
    - `APIClientProtocol`: stripped to admin + config methods only (`settings`, `promptsTrending`, admin verbs).
    - `APIClient`: removed `register`, `login`, `googleAuth`, `appleAuth`, `me`, `updatePlan`, `deleteUser`, `resetUsage`, `generate`, `config` methods.
    - `APIEndpoint`: removed all user/auth/generate cases; only `settings`, `promptsTrending`, and admin cases remain.
    - `AuthModels.swift`: removed Railway-only DTOs (`AuthResponse`, `RegisterRequest`, `LoginRequest`, `GoogleAuthRequest`, `AppleAuthRequest`, `AppConfigResponse`, `UpdatePlanRequest`, `UpdatePlanResponse`). Kept shared types: `SuccessResponse`, `AdminVerifyResponse`, `APIErrorResponse`.
    - `UpgradeView.handlePurchase()`: removed redundant `viewModel.updatePlan()` call (StoreManager already calls `syncPlanToSupabase`).

### What's NOT Fully Validated Yet

1. ⏳ Physical iPhone end-to-end generation validation — build and run on device with `SUPABASE_GENERATE_FUNCTION=generate` active
2. ⏳ Apple Sign In — Supabase dashboard Apple provider not yet configured (requires Apple Developer Services ID + .p8 key)
3. ⏳ App Store Connect IAP products not yet created (`com.prompt28.pro.monthly`, `.pro.yearly`, `.unlimited.monthly`, `.unlimited.yearly`)
4. ⏳ Supabase Edge Function for account deletion — code written and deployed ✅; iOS wired ✅; needs device test
5. ⏳ Simulator validation: use only `Prompt28-iPhone17` / UDID `06B488AD-877C-4EC1-A472-E2053BD31DB9`

### Build Info

- **Branch**: `orion-upgrade-main`
- **Target iOS**: 17.0+
- **Build system**: Xcode (Swift 5.9+)
- **Package dependencies** (SPM):
  - `supabase-swift` (live Supabase SDK)
  - `GoogleSignIn` (9.1.0)
  - `AppAuth`, `GTMAppAuth`, `GTMSessionFetcher` (OAuth helpers)

---

## Part 2: Immediate Next Steps

### Step 1: Validate Edge Function Generation On Device

1. `git pull` on Mac, then rebuild in Xcode targeting physical iPhone
2. Sign in → tap orb → speak or type a prompt → tap Generate
3. Confirm the generated result appears (no error banner)
4. Check Supabase dashboard → Table Editor → `prompts` table — new row should appear
5. Pull down on History tab — confirm pull-to-refresh spinner appears and item is there
6. Test refinement (type in the refine field, tap refine) — should call Edge Function again
7. Confirm paywall only appears after 10 free generations

### Step 2: Apple Sign In Setup (Manual — Requires Apple Developer Account)

Apple Sign In requires config in both Apple Developer Portal and Supabase. Steps:

**Apple Developer Portal** (developer.apple.com):
1. Identifiers → create a **Services ID** (e.g. `com.yourapp.siwa`)
   - Enable "Sign In with Apple"
   - Add your Supabase callback URL: `https://jzwerkqoczhtkyhigigf.supabase.co/auth/v1/callback`
2. Keys → create a new **Key** with "Sign In with Apple" enabled
   - Download the `.p8` private key file (save it — you only get one download)
   - Note the **Key ID**
3. Note your **Team ID** from the top-right of developer.apple.com

**Supabase Dashboard** (supabase.com/dashboard → your project):
1. Authentication → Providers → Apple → Enable
2. Fill in:
   - **Services ID** (the `com.yourapp.siwa` you created)
   - **Team ID**
   - **Key ID**
   - **Private Key** (paste the contents of the `.p8` file)
3. Save

### Step 3: App Store Connect IAP Products

Create four subscription products in App Store Connect → your app → In-App Purchases → Subscriptions:

| Product ID | Type | Price tier |
|-----------|------|-----------|
| `com.prompt28.pro.monthly` | Auto-renewable | ~$4.99/mo |
| `com.prompt28.pro.yearly` | Auto-renewable | ~$39.99/yr |
| `com.prompt28.unlimited.monthly` | Auto-renewable | ~$9.99/mo |
| `com.prompt28.unlimited.yearly` | Auto-renewable | ~$79.99/yr |

These product IDs must match exactly what `StoreProductID` enum defines in `StoreManager.swift`.
After creating them, StoreKit will return them — the "Loading plans…" banner will resolve automatically.

### Step 4: Verify Supabase Tables (if not already done)

Run these SQL statements in your Supabase SQL editor if not already created:

```sql
-- prompts table (history sync)
create table prompts (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null,
  mode          text not null,
  input         text not null,
  professional  text not null,
  template      text not null,
  favorite      boolean not null default false,
  custom_name   text,
  last_modified timestamptz not null
);
alter table prompts enable row level security;
create policy "Users own their prompts"
  on prompts for all using (auth.uid() = user_id);
create index prompts_user_id_idx on prompts(user_id);
```

### Step 5: Test Offline Resilience

1. Create a prompt
2. Put app in airplane mode
3. Modify the prompt (favorite, rename, delete)
4. Disable airplane mode
5. Pull-to-refresh on History tab
6. Verify changes sync correctly (last-write-wins)

---

## Part 3: Phase 3 — Core Generation & Monetization

The Orion Orb Upgrade Roadmap (from the docx) outlines Phase 3 in full detail. High-level summary:

### Phase 3 Goals

1. **AI Prompt Generation** — Wire HomeView generation flow to backend (currently stubs)
2. **Usage Metering** — Server-side validation of freemium limits in Edge Function
3. **StoreKit 2 Monetization** — Complete In-App Purchase flow (products, receipts, subscriptions)
4. **Webhook Sync** — App Store Server Notifications keep Supabase user subscription tier in sync

### Key Phase 3 Files to Touch

| File | Purpose |
|------|---------|
| `Features/Home/ViewModels/GenerateViewModel.swift` | Wire `.generate()` to real API call |
| `Core/Networking/APIEndpoint.swift` | Add `.generate` endpoint (Routes to Edge Function) |
| `Core/Store/StoreManager.swift` | Complete StoreKit 2 integration (already stubbed) |
| `Features/Settings/UpgradeView.swift` | Wire subscription UI to StoreKit products |
| `Core/Auth/AuthManager.swift` | Fetch updated plan info after purchase |
| Backend (Edge Function) | Implement `/api/generate` route with usage metering + LLM broker |

### Phase 3 Success Criteria

- ✅ User can tap orb → speak/type → receive generated prompt
- ✅ Starter plan enforced (10/month), Pro plan unlimited
- ✅ Upgrade button routes to App Store
- ✅ Subscription purchase syncs immediately to app
- ✅ Analytics event `prompt_generated` fired and logged

---

## Part 4: Phase 4 — Experience & Data Flywheel

Once Phase 3 generation works:

### Phase 4 Goals

1. **Metal Orb GPU Animation** — Roll out via feature flag (`is_metal_orb_enabled`)
2. **Feedback Loop** — Thumbs up/down on results; store in Supabase for RLHF data
3. **Shareable Cards** — Social-ready prompt cards with watermark
4. **Real-Time Trending** — Supabase Realtime + Postgres CDC for live trending prompts

### Key Phase 4 Features

- `OrbView` Metal shader safe rollout
- `ResultView` feedback buttons → Supabase upsert
- `ShareCardView` → `ImageRenderer` → social share
- `TrendingView` live updates via `Supabase.Realtime`

---

## Part 5: Phase 5 — Future Vision (MCP & Intent Routing)

Long-term architecture (not immediate):

### Goals

1. **Intent Classifier** — Edge Function routes user intent to optimized prompt template
2. **MCP Integration** — iOS client stays lightweight; backend uses MCP to fetch web context
3. **Result Metadata** — Return confidence scores, model latency, intent category to client
4. **Context-Aware Generation** — For queries requiring live data (e.g., "today's news"), fetch via MCP tools

### Implication

iOS app remains a "thin client" — handles audio input, UI, Metal rendering. All reasoning and data fetching happens server-side.

---

## Architecture Reference (Single Source of Truth)

### Entry Point & Bootstrap

**File**: `PromptMeNative_Blueprint/OrionOrbApp.swift`

```swift
@main struct OrionOrbApp: App {
    @State var env = AppEnvironment()  // Initializes all services

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .environment(errorState)
                // ... all EnvironmentValues wired
        }
    }
}
```

**Dependency Container**: `PromptMeNative_Blueprint/App/AppEnvironment.swift`

All services are instantiated here, exactly once. Key services:

- `supabase: SupabaseClient` — Loaded from `Info.plist` config
- `authManager: AuthManager` — Manages Supabase Auth + local JWT storage
- `historyStore: HistoryStore` — Loads JSON from disk, syncs to Supabase on auth
- `apiClient: APIClient` — Legacy Railway API (for backward compatibility)

### Persistence Strategy

1. **Local storage** — `Application Support/OrionOrb/history.json` (Codable)
   - Survives offline
   - Loaded on app launch
2. **Cloud sync** — Supabase `prompts` table
   - Two-way merge (last-write-wins)
   - Triggered on sign-in and on-demand (`forceSync()`)
   - Private RLS: each user sees only their own records

### Authentication Flow

1. User taps "Sign in with Google" / "Sign in with Apple" / "Email"
2. `AuthFlowView` → `OAuthCoordinator` or `EmailAuthView` → `AuthManager.signIn(…)`
3. `AuthManager` calls `supabase.auth.signIn(…)`
4. Supabase returns JWT + refresh token
5. `AuthManager` stores JWT in Keychain
6. `HistoryStore` auth listener detects `.signedIn` event → calls `syncWithSupabase(userId:)`
7. App transitions to main tabs

**File**: `PromptMeNative_Blueprint/Core/Auth/AuthManager.swift`

### State Machine

**File**: `PromptMeNative_Blueprint/App/RootView.swift`

```
hasAcceptedPrivacy?
  NO  → PrivacyConsentView
  YES → didBootstrap?
        NO  → ProgressView (spinner)
        YES → isAuthenticated?
              NO  → AuthFlowView
              YES → hasSeenOnboarding?
                    NO  → OnboardingView
                    YES → mainTabs (iPhone) or iPadSidebar (iPad)
```

### Design System

All tokens in two files:

- **Colors** — `PromptTheme` enum in `RootView.swift`
- **Spacing/Radii/Heights** — `AppUI.swift`
- **Backgrounds** — `PromptPremiumBackground` struct in `RootView.swift`
- **Glass cards** — `PromptTheme.glassCard(cornerRadius:)` function + `.appGlassCard()` modifier

**Critical rule**: Every view with `NavigationStack` must own `PromptPremiumBackground().ignoresSafeArea()` as first child of its top-level ZStack.

### Key Files Overview

| Path | Purpose |
|------|---------|
| `OrionOrbApp.swift` | App entry point, bootstraps environment |
| `App/AppEnvironment.swift` | Dependency container |
| `App/RootView.swift` | Root state machine, design tokens |
| `Core/Auth/AuthManager.swift` | Supabase auth, JWT management |
| `Core/Storage/HistoryStore.swift` | JSON local + Supabase sync |
| `Core/Networking/APIClient.swift` | Railway backend client |
| `Core/Utils/AnalyticsService.swift` | Event logging to Supabase |
| `Core/Utils/TelemetryService.swift` | Error logging to Supabase |
| `Features/Home/Views/HomeView.swift` | Main generation screen |
| `Features/Auth/Views/AuthFlowView.swift` | OAuth sign-in UI |

---

## Implementation Notes for Codex & Future Agents

### What Not to Do

1. ❌ **Do not reintroduce SwiftData** — Codable + Supabase is the permanent solution
2. ❌ **Do not reintroduce CloudKit** — Supabase is the single cloud source
3. ❌ **Do not use Railway as primary auth** — Supabase Auth is the source of truth
4. ❌ **Do not hardcode API keys** — All config comes from `Info.plist`
5. ❌ **Do not bypass Keychain for JWT** — Always use `KeychainService` for token storage

### Testing Your Changes

When implementing Phase 3+ features:

1. **Auth flow** — Sign in → Supabase user created → JWT in Keychain
2. **History sync** — Create item locally → appears in Supabase `prompts` table
3. **Generation** — Add endpoint call → results save to history
4. **Analytics** — Generation event fires → appears in Supabase `events` table
5. **Errors** — Catch exceptions → logged to Supabase `telemetry_errors`

### Git Workflow

- **Current branch**: `orion-upgrade-main`
- **Before Phase 3**: Ensure this branch is clean (no merge conflicts, all tests pass)
- **Phase 3+**: Create feature branches (`feature/phase3-generation`, etc.) off `orion-upgrade-main`

---

## Known Limitations & Workarounds

| Issue | Status | Workaround |
|-------|--------|-----------|
| Supabase anon key format | ✅ Publishable key (`sb_publishable_...`) is correct format | In Info.plist |
| Auth "session expired" on login | ✅ Fixed — bootstrap now clears stale SDK session | `AuthManager.bootstrap()` |
| Railway generate call fails (401) | ✅ Resolved — generation now routes through Supabase Edge Function | `SUPABASE_GENERATE_FUNCTION=generate` |
| Railway user plan fetch fails | ✅ Mitigated — `StoreManager.activePlan` reads StoreKit receipts directly | `StoreManager.swift` |
| Settings red error banner | ✅ Fixed — Railway 401 silenced, logged via TelemetryService | `SettingsViewModel.swift` |
| `deleteAccount()` Railway call | ✅ Fixed — calls `clearAll() + logout()` directly | `SettingsViewModel.swift` |
| Trending blank screen offline | ✅ Fixed — bundled JSON fallback loads before API call | `TrendingViewModel.swift` |
| Edge Function error shows raw status | ✅ Fixed — Mirror extraction + JSON decode shows real message | `GenerateViewModel.swift` |
| UpgradeView "Loading plans…" forever | ✅ Fixed — `productsLoaded` state + fallback UI | `UpgradeView.swift` |
| Apple Sign In not configured | ⏳ Requires Apple Developer setup + Supabase dashboard config | See Step 2 in Part 2 |
| IAP products not available | ⏳ Awaiting App Store Connect setup | Create products in App Store Connect |
| Account deletion (server-side) | ✅ `delete-account` Edge Function deployed; iOS calls it via SettingsViewModel | Needs device test |
| Metal Orb not rolling out | ✅ Ready — `MetalOrbView` + `Orb.metal` implemented | Set `is_metal_orb_enabled = true` in AdminDashboard AppStorage |
| Trending not realtime | ✅ Fixed — Supabase Realtime channel subscribed to `trending_prompts` INSERT/UPDATE | Run `20240602000000_trending_prompts.sql` migration |
| Feedback not captured | ✅ Fixed — thumbs UI in ResultView, inserts to `prompt_feedback` | Run `20240601000000_prompt_feedback.sql` migration |

---

## Version History

- **v1.0-1.8**: Early phases (SwiftData era, CloudKit attempts)
- **v1.8** (2026-03-18): Phase 2 Supabase SDK integration, SwiftData removed, JSON + sync functional
- **v1.9** (2026-03-18 cleanup): Documentation cleaned, roadmap clarified, post-Phase-2 state documented
- **v2.5** (2026-03-19): Phase 3 foundation complete — Supabase Edge Function deployed (Anthropic API), Railway retired as primary, StoreManager.activePlan, error surface improvements, settings/delete fixes, trending offline fallback, pull-to-refresh history sync
- **v3.0** (2026-03-19): Phase 4 complete — thumbs up/down RLHF feedback (ResultView + Supabase insert), Metal Orb GPU renderer (MetalOrbView + Orb.metal + feature flag), Supabase Realtime Trending (INSERT/UPDATE channel subscription), shareable card UI polished, TypePromptView glass rewrite, analytics gaps closed
- **v3.2** (2026-03-19): Railway fully retired — dead code removed, APIClient stripped to admin-only, AuthManager Supabase-only, plan from user_metadata, AGENTS.md + HANDOFF.md synced
- **v3.3** (2026-03-19): Phase 5 complete — MCP web-context (Brave Search grounding in Edge Function, opt-in via BRAVE_API_KEY secret), `web_context_used` surfaced in GenerateResponse + analytics; MetalOrbView.swift added to Xcode target; core table migrations created (`20240101000000_core_tables.sql`); CODEX_HANDOFF_v3_2.md created

---

## For the Next AI Agent

When you pick up this project:

1. **Read this file first** — It's the ground truth for current state
2. **Check HANDOFF.md** — Deep technical reference (much longer), always kept in sync
3. **Check AGENTS.md** — Agent-focused rules and patterns
4. **Verify Supabase config** — Is the anon key correct? Have the two new migrations been run?
5. **Redeploy the Edge Function** — `supabase functions deploy generate --no-verify-jwt` picks up Phase 5 intent + context changes
6. **Phase 3 + 4 are DONE** — Do not re-implement them. Read v3.0 status above.
7. **Phase 5 remaining** — MCP web-context integration, App Store Connect IAP products, Apple Sign In, TestFlight submission
8. **Device testing** — Build on physical iPhone, validate generation → metering → paywall → upgrade → deletion end-to-end

Good luck building Orion Orb! 🌌
