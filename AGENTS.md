# Prompt28 (Orion Orb) — AI Agent Guide (v3.3)

**Last updated: 2026-03-19 | Version v3.3 — THIS IS THE SINGLE SOURCE OF TRUTH**

> All other project-status/handoff docs (`HANDOFF.md`, `CURRENT_STATE_CLEAN_ROADMAP.md`, `CODEX_HANDOFF_v3_2.md`) are deprecated. Read only this file.

This document is the single source of truth for AI coding agents working on the Prompt28 iOS project (marketed as "Orion Orb"). Read this before touching anything.

---

## Current Status

- **Version:** v3.2
- **Platform:** iOS 17.0+ SwiftUI app (Swift 5.9+, Observation framework)
- **Backend:** Supabase only — Railway is fully retired
- **Generation:** Supabase Edge Function (`generate`) — Anthropic Claude primary, OpenAI fallback
- **Auth:** Supabase Auth (email/password, Google Sign-In, Apple Sign-In)
- **Plan tier:** Read from `user_metadata.plan` (written by StoreManager after IAP), not Railway
- **Metering:** Server-side (Edge Function counts `prompts` rows) + client-side (`UsageTracker` Keychain)
- **Trending:** Supabase `trending_prompts` table with Realtime subscriptions; bundled JSON is the offline seed
- **Feedback:** RLHF thumbs up/down → Supabase `prompt_feedback` table

---

## Project Identity

- **App name:** Orion Orb
- **Project name:** Prompt28
- **Bundle ID:** `com.prompt28.prompt28`
- **Supabase project:** `jzwerkqoczhtkyhigigf`
- **Edge Functions deployed:** `generate`, `delete-account`

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI with Observation framework (`@Observable`) |
| Persistence | Codable JSON (`Application Support/OrionOrb/history.json`) + Supabase two-way sync |
| Pending deletes | `Application Support/OrionOrb/history_pending_deletes.json` |
| Authentication | Supabase Auth — JWT in Keychain; Google Sign-In, Apple Sign-In, email/password |
| Database | Supabase PostgreSQL (`prompts`, `events`, `telemetry_errors`, `prompt_feedback`, `trending_prompts`) |
| Generation | Supabase Edge Function `generate` (Anthropic Claude primary, OpenAI fallback) |
| Legacy API | `APIClient` → `https://promptme-app-production.up.railway.app` — **admin panel only**; all user-facing Railway calls removed |
| Networking | URLSession async/await (`APIClient`) |
| Audio | `SFSpeechRecognizer` + `AVFoundation` |
| In-App Purchases | StoreKit 2 (`StoreManager`) |
| Metal graphics | `MetalOrbView` + `Orb.metal` — behind `is_metal_orb_enabled` flag |
| Dependencies | `supabase-swift` 2.41.1, `GoogleSignIn` 9.1.0 (SPM) |

---

## Project Structure

```
PromptMeNative_Blueprint/          # Source root
├── App/
│   ├── AppEnvironment.swift       # Dependency container (@Observable @MainActor)
│   ├── AppUI.swift                # ExperimentFlags, design tokens, spacing constants
│   ├── OrionMainContainer.swift
│   ├── PremiumTabScreen.swift
│   ├── RootView.swift             # Root state machine + PromptTheme + PromptPremiumBackground
│   └── Routing/AppRouter.swift
├── Components/
│   └── Glassmorphism.swift
├── Core/
│   ├── Auth/                      # AuthManager (Supabase-only), KeychainService, SupabaseConfig
│   ├── Networking/                # APIClient (admin+config only), APIEndpoint, NetworkError
│   ├── Storage/                   # HistoryStore (JSON+Supabase), PreferencesStore
│   ├── Store/                     # StoreManager (StoreKit 2), UsageTracker (Keychain)
│   ├── Audio/                     # OrbEngine, SpeechRecognizerService
│   ├── Notifications/             # NotificationService
│   └── Utils/                     # AnalyticsService, TelemetryService, HapticService
├── Features/
│   ├── Admin/                     # Dev-only admin panel (admin key required)
│   ├── Auth/                      # AuthFlowView, AuthViewModel
│   ├── History/                   # HistoryView, FavoritesView, HistoryViewModel
│   ├── Home/
│   │   ├── Views/                 # HomeView, OrbView, MetalOrbView, ResultView, TypePromptView, ShareCardView
│   │   └── ViewModels/            # GenerateViewModel, HomeViewModel
│   ├── Onboarding/
│   ├── Privacy/
│   ├── Settings/                  # SettingsView, UpgradeView, SettingsViewModel
│   └── Trending/                  # TrendingView, PromptDetailView, TrendingViewModel
├── Models/
│   ├── API/                       # GenerateModels, PromptCatalogModels, SettingsModels, AuthModels, User
│   └── Local/                     # PromptHistoryItem, AppPreferences
├── Resources/
│   ├── trending_prompts.json      # Bundled catalog (offline seed for TrendingView)
│   └── PrivacyInfo.xcprivacy
└── OrionOrbApp.swift              # @main entry point

supabase/
├── functions/
│   ├── generate/index.ts          # Generation Edge Function (deployed)
│   └── delete-account/index.ts   # Account deletion Edge Function (deployed)
└── migrations/
    ├── 20240101000000_core_tables.sql       # prompts, events, telemetry_errors
    ├── 20240601000000_prompt_feedback.sql
    └── 20240602000000_trending_prompts.sql
```

---

## Architecture

### AppEnvironment (Dependency Container)

```swift
@Observable @MainActor final class AppEnvironment {
    let supabase: SupabaseClient        // Supabase auth, database, Edge Functions, Realtime
    let apiClient: APIClient            // Railway admin+config only (NOT for generation or auth)
    let keychain: KeychainService
    let authManager: AuthManager        // Supabase Auth — no Railway dependency
    let historyStore: HistoryStore      // JSON + Supabase two-way sync
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager      // StoreKit 2; writes plan to Supabase user_metadata on purchase
    let usageTracker: UsageTracker      // Keychain-backed monthly counter, synced from Edge Function
    let telemetryService: TelemetryService
    let speechRecognizerFactory: SpeechRecognizerFactoryProtocol
    let orbEngineFactory: OrbEngineFactoryProtocol
}
```

**Rule:** Never instantiate stores or view models directly in views. Always use environment injection or pass dependencies through view initialisers.

### State Machine (RootView)

```
App launch
  └── hasAcceptedPrivacy = false  →  PrivacyConsentView   ← NEVER move this gate
  └── hasAcceptedPrivacy = true
        └── didBootstrap = false  →  spinner
        └── bootstrap() completes →  didBootstrap = true
              ├── !isAuthenticated  →  AuthFlowView
              ├── !hasSeenOnboarding  →  OnboardingView
              └── ready
                    ├── compact   →  mainTabs (TabView)
                    └── regular   →  iPadSidebar (NavigationSplitView)
```

### Generation Flow

1. `GenerateViewModel.generate()` / `generateFromOrb()` / `refine()`
2. Client-side freemium gate via `UsageTracker.canGenerate(for:)` — prefers `StoreManager.activePlan`
3. `invokeEdgeFunction(supabase:functionName:request:plan:)` → `supabase.functions.invoke("generate")`
4. Edge Function applies server-side metering, intent classification, temporal context
5. Response decoded into `EdgeGenerateResponse` → `GenerateResponse`
6. `UsageTracker.sync(promptsRemaining:plan:)` realigns local counter with server truth
7. History item saved, analytics fired

`SUPABASE_GENERATE_FUNCTION` in `Info.plist` must be `"generate"`. Empty/missing → clear config error at generate time (no silent fallback).

### Plan Tier Source of Truth

| Gate | Source |
|------|--------|
| Client UI gate (paywall) | `StoreManager.activePlan` (StoreKit receipt) |
| In-memory user plan | `user_metadata.plan` in Supabase Auth (set by `StoreManager.syncPlanToSupabase()`) |
| Server-side metering | `user_metadata.plan` read by Edge Function |
| Dev plan activation | `SettingsViewModel.updatePlan()` → `supabase.auth.update(user: UserAttributes(data: ["plan": ...]))` |

### APIClient — Admin Only

`APIClient` and its `APIClientProtocol` are **not** used for generation, auth, or user data. Remaining live calls:

| Method | Endpoint | Used by |
|--------|----------|---------|
| `settings()` | `/api/settings` | `HomeViewModel`, `SettingsViewModel` (cosmetic, silently ignored on failure) |
| `promptsTrending()` | `/prompts_trending.json` | `TrendingViewModel` (fallback only — Supabase table is tried first) |
| `adminVerify/Settings/Prompts/UpdateSettings/UpdatePrompts` | `/api/admin/*` | `AdminViewModel` (dev panel, requires admin key) |

---

## Key Models

### User

```swift
struct User: Decodable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String
    let provider: String
    let plan: PlanType      // derived from user_metadata.plan; defaults to .starter
    let prompts_used: Int
    let prompts_remaining: Int?
    let period_end: String
}
```

### PlanType

```swift
enum PlanType: String, Codable, CaseIterable {
    case starter    // Free: 10 generations/month
    case pro        // Paid
    case unlimited  // Paid
    case dev        // Developer/admin (set via dev panel)
}
```

### GenerateResponse / EdgeGenerateResponse

- `GenerateResponse` — app-internal model (stored in history, displayed in ResultView)
- `EdgeGenerateResponse` — private DTO in `GenerateViewModel.swift` for decoding Edge Function response
- Both include optional `intent_category: String?`, `latency_ms: Int?`, and `web_context_used: Bool?`

### PromptCatalog → PromptCategory → PromptItem

Used by `TrendingViewModel`. Rows from `trending_prompts` Supabase table are mapped into this hierarchy (grouped by `category`, ordered by `use_count`).

---

## Supabase Tables

| Table | Purpose |
|-------|---------|
| `prompts` | User prompt history (synced from HistoryStore) |
| `events` | Analytics events |
| `telemetry_errors` | Error telemetry |
| `prompt_feedback` | Thumbs up/down RLHF data |
| `trending_prompts` | Curated trending prompts (Realtime-enabled) |

RLS is enabled on all tables. See `supabase/migrations/` for schemas.

---

## Design System

All design tokens live in two files:

### PromptTheme (`RootView.swift`)

```swift
enum PromptTheme {
    static let backgroundBase = Color(hex: "#02060D")
    static let deepShadow     = Color(hex: "#050A16")
    static let plum           = Color(hex: "#07101E")
    static let mutedViolet    = Color(hex: "#5D628A")
    static let softLilac      = Color(hex: "#CFD7FF")
    static let paleLilacWhite = Color(hex: "#F2F5FF")
    static let glassFill      = Color(red: 0.15, green: 0.17, blue: 0.22).opacity(0.72)
    static let glassStroke    = Color.white.opacity(0.14)
}
```

### AppUI / AppSpacing / AppHeights / AppRadii (`AppUI.swift`)

```swift
AppSpacing.screenHorizontal = 18
AppSpacing.section          = 24
AppSpacing.element          = 12
AppSpacing.bottomContentClearance = 88

AppHeights.primaryButton    = 56
AppHeights.tabBarClearance  = 102

AppRadii.card    = 24
AppRadii.control = 22
AppRadii.field   = 18
```

### Glass Cards

```swift
// Background only
.background { PromptTheme.glassCard(cornerRadius: AppRadii.card) }
// Background + shadow
.appGlassCard(radius: AppRadii.card)
```

**Never** create a new glass card implementation. Always use `PromptTheme.glassCard(cornerRadius:)`.

### ExperimentFlags (`AppUI.swift`)

```swift
enum ExperimentFlags {
    enum RootBackground { static let home = "use_root_background_home" }
    enum Orb            { static let metalOrb = "is_metal_orb_enabled" }
}
```

Feature flags are `@AppStorage` bools. Toggle in `AdminDashboardView` (dev only).

---

## Build Commands

```bash
# Build
xcodebuild -project Prompt28.xcodeproj -scheme OrionOrb \
  -destination "platform=iOS Simulator,name=iPhone 16" build

# Unit tests
xcodebuild test -project Prompt28.xcodeproj -scheme OrionOrb \
  -destination "id=06B488AD-877C-4EC1-A472-E2053BD31DB9" \
  -only-testing:OrionOrbTests

# Clean
xcodebuild clean -project Prompt28.xcodeproj -scheme OrionOrb
```

**Simulator:** Always use `Prompt28-iPhone17` / UDID `06B488AD-877C-4EC1-A472-E2053BD31DB9`.

---

## Navigation Rules

**CRITICAL:** Every view with a `NavigationStack` must place `PromptPremiumBackground().ignoresSafeArea()` as the **first** item in its top-level `ZStack`. Views with NavigationStack that own their background: `HomeView`, `HistoryView`, `FavoritesView`, `TrendingView`.

---

## Testing

Swift Testing framework (`import Testing`) for unit tests, XCTest for UI tests.

Key test suites in `OrionOrbTests/`:
- `UsageTrackerTests` — freemium counter
- `HistoryStoreTests` — sync logic, pending deletes, owner isolation
- `AppPreferencesTests`, `PromptModeTests`, `PlanTypeTests`, `SpeechErrorClassificationTests`

`HistoryStore` has deterministic test seams (inject session provider, disable auth listener, disable lifecycle observation). Physical device is the primary validation path; hosted simulator execution is secondary.

---

## Manual Setup Steps (One-time, done on Mac)

These are not done automatically. Each one must be completed manually:

1. **Redeploy Edge Function** after any `supabase/functions/generate/index.ts` change:
   ```bash
   cd ~/Desktop/Prompt28
   supabase functions deploy generate --no-verify-jwt
   ```
2. **Run SQL migrations** in Supabase Dashboard → SQL Editor (run in order):
   - `supabase/migrations/20240101000000_core_tables.sql` — `prompts`, `events`, `telemetry_errors`
   - `supabase/migrations/20240601000000_prompt_feedback.sql`
   - `supabase/migrations/20240602000000_trending_prompts.sql`
3. **(Optional) Brave Search web-context enrichment:** Set `BRAVE_API_KEY` secret in Supabase Dashboard → Settings → Edge Functions → Secrets. Free tier: 2 000 req/mo at api.search.brave.com. Generation works without it — web grounding is opt-in.
4. **Apple Sign In:** Apple Developer Portal → Services ID + `.p8` key → Supabase Dashboard → Authentication → Providers → Apple
5. **App Store Connect IAP:** Create 4 auto-renewable subscriptions matching `StoreProductID` enum constants in `StoreManager.swift`

---

## Critical Rules

### SAFE — Always Allowed

- Modifying text, font sizes, colors, padding, spacing
- Adding `@State` / `@AppStorage` variables to views
- Modifying ViewModel logic
- Adding new analytics events to `AnalyticsEvent` enum
- Adding new Supabase migrations

### CAUTION — Follow Rules

- Adding `PromptPremiumBackground()`: only if view has its own `NavigationStack` and doesn't already have one. First child of outermost `ZStack`.
- Modifying `PromptTheme` tokens: grep all usages before changing
- Modifying `glassCard(cornerRadius:)`: check all tabs after
- Changing `AppEnvironment.init()` ordering: services have init dependencies

### NEVER DO

1. Remove `PromptPremiumBackground()` from views with NavigationStack
2. Remove window background color setup in `OrionOrbApp.init()` (prevents black flash)
3. Add NavigationStack inside a view already inside another NavigationStack
4. Change `.toolbar(.hidden, for: .navigationBar)` on main tab screens
5. Create a new glass card implementation
6. Remove `Color.clear.frame(height: AppHeights.tabBarClearance)` from scroll views
7. Move the `PrivacyConsentView` gate below bootstrap/auth checks in `RootView`
8. Touch `HistoryStore.swift` without understanding the full sync/test-seam architecture
9. Change `supabase/functions/` without redeploying
10. Introduce any Railway dependency — Railway is retired

---

## Version & Completion Status

**v3.3 (2026-03-19) — current**

| Feature | Code | Live |
|---------|------|------|
| Supabase Auth (email, Google, Apple) | ✅ | ✅ |
| Edge Function `generate` (Anthropic primary, OpenAI fallback) | ✅ | ✅ needs redeploy |
| Edge Function `delete-account` | ✅ | ✅ |
| Server-side metering (starter plan 10/mo) | ✅ | ✅ needs redeploy |
| Intent classifier + temporal context | ✅ | ✅ needs redeploy |
| Brave Search web-context enrichment | ✅ | ⏳ needs redeploy + `BRAVE_API_KEY` |
| StoreKit 2 IAP | ✅ | ⏳ App Store Connect products not created |
| Apple Sign In | ✅ | ⏳ developer portal config needed |
| Metal Orb GPU renderer | ✅ | ⏳ behind `is_metal_orb_enabled` flag (off by default) |
| Supabase Realtime Trending | ✅ | ✅ needs `trending_prompts` migration run |
| SQL migrations on Supabase | ✅ files exist | ⏳ must be run manually |
| TestFlight | — | ⏳ pending |

---

## Security

- JWT tokens in Keychain (never UserDefaults)
- Admin panel requires `devAdminKey` stored only in memory
- No hardcoded API keys in source
- Privacy manifest at `PrivacyInfo.xcprivacy` covers all data collection
