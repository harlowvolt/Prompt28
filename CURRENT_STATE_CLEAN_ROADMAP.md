# Orion Orb — Clean Roadmap (Post-Phase-2, v1.9)

**Last updated: 2026-03-19**
**Version**: v2.0 (Phase 2 hardening / Phase 2.5)
**Status**: Phase 2 hardening in progress — native cleanup done, auth live, history hardening implemented, automated validation still in progress

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

### What's NOT Fully Validated Yet

1. ⏳ Automated validation of `HistoryStore` is not complete yet
2. ⏳ Confirmed passing hosted test:
   - `Prompt28Tests/HistoryStoreTests/coldLaunchExistingSessionTriggersSync`
3. ⏳ Current first blocker:
   - `Prompt28Tests/HistoryStoreTests/foregroundRetrySyncsPendingWork`
   - init-time session reconciliation race already removed for this test
   - test no longer depends on `UIApplication.didBecomeActiveNotification`; it calls the foreground retry path directly
   - hosted run still does not return a real pass/fail result yet
4. ⏳ Remaining `HistoryStoreTests` should continue one-by-one only after the foreground retry blocker is understood

### Build Info

- **Branch**: `orion-upgrade-main`
- **Target iOS**: 17.0+
- **Build system**: Xcode (Swift 5.9+)
- **Package dependencies** (SPM):
  - `supabase-swift` (live Supabase SDK)
  - `GoogleSignIn` (9.1.0)
  - `AppAuth`, `GTMAppAuth`, `GTMSessionFetcher` (OAuth helpers)

---

## Part 2: Immediate Next Steps (Before Phase 3)

### Step 1: Finish Phase 2 History Validation

1. Continue using the unique simulator only:
   - `Prompt28-iPhone17`
   - UDID `06B488AD-877C-4EC1-A472-E2053BD31DB9`
2. Keep using the shared derived data path:
   - `/tmp/Prompt28DerivedData`
3. Resolve the remaining first blocker:
   - `Prompt28Tests/HistoryStoreTests/foregroundRetrySyncsPendingWork`
4. After that blocker is resolved, run remaining `HistoryStoreTests` one-by-one, not as a full suite first
5. Do not mark Phase 2 hardening complete until `xcodebuild test` returns real pass/fail results for the history validation cases

### Step 2: Verify Live Supabase Assumptions

If not already created or confirmed, execute/verify these SQL statements in your Supabase SQL editor:

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

-- events table (analytics)
create table events (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid,
  event    text not null,
  metadata jsonb,
  created_at timestamptz default now()
);
alter table events enable row level security;
create policy "Users can read their events"
  on events for select using (auth.uid() = user_id);

-- telemetry_errors table (error logs)
create table telemetry_errors (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid,
  code     text not null,
  message  text not null,
  metadata jsonb,
  created_at timestamptz default now()
);
alter table telemetry_errors enable row level security;
create policy "Users can read their errors"
  on telemetry_errors for select using (auth.uid() = user_id);
```

**Verification**: Query each table in Supabase dashboard to confirm existence.

### Step 3: Verify Signed-In Sync Flow

1. Sign in to the app
2. Create a new prompt (Home tab)
3. Check Supabase `prompts` table — new row should appear with `user_id` matching your auth user
4. Modify the prompt locally (favorite toggle)
5. Verify `last_modified` and `isSynced` fields update correctly
6. Force refresh (pull-to-refresh on History tab)
7. Confirm remote changes merge back to local JSON

### Step 4: Test Offline Resilience

1. Create a prompt
2. Put app in airplane mode
3. Modify the prompt (favorite, rename, delete)
4. Disable airplane mode
5. Force refresh
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
| Supabase anon key wrong | ⏳ Awaiting fix | Replace in Info.plist |
| Supabase tables missing | ⏳ Awaiting creation | Run SQL setup scripts |
| Railway user plan fetch fails | ⏳ Awaiting schema alignment | Verify endpoint in AuthManager |
| Metal Orb not rolling out | ✅ Ready | Enable feature flag |
| IAP products not available | ⏳ Awaiting App Store setup | Create products in App Store Connect |

---

## Version History

- **v1.0-1.8**: Early phases (SwiftData era, CloudKit attempts)
- **v1.8** (2026-03-18): Phase 2 Supabase SDK integration, SwiftData removed, JSON + sync functional
- **v1.9** (2026-03-18 cleanup): Documentation cleaned, roadmap clarified, post-Phase-2 state documented

---

## For the Next AI Agent

When you pick up this project:

1. **Read this file first** — It's the ground truth
2. **Check HANDOFF.md** — Deep technical reference (much longer)
3. **Check AGENTS.md** — Agent-focused rules and patterns
4. **Verify Supabase config** — Is the anon key correct? Are tables created?
5. **Run a smoke test** — Can you sign in? Does JSON persist?
6. **Then start Phase 3** — Generation, metering, IAP

Good luck building Orion Orb! 🌌
