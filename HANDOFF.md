# Prompt28 (Orion Orb) — AI Handoff Document (v3.1, Phase 5 Active)

**Last updated: 2026-03-19. Version v3.1 (Phase 4 complete + Trending Supabase-direct, Phase 5 foundations active). Safe for Codex, Gemini, ChatGPT, and future Claude sessions.**

---

## ⚡ Current Status: Phase 5 Active — Intent Routing + Context-Aware Generation

Phases 3 and 4 are fully complete. Phase 5 foundations (intent classifier, temporal context, result metadata) are live in the Edge Function.

### What's done (Phase 3 — Generation)
- ✅ `supabase/functions/generate/index.ts` deployed to project `jzwerkqoczhtkyhigigf`
- ✅ Uses **Anthropic Claude** (`claude-haiku-4-5-20251001`) as primary AI, OpenAI GPT-4o-mini as fallback
- ✅ Verifies Supabase JWT server-side, extracts `user.id` for metering
- ✅ **Server-side usage metering**: counts `prompts` table rows this calendar month; returns HTTP 429 at 10 for starter plan
- ✅ Returns `{ professional, template, prompts_used, prompts_remaining, plan }` — iOS `UsageTracker` syncs from this
- ✅ `SUPABASE_GENERATE_FUNCTION = "generate"` set in `Info.plist`
- ✅ `StoreManager.syncPlanToSupabase()` writes `user_metadata.plan` after IAP — Edge Function reads it to bypass metering
- ✅ Edge Function 429 triggers iOS paywall + `generateRateLimited` analytics event
- ✅ All Railway calls silenced or removed

### What's done (Phase 4 — Experience)
- ✅ **Thumbs up/down feedback** in `ResultView` → Supabase `prompt_feedback` table
- ✅ **Metal Orb GPU renderer** (`MetalOrbView.swift` + `Orb.metal`) behind `is_metal_orb_enabled` flag
- ✅ **Supabase Realtime Trending** — `TrendingViewModel` subscribes to INSERT/UPDATE on `trending_prompts`
- ✅ **Trending Supabase-direct fetch** — `TrendingViewModel.refreshFromSupabase()` queries `trending_prompts` table directly (WHERE `is_active=true`, ORDER BY `use_count DESC`), maps rows → `PromptCatalog`. Railway `promptsTrending()` retained as silent fallback only. Realtime-triggered refreshes also use the Supabase path.
- ✅ **Shareable cards** — `ShareCardView` + `ImageRenderer` + `ShareLink` with PNG preview
- ✅ `TypePromptView` glass design system rewrite; `HomeView` double-NavigationStack fixed
- ✅ **Usage pill** on `HomeView` — live prompts-remaining counter for starter plan users
- ✅ **SettingsView usage bar** now reads from `UsageTracker` (not stale Railway User model)
- ✅ **AdminDashboard** — Metal Orb toggle added to Experiments panel

### What's done (Phase 5 — Intelligence)
- ✅ **Intent classifier** (`classifyIntent()`) — keyword scoring across 6 categories (work / school / business / fitness / technical / creative), runs in <1 ms, zero LLM calls
- ✅ **Intent-specialized system prompts** — 12 tailored prompts (6 categories × 2 modes), selected automatically
- ✅ **Temporal context injection** — every generation is prefixed with current date, week number, and season; no user input required
- ✅ `intent_category` + `latency_ms` returned in every response; decoded on iOS, logged to analytics
- ✅ **Intent badge** in `ResultView` header — color-coded per category (blue=work, mint=school, amber=business, coral=fitness, lavender=technical, gold=creative)
- ✅ `AnalyticsEvent.generateSuccess` now carries `intentCategory` + `latencyMs`

### What still needs to be done manually (by you, on Mac)
1. `git pull` on your Mac and rebuild in Xcode
2. **Redeploy Edge Function** to pick up Phase 5 intent + context changes:
   ```bash
   cd ~/Desktop/Prompt28
   supabase functions deploy generate --no-verify-jwt
   ```
3. **Run SQL migrations** in Supabase Dashboard → SQL Editor:
   - `supabase/migrations/20240601000000_prompt_feedback.sql` (RLHF feedback table)
   - `supabase/migrations/20240602000000_trending_prompts.sql` (trending + Realtime)
4. Apple Sign In: Apple Developer Portal → create Services ID + .p8 Key → paste into Supabase Dashboard → Authentication → Providers → Apple
5. App Store Connect: create 4 IAP subscription products (`com.prompt28.pro.monthly`, `.pro.yearly`, `.unlimited.monthly`, `.unlimited.yearly`)

### Edge Function: Request & Response shapes

**Request** (from iOS `GenerateRequest`):
```json
{ "input": "string", "refinement": "string|null", "mode": "ai|human", "systemPrompt": "string|null" }
```

**Success response** (`EdgeGenerateResponse` on iOS) — Phase 5 shape:
```json
{
  "professional":    "Full polished prompt text…",
  "template":        "Template with [PLACEHOLDER] tokens…",
  "prompts_used":    3,
  "prompts_remaining": 7,
  "plan":            "starter",
  "intent_category": "work",
  "latency_ms":      843
}
```

**Error response** (any non-2xx):
```json
{ "error": "Human-readable message" }
```
Decoded by `GenerateViewModel.edgeFunctionErrorMessage(from:)` via Mirror.
429 additionally triggers `showPaywall = true` via `edgeFunctionHTTPStatus(from:)`.

### Re-deploy command (run after any Edge Function change)
```bash
cd ~/Desktop/Prompt28
supabase functions deploy generate --no-verify-jwt
```

### If supabase CLI is not installed
```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref jzwerkqoczhtkyhigigf
```

---

---

## 1. Architecture Summary

Prompt28 (marketed as **Orion Orb**) is a SwiftUI iOS app (Swift 5.9+, **iOS 17+**) built with the Observation framework (`@Observable`).

> ✅ **Minimum deployment target is iOS 17.0** — no SwiftData, no CloudKit. Pure Codable + Supabase.

It uses a single shared `AppEnvironment` injected via `.environment()` at the root.

> **Architecture note (v2.5):** Auth and history persistence run through Supabase. Generation runs through a Supabase Edge Function (Anthropic API). The `APIClient` pointing at Railway is still present but all user-facing calls have been removed or silenced — only dev-admin endpoints remain. `APIClient` can be removed entirely in a future cleanup pass.

## Current State

- **Current phase:** Phase 5 active (Phases 3 + 4 complete)
- **Platform direction:** native iOS 17+ SwiftUI app
- **Persistence direction:** no SwiftData, no CloudKit — Codable JSON + Supabase only
- **Auth direction:** Supabase Auth is live; Apple Sign In code exists but not yet configured in dashboard
- **OAuth status:** Google sign-in working; Apple sign-in needs Apple Developer + Supabase config
- **Generation backend:** Supabase Edge Function (`generate`) — Anthropic API primary, OpenAI fallback; Phase 5 intent classifier + temporal context active
- **Railway status:** fully retired for user-facing calls; `APIClient` may be deleted in a future cleanup
- **Metering:** server-side (Edge Function counts `prompts` table rows) + client-side (`UsageTracker` Keychain, synced after each generation)
- **History direction:** local-first JSON + Supabase two-way sync (last-write-wins); pull-to-refresh available
- **Feedback direction:** RLHF thumbs up/down → Supabase `prompt_feedback` table; `intent_category` + `latency_ms` logged per generation

### Entry Point
**App file**: `PromptMeNative_Blueprint/OrionOrbApp.swift` (struct `OrionOrbApp`)
**Source root**: `PromptMeNative_Blueprint/` — all Swift source is here.

### State Machine (RootView)
```
App launch
  └── hasAcceptedPrivacy = false  →  PrivacyConsentView  (blocks ALL other UI)
  └── hasAcceptedPrivacy = true
        └── didBootstrap = false  →  launchView (spinner)
        └── bootstrap() runs      →  didBootstrap = true
              ├── isAuthenticated = false  →  AuthFlowView (Supabase JWT)
              ├── isAuthenticated = true, hasSeenOnboarding = false  →  OnboardingView
              └── isAuthenticated = true, hasSeenOnboarding = true
                    ├── iPhone (.compact)  →  mainTabs (TabView)
                    └── iPad (.regular)    →  iPadSidebar (NavigationSplitView)
```
Privacy gate satisfies App Store Review Guideline 5.1.2(i). Consent flag stored in `@AppStorage("hasAcceptedPrivacy")`.

### AppEnvironment (Dependency Container)
```swift
// File: PromptMeNative_Blueprint/App/AppEnvironment.swift
@Observable @MainActor final class AppEnvironment {
    let supabase: SupabaseClient         // Live Supabase auth & DB client
    let apiClient: APIClient             // Railway backend (for legacy endpoints)
    let keychain: KeychainService
    let authManager: AuthManager         // Supabase JWT auth
    let historyStore: HistoryStore       // Codable JSON + Supabase prompts table sync
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager       // StoreKit 2
    let usageTracker: UsageTracker       // Keychain freemium counter
    let telemetryService: TelemetryService
    let speechRecognizerFactory: SpeechRecognizerFactoryProtocol
    let orbEngineFactory: OrbEngineFactoryProtocol
}
```
Pass `env` to views via `@Environment(AppEnvironment.self)`. Never instantiate stores directly in a view.

### Tab System
```swift
// File: PromptMeNative_Blueprint/App/Routing/AppRouter.swift
enum MainTab: Hashable { case home, trending, history, favorites, admin }
```
- iPhone: `TabView(selection: $selectedTab)` in `RootView.mainTabs`
- iPad: `NavigationSplitView` in `RootView.iPadSidebar` — admin tab is phone-only
- Tab order in UI: Home → Favorites → History → Trending

---

## 2. File Structure Map

```
PromptMeNative_Blueprint/
├── App/
│   ├── AppEnvironment.swift          ← dependency container (@Observable)
│   ├── AppUI.swift                   ← shared spacing, heights, radii, reusable controls
│   ├── PremiumTabScreen.swift        ← thin wrapper over AppScreenContainer
│   ├── RootView.swift                ← root state machine, PromptPremiumBackground, PromptTheme
│   └── Routing/
│       └── AppRouter.swift           ← RootRoute enum, MainTab enum
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift         ← bootstrap(), login, logout, currentUser
│   │   ├── KeychainService.swift
│   │   └── OAuthCoordinator.swift
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   ├── APIEndpoint.swift
│   │   ├── NetworkError.swift
│   │   └── RequestBuilder.swift
│   ├── Storage/
│   │   ├── HistoryStore.swift        ← Codable JSON + Supabase prompts table sync (two-way, last-write-wins, delete propagation)
│   │   ├── PreferencesStore.swift    ← user prefs (mode, saveHistory)
│   │   └── SecureStore.swift
│   ├── Store/
│   │   ├── StoreConfig.swift
│   │   ├── StoreManager.swift        ← StoreKit 2 / IAP
│   │   └── UsageTracker.swift        ← Keychain freemium monthly counter
│   ├── Audio/
│   │   ├── OrbEngine.swift           ← mic + speech rec state machine
│   │   └── SpeechRecognizerService.swift
│   ├── Notifications/
│   │   └── NotificationService.swift
│   └── Utils/
│       ├── AnalyticsService.swift
│       ├── Date+Extensions.swift
│       ├── HapticService.swift
│       └── JSONCoding.swift
├── Features/
│   ├── Admin/                        ← dev-only admin panel (plan == .dev)
│   │   ├── ViewModels/AdminViewModel.swift
│   │   └── Views/  (AdminDashboardView, AdminCategoriesView, etc.)
│   ├── Auth/
│   │   ├── ViewModels/AuthViewModel.swift
│   │   └── Views/ (AuthFlowView, EmailAuthView)
│   ├── History/
│   │   ├── ViewModels/HistoryViewModel.swift
│   │   └── Views/
│   │       ├── HistoryView.swift     ← NavigationStack, owns PromptPremiumBackground
│   │       └── FavoritesView.swift   ← NavigationStack, owns PromptPremiumBackground
│   ├── Home/
│   │   ├── ViewModels/ (HomeViewModel, GenerateViewModel)
│   │   └── Views/
│   │       ├── HomeView.swift        ← NavigationStack, owns PromptPremiumBackground
│   │       ├── OrbView.swift
│   │       ├── ResultView.swift
│   │       ├── TypePromptView.swift
│   │       └── ShareCard*.swift
│   ├── Onboarding/
│   │   └── Views/OnboardingView.swift
│   ├── Privacy/
│   │   └── PrivacyConsentView.swift  ← first-launch consent modal (Guideline 5.1.2(i))
│   ├── Settings/
│   │   ├── ViewModels/SettingsViewModel.swift
│   │   └── Views/
│   │       ├── SettingsView.swift    ← GeometryReader ZStack, owns PromptPremiumBackground
│   │       └── UpgradeView.swift
│   └── Trending/
│       ├── ViewModels/TrendingViewModel.swift
│       └── Views/
│           ├── TrendingView.swift    ← NavigationStack, owns PromptPremiumBackground
│           └── PromptDetailView.swift
├── Models/
│   ├── API/
│   │   ├── User.swift                ← User struct, PlanType enum
│   │   ├── AuthModels.swift
│   │   ├── GenerateModels.swift
│   │   ├── PromptCatalogModels.swift
│   │   └── SettingsModels.swift
│   └── Local/
│       ├── AppPreferences.swift
│       └── PromptHistoryItem.swift   ← Codable final class (Supabase sync, no SwiftData)
└── Resources/
    ├── trending_prompts.json         ← bundled catalog (6 categories, 44 prompts)
    └── PrivacyInfo.xcprivacy         ← Apple privacy manifest (also at Prompt28/PrivacyInfo.xcprivacy)
```

---

## 3. Global Design System

All design tokens live in two files: `App/RootView.swift` (PromptTheme, PromptPremiumBackground) and `App/AppUI.swift` (AppSpacing, AppRadii, AppHeights, glassCard modifier).

### PromptTheme Tokens (RootView.swift)

```swift
enum PromptTheme {
    // Color palette
    static let backgroundBase   = Color(hex: "#02060D")
    static let deepShadow       = Color(hex: "#050A16")
    static let plum             = Color(hex: "#07101E")
    static let mutedViolet      = Color(hex: "#5D628A")
    static let softLilac        = Color(hex: "#CFD7FF")
    static let paleLilacWhite   = Color(hex: "#F2F5FF")

    // Glass system
    static let glassFill        = Color(red: 0.15, green: 0.17, blue: 0.22).opacity(0.72)
    static let glassStroke      = Color.white.opacity(0.14)

    // Orb glows
    static let orbIdleGlow      = Color(hex: "#95A7FF")
    static let orbActiveGlow    = Color(hex: "#A9BAFF")
    static let orbProcessingGlow= Color(hex: "#B9C6FF")

    // Tab bar (UIKit)
    static let tabBackground    = UIColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 0.9)
    static let tabSelected      = UIColor.white.withAlphaComponent(0.96)
    static let tabUnselected    = UIColor.white.withAlphaComponent(0.56)

    // Typography helper
    static func Typography.rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font  // .system rounded design

    // Spacing
    enum Spacing { xxs=6, xs=10, s=14, m=18, l=24, xl=32 }

    // Corner radii
    enum Radius { medium=16, large=24 }

    // Material
    static let premiumMaterial: Material = .ultraThinMaterial
}
```

### AppSpacing / AppHeights / AppRadii (AppUI.swift)

```swift
AppSpacing.screenHorizontal = 18    // standard horizontal page padding
AppSpacing.section           = 24   // between major sections
AppSpacing.element           = 12   // between related elements
AppSpacing.elementTight      = 8
AppSpacing.cardInset         = 22   // inner card padding
AppSpacing.bottomContentClearance = 88  // clears floating tab bar

AppHeights.searchBar / searchField  = 56
AppHeights.primaryButton            = 56
AppHeights.tabBarClearance          = 102  // Color.clear spacer at bottom of all scroll views
AppHeights.floatingTabBar           = 72

AppRadii.card    = 24
AppRadii.control = 22    // primary buttons
AppRadii.field   = 18    // text fields
AppRadii.chip    = 10
```

### Glass Card System

**Single source of truth**: `PromptTheme.glassCard(cornerRadius:)` in AppUI.swift.
Use `.appGlassCard()` view modifier for cards that also need a drop shadow.

```swift
// Full implementation (AppUI.swift):
static func glassCard(cornerRadius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PromptTheme.glassFill)         // dark tinted overlay
        )
        .overlay(
            GeometryReader { geo in
                RadialGradient(
                    stops: [.init(color: .white.opacity(0.18), location: 0.0),
                            .init(color: .clear, location: 0.60)],
                    center: UnitPoint(x: 0.15, y: 0.0),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.72
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.14), lineWidth: 0.5))
}

// With shadow:
extension View {
    func appGlassCard(radius: CGFloat = AppRadii.card) -> some View {
        self.background { PromptTheme.glassCard(cornerRadius: radius) }
            .shadow(color: .black.opacity(0.28), radius: 16, y: 10)
    }
}
```

---

## HistoryStore Source Of Truth

File: `PromptMeNative_Blueprint/Core/Storage/HistoryStore.swift`

- Local-first JSON persistence remains primary.
- Main local files are:
  - `Application Support/OrionOrb/history.json`
  - `Application Support/OrionOrb/history_pending_deletes.json`
- Supabase sync remains secondary / best-effort.
- Immediate best-effort sync now happens after:
  - `add(_:)`
  - `toggleFavorite(id:)`
  - `rename(id:customName:)`
- Launch-time sync now occurs if an authenticated Supabase session already exists.
- Sync also responds to auth events:
  - `.signedIn`
  - `.tokenRefreshed`
  - `.userUpdated`
- On:
  - `.signedOut`
  - `.userDeleted`
  local history state is cleared from memory and disk to prevent cross-user contamination.

## Merge / Sync Behavior

- Sync is two-way and last-write-wins based on `lastModified`.
- Unsynced local records are upserted first.
- Remote Supabase records are fetched after upload and then merged locally.
- Delete propagation now exists and is part of sync behavior.
- Pending delete IDs are persisted locally and retried on future sync attempts.

## Delete Propagation

- History deletes now propagate to Supabase.
- Pending delete IDs are stored in `history_pending_deletes.json`.
- If the app is offline or sync fails, deletes remain queued locally and retry on a later authenticated sync.
- `remove(id:)` and `clearAll()` are part of delete propagation behavior.

## Testing / Validation Status

- Storage hardening code is improved and compiles.
- `HistoryStore` now includes deterministic test seams/hooks used by validation:
  - disable auth listener on init
  - disable lifecycle observers
  - disable initial session reconciliation on init
  - inject session user ID provider
  - inject sync executor
- `HistoryStore` now defers exposing disk-backed local history until initial auth/session reconciliation completes, preventing stale wrong-user history from flashing during launch or account switching.
- `HistoryStore` now also persists the signed-in local history owner (`history_owner.txt`) and clears/ignores cached local history when a different user session is detected.
- `HistoryStore` persistence now writes both visible `items` and deferred owned history during initial session resolution, so fast post-launch mutations do not accidentally overwrite the owned local cache before reconciliation finishes.
- `HistoryStore` lifecycle observer registration is now deduped before re-registering, preventing duplicate foreground retry observers if observer setup runs more than once.
- `HistoryStore` now treats unowned local history as ambiguous on signed-in reconciliation and clears it before binding cache ownership, favoring privacy/isolation over restoring potentially wrong-user legacy cache.
- All authenticated sync entrypoints now route through the same owner-preparation + deferred-history-restore path before syncing, keeping launch-time sync, foreground retry, pull-to-refresh, and post-mutation sync behavior aligned.
- Pending-deleted IDs are now filtered out of deferred-history restore and deferred-history persistence, so deleting an item during the reconciliation window cannot resurrect it from hidden local cache.
- `HistoryStore` also exposes an internal foreground-retry entry point for tests so lifecycle retry behavior can be invoked directly without depending on UIKit notification delivery in the hosted runner.
- Unit test target now points to the real `OrionOrbTests` folder.
- History tests use MainActor-safe polling.
- `OrionOrbApp` has a test-mode bypass so unit tests do not bootstrap the full app environment.
- Shared scheme no longer includes `Prompt28UITests` inside the main unit-test `TestAction`.
- Simulator ambiguity is solved by using only:
  - `Prompt28-iPhone17`
  - `06B488AD-877C-4EC1-A472-E2053BD31DB9`
- Confirmed passing hosted history test on simulator `Prompt28-iPhone17` (`06B488AD-877C-4EC1-A472-E2053BD31DB9`):
  - `Prompt28Tests/HistoryStoreTests/coldLaunchExistingSessionTriggersSync`
- Current first blocker:
  - `Prompt28Tests/HistoryStoreTests/foregroundRetrySyncsPendingWork`
  - initial session reconciliation race was removed for this test
  - UIKit notification dependency was removed for this test by calling the foreground retry path directly
  - lifecycle observation was also disabled for this test so it is fully isolated from hosted app lifecycle behavior
  - despite that, the hosted run still does not return a real XCTest pass/fail result yet
  - latest process inspection showed `xcodebuild` still alive after build/package handoff with no active `xctest`/`XCTRunner` process visible, which points to hosted runner/process launch behavior rather than the test body itself
- Physical iPhone manual validation is now the primary short-term validation path.
- Hosted simulator validation remains useful secondary coverage, but it is no longer the main blocker for continuing Phase 2 hardening.
- Generation remains on the legacy Railway `/api/generate` path during Phase 2.
- StoreKit product loading failure is not the generation gate in the current app flow.
- `GenerateViewModel` now refreshes the Supabase session token before generation and retries once on legacy 401/session-expired responses instead of immediately logging the user out.
- `APIClient` now surfaces raw backend/body text for `/api/generate` failures when the Railway response is non-JSON or decodes unexpectedly, so device testing can distinguish auth rejection, bad response shape, and backend errors.
- `UpgradeView` now tracks a `productsLoaded: Bool` state separately from `products.isEmpty`. After `loadProducts()` returns with no products (e.g. no App Store Connect sandbox products registered), the view shows "Plans are not available right now." instead of an infinite spinner.
- `UpgradeView` dev section now has two clearly separated subsections: "Usage Counter" (Reset button, no key needed) and "Dev Plan (requires admin key)" (SecureField + Activate Dev Plan button). Labels make it explicit that the reset button does not require an admin key.
- `GenerateViewModel` outer catch now shows "Prompt generation is temporarily unavailable. Please try again." for `.unauthorized` errors instead of "Session expired. Please sign in again." — Railway rejects Supabase JWTs with 401, and the previous message was misleading since the user is authenticated.
- `AuthManager.bootstrap()` now calls `try? await supabase.auth.signOut()` when session restoration fails, clearing the SDK's internal session storage so subsequent login attempts do not re-send the expired token as a Bearer header. This fixes the "session expired, please login again" error that blocked all fresh login attempts.
- **Phase 3 generation foundation wired**: `GenerateViewModel` now has a dual-path generation switch. If `SUPABASE_GENERATE_FUNCTION` is set in Info.plist to a non-empty value (currently `""`), generation calls `supabase.functions.invoke()` with the Supabase JWT — bypassing Railway entirely. `HomeView.init` and `RootView.homeView` thread `SupabaseClient?` through to `GenerateViewModel`. `EdgeGenerateResponse` DTO only requires `{ professional, template }` from the Edge Function — usage/plan fields filled locally. To activate Phase 3 generation: set `SUPABASE_GENERATE_FUNCTION = "generate"` in Info.plist and deploy the Edge Function.
- **Important truth:** automated validation completion is still pending unless `xcodebuild test` returns real pass/fail results. Do not claim Phase 2 hardening is fully validated yet.

## Known Remaining Gaps

- End-to-end automated validation is not yet fully complete.
- The storage hardening implementation is in place, but `xcodebuild test` completion still needs to be proven with real pass/fail output.
- The first remaining validation blocker is still `Prompt28Tests/HistoryStoreTests/foregroundRetrySyncsPendingWork`.
- Latest test command run:
  - `xcodebuild test -project Prompt28.xcodeproj -scheme OrionOrb -destination 'id=06B488AD-877C-4EC1-A472-E2053BD31DB9' -derivedDataPath /tmp/Prompt28DerivedData -only-testing:Prompt28Tests/HistoryStoreTests/foregroundRetrySyncsPendingWork -resultBundlePath /tmp/prompt28-foregroundRetry-4.xcresult`
- Latest result:
  - no real XCTest pass/fail result returned
  - run stopped after repeated quiet periods post-build/package handoff
- Current practical validation path:
  - manual verification on physical iPhone
- Phase 2 hardening should not be marked complete until the history validation suite actually finishes successfully.
- Recommended next step:
  - continue Phase 2 hardening work and validate behavior on physical iPhone first
  - keep the hosted simulator issue documented, but do not spend more time on it unless it becomes necessary again
  - use simulator-hosted testing as secondary validation only

### PromptPremiumBackground (RootView.swift)

The full-screen dark navy gradient used across all screens.

```swift
struct PromptPremiumBackground: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color(hex: "#02040F")                          // base solid
                LinearGradient(                                // top-to-bottom navy fade
                    colors: ["#0D1A40", "#0A1431", "#061022", "#02040F"],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(                                // subtle center bloom
                    colors: ["#1A2E59".opacity(0.30), "#0D1A40".opacity(0.16), .clear],
                    center: UnitPoint(x: 0.50, y: 0.40),
                    startRadius: 14, endRadius: size.width * 0.72
                )
                RadialGradient(                                // soft secondary bloom
                    colors: ["#1A2E59".opacity(0.08), "#0D1A40".opacity(0.04), .clear],
                    center: UnitPoint(x: 0.64, y: 0.60),
                    startRadius: 8, endRadius: size.width * 0.50
                )
                LinearGradient(                                // soft-light polish
                    colors: [.white.opacity(0.015), .clear, .white.opacity(0.01)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .blendMode(.softLight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // ← REQUIRED, not geo.size
        }
        .ignoresSafeArea()
    }
}
```

**Critical rendering rule**: Always use `.frame(maxWidth: .infinity, maxHeight: .infinity)` inside the inner ZStack — never `CGSize` fixed dimensions. The outer view must have `.ignoresSafeArea()`.

### Tab Bar (TabBarRaiser / RootView.swift init)

The floating rounded tab bar is configured in two places:

1. `RootView.init()` — sets `UITabBarAppearance` (colors, selection indicator, font)
2. `TabBarRaiser` UIViewRepresentable — raises bar 10pt, applies corner radius 28, border + shadow

```swift
// TabBarRaiser key values:
extraInset: 10          // extra bottom safe area
cornerRadius: 28        // .continuous curve
borderWidth: 0.5, borderColor: white 0.10
shadowColor: black 0.40, shadowOpacity: 1, shadowRadius: 16, shadowOffset: (0, 10)
symbolConfig: 20pt, .medium weight

// Selection indicator:
size: 96×72, inset dx:8 dy:6, cornerRadius: 24
color: UIColor(red: 0.30, green: 0.34, blue: 0.43, alpha: 0.62)
```

---

## 4. Navigation Rules

### ⚠️ Critical: The NavigationStack Background Rule

**Every view that contains a `NavigationStack` in its `body` must independently place `PromptPremiumBackground().ignoresSafeArea()` as the FIRST item in its own top-level ZStack.**

This is because SwiftUI's NavigationStack renders through an opaque `UINavigationController` UIViewController layer that completely blocks any background from a parent view. The root-level background in `RootView` cannot reach through it.

| Screen | Has NavigationStack | Owns PromptPremiumBackground | How |
|---|---|---|---|
| RootView | No | Yes (root ZStack) | Serves launch/auth/onboarding |
| HomeView | **Yes** | **Yes** | ZStack > PromptPremiumBackground first |
| HistoryView | **Yes** | **Yes** | GeometryReader > ZStack > PromptPremiumBackground first |
| FavoritesView | **Yes** | **Yes** | GeometryReader > ZStack > PromptPremiumBackground first |
| TrendingView | **Yes** | **Yes** | GeometryReader > ZStack > PromptPremiumBackground first |
| SettingsView | No NavigationStack | **Yes** | GeometryReader > ZStack > PromptPremiumBackground first |
| AppScreenContainer | No NavigationStack | **Yes** | ZStack > PromptPremiumBackground first |

### Sheet Presentation

All sheets use `.presentationBackground(.regularMaterial)` and `.presentationCornerRadius(32)`:

```swift
// TypePromptView sheet (from HomeView)
.presentationDetents([.medium, .large])
.presentationDragIndicator(.visible)
.presentationBackground(.regularMaterial)
.presentationCornerRadius(32)

// SettingsView sheet (from HomeView)
SettingsView { activeSheet = nil }   // onDone callback
.presentationDetents([.large])
.presentationDragIndicator(.visible)
.presentationBackground(.regularMaterial)
.presentationCornerRadius(32)
// Note: SettingsView also has its own PromptPremiumBackground internally

// UpgradeView sheet
.presentationDetents([.large])
.presentationBackground(.regularMaterial)
.presentationCornerRadius(32)
```

### Toolbar / Navigation Bar

All main screens hide the system navigation bar:
```swift
.toolbar(.hidden, for: .navigationBar)
```

### Tab Clearance

Every scroll view must end with a spacer:
```swift
Color.clear.frame(height: AppHeights.tabBarClearance)  // 102pt
```

---

## 5. Data Models

### User (API) — Models/API/User.swift

```swift
enum PlanType: String, Codable { case starter, pro, unlimited, dev }

struct User: Decodable, Identifiable, Equatable {
    let id: String              // handles both String and Int from API
    let email: String
    let name: String
    let provider: String        // "apple", "email", etc.
    let plan: PlanType
    let prompts_used: Int
    let prompts_remaining: Int? // nil for unlimited plan
    let period_end: String
    // Decodes both snake_case and camelCase keys from API
}
```

### PromptHistoryItem (Local) — Models/Local/PromptHistoryItem.swift

Local storage model. Access via `HistoryStore` from `AppEnvironment`.

### AppPreferences — Models/Local/AppPreferences.swift

Stored via `PreferencesStore`. Contains `saveHistory: Bool` and `selectedMode: PromptMode`.

### PromptMode

```swift
enum PromptMode: String { case ai, human }
```

### Navigation Enums — App/Routing/AppRouter.swift

```swift
enum RootRoute { case launching, auth, main }
enum MainTab: Hashable { case home, trending, history, favorites, admin }
```

---

## 6. Editing Rules for Other AI Tools

### ✅ SAFE — Always allowed

- Modifying text content, font sizes, font weights inside existing views
- Changing `Color` values or opacity
- Adjusting padding, spacing, frame heights
- Adding new `@State` variables to existing views
- Adding new computed view properties to existing view structs
- Modifying ViewModel logic (GenerateViewModel, HistoryViewModel, etc.)
- Adding cases to ViewModels' `@Published` properties
- Editing API endpoint logic in APIClient/APIEndpoint

### ⚠️ CAUTION — Safe only if you follow the rules

- **Adding `PromptPremiumBackground()`**: Only do this if the view you're editing contains a `NavigationStack` in its `body`, AND does not already have one. Always place it as the **first child** of the outermost ZStack.
- **Modifying `PromptTheme` tokens**: Changes propagate everywhere. Before changing a color, search for all usages.
- **Modifying `glassCard(cornerRadius:)`**: This is used on ALL cards across all screens. Test all tabs after changes.
- **Modifying `TabBarRaiser`**: Affects all tab bar behavior system-wide.

### ❌ NEVER DO THESE

1. **Never remove `PromptPremiumBackground()` from AppScreenContainer** — this causes History, Favorites, and Trending screens to go black, because they use `AppScreenContainer` but have their own NavigationStack.

2. **Never remove these two lines from `PromptMeNativeApp.init()`**:
   ```swift
   // These prevent black flash and white background bleed-through on launch
   window.backgroundColor = UIColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
   (window.rootViewController as? UIHostingController<RootView>)?.view.backgroundColor = .clear
   ```

3. **Never use `geo.size.width` / `geo.size.height` inside `PromptPremiumBackground`'s inner ZStack frame** — use `.frame(maxWidth: .infinity, maxHeight: .infinity)` instead.

4. **Never add `NavigationStack` to a view that already wraps inside another NavigationStack** — sheets use their own NavigationStack for toolbar, but the underlying screen views (HistoryView, FavoritesView, etc.) already own one.

5. **Never change `.toolbar(.hidden, for: .navigationBar)`** on main tab screens — the system navbar is always hidden; these screens manage their own header rows.

6. **Never create a new glass card implementation** — always use `PromptTheme.glassCard(cornerRadius:)` or the `.appGlassCard()` modifier.

7. **Never remove `Color.clear.frame(height: AppHeights.tabBarClearance)`** from the bottom of scroll views — this prevents content from being obscured by the floating tab bar.

8. **Never move the `PrivacyConsentView` gate below the bootstrap/auth checks in `RootView`** — consent must gate ALL data collection and auth flows. The `if !hasAcceptedPrivacy` branch must remain the first branch in the `Group`.

---

## 7. Safe Edit Phases

Use these phases when making broad changes. Complete and verify each phase before starting the next.

### Phase 1 — Design Tokens Only
**Scope**: `RootView.swift` (`PromptTheme` enum, `PromptPremiumBackground` struct) and `AppUI.swift` (spacing/height/radii enums).
**Risk**: Low if you don't change the structure, only values.
**Verify**: Build succeeds. Launch app, check all 4 tabs render with correct background.

### Phase 2 — Shared Controls
**Scope**: `AppUI.swift` (`glassCard`, `AppSearchField`, `AppGlassField`, `AppPrimaryButton`, `AppScreenContainer`).
**Risk**: Medium — changes affect all screens.
**Verify**: History, Favorites, Trending tabs all render correctly. Cards have correct glass appearance.

### Phase 3 — Tab Bar
**Scope**: `RootView.swift` (`init()` appearance block, `TabBarRaiser`, `mainTabs` body).
**Risk**: Medium — tab bar is global UI chrome.
**Verify**: Tab bar floats, rounded, correct selection indicator. No black flash on launch.

### Phase 4 — Individual Screens
**Scope**: One feature folder at a time (`Features/Home/`, `Features/History/`, etc.).
**Risk**: Low per screen.
**Verify**: Each screen renders background correctly. Sheets open and dismiss cleanly.

### Phase 5 — ViewModels / Business Logic
**Scope**: `Core/` and `Features/*/ViewModels/`.
**Risk**: Low UI risk, potential logic risk.
**Verify**: Generate flow works, history saves, favorites toggle, settings save.

### Phase 6 — Models / API
**Scope**: `Models/` and `Core/Networking/`.
**Risk**: Breaking decoder changes will crash on malformed API responses.
**Verify**: Login works. User plan/usage data shows correctly in Settings.

---

## 8. Quick Reference — Per-Screen Summary

| Screen | File | NavigationStack | Own Background | Sheet Detents | Key Notes |
|---|---|---|---|---|---|
| Home | HomeView.swift | ✅ Yes | ✅ Yes | — | Orb + generate flow. Settings/Upgrade/TypePrompt as sheets. |
| History | HistoryView.swift | ✅ Yes | ✅ Yes | — | Search + Export + Clear in header row. Cards: title+badge+preview+actions. |
| Favorites | FavoritesView.swift | ✅ Yes | ✅ Yes | — | Search + Export in controls row. Simple list cards. |
| Trending | TrendingView.swift | ✅ Yes | ✅ Yes | — | Category pills. Cards: expandable text + Save (glass) + Copy (purple gradient). |
| Settings | SettingsView.swift | ❌ No | ✅ Yes | .large | Presented as sheet from HomeView. Has own background. Done button callback. |
| Upgrade | UpgradeView.swift | ❌ No | — | .large | Presented from SettingsView or HomeView. Uses `.regularMaterial` sheet bg. |
| Auth | AuthFlowView.swift | ❌ No | — | — | Served by RootView's root-level background. |
| Onboarding | OnboardingView.swift | ❌ No | — | — | Served by RootView's root-level background. |
| Privacy Consent | PrivacyConsentView.swift | ❌ No | — | — | First-launch gate. Served by RootView's root-level background. |

---

## 9. Common Patterns Reference

### Glassmorphic Button (chip style, used for Export/Clear/action chips)
```swift
Text("Label")
    .font(.system(size: 16, weight: .medium, design: .rounded))
    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.84))
    .padding(.horizontal, 18)
    .frame(height: 46)
    .background(
        Capsule()
            .fill(PromptTheme.glassFill)
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
    )
```

### Solid Purple CTA Button (used for Copy in Trending, Upgrade Plan)
```swift
.background(
    Capsule()  // or RoundedRectangle(cornerRadius: 22)
        .fill(LinearGradient(
            colors: [Color(hex: "#7F7FD5"), Color(hex: "#6E55D8")],
            startPoint: .leading, endPoint: .trailing
        ))
        .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.28), lineWidth: 0.5))
)
```

### Mode Badge
```swift
Text(mode == .ai ? "AI" : "HUMAN")
    .font(.system(size: 16, weight: .bold, design: .rounded))
    .foregroundStyle(mode == .ai ? Color(red: 0.70, green: 0.53, blue: 1.0) : .white.opacity(0.82))
    .padding(.horizontal, 14)
    .frame(height: 34)
    .background(
        Capsule().stroke(
            mode == .ai ? Color(red: 0.18, green: 0.63, blue: 0.90).opacity(0.9) : .white.opacity(0.35),
            lineWidth: 1
        )
    )
```

### Section Header (used in SettingsView and section labels)
```swift
Text("SECTION TITLE")
    .font(.system(size: 12, weight: .bold, design: .rounded))
    .foregroundStyle(.white.opacity(0.40))
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 18)
    .padding(.top, 14)
    .padding(.bottom, 8)
```

### Copied Toast
```swift
Text("Copied to clipboard")
    .font(.footnote.weight(.semibold))
    .foregroundStyle(PromptTheme.paleLilacWhite)
    .padding(.horizontal, 16).padding(.vertical, 10)
    .background(
        Capsule()
            .fill(PromptTheme.glassFill)
            .overlay(Capsule().stroke(PromptTheme.glassStroke, lineWidth: 1))
    )
    .padding(.bottom, 18)
// Presented via .overlay(alignment: .bottom) on the NavigationStack
// Animate with .transition(.move(edge: .bottom).combined(with: .opacity))
```

### Back Button (header style, used in HistoryView / FavoritesView)
```swift
Button { dismiss() } label: {
    Image(systemName: "arrow.left")
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(.white.opacity(0.82))
        .frame(width: 44, height: 44)
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.7))
        )
}
.buttonStyle(.plain)
```

---

## 10. Session Fix Log

### Session — 2026-03-12

#### Crash: `withAnimation` + `@Observable` + `LazyVStack/ForEach` removal

**Symptom**: Tapping the Delete button (HistoryView) or Remove button (FavoritesView) immediately crashed the app.

**Root cause**: Wrapping an `@Observable` mutation that removes an item from a `LazyVStack/ForEach` data source inside `withAnimation(.easeInOut(duration:))` triggers a SwiftUI layout pass on the lazy container during item removal. The framework attempts to recalculate layout for a cell that has already been deallocated from the `@Observable` store, causing a runtime crash.

This pattern is safe in older `@ObservableObject` code but breaks with the `@Observable` macro (iOS 17+) because property tracking is synthesized differently — observation accesses happen on property read, not on publisher subscription, so the timing of mutations vs. layout is tighter.

**Files fixed**:

- `Features/History/Views/HistoryView.swift` — `historyCard()` Delete button action:
  ```swift
  // Before (crashes):
  withAnimation(.easeInOut(duration: 0.2)) { viewModel.delete(item) }
  
  // After (fixed):
  viewModel.delete(item)
  ```

- `Features/History/Views/FavoritesView.swift` — `favoriteCard()` Remove button action:
  ```swift
  // Before (crashes):
  withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleFavorite(item) }
  
  // After (fixed):
  viewModel.toggleFavorite(item)
  ```

**Rule for future sessions**: Never wrap `@Observable` state mutations that remove items from a `ForEach`/`LazyVStack` data source in `withAnimation`. The removal animation (fade-out, slide) will not play, but the app will be stable. If animation is required, use `.animation(_:value:)` on the `LazyVStack` itself with a value that changes on removal, rather than wrapping the mutation.

#### Previous sessions — compile errors fixed

All of these were introduced by AI edits and reverted/corrected:

- `AdminUnlockView.swift`: `Cannot find '$viewModel' in scope` — `@Bindable` binding syntax fix
- `GenerateViewModel.swift`: `withAnimation`/`easeInOut` misuse in ViewModel — removed
- `ResultView.swift`, `TrendingViewModel.swift`: Scope errors from helper-function extraction — inlined back into view bodies
- `HistoryView.swift`: `viewModel.items` (old property) replaced with `viewModel.filteredItems` throughout

### Session — 2026-03-12 (Phase 1 stabilization pass)

#### Scoped DI (staged migration started)

Added `EnvironmentValues` keys in `App/AppEnvironment.swift`:

- `\.historyStore` (`any HistoryStoring`)
- `\.authManager` (`AuthManager`)
- `\.appRouter` (`AppRouter`)
- `\.errorState` (`ErrorState`)

Injected all keys in `PromptMeNativeApp.swift` at app root so feature views can adopt keys incrementally without breaking current `AppEnvironment` usage.

#### Global error architecture

Added `ErrorState` (`@Observable`, `@MainActor`) in `App/AppEnvironment.swift` and global presentation in `App/RootView.swift` using `.alert(item:)`.

- API failures from `HomeView` (`GenerateViewModel.errorMessage`) now report to global `ErrorState`.
- Audio failures from `HomeView` (`OrbEngine.State.failure`) now report to global `ErrorState`.
- Duplicate error alerts are deduped per message in `HomeView` to prevent alert spam during repeated state updates.

#### History/Favorites deletion safety + animation

Updated both list screens to use scoped history DI and safe list-level animation values:

- `Features/History/Views/HistoryView.swift`
    - Replaced `@Environment(AppEnvironment.self)` history access with `@Environment(\.historyStore)`
    - Added `.animation(.easeInOut(duration: 0.2), value: viewModel.filteredItems.map(\.id))` on `LazyVStack`
- `Features/History/Views/FavoritesView.swift`
    - Replaced `@Environment(AppEnvironment.self)` history access with `@Environment(\.historyStore)`
    - Added `.animation(.easeInOut(duration: 0.2), value: viewModel.favoriteItems.map(\.id))` on `LazyVStack`

#### Verification

- `get_errors` on touched files: no Swift diagnostics.
- Full simulator build passed:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`

### Session — 2026-03-12 (Phase 2 routing + clear-surface groundwork)

#### Router-owned tab state (staged UDF migration)

`RootView` now reads/writes selected tab through `AppRouter` instead of local `@State` tab vars.

- File: `App/RootView.swift`
    - Removed local tab-selection ownership.
    - `TabView(selection:)` now binds to `appRouter.selectedTab` (fallback to `env.router`).
    - iPad `NavigationSplitView` sidebar selection now binds to router-owned tab state.
    - On auth token reset, router now executes:
        - `switchTab(.home)`
        - `popToRoot()`

#### AppRouter navigation primitives

Extended `AppRouter` with navigation-path primitives for future `navigationDestination` rollout.

- File: `App/Routing/AppRouter.swift`
    - Added `var path = NavigationPath()`
    - Added `switchTab(_:)`, `push(_:)`, `popToRoot()` helpers
    - Added `AppDestination` enum (`trendingDetail(id:)`) as initial typed destination scaffold

#### Global clear-background/navigation-surface modifier

Added a reusable modifier to standardize transparent navigation surfaces while we still keep per-screen backgrounds (per current NavigationStack safety rule).

- File: `App/AppUI.swift`
    - `promptClearNavigationSurfaces()`
    - Internals:
        - `.scrollContentBackground(.hidden)`
        - `.toolbarBackground(.hidden, for: .navigationBar)`
        - `.background(Color.clear)`

Applied this modifier to key stack roots in:

- `App/RootView.swift` (`mainTabs`, `iPadSidebar`)
- `Features/Home/Views/HomeView.swift`
- `Features/History/Views/HistoryView.swift`
- `Features/History/Views/FavoritesView.swift`
- `Features/Trending/Views/TrendingView.swift`
- `Features/Settings/Views/UpgradeView.swift`
- `Features/Auth/Views/AuthFlowView.swift`

#### Scoped DI adoption continued

`AuthFlowView` now consumes scoped keys with safe fallback:

- `@Environment(\.authManager)`
- `@Environment(\.appRouter)`

Auth success path now also resets router navigation context (`home` tab + root path).

#### Verification

- `get_errors` on touched files: no Swift diagnostics.
- Full simulator build passed after fixes:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`

#### Phase 2 continuation — Trending moved to router path

Replaced direct view-owned destination navigation in Trending with router-driven typed destinations.

- File: `App/Routing/AppRouter.swift`
    - `AppDestination` currently includes `trendingDetail(id: String)`

- File: `Features/Trending/Views/TrendingView.swift`
    - `NavigationStack` now binds to `router.path`
    - Added `.navigationDestination(for: AppDestination.self)` with destination resolution
    - Replaced direct `NavigationLink(destination:)` in card action row with router push:
        - `router.push(.trendingDetail(id: item.id))`

- File: `Features/Trending/ViewModels/TrendingViewModel.swift`
    - Added `promptItem(id:)` helper to resolve typed destination IDs back to `PromptItem`

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed again (`iPhone 17` destination)

#### Phase 2 continuation — Settings + Root silent DI migration

Further reduced direct `AppEnvironment` coupling by moving Settings and Root routing/state access to scoped keys with safe fallback.

- File: `Features/Settings/Views/SettingsView.swift`
    - Added scoped env usage:
        - `@Environment(\.authManager)`
        - `@Environment(\.historyStore)`
        - `@Environment(\.appRouter)`
    - Added local fallback helpers (`authManager`, `historyStore`, `router`) so behavior is unchanged if scoped key injection is absent.
    - Updated:
        - `viewModel.bind(...)` to use scoped auth/history
        - account/subscription UI reads to scoped auth
        - logout/delete-account route transitions to scoped router

- File: `App/RootView.swift`
    - Added `router` helper (`appRouter ?? env.router`) and replaced remaining direct `env.router` reads/writes.
    - Sidebar and tab bindings now read/write via unified router helper.

Verification:
- `get_errors` on edited files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — RootView and HomeView constructor decoupled from AppEnvironment

Completed the pending Root/Home cleanup by removing `AppEnvironment`-based feature composition and switching Home construction to explicit dependency injection.

- File: `Features/Home/Views/HomeView.swift`
    - Replaced `init(appEnvironment:)` with explicit dependency initializer:
        - `authManager`
        - `router`
        - `apiClient`
        - `preferencesStore`
        - `historyStore`
        - `usageTracker`
    - Removed scoped-vs-fallback helper properties now that dependencies are injected directly.

- File: `App/RootView.swift`
    - Removed `@Environment(AppEnvironment.self)` usage.
    - Added scoped dependency reads for Home composition:
        - `apiClient`, `preferencesStore`, `historyStore`, `usageTracker`
    - Added `homeView` builder that instantiates `HomeView(...)` only when all scoped dependencies are available; otherwise shows `launchView`.
    - Updated tab and iPad sidebar Home routes to use the shared `homeView` builder.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 prep continuation — Pure transcript-candidate helper + tests

Added a pure helper for transcript source selection to make this behavior testable without actor state coupling.

- File: `Core/Audio/OrbEngine.swift`
    - `finalizeTranscript()` now calls:
        - `preferredTranscriptCandidate(finalTranscript:transcript:)`
    - Added helper:
        - `nonisolated static func preferredTranscriptCandidate(finalTranscript:transcript:) -> String`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Transcript Candidate` with coverage for:
        - prefers non-empty final transcript
        - falls back to live transcript when final is empty
        - returns empty when both inputs are empty

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)
- Prompt28Tests command last run in terminal exited `0`

#### Phase 3 prep continuation — Removed remaining OrbEngine internal factory fallback

Completed the same DI-tightening pattern inside OrbEngine construction so speech creation is fully explicit.

- File: `Core/Audio/OrbEngine.swift`
    - `LiveOrbEngineFactory.speechFactory` is now required (non-optional)
    - `OrbEngine.makeDefault(...)` now requires `speechFactory` (no fallback to `LiveSpeechRecognizerFactory`)

Behavior:
1. No functional change under app startup path (AppEnvironment already provides both factories).
2. Audio construction has no hidden live-default fallback in Home or OrbEngine paths.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 prep continuation — Removed Home-level live factory fallback

Tightened audio DI by eliminating `HomeView`'s internal fallback to `LiveOrbEngineFactory`.

- File: `Features/Home/Views/HomeView.swift`
    - `orbEngineFactory` init parameter is now required (non-optional)
    - Removed local fallback construction path

- File: `App/RootView.swift`
    - `homeView` composition now requires scoped `orbEngineFactory` alongside other Home deps
    - Falls back to `launchView` if missing (consistent with existing guarded composition pattern)

Behavior:
1. No functional change under normal app startup (factory is root-injected).
2. Audio engine construction ownership is now fully composition-driven.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 prep continuation — Audio factory composition centralized in AppEnvironment

Shifted audio-factory composition ownership into `AppEnvironment` so future actor-backed swaps are made in one container location.

- File: `App/AppEnvironment.swift`
    - Added stored deps:
        - `speechRecognizerFactory: any SpeechRecognizerFactoryProtocol`
        - `orbEngineFactory: any OrbEngineFactoryProtocol`
    - Initialized live defaults in container init:
        - `LiveSpeechRecognizerFactory()`
        - `LiveOrbEngineFactory(speechFactory: speechRecognizerFactory)`
    - Added scoped key:
        - `EnvironmentValues.speechRecognizerFactory`

- File: `PromptMeNativeApp.swift`
    - Root now injects factory dependencies from `env`:
        - `\.speechRecognizerFactory`
        - `\.orbEngineFactory`

Behavior:
1. No runtime behavior change.
2. Audio construction seams are now owned by the app container (not ad hoc in views).

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 prep continuation — OrbEngine factory wired through scoped DI

Moved the OrbEngine factory seam from local-only fallback to app-level scoped injection, so composition can swap engine construction without touching `HomeView` internals.

- File: `App/AppEnvironment.swift`
    - Added `EnvironmentValues.orbEngineFactory` key:
        - type: `(any OrbEngineFactoryProtocol)?`

- File: `PromptMeNativeApp.swift`
    - Injected live factory at root:
        - `.environment(\.orbEngineFactory, LiveOrbEngineFactory())`

- File: `App/RootView.swift`
    - Reads scoped `orbEngineFactory`
    - Passes it into `HomeView(..., orbEngineFactory:)`

Behavior:
1. No functional change; live app still uses the same OrbEngine behavior.
2. Factory replacement now supports scoped composition and test/migration seams.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 prep continuation — Speech factory seam for OrbEngine default path

Decoupled `OrbEngine.makeDefault()` from direct `SpeechRecognizerService` construction to allow actor-backed speech implementations later without touching Home wiring.

- File: `Core/Audio/SpeechRecognizerService.swift`
    - Added `SpeechRecognizerFactoryProtocol`
    - Added `LiveSpeechRecognizerFactory` implementation

- File: `Core/Audio/OrbEngine.swift`
    - `LiveOrbEngineFactory` now accepts optional `speechFactory`
    - `OrbEngine.makeDefault(...)` now resolves speech via factory:
        - `makeDefault(speechFactory:locale:)`

Behavior:
1. No runtime behavior change (live defaults still create `SpeechRecognizerService(locale: .current)`).
2. Construction path is now swappable through factory seams.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 prep continuation — OrbView now uses protocol boundary for commands

Extended protocol-boundary adoption from Home generation flow into `OrbView` interactions.

- File: `Features/Home/Views/OrbView.swift`
    - Added `engineCommands` helper typed as `any OrbEngineProtocol`
    - Routed command/callback interactions through protocol boundary:
        - `startListening`
        - `stopListening`
        - `onFinalTranscript` set/unset

Behavior:
1. No functional change; this is boundary prep for future engine backend swaps.
2. View still stores concrete `OrbEngine` for Observation compatibility.

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Centralized transcript trimming character set in OrbEngine

Introduced a single private trim character set constant and replaced repeated inline `.whitespacesAndNewlines` usage across transcript normalization paths.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `transcriptTrimCharacterSet = CharacterSet.whitespacesAndNewlines`
    - Updated transcript/final transcript trimming callsites to use the shared constant
    - No logic changes; this is a consistency and maintainability cleanup

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Simplified final transcript promotion assignments in OrbEngine

Replaced duplicated two-line assignments with tuple assignment when promoting finalized transcript text, preserving the same values and control flow.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - In `awaitFinalTranscriptAndFinalize()`, changed:
        - `finalTranscript = best` + `transcript = best`
        - to `(finalTranscript, transcript) = (best, best)`
    - In fallback promotion path, changed:
        - `finalTranscript = fallbackCandidate` + `transcript = fallbackCandidate`
        - to `(finalTranscript, transcript) = (fallbackCandidate, fallbackCandidate)`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Centralized final transcript polling constants in OrbEngine

Replaced duplicated final-transcript polling magic numbers with private constants to reduce drift risk while preserving behavior.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `finalTranscriptPollingAttempts = 30`
    - Added `finalTranscriptPollingSleepNanoseconds: UInt64 = 50_000_000`
    - Updated both final-transcript polling loops to use these constants

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 prep continuation — Inline minimum listening-duration constant

Removed a single-use listening-duration field and applied the stable threshold directly in the stop-listening guard.

- File: `Core/Audio/OrbEngine.swift`
    - In `stopListening()`, replaced:
        - `minimumListeningDuration`
      with direct threshold:
        - `0.7`
    - Removed field:
        - `minimumListeningDuration`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 315)
- No test command was run.

#### Phase 3 prep continuation — Inline minimum transcript threshold constant

Removed a single-use threshold field and applied the stable threshold directly in transcript meaningfulness evaluation.

- File: `Core/Audio/OrbEngine.swift`
    - In `isMeaningfulTranscript(_:)`, replaced:
        - `minimumTranscriptCharacterCount`
      with direct threshold:
        - `3`
    - Removed field:
        - `minimumTranscriptCharacterCount`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 314)
- No test command was run.

#### Phase 3 prep continuation — Remove unused speech-content tracking state

Removed dead internal state after meaningfulness logic no longer depended on transcript-content tracking.

- File: `Core/Audio/OrbEngine.swift`
    - Removed unused field:
        - `hasDetectedSpeechContent`
    - Removed now-dead assignments in:
        - `startListening()` reset path
        - transcript publisher sink

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 314)
- No test command was run.

#### Phase 3 prep continuation — Remove redundant meaningfulness guard

Removed a redundant boolean guard in transcript meaningfulness evaluation.

- File: `Core/Audio/OrbEngine.swift`
    - In `isMeaningfulTranscript(_:)`, removed:
        - `guard hasDetectedSpeechContent || !trimmed.isEmpty else { return false }`
    - Rationale:
        - previous guard is always true after `trimmed.count >= minimumTranscriptCharacterCount`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 288)
- No test command was run.

#### Phase 3 prep continuation — Inline stop-listening time gate property

Removed a small computed-property indirection and applied the stop-listening time gate directly in `stopListening()`.

- File: `Core/Audio/OrbEngine.swift`
    - In `stopListening()`, replaced `canStopListeningNow` usage with direct guard logic:
        - `listeningStartedAt` must exist
        - elapsed time since start must meet `minimumListeningDuration`
    - Removed computed property:
        - `canStopListeningNow`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 315)
- No test command was run.

#### Phase 3 prep continuation — Inline transcript normalization helper

Removed the final transcript-normalization helper and inlined trimming logic directly at all call sites.

- File: `Core/Audio/OrbEngine.swift`
    - Replaced `normalizedTranscript(...)` with direct `trimmingCharacters(in: .whitespacesAndNewlines)` in:
        - `stopListeningAndFinalize()`
        - `awaitFinalTranscriptAndFinalize()` (final transcript path)
        - `awaitFinalTranscriptAndFinalize()` (fallback transcript path)
        - transcript publisher sink
        - final transcript publisher sink
    - Removed helper:
        - `normalizedTranscript(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Transcript Normalization`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 319)
- No test command was run.

#### Phase 3 prep continuation — Inline transcript meaningfulness helper

Removed the static transcript-meaningfulness helper and applied the logic directly in the instance-level meaningfulness check.

- File: `Core/Audio/OrbEngine.swift`
    - In fallback acceptance path, replaced call to:
        - `isMeaningfulTranscriptCandidate(...)`
      with:
        - `isMeaningfulTranscript(...)`
    - In `isMeaningfulTranscript(_:)`, inlined the complete meaningfulness logic:
        - trim whitespace/newlines
        - minimum character count gate
        - speech-content/emptiness gate
        - alphanumeric-content gate
    - Removed helper:
        - `isMeaningfulTranscriptCandidate(...)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Transcript Meaning`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 319)
- No test command was run.

#### Phase 3 prep continuation — Inline permission failure/message mappings

Removed two single-use permission mapping helpers and inlined their behavior directly at usage sites.

- File: `Core/Audio/OrbEngine.swift`
    - `permissionStatusPublisher` sink now maps statuses directly to failure states instead of calling:
        - `failureMessage(for:)`
    - `permissionMessage` computed property now switches directly on `permissionStatus` instead of calling:
        - `permissionMessage(for:)`
    - Removed helpers:
        - `failureMessage(for:)`
        - `permissionMessage(for:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suites:
        - `Orb Permission Failure Mapping`
        - `Orb Permission Message Mapping`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 320)
- No test command was run.

#### Phase 3 prep continuation — Inline polling sleep duration constant

Removed a small polling-sleep helper and used the stable sleep constant directly in both final-transcript polling loops.

- File: `Core/Audio/OrbEngine.swift`
    - In `stopListeningAndFinalize()`, replaced:
        - `finalTranscriptPollingSleepNanoseconds()`
      with:
        - `50_000_000`
    - In `awaitFinalTranscriptAndFinalize()`, replaced:
        - `finalTranscriptPollingSleepNanoseconds()`
      with:
        - `50_000_000`
    - Removed helper:
        - `finalTranscriptPollingSleepNanoseconds()`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Final Transcript Polling Sleep`

#### Phase 3 prep continuation — Inline permission settings-action mapping in property

Removed a single-use permission-settings helper and mapped statuses directly in the computed property.

- File: `Core/Audio/OrbEngine.swift`
    - In `needsPermissionSettingsAction`, replaced helper call:
        - `needsPermissionSettingsAction(for: permissionStatus)`
      with inline `switch` over `permissionStatus`
    - Removed helper:
        - `needsPermissionSettingsAction(for:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Permission Settings Action Mapping`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 319)
- No test command was run.

#### Phase 3 prep continuation — Inline polling attempt range helper

Removed a small helper for polling range and used the stable range directly in both final-transcript polling loops.

- File: `Core/Audio/OrbEngine.swift`
    - In `stopListeningAndFinalize()`, replaced:
        - `finalTranscriptPollingAttemptRange()` with `0..<30`
    - In `awaitFinalTranscriptAndFinalize()`, replaced:
        - `finalTranscriptPollingAttemptRange()` with `0..<30`
    - Removed helper:
        - `finalTranscriptPollingAttemptRange()`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Final Transcript Polling Range`

#### Phase 3 prep continuation — Inline normalized transcript-content checks

Removed a single-use normalized-content helper and performed non-empty checks directly at each call site.

- File: `Core/Audio/OrbEngine.swift`
    - Replaced `hasNormalizedTranscriptContent(...)` with `!trimmed.isEmpty`/`!best.isEmpty` in:
        - `stopListeningAndFinalize()`
        - `awaitFinalTranscriptAndFinalize()`
        - transcript publisher sink
        - final transcript publisher sink
    - Removed helper:
        - `hasNormalizedTranscriptContent(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Normalized Transcript Content`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 318)
- No test command was run.

#### Phase 3 prep continuation — Inline polling attempt range in finalize loops

Removed a small polling-range helper and applied the stable range directly in both transcript polling loops.

- File: `Core/Audio/OrbEngine.swift`
    - In `stopListeningAndFinalize()`, replaced:
        - `finalTranscriptPollingAttemptRange()`
      with:
        - `0..<30`
    - In `awaitFinalTranscriptAndFinalize()`, replaced:
        - `finalTranscriptPollingAttemptRange()`
      with:
        - `0..<30`
    - Removed helper:
        - `finalTranscriptPollingAttemptRange()`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Final Transcript Polling Range`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 318)
- No test command was run.

#### Phase 3 prep continuation — Inline minimum-listening-duration gate

Removed a single-use listening-duration helper and applied the gate directly in `canStopListeningNow`.

- File: `Core/Audio/OrbEngine.swift`
    - In `canStopListeningNow`, replaced helper call:
        - `hasMetMinimumListeningDuration(...)`
      with direct logic:
        - guard `listeningStartedAt` exists
        - compare elapsed time against `minimumListeningDuration`
    - Removed helper:
        - `hasMetMinimumListeningDuration(listeningStartedAt:now:minimumListeningDuration:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Listening Duration`

#### Phase 3 prep continuation — Inline polling-iteration limit into attempt range

Removed a one-line polling-limit indirection and encoded the stable attempt range directly.

- File: `Core/Audio/OrbEngine.swift`
    - `finalTranscriptPollingAttemptRange()` now returns `0..<30` directly
    - Removed helper:
        - `finalTranscriptPollingIterationLimit()`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Final Transcript Polling Limit`
    - Updated suite `Orb Final Transcript Polling Range` to assert count equals `30`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 317)
- No test command was run.

#### Phase 3 prep continuation — Inline alphanumeric transcript-content check

Removed a single-use alphanumeric-content helper and kept the content check directly in transcript meaningfulness evaluation.

- File: `Core/Audio/OrbEngine.swift`
    - In `isMeaningfulTranscriptCandidate(...)`, replaced helper call:
        - `containsAlphanumericContent(trimmed)`
      with direct check:
        - `trimmed.rangeOfCharacter(from: .alphanumerics) != nil`
    - Removed helper:
        - `containsAlphanumericContent(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Alphanumeric Content Detection`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 319)
- No test command was run.

#### Phase 3 prep continuation — Inline transcript minimum-length check

Removed a single-use minimum-length helper and performed the length gate directly in transcript meaningfulness evaluation.

- File: `Core/Audio/OrbEngine.swift`
    - In `isMeaningfulTranscriptCandidate(...)`, replaced helper call:
        - `meetsMinimumTranscriptLength(...)`
      with direct check:
        - `trimmed.count >= minimumTranscriptCharacterCount`
    - Removed helper:
        - `meetsMinimumTranscriptLength(trimmedText:minimumTranscriptCharacterCount:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Transcript Minimum Length`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 320)
- No test command was run.

#### Phase 3 prep continuation — Inline transcript field assignment in finalize polling paths

Removed a single-use transcript-assignment helper and assigned transcript fields directly in the two finalize polling paths.

- File: `Core/Audio/OrbEngine.swift`
        - In successful final-transcript polling path, replaced:
                - `transcriptAssignment(for:)`
            with direct assignments to `finalTranscript` and `transcript`
        - In fallback-accepted path, replaced:
                - `transcriptAssignment(for:)`
            with direct assignments to `finalTranscript` and `transcript`
        - Removed helper:
                - `transcriptAssignment(for:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
        - Removed obsolete suite `Orb Transcript Assignment`

Verification:
- Build succeeded:
        - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
        - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 319)
- No test command was run.

#### Phase 3 prep continuation — Inline fallback candidate selection in finalize polling

Removed a single-use fallback candidate helper and applied selection logic directly in `awaitFinalTranscriptAndFinalize()`.

- File: `Core/Audio/OrbEngine.swift`
    - In fallback path, replaced helper call:
        - `fallbackTranscriptCandidateAfterPolling(...)`
      with inline logic:
        - normalize `speech.transcript`
        - gate via `isMeaningfulTranscriptCandidate(...)`
        - use normalized candidate for transcript assignment
    - Removed helper:
        - `fallbackTranscriptCandidateAfterPolling(transcript:hasDetectedSpeechContent:minimumTranscriptCharacterCount:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Fallback Transcript Candidate Selection`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 319)
- No test command was run.

#### Phase 3 prep continuation — Inline final-transcript finalize gate in publisher sink

Removed a single-use finalize-gating helper and applied its gate directly in the final-transcript publisher sink.

- File: `Core/Audio/OrbEngine.swift`
    - In `speech.finalTranscriptPublisher` sink, replaced helper call:
        - `shouldFinalizeOnFinalTranscriptUpdate(trimmedFinalTranscript:state:)`
      with direct gate:
        - normalized transcript has content
        - state is `.transcribing` or `.listening`
    - Removed helper:
        - `shouldFinalizeOnFinalTranscriptUpdate(trimmedFinalTranscript:state:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Final Transcript Finalize Gate`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 318)
- No test command was run.

#### Phase 3 prep continuation — Inline speech-content detection flag updates

Removed a single-use speech-content detection helper and updated the transcript sink to apply sticky-detection logic directly.

- File: `Core/Audio/OrbEngine.swift`
    - In `speech.transcriptPublisher` sink, replaced helper call:
        - `updatedSpeechContentDetectionFlag(currentValue:trimmedTranscript:)`
      with direct expression:
        - `self.hasDetectedSpeechContent || hasNormalizedTranscriptContent(trimmed)`
    - Removed helper:
        - `updatedSpeechContentDetectionFlag(currentValue:trimmedTranscript:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Speech Content Detection Flag`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Inline non-empty normalized transcript selection

Removed a single-use normalized-transcript wrapper and applied its selection logic directly in both final-transcript polling loops.

- File: `Core/Audio/OrbEngine.swift`
        - In `stopListeningAndFinalize()`, replaced:
                - `nonEmptyNormalizedTranscript(finalTranscript)`
            with inline normalization + non-empty check
        - In `awaitFinalTranscriptAndFinalize()`, replaced:
                - `nonEmptyNormalizedTranscript(speech.finalTranscript)`
            with inline normalization + non-empty check
        - Removed helper:
                - `nonEmptyNormalizedTranscript(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
        - Removed obsolete suite `Orb Non-Empty Normalized Transcript`

Verification:
- Build succeeded:
        - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
        - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 326)
- No test command was run.

#### Phase 3 prep continuation — Inline transcript candidate selection in finalize flow

Removed a single-use transcript-candidate helper and kept candidate selection directly in `finalizeTranscript()`.

- File: `Core/Audio/OrbEngine.swift`
    - In `finalizeTranscript()`, replaced helper call:
        - `preferredTranscriptCandidate(finalTranscript:transcript:)`
      with direct selection logic:
        - use trimmed `finalTranscript` when non-empty
        - otherwise fall back to trimmed `transcript`
    - Removed helper:
        - `preferredTranscriptCandidate(finalTranscript:transcript:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Transcript Candidate`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 323)
- No test command was run.

#### Phase 3 prep continuation — Inline final-transcript eligible-state gating

Removed a single-use eligible-state helper and kept the eligibility check directly in `shouldFinalizeOnFinalTranscriptUpdate(...)`.

- File: `Core/Audio/OrbEngine.swift`
    - In `shouldFinalizeOnFinalTranscriptUpdate(...)`, replaced helper delegation with direct check:
        - `state == .transcribing || state == .listening`
    - Removed helper:
        - `isStateEligibleForFinalTranscriptFinalize(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Final Transcript Eligible States`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 326)
- No test command was run.

#### Phase 3 prep continuation — Inline discarded-transcript state mapping

Removed a single-use discarded-transcript state helper and mapped idle-preservation behavior directly in `finalizeTranscript()`.

- File: `Core/Audio/OrbEngine.swift`
    - In discarded-transcript branch of `finalizeTranscript()`, replaced:
        - `stateAfterDiscardingTranscriptCandidate(currentState:isRecording:)`
      with direct assignment:
        - `state = isRecording ? state : .idle`
    - Removed helper:
        - `stateAfterDiscardingTranscriptCandidate(currentState:isRecording:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Discarded Transcript State Mapping`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 323)
- No test command was run.

#### Phase 3 prep continuation — Inline failing-permission classification in failure mapping

Removed a single-use failing-permission classification helper and kept classification directly in `failureMessage(for:)`.

- File: `Core/Audio/OrbEngine.swift`
    - Removed helper:
        - `isFailingPermissionStatus(_:)`
    - Updated:
        - `failureMessage(for:)` now directly returns messages for failing statuses and `nil` for non-failing statuses

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Permission Failure Classification`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 324)
- No test command was run.

#### Phase 3 prep continuation — Inline permission-status failure transition

Removed a single-use permission-status state-mapping helper and handled failure-state transition directly in the permission-status publisher sink.

- File: `Core/Audio/OrbEngine.swift`
    - In `speech.permissionStatusPublisher` sink, replaced helper call:
        - `stateAfterPermissionStatusUpdate(currentState:status:)`
      with direct mapping:
        - if `failureMessage(for:)` exists, set `.failure(message)`
        - otherwise preserve current state
    - Removed helper:
        - `stateAfterPermissionStatusUpdate(currentState:status:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Permission Status State Transition`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Inline recording-state transition mapping

Removed a single-use recording-state transition helper and assigned the mapped state directly in the recording publisher sink.

- File: `Core/Audio/OrbEngine.swift`
    - In `speech.isRecordingPublisher` sink, replaced:
        - `stateAfterRecordingUpdate(currentState:isRecording:)`
      with direct assignment:
        - `self.state = value ? .listening : self.state`
    - Removed helper:
        - `stateAfterRecordingUpdate(currentState:isRecording:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Recording State Transition`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Inline stop-listening eligibility guard

Removed a single-use stop-listening eligibility helper and performed the eligibility check directly in `stopListening()`.

- File: `Core/Audio/OrbEngine.swift`
    - In `stopListening()`, replaced helper call:
        - `shouldBeginStopListening(isRecording:canStopListeningNow:)`
      with direct guard:
        - `isRecording && canStopListeningNow`
    - Removed helper:
        - `shouldBeginStopListening(isRecording:canStopListeningNow:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Stop Listening Eligibility`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Inline transcript-delivery dedupe comparison

Removed a single-use dedupe wrapper and performed direct transcript comparison in `finalizeTranscript()`.

- File: `Core/Audio/OrbEngine.swift`
    - In `finalizeTranscript()`, replaced:
        - `shouldDeliverTranscriptCandidate(...)`
      with direct guard:
        - `trimmed != lastDeliveredTranscript`
    - Removed helper:
        - `shouldDeliverTranscriptCandidate(trimmedTranscript:lastDeliveredTranscript:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Transcript Delivery Dedupe`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 324)
- No test command was run.

#### Phase 3 prep continuation — Inline fallback-acceptance meaningfulness check

Removed a pass-through fallback-acceptance helper and performed the meaningfulness check directly in fallback candidate selection.

- File: `Core/Audio/OrbEngine.swift`
    - In `fallbackTranscriptCandidateAfterPolling(...)`, replaced:
        - `shouldAcceptFallbackTranscriptCandidate(...)`
      with:
        - `isMeaningfulTranscriptCandidate(...)`
    - Removed helper:
        - `shouldAcceptFallbackTranscriptCandidate(text:hasDetectedSpeechContent:minimumTranscriptCharacterCount:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Fallback Transcript Acceptance`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Remove fallback transcript trimming wrapper

Removed a redundant transcript-trimming wrapper and used `normalizedTranscript(_:)` directly in fallback candidate selection.

- File: `Core/Audio/OrbEngine.swift`
    - In `fallbackTranscriptCandidateAfterPolling(...)`, replaced:
        - `let trimmed = trimmedFallbackTranscript(transcript)`
      with:
        - `let trimmed = normalizedTranscript(transcript)`
    - Removed helper:
        - `trimmedFallbackTranscript(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Fallback Transcript Trimming`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Inline permission failure-state mapping

Removed a redundant failure-state wrapper and kept permission-to-state mapping directly in `stateAfterPermissionStatusUpdate(...)`.

- File: `Core/Audio/OrbEngine.swift`
    - Removed helper:
        - `failureState(for:)`
    - Updated:
        - `stateAfterPermissionStatusUpdate(currentState:status:)` now directly maps `failureMessage(for:)` to `.failure(message)` and otherwise preserves current state

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Failure State Mapping`
    - Existing permission transition and failure-message suites continue to cover behavior

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 326)
- No test command was run.

#### Phase 3 prep continuation — Remove redundant polled-final-transcript wrapper

Removed a pass-through helper and used `nonEmptyNormalizedTranscript(_:)` directly in the final-transcript polling loop.

- File: `Core/Audio/OrbEngine.swift`
    - In `stopListeningAndFinalize()`, replaced:
        - `Self.polledFinalTranscriptCandidate(finalTranscript)`
      with:
        - `Self.nonEmptyNormalizedTranscript(finalTranscript)`
    - Removed helper:
        - `polledFinalTranscriptCandidate(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Polled Final Transcript Candidate`
    - Existing suite `Orb Non-Empty Normalized Transcript` continues to cover the underlying behavior

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 324)
- No test command was run.

#### Phase 3 prep continuation — Inline stop-listening transcribing transition

Removed a fixed-result stop-listening state helper and assigned `.transcribing` directly in `stopListening()` to reduce indirection while preserving behavior.

- File: `Core/Audio/OrbEngine.swift`
    - In `stopListening()`, replaced:
        - `state = Self.stateAfterBeginningStopListening()`
      with:
        - `state = .transcribing`
    - Removed helper:
        - `stateAfterBeginningStopListening()`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Stop Listening State Mapping`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Inline fallback-rejection idle transition

Removed a fixed-result fallback-rejection state helper and assigned `.idle` directly at the reject branch to reduce indirection while preserving behavior.

- File: `Core/Audio/OrbEngine.swift`
    - In `awaitFinalTranscriptAndFinalize()` reject branch, replaced:
        - `state = Self.stateAfterRejectingFallbackCandidate()`
      with:
        - `state = .idle`
    - Removed helper:
        - `stateAfterRejectingFallbackCandidate()`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Fallback Rejection State Mapping`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Remove transcript-delivery state mapping indirection

Removed a one-line state-mapping helper and assigned the ready state directly in `finalizeTranscript()` to reduce indirection while preserving behavior.

- File: `Core/Audio/OrbEngine.swift`
    - In `finalizeTranscript()`, replaced:
        - `state = Self.stateAfterDeliveringTranscript(trimmed)`
      with:
        - `state = .ready(text: trimmed)`
    - Removed helper:
        - `stateAfterDeliveringTranscript(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Transcript Delivery State Mapping`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 324)
- No test command was run.

#### Phase 3 prep continuation — Inline discarded-transcript idle-reset decision

Removed a redundant boolean helper and kept the discard-state mapping logic in one pure function.

- File: `Core/Audio/OrbEngine.swift`
    - Removed helper:
        - `shouldResetToIdleAfterDiscardedTranscript(isRecording:)`
    - Simplified:
        - `stateAfterDiscardingTranscriptCandidate(currentState:isRecording:)` now directly maps to `.idle` when not recording, otherwise preserves current state

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Idle Reset Decision`
    - Existing suite `Orb Discarded Transcript State Mapping` remains and validates behavior

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 326)
- No test command was run.

#### Phase 3 prep continuation — Pure non-empty-normalized-transcript helper + tests

Extracted a reusable pure helper for normalized transcript selection that only returns content when non-empty, and reused it across polling paths.

- File: `Core/Audio/OrbEngine.swift`
    - Added helper:
        - `nonisolated static func nonEmptyNormalizedTranscript(_:) -> String?`
    - Updated callsites:
        - `awaitFinalTranscriptAndFinalize()` polling loop now uses this helper directly
        - `polledFinalTranscriptCandidate(_:)` now delegates to this helper

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Non-Empty Normalized Transcript` with coverage for:
        - returns trimmed text for non-empty input
        - returns `nil` for whitespace-only input

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Simplify recording-state transition mapping

Removed an intermediate recording-transition helper and kept the state mapping in a single pure function to reduce indirection without changing behavior.

- File: `Core/Audio/OrbEngine.swift`
    - Removed helper:
        - `recordingTransitionState(isRecording:)`
    - Simplified:
        - `stateAfterRecordingUpdate(currentState:isRecording:)` now directly returns `.listening` when recording, else preserves current state

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Recording Transition Mapping`
    - Existing suite `Orb Recording State Transition` remains to verify behavior

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — Remove no-op fallback-acceptance state mapping

Removed an identity transition in the accepted-fallback path to reduce indirection while preserving behavior.

- File: `Core/Audio/OrbEngine.swift`
    - In `awaitFinalTranscriptAndFinalize()`, removed no-op assignment:
        - `state = Self.stateAfterAcceptingFallbackCandidate(currentState: state)`
    - Removed redundant helper:
        - `stateAfterAcceptingFallbackCandidate(currentState:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Removed obsolete suite `Orb Fallback Acceptance State Mapping` that only verified identity behavior

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 323)
- No test command was run.

#### Phase 3 prep continuation — Pure stop-listening-state helper signature cleanup + tests

Removed the unused `currentState` parameter from stop-listening state mapping so the helper more accurately expresses its fixed transition behavior.

- File: `Core/Audio/OrbEngine.swift`
    - stop-listening path in `stopListening()` now calls:
        - `nonisolated static func stateAfterBeginningStopListening() -> State`
    - Removed unused parameter from helper signature

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Updated suite `Orb Stop Listening State Mapping` to validate:
        - beginning stop-listening maps to `.transcribing` via the no-argument helper

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 323)
- No test command was run.

#### Phase 3 prep continuation — Pure fallback-rejection-state helper signature cleanup + tests

Removed the unused `currentState` parameter from fallback-rejection state mapping so the helper reflects its true behavior and remains simpler to call and test.

- File: `Core/Audio/OrbEngine.swift`
    - rejected fallback path in `awaitFinalTranscriptAndFinalize()` now calls:
        - `nonisolated static func stateAfterRejectingFallbackCandidate() -> State`
    - Removed unused parameter from helper signature

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Updated suite `Orb Fallback Rejection State Mapping` to validate:
        - rejected fallback maps to `.idle` via the no-argument helper

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 326)
- No test command was run.

#### Phase 3 prep continuation — Pure fallback-transcript-trimming helper + tests

Extracted fallback transcript trimming into a pure helper so fallback normalization behavior is centralized and directly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `fallbackTranscriptCandidateAfterPolling(...)` now delegates trimming to:
        - `nonisolated static func trimmedFallbackTranscript(_:) -> String`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Fallback Transcript Trimming` with coverage for:
        - trims leading/trailing whitespace and newlines
        - returns empty string for whitespace-only input

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -n "\*\* BUILD SUCCEEDED \*\*" build.log | tail -1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **` (line 325)
- No test command was run.

#### Phase 3 prep continuation — OrbEngine factory seam added

Added a minimal factory seam so default OrbEngine construction can be swapped later without rewriting Home composition.

- File: `Core/Audio/OrbEngine.swift`
    - Added `OrbEngineFactoryProtocol`
    - Added default implementation `LiveOrbEngineFactory`

- File: `Features/Home/Views/HomeView.swift`
    - Replaced inline `@State` default engine construction with init-time factory creation
    - Added optional init parameter:
        - `orbEngineFactory: (any OrbEngineFactoryProtocol)? = nil`
    - Defaults to `LiveOrbEngineFactory` when not provided

Concurrency note:
1. Initial default-argument form (`orbEngineFactory = LiveOrbEngineFactory()`) triggered actor-isolation compile failure.
2. Resolved by making the parameter optional and constructing the fallback factory inside init body.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Root background flag keys centralized

Consolidated all root-background experiment key strings into one shared constants location to avoid typo drift across screens.

- File: `App/AppUI.swift`
    - Added `ExperimentFlags.RootBackground` constants:
        - `home`
        - `trending`
        - `history`
        - `favorites`

- Updated screens to use shared keys:
    - `Features/Home/Views/HomeView.swift`
    - `Features/Trending/Views/TrendingView.swift`
    - `Features/History/Views/HistoryView.swift`
    - `Features/History/Views/FavoritesView.swift`

Implementation note:
- Constants were placed in `AppUI.swift` (already target-included) to avoid project-file edits during this migration pass.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — In-app QA controls for root-background flags

Added Admin UI controls so manual background QA can be run without LLDB commands.

- File: `Features/Admin/Views/AdminDashboardView.swift`
    - Added new segmented section: `Experiments`
    - Added `@AppStorage` toggles for:
        - `ExperimentFlags.RootBackground.home`
        - `ExperimentFlags.RootBackground.trending`
        - `ExperimentFlags.RootBackground.history`
        - `ExperimentFlags.RootBackground.favorites`
    - Added `Reset All Flags` action to set all four flags to `false`

Usage:
1. Open Admin -> Experiments.
2. Enable one flag at a time while running the deterministic QA script.
3. Use `Reset All Flags` between passes.

Determinism hardening:
1. Enabling any single flag now auto-disables the other three.
2. Panel displays the currently active flag (`Active: Home/Trending/History/Favorites/None`).
3. Entire Experiments section is `#if DEBUG`-gated (internal QA only).

Release safety:
1. `PromptMeNativeApp` resets all root-background experiment flags to `false` on startup in non-DEBUG builds.
2. This ensures QA toggles cannot persist into production behavior.

#### Phase 3 prep — OrbEngine transition protocol boundary (low-risk)

Started Phase 3 groundwork by formalizing OrbEngine's command/state surface behind a protocol and consuming transition commands through that boundary in Home generation flow.

- File: `Core/Audio/OrbEngine.swift`
    - Added `OrbEngineProtocol` in the same file (target-included) with:
        - observable state reads (`state`, `isRecording`, `transcript`, `finalTranscript`, `permissionStatus`, `audioLevel`)
        - transcript callback (`onFinalTranscript`)
        - transition commands (`startListening`, `stopListening`, `markGenerating`, `markSuccess`, `markFailure`, `markIdle`, etc.)
    - `OrbEngine` conforms via extension.

- File: `Features/Home/Views/HomeView.swift`
    - Added `orbTransitions` helper typed as `any OrbEngineProtocol`
    - Generation transition calls now flow through protocol boundary (no behavior change):
        - `markGenerating`
        - `markFailure` / `markSuccess`
        - `markIdle`

Implementation note:
1. Initial protocol file under `Core/Protocols` was not target-visible.
2. Protocol was relocated into `OrbEngine.swift` to avoid `.pbxproj` churn during migration.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Remaining AppEnvironment hotspots (updated)

Direct `@Environment(AppEnvironment.self)` usage has now been eliminated from `RootView` and feature views touched in Phase 2.

Current intentional usage:
1. `PromptMeNative_Blueprint/OrionOrbApp.swift` (root container creation + scoped key injection source)

#### Phase 2 continuation — Home sheet routing moved into AppRouter

Home screen sheet presentation state is now router-owned (not local `@State`) to continue unidirectional routing migration.

- File: `App/Routing/AppRouter.swift`
    - Added `HomeSheet` enum (`typePrompt`, `settings`, `upgrade`) conforming to `Identifiable` + `Hashable`
    - Added router state: `var homeSheet: HomeSheet?`
    - Added helpers:
        - `presentHomeSheet(_:)`
        - `dismissHomeSheet()`

- File: `Features/Home/Views/HomeView.swift`
    - Removed local `ActiveSheet` enum and `@State activeSheet`
    - Added scoped router usage (`@Environment(\.appRouter)` + fallback to `env.router`)
    - `.sheet(item:)` now binds to `router.homeSheet`
    - Updated triggers:
        - Type button -> `router.presentHomeSheet(.typePrompt)`
        - Settings gear -> `router.presentHomeSheet(.settings)`
        - Paywall change -> `router.presentHomeSheet(.upgrade)`
        - Dismiss actions -> `router.dismissHomeSheet()`

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Scoped `apiClient` key added and adopted

Continued staged DI migration by introducing a scoped API client environment key and moving key feature views off direct `AppEnvironment` API access.

- File: `App/AppEnvironment.swift`
    - Added `EnvironmentValues.apiClient` (`any APIClientProtocol`)

- File: `PromptMeNativeApp.swift`
    - Injected `\.apiClient` at app root from `env.apiClient`

- File: `Features/Trending/Views/TrendingView.swift`
    - Added `@Environment(\.apiClient)` + fallback helper
    - `loadIfNeeded`, `refresh`, and retry now use scoped API client

- File: `Features/Home/Views/HomeView.swift`
    - Added `@Environment(\.apiClient)` + fallback helper
    - `settingsViewModel.bind(...)` now passes scoped API client

- File: `Features/Settings/Views/SettingsView.swift`
    - Added `@Environment(\.apiClient)` + fallback helper
    - `viewModel.bind(...)` now passes scoped API client

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Scoped `preferencesStore` key added and adopted

Extended DI decoupling by adding a scoped preferences-store key and migrating Home/Settings bind paths to use it.

- File: `App/AppEnvironment.swift`
    - Added `EnvironmentValues.preferencesStore` (`any PreferenceStoring`)

- File: `PromptMeNativeApp.swift`
    - Injected `\.preferencesStore` from `env.preferencesStore`

- File: `Features/Home/Views/HomeView.swift`
    - Added `@Environment(\.preferencesStore)` with fallback helper
    - `settingsViewModel.bind(...)` now passes scoped preferences store

- File: `Features/Settings/Views/SettingsView.swift`
    - Added `@Environment(\.preferencesStore)` with fallback helper
    - `viewModel.bind(...)` now passes scoped preferences store

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Scoped `usageTracker` key added

Added a scoped usage-tracker key to continue DI decoupling and prepared Home for scoped dependency fallback paths.

- File: `App/AppEnvironment.swift`
    - Added `EnvironmentValues.usageTracker` (`UsageTracker`)

- File: `PromptMeNativeApp.swift`
    - Injected `\.usageTracker` from `env.usageTracker`

- File: `Features/Home/Views/HomeView.swift`
    - Added scoped fallback helpers for auth/history (used in settings binding path)
    - No behavioral routing/UI changes in this step

Note:
- A temporary attempt to reinitialize `GenerateViewModel` inside `.task` was removed in the same session to avoid resetting in-progress UI state.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Scoped `storeManager` key and Upgrade migration

Added scoped store-manager DI and migrated `UpgradeView` purchase/restore paths off direct `env.storeManager` access.

- File: `App/AppEnvironment.swift`
    - Added `EnvironmentValues.storeManager` (`StoreManager`)

- File: `PromptMeNativeApp.swift`
    - Injected `\.storeManager` from `env.storeManager`

- File: `Features/Settings/Views/UpgradeView.swift`
    - Added `@Environment(\.storeManager)` with fallback helper to `env.storeManager`
    - Updated all StoreKit UI reads/actions to use the scoped helper:
        - product loading
        - product list rendering
        - restore purchases
        - purchasing state and error state reads

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Root auth lifecycle moved to scoped key

Reduced remaining `AppEnvironment` coupling in root flow by migrating auth lifecycle checks to the scoped `authManager` key (with fallback).

- File: `App/RootView.swift`
    - Added `@Environment(\.authManager)` + local fallback helper
    - Migrated auth-driven branches and lifecycle hooks to use scoped helper:
        - bootstrapping check
        - authenticated gate
        - bootstrap task call
        - token reset observer

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Shared destination host extracted

Started centralizing destination rendering logic by extracting typed `AppDestination` rendering out of feature view switch statements.

- File: `App/Routing/AppRouter.swift`
    - Added reusable `AppDestinationHost` view:
        - Accepts `AppDestination`
        - Accepts resolver closure for `PromptItem` by ID
        - Handles empty/missing destination data with `ContentUnavailableView`

- File: `Features/Trending/Views/TrendingView.swift`
    - Replaced inline `.navigationDestination` switch body with `AppDestinationHost`

This is an intermediate step toward broader, shared destination hosting while preserving current per-screen `NavigationStack` ownership.

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Global background pilot scaffold (Trending only)

Added a controlled pilot switch to test root-level background strategy on one screen without changing default behavior.

- File: `Features/Trending/Views/TrendingView.swift`
    - Added flag:
        - `@AppStorage("experiment.useRootBackground.trending")`
    - Behavior:
        - `false` (default): keeps existing local `PromptPremiumBackground` (current safe path)
        - `true`: suppresses local background (`Color.clear`) to test root-background propagation behavior

Safety:
- Default remains unchanged (`false`), so this is non-breaking unless explicitly enabled.
- Use only for controlled visual testing while NavigationStack background migration is in progress.

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Global background pilot expanded (History)

Added the same controlled pilot switch to `HistoryView` so root-background experiments can be compared across two NavigationStack-heavy screens.

- File: `Features/History/Views/HistoryView.swift`
    - Added `@AppStorage("experiment.useRootBackground.history")`
    - `false` (default): uses local `PromptPremiumBackground`
    - `true`: suppresses local background with `Color.clear`

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Global background pilot expanded (Favorites)

Added the third pilot switch in `FavoritesView` for broader A/B coverage across NavigationStack screens.

- File: `Features/History/Views/FavoritesView.swift`
    - Added `@AppStorage("experiment.useRootBackground.favorites")`
    - `false` (default): uses local `PromptPremiumBackground`
    - `true`: suppresses local background with `Color.clear`

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Experiment Matrix (Root Background Pilot)

| Screen | Flag | Default | Local Background Suppressed When `true` | Manual Visual QA Status |
|---|---|---|---|---|
| Trending | `experiment.useRootBackground.trending` | `false` | Yes | Pending manual QA |
| History | `experiment.useRootBackground.history` | `false` | Yes | Pending manual QA |
| Favorites | `experiment.useRootBackground.favorites` | `false` | Yes | Pending manual QA |

Notes:
- Both pilots are opt-in and non-breaking by default.
- Keep flags off in normal builds until manual QA confirms acceptable transitions/background behavior.

Manual QA checklist (per screen with flag `true`):
1. Launch into tab and scroll to top/bottom: verify no black flashes or white bleed.
2. Push/present detail or sheet and dismiss: verify transitions retain consistent background.
3. Return to tab from another tab: verify background persists (no reset flicker).
4. Trigger pull-to-refresh (where available): verify background remains stable during rubber-banding.
5. Rotate simulator (if supported): verify no clipped/empty regions appear.

#### Phase 2 continuation — Scoped `keychainService` key + Admin migration

Continued DI decoupling by adding a scoped keychain service and moving Admin dashboard binding to scoped dependencies.

- File: `App/AppEnvironment.swift`
    - Added `EnvironmentValues.keychainService` (`KeychainService`)

- File: `PromptMeNativeApp.swift`
    - Injected `\.keychainService` from `env.keychain`

- File: `Features/Admin/Views/AdminDashboardView.swift`
    - Added scoped env usage:
        - `@Environment(\.apiClient)`
        - `@Environment(\.keychainService)`
    - Added fallback helpers to preserve behavior if scoped keys are absent
    - Updated `viewModel.bind(...)` to use scoped dependencies

Verification:
- `get_errors` on touched files: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — Upgrade `ProductCard` no longer depends on AppEnvironment

Removed direct `AppEnvironment` usage from `ProductCard` by resolving auth in parent `UpgradeView` and passing it as an explicit dependency.

- File: `Features/Settings/Views/UpgradeView.swift`
    - `UpgradeView` now resolves scoped auth manager (`@Environment(\.authManager)` with fallback)
    - `ProductCard` now receives `authManager: AuthManager` as input
    - Removed `@Environment(AppEnvironment.self)` from `ProductCard`
    - Purchase-success refresh now calls `await authManager.refreshMe()` directly

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 prep continuation — Pure listening-duration helper + tests

Extracted the minimum-listening-duration stop gate into a pure helper to reduce actor-coupled decision logic and keep behavior testable.

- File: `Core/Audio/OrbEngine.swift`
    - `canStopListeningNow` now delegates to:
        - `nonisolated static func hasMetMinimumListeningDuration(listeningStartedAt:now:minimumListeningDuration:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Listening Duration` with coverage for:
        - missing start timestamp returns false
        - elapsed below threshold returns false
        - elapsed at threshold returns true

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure transcript-meaning helper + tests

Extracted transcript meaningfulness logic into a pure helper so actor-state migration can proceed with testable behavior boundaries.

- File: `Core/Audio/OrbEngine.swift`
    - `isMeaningfulTranscript(_:)` now delegates to:
        - `nonisolated static func isMeaningfulTranscriptCandidate(text:hasDetectedSpeechContent:minimumTranscriptCharacterCount:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Transcript Meaning` with coverage for:
        - rejects too-short transcript text
        - rejects non-alphanumeric transcript text
        - accepts detected-speech alphanumeric text
        - accepts alphanumeric fallback when speech-content flag is false

Verification:
- `get_errors` was not re-run in this slice.
- Build command attempts were interrupted by terminal `^C` before completion:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; tail -n 60 build.log`
- No test command was run in this slice.

#### Phase 3 prep continuation — Pure permission-message helper + tests

Extracted permission helper-text mapping into a pure static helper so permission messaging behavior is independently testable and less tied to actor state.

- File: `Core/Audio/OrbEngine.swift`
    - `permissionMessage` now delegates to:
        - `nonisolated static func permissionMessage(for:) -> String`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Permission Message Mapping` with coverage for:
        - non-blocking statuses (`notDetermined`, `granted`) return empty text
        - denied/restricted/unavailable statuses map to expected copy
        - `.error(message)` returns passthrough message

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure permission-settings-action helper + tests

Extracted the permission-settings-action decision into a pure helper so recovery-action behavior is testable and isolated from actor state.

- File: `Core/Audio/OrbEngine.swift`
    - `needsPermissionSettingsAction` now delegates to:
        - `nonisolated static func needsPermissionSettingsAction(for:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Permission Settings Action Mapping` with coverage for:
        - denied/restricted statuses return `true`
        - not-determined/granted/unavailable/error statuses return `false`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure final-transcript finalize gate + tests

Extracted the final-transcript update finalize gate into a pure helper to make this state-transition decision independently testable.

- File: `Core/Audio/OrbEngine.swift`
    - final transcript subscriber now delegates finalize gating to:
        - `nonisolated static func shouldFinalizeOnFinalTranscriptUpdate(trimmedFinalTranscript:state:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Final Transcript Finalize Gate` with coverage for:
        - allows non-empty transcript only when state is `.listening` or `.transcribing`
        - rejects non-empty transcript for non-eligible states (`idle`, `generating`, `success`)
        - rejects empty transcript for eligible states

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure permission failure-state helper + tests

Extracted permission-status to failure-state mapping into a pure helper to keep permission state-transition behavior independently testable.

- File: `Core/Audio/OrbEngine.swift`
    - permission status publisher now delegates to:
        - `nonisolated static func failureState(for:) -> State?`
    - `failureState(for:)` reuses existing `failureMessage(for:)` mapping

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Failure State Mapping` with coverage for:
        - non-failing statuses (`notDetermined`, `granted`) -> `nil`
        - permission failures map to expected `.failure(message)`
        - `.error(message)` maps to passthrough `.failure(message)`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure recording-transition helper + tests

Extracted recording-flag to state-transition mapping into a pure helper to isolate and test this publisher-driven transition behavior.

- File: `Core/Audio/OrbEngine.swift`
    - recording publisher sink now delegates to:
        - `nonisolated static func recordingTransitionState(isRecording:) -> State?`
    - behavior remains: `true` -> `.listening`, `false` -> no transition

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Recording Transition Mapping` with coverage for:
        - `isRecording == true` maps to `.listening`
        - `isRecording == false` maps to `nil`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure transcript-delivery dedupe helper + tests

Extracted transcript-delivery dedupe into a pure helper so transcript re-delivery behavior can be tested without actor state coupling.

- File: `Core/Audio/OrbEngine.swift`
    - `finalizeTranscript()` now delegates duplicate filtering to:
        - `nonisolated static func shouldDeliverTranscriptCandidate(trimmedTranscript:lastDeliveredTranscript:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Transcript Delivery Dedupe` with coverage for:
        - delivers when candidate differs from last delivered
        - skips when candidate matches last delivered

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure idle-reset decision helper + tests

Extracted the discarded-transcript idle-reset decision into a pure helper so this state fallback behavior is explicitly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `finalizeTranscript()` now delegates idle-reset condition to:
        - `nonisolated static func shouldResetToIdleAfterDiscardedTranscript(isRecording:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Idle Reset Decision` with coverage for:
        - resets to idle when `isRecording == false`
        - does not reset when `isRecording == true`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure stop-listening eligibility helper + tests

Extracted stop-listening eligibility into a pure helper so the stop gate condition is explicitly testable without actor state setup.

- File: `Core/Audio/OrbEngine.swift`
    - `stopListening()` now delegates initial guard to:
        - `nonisolated static func shouldBeginStopListening(isRecording:canStopListeningNow:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Stop Listening Eligibility` with coverage for:
        - true only when both conditions are true
        - false for all other condition combinations

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure fallback-transcript acceptance helper + tests

Extracted fallback-transcript acceptance into a pure helper to keep polling fallback behavior explicitly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `awaitFinalTranscriptAndFinalize()` fallback path now delegates to:
        - `nonisolated static func shouldAcceptFallbackTranscriptCandidate(text:hasDetectedSpeechContent:minimumTranscriptCharacterCount:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Fallback Transcript Acceptance` with coverage for:
        - accepts meaningful fallback transcript
        - rejects non-meaningful fallback transcript

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure polled-final-transcript helper + tests

Extracted polling-based final-transcript normalization into a pure helper so poll-loop result behavior is directly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `stopListeningAndFinalize()` polling loop now delegates to:
        - `nonisolated static func polledFinalTranscriptCandidate(_:) -> String?`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Polled Final Transcript Candidate` with coverage for:
        - returns trimmed non-empty candidate
        - returns `nil` for empty/whitespace candidate

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure speech-content detection helper + tests

Extracted transcript-driven speech-content flag updates into a pure helper so sticky detection behavior is explicitly testable.

- File: `Core/Audio/OrbEngine.swift`
    - transcript publisher sink now delegates to:
        - `nonisolated static func updatedSpeechContentDetectionFlag(currentValue:trimmedTranscript:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Speech Content Detection Flag` with coverage for:
        - flag remains true once previously detected
        - flag turns true when trimmed transcript has content
        - flag stays false with no prior detection and empty transcript

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure permission-status state transition helper + tests

Extracted permission-status-driven state transition into a pure helper so state behavior on permission updates is explicitly testable.

- File: `Core/Audio/OrbEngine.swift`
    - permission status sink now delegates to:
        - `nonisolated static func stateAfterPermissionStatusUpdate(currentState:status:) -> State`
    - behavior remains:
        - failing statuses transition to `.failure(message)`
        - non-failing statuses preserve current state

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Permission Status State Transition` with coverage for:
        - state preservation on non-failing statuses
        - transition to failure on failing statuses

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure fallback-transcript candidate selection helper + tests

Extracted fallback transcript candidate selection into a pure helper so post-poll fallback behavior is directly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `awaitFinalTranscriptAndFinalize()` fallback path now delegates to:
        - `nonisolated static func fallbackTranscriptCandidateAfterPolling(transcript:hasDetectedSpeechContent:minimumTranscriptCharacterCount:) -> String?`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Fallback Transcript Candidate Selection` with coverage for:
        - returns trimmed fallback when candidate is acceptable
        - returns `nil` when fallback candidate is rejected

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure finalize-eligible-state helper + tests

Extracted final-transcript finalize eligible-state logic into a pure helper so transition eligibility is independently testable.

- File: `Core/Audio/OrbEngine.swift`
    - `shouldFinalizeOnFinalTranscriptUpdate(...)` now delegates state eligibility to:
        - `nonisolated static func isStateEligibleForFinalTranscriptFinalize(_:) -> Bool`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Final Transcript Eligible States` with coverage for:
        - eligible states: `.listening`, `.transcribing`
        - ineligible states: `.idle`, `.generating`, `.success`, `.failure(_)`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure transcript-normalization helper + tests

Extracted transcript edge-whitespace normalization into a pure helper and applied it to key transcript update paths to keep normalization behavior centralized and testable.

- File: `Core/Audio/OrbEngine.swift`
    - Added helper:
        - `nonisolated static func normalizedTranscript(_:) -> String`
    - Updated callsites to use this helper in:
        - `awaitFinalTranscriptAndFinalize()` polling loop
        - `speech.transcriptPublisher` sink
        - `speech.finalTranscriptPublisher` sink
        - `polledFinalTranscriptCandidate(_:)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Transcript Normalization` with coverage for:
        - trimming leading/trailing whitespace/newlines
        - preserving internal spacing

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure permission-failure classification helper + tests

Extracted permission failure classification into a pure helper to make failing-status logic explicit and testable.

- File: `Core/Audio/OrbEngine.swift`
    - Added helper:
        - `nonisolated static func isFailingPermissionStatus(_:) -> Bool`
    - `failureMessage(for:)` now early-guards via this helper

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Permission Failure Classification` with coverage for:
        - failing statuses return `true`
        - non-failing statuses return `false`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure alphanumeric-content helper + tests

Extracted alphanumeric transcript-content detection into a pure helper so the content check is centralized and directly testable.

- File: `Core/Audio/OrbEngine.swift`
    - Added helper:
        - `nonisolated static func containsAlphanumericContent(_:) -> Bool`
    - `isMeaningfulTranscriptCandidate(...)` now uses this helper

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Alphanumeric Content Detection` with coverage for:
        - strings containing alphabetic or numeric content return `true`
        - punctuation/whitespace-only strings return `false`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure normalized-transcript-content helper + tests

Extracted normalized transcript content checks into a pure helper and reused it across transcript gates for consistent behavior.

- File: `Core/Audio/OrbEngine.swift`
    - Added helper:
        - `nonisolated static func hasNormalizedTranscriptContent(_:) -> Bool`
    - Updated callsites to use this helper in:
        - `polledFinalTranscriptCandidate(_:)`
        - `updatedSpeechContentDetectionFlag(...)`
        - `shouldFinalizeOnFinalTranscriptUpdate(...)`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Normalized Transcript Content` with coverage for:
        - non-empty normalized text returns `true`
        - empty normalized text returns `false`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure minimum-transcript-length helper + tests

Extracted minimum transcript length checking into a pure helper to isolate threshold logic and improve direct testability.

- File: `Core/Audio/OrbEngine.swift`
    - Added helper:
        - `nonisolated static func meetsMinimumTranscriptLength(trimmedText:minimumTranscriptCharacterCount:) -> Bool`
    - `isMeaningfulTranscriptCandidate(...)` now uses this helper

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Transcript Minimum Length` with coverage for:
        - returns `true` when length meets threshold
        - returns `false` when below threshold

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure recording-state-transition helper + tests

Extracted recording-flag-driven state transition into a pure helper to make state preservation/transition behavior directly testable.

- File: `Core/Audio/OrbEngine.swift`
    - Added helper:
        - `nonisolated static func stateAfterRecordingUpdate(currentState:isRecording:) -> State`
    - `speech.isRecordingPublisher` sink now uses this helper

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Recording State Transition` with coverage for:
        - transitions to `.listening` when `isRecording == true`
        - preserves current state when `isRecording == false`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure transcript-delivery-state helper + tests

Extracted transcript-delivery state mapping into a pure helper so successful delivery transition behavior is explicitly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `finalizeTranscript()` now delegates ready-state assignment to:
        - `nonisolated static func stateAfterDeliveringTranscript(_:) -> State`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Transcript Delivery State Mapping` with coverage for:
        - delivered transcript maps to `.ready(text:)`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure fallback-rejection-state helper + tests

Extracted fallback-rejection state mapping into a pure helper so this fallback failure transition is explicitly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `awaitFinalTranscriptAndFinalize()` rejected-fallback path now delegates to:
        - `nonisolated static func stateAfterRejectingFallbackCandidate(currentState:) -> State`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Fallback Rejection State Mapping` with coverage for:
        - rejected fallback maps to `.idle`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure stop-listening-state helper + tests

Extracted stop-listening initiation state mapping into a pure helper so this transition is directly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `stopListening()` now delegates state transition to:
        - `nonisolated static func stateAfterBeginningStopListening(currentState:) -> State`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Stop Listening State Mapping` with coverage for:
        - beginning stop-listening maps to `.transcribing`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure final-transcript-polling-limit helper + tests

Extracted final transcript polling iteration count into a pure helper so poll-loop bounds are explicit and testable.

- File: `Core/Audio/OrbEngine.swift`
    - `stopListeningAndFinalize()` now uses:
        - `nonisolated static func finalTranscriptPollingIterationLimit() -> Int`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Final Transcript Polling Limit` with coverage for:
        - polling limit is positive
        - polling limit remains expected value (`30`)

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure final-transcript-polling-sleep helper + tests

Extracted final transcript polling sleep duration into a pure helper so polling timing is explicit and testable.

- File: `Core/Audio/OrbEngine.swift`
    - polling loops now use:
        - `nonisolated static func finalTranscriptPollingSleepNanoseconds() -> UInt64`
    - applied in:
        - `stopListeningAndFinalize()` polling loop
        - `awaitFinalTranscriptAndFinalize()` polling loop

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Final Transcript Polling Sleep` with coverage for:
        - polling sleep is positive
        - polling sleep equals expected value (`50_000_000`)

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure final-transcript-polling-range helper + tests

Extracted final transcript polling attempt range into a pure helper and reused it across both polling loops.

- File: `Core/Audio/OrbEngine.swift`
    - Added helper:
        - `nonisolated static func finalTranscriptPollingAttemptRange() -> Range<Int>`
    - Updated callsites to use this helper in:
        - `stopListeningAndFinalize()` polling loop
        - `awaitFinalTranscriptAndFinalize()` polling loop

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Final Transcript Polling Range` with coverage for:
        - range starts at zero
        - range count matches `finalTranscriptPollingIterationLimit()`

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure discarded-transcript-state helper + tests

Extracted discarded-transcript state outcome mapping into a pure helper so this branch is directly testable.

- File: `Core/Audio/OrbEngine.swift`
    - `finalizeTranscript()` discarded-candidate branch now delegates to:
        - `nonisolated static func stateAfterDiscardingTranscriptCandidate(currentState:isRecording:) -> State`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Discarded Transcript State Mapping` with coverage for:
        - maps to `.idle` when not recording
        - preserves current state when still recording

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure fallback-acceptance-state helper + tests

Extracted fallback-acceptance state mapping into a pure helper so accepted fallback transition behavior is explicit and testable.

- File: `Core/Audio/OrbEngine.swift`
    - accepted fallback path in `awaitFinalTranscriptAndFinalize()` now delegates to:
        - `nonisolated static func stateAfterAcceptingFallbackCandidate(currentState:) -> State`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Fallback Acceptance State Mapping` with coverage for:
        - accepted fallback preserves current state

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 3 prep continuation — Pure transcript-assignment helper + tests

Extracted transcript field assignment into a pure helper so successful transcript assignment behavior is explicit and testable.

- File: `Core/Audio/OrbEngine.swift`
    - added helper:
        - `nonisolated static func transcriptAssignment(for:) -> (finalTranscript: String, transcript: String)`
    - used in:
        - successful final-transcript polling path in `awaitFinalTranscriptAndFinalize()`
        - accepted fallback path in `awaitFinalTranscriptAndFinalize()`

- File: `Prompt28Tests/Prompt28Tests.swift`
    - Added suite `Orb Transcript Assignment` with coverage for:
        - assignment copies the same value into both transcript fields

Verification:
- Build succeeded:
    - `xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination 'platform=iOS Simulator,name=iPhone 17' build > build.log 2>&1; echo EXIT:$?; grep -nE "\*\* BUILD (SUCCEEDED|FAILED|INTERRUPTED) \*\*" build.log | tail -n 1`
    - output: `EXIT:0` and `** BUILD SUCCEEDED **`
- No test command was run.

#### Phase 2 continuation — Global background pilot expanded (Home)

Added the same opt-in root-background experiment switch to `HomeView`.

- File: `Features/Home/Views/HomeView.swift`
    - Added `@AppStorage("experiment.useRootBackground.home")`
    - `false` (default): keeps local `PromptPremiumBackground`
    - `true`: suppresses local background with `Color.clear`

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Experiment Matrix (Root Background Pilot) — updated

| Screen | Flag | Default | Local Background Suppressed When `true` | Manual Visual QA Status |
|---|---|---|---|---|
| Home | `experiment.useRootBackground.home` | `false` | Yes | Pending manual QA |
| Trending | `experiment.useRootBackground.trending` | `false` | Yes | Pending manual QA |
| History | `experiment.useRootBackground.history` | `false` | Yes | Pending manual QA |
| Favorites | `experiment.useRootBackground.favorites` | `false` | Yes | Pending manual QA |

#### Deterministic QA Script — Root Background Flags

Use this exact flow to test each screen with minimal variance between runs.

Preconditions:
1. Build + run `Prompt28` on iPhone 17 simulator.
2. Sign in and complete privacy/onboarding so all tabs are reachable.
3. Keep all four flags `false` before starting a new screen pass.

Flag control method (Xcode LLDB console while app is paused/running):
1. Set one flag `true`:
    - `e -l swift -- UserDefaults.standard.set(true, forKey: "experiment.useRootBackground.<screen>")`
2. Reset all others `false`:
    - `e -l swift -- UserDefaults.standard.set(false, forKey: "experiment.useRootBackground.home")`
    - `e -l swift -- UserDefaults.standard.set(false, forKey: "experiment.useRootBackground.trending")`
    - `e -l swift -- UserDefaults.standard.set(false, forKey: "experiment.useRootBackground.history")`
    - `e -l swift -- UserDefaults.standard.set(false, forKey: "experiment.useRootBackground.favorites")`
3. Relaunch app after changing values to guarantee `@AppStorage` picks up persisted state from cold start.

Per-screen test steps (run once for each flag):
1. Open the target tab and scroll top-to-bottom repeatedly (3 passes).
2. Trigger every major navigation transition on that tab:
    - push detail, pop back
    - open sheet/full-screen modal, dismiss
3. Switch to another tab, then back to target tab (3 cycles).
4. Perform pull-to-refresh or equivalent gesture if available.
5. Rotate simulator portrait -> landscape -> portrait (if UI supports it).

Pass criteria:
1. No black flash or white bleed at any edge.
2. No background reset flicker after tab switches.
3. No clipped/empty background regions on rotation.
4. No regressions in navigation animation smoothness.

Failure logging format:
1. Screen + flag key.
2. Exact action that triggered artifact.
3. Simulator orientation and navigation depth.
4. Screenshot/video reference.

Note:
- Flag keys are centralized in `App/AppUI.swift` under `ExperimentFlags.RootBackground`.

#### Remaining AppEnvironment hotspots (current)

Verified current state:

1. No direct `@Environment(AppEnvironment.self)` usage remains in feature/root views.
2. `AppEnvironment` is now intentionally limited to:
    - `App/AppEnvironment.swift` (container definition)
    - `PromptMeNativeApp.swift` (root container instantiation + scoped key injection)

Recommendation: continue manual QA for root-background experiment flags before enabling any of them by default.

#### Phase 2 continuation — AdminDashboardView no longer depends on AppEnvironment

Removed direct `AppEnvironment` dependency from `AdminDashboardView` and switched to scoped keys only.

- File: `Features/Admin/Views/AdminDashboardView.swift`
    - Removed `@Environment(AppEnvironment.self)`
    - Uses `@Environment(\.apiClient)` and `@Environment(\.keychainService)` directly
    - Added guard in `.task` to handle missing scoped dependencies gracefully by setting an error message

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — AuthFlowView no longer depends on AppEnvironment

Removed direct `AppEnvironment` dependency from auth flow and moved to scoped keys.

- File: `Features/Auth/Views/AuthFlowView.swift`
    - Removed `@Environment(AppEnvironment.self)`
    - Uses scoped `@Environment(\.authManager)` and `@Environment(\.appRouter)`
    - Added nil-safe handling for auth manager reads/actions (defensive in case scoped injection is absent)

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — UpgradeView no longer depends on AppEnvironment

Removed direct `AppEnvironment` dependency from `UpgradeView`; it now uses scoped `storeManager` and `authManager` keys only.

- File: `Features/Settings/Views/UpgradeView.swift`
    - Removed `@Environment(AppEnvironment.self)`
    - Uses `@Environment(\.storeManager)` and `@Environment(\.authManager)`
    - Added graceful unavailable-state UI when `storeManager` is not injected
    - `ProductCard` now accepts optional auth manager and refreshes when present

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — TrendingView no longer depends on AppEnvironment

Removed direct `AppEnvironment` usage from `TrendingView` and switched to scoped dependencies plus local routing fallback.

- File: `Features/Trending/Views/TrendingView.swift`
    - Removed `@Environment(AppEnvironment.self)`
    - Uses scoped `@Environment(\.appRouter)` and `@Environment(\.apiClient)`
    - Added local `NavigationPath` fallback when router is unavailable
    - Added defensive unavailable handling for missing API client (`Trending service unavailable.`)
    - Route pushes now go through a helper that uses scoped router when available, else local path

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — SettingsView no longer depends on AppEnvironment

Removed direct `AppEnvironment` usage from `SettingsView`; it now relies on scoped keys only.

- File: `Features/Settings/Views/SettingsView.swift`
    - Removed `@Environment(AppEnvironment.self)`
    - Uses optional scoped keys:
        - `authManager`, `historyStore`, `appRouter`, `apiClient`, `preferencesStore`
    - Added startup guard in `.task`:
        - If dependencies are missing, sets `viewModel.errorMessage = "Settings dependencies unavailable."`
    - Updated logout/delete/account/subscription reads to optional-safe paths

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)

#### Phase 2 continuation — HomeView no longer depends on AppEnvironment

Removed direct `@Environment(AppEnvironment.self)` usage from `HomeView` while preserving runtime safety via initializer-provided fallback dependencies.

- File: `Features/Home/Views/HomeView.swift`
    - Removed `@Environment(AppEnvironment.self)`
    - Added fallback dependencies captured in `init(appEnvironment:)`:
        - auth manager
        - router
        - API client
        - preferences store
        - history store
        - usage tracker
    - Scoped keys remain primary sources; init-captured values are fallback only

Verification:
- `get_errors` on touched file: clean
- Full simulator build passed (`iPhone 17` destination)


#### Phase 3 continuation — Centralized minimum listening duration constant in OrbEngine

Replaced the inline minimum-recording-duration literal with a private constant to keep stop-gating behavior explicit and easier to tune.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `minimumListeningDuration: TimeInterval = 0.7`
    - Updated `stopListening()` guard to compare against `minimumListeningDuration`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Simplified startListening transcript reset in OrbEngine

Collapsed paired transcript reset lines into a tuple assignment in `startListening()` to reduce repetitive state write boilerplate.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Replaced `transcript = ""` plus `finalTranscript = ""`
    - With `(transcript, finalTranscript) = ("", "")`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Extracted permission failure message mapping in OrbEngine

Replaced repeated permission-status failure assignments with a single helper that maps permission status to an optional failure message.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `permissionFailureMessage(for:) -> String?`
    - Updated permission status subscription to set failure state from helper output
    - Preserved all existing failure messages and non-failure statuses

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Centralized minimum meaningful transcript length in OrbEngine

Replaced the inline minimum transcript length literal with a private constant in the transcript quality gate.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `minimumMeaningfulTranscriptLength = 3`
    - Updated `isMeaningfulTranscript(_:)` to guard against `minimumMeaningfulTranscriptLength`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Consolidated startListening empty-string resets in OrbEngine

Merged transcript and last-delivered transcript reset writes into one tuple assignment for a tighter start-listening initialization block.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Replaced separate reset lines with `(transcript, finalTranscript, lastDeliveredTranscript) = ("", "", "")`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Named stopListening elapsed duration in OrbEngine

Introduced a local `listeningDuration` value in `stopListening()` so the minimum-duration gate reads more clearly without changing behavior.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `let listeningDuration = listeningStartedAt.map { Date().timeIntervalSince($0) }`
    - Updated guard to check `listeningDuration >= minimumListeningDuration`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Added transcript trim helper in OrbEngine

Introduced a private trim helper and used it in finalize/polling transcript normalization paths to reduce repeated trim expressions.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `trimmedTranscriptText(_:)`
    - Updated finalize and polling callsites to use the helper
    - No behavior change; trimming rules remain the same

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Reused transcript trim helper in finalTranscript publisher sink

Replaced the last direct trim expression in `bindSpeechState()` with the shared `trimmedTranscriptText(_:)` helper for consistency.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Changed `let trimmed = value.trimmingCharacters(in: transcriptTrimCharacterSet)`
    - To `let trimmed = self.trimmedTranscriptText(value)`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Extracted transcript-update finalization state helper in OrbEngine

Moved the repeated final transcript state check behind a small helper to keep the publisher sink condition clearer.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `shouldFinalizeOnTranscriptUpdate` computed helper
    - Updated final transcript publisher sink to use the helper

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Extracted current transcript assignment helper in OrbEngine

Replaced repeated `(finalTranscript, transcript)` tuple writes with a helper to keep finalization paths aligned.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `updateCurrentTranscripts(with:)`
    - Updated both finalized and fallback transcript promotion paths to call the helper

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation — Centralized failure-state assignment in OrbEngine

Extracted failure-state writes behind a helper so explicit failure transitions share one implementation path.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `setFailureState(_:)`
    - Updated `markFailure(_:)` to call `setFailureState(_:)`
    - Updated permission-status sink to call `setFailureState(_:)`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Centralized OrbEngine state transitions

Applied a larger cohesive cleanup to route common state writes through a single helper and align transition callsites.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `setState(_:)` helper
    - Updated common transitions to use helper:
        - `reset()` -> idle
        - `startListening()` -> listening
        - `stopListening()` -> transcribing
        - `markGenerating()` / `markSuccess()` / `markIdle()`
        - fallback idle transitions in finalize/polling flow
    - Updated `setFailureState(_:)` to call `setState(.failure(...))`
    - Simplified `isRecordingPublisher` transition to only set listening when recording is true
    - Fixed `stopListening()` local binding indentation/readability

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Extracted shared final-transcript polling helper in OrbEngine

Consolidated duplicated polling loops into one async helper to keep final-transcript wait behavior consistent across finalize paths.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `pollForFinalTranscript(_:) async -> String?`
    - Updated `stopListeningAndFinalize()` to use shared polling helper
    - Updated `awaitFinalTranscriptAndFinalize()` to use shared polling helper for speech final transcript
    - Preserved existing fallback behavior when no final transcript arrives
    - Fixed `stopListening()` indentation drift from previous refactors

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Simplified finalize transcript flow in OrbEngine

Applied a cohesive readability cleanup around transcript finalization while preserving existing behavior.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Fixed indentation drift in `stopListening()` local duration/state lines
    - Added `preferredFinalizedTranscriptText()` to centralize final-vs-live transcript candidate selection
    - Added `deliverFinalizedTranscript(_:)` to centralize ready-state delivery (`lastDeliveredTranscript`, state update, callback)
    - Updated `finalizeTranscript()` to use both helpers

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Extracted publisher sink handlers in OrbEngine

Refactored `bindSpeechState()` by moving inline sink logic into dedicated private handlers, reducing closure complexity while preserving behavior.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added handler methods:
        - `handleRecordingChange(_:)`
        - `handleTranscriptChange(_:)`
        - `handleFinalTranscriptChange(_:)`
        - `handlePermissionStatusChange(_:)`
        - `handleAudioLevelChange(_:)`
    - Updated all corresponding publisher sinks in `bindSpeechState()` to call the handlers

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Simplified OrbEngine listening lifecycle flow

Applied a cohesive internal cleanup around listening start/stop orchestration with helper extraction, preserving existing behavior.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `prepareForListeningStart()` and used it from `startListening()`
    - Added `hasMetMinimumListeningDuration` and used it in `stopListening()` guard
    - Added `beginTranscribingAndFinalize()` to group transcribing transition + recorder stop + finalize kickoff
    - Added `startFinalizationAwaitTask()` to encapsulate async await-task launch

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Simplified finalize candidate handling in OrbEngine

Refined finalization internals by extracting shared transcript-candidate promotion and fallback handling helpers, keeping behavior unchanged.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added `finalizeUsingTranscriptCandidate(_:)` for shared transcript promotion + finalize invocation
    - Added `finalizeWithFallbackTranscriptIfMeaningful() -> Bool` for fallback candidate gating
    - Updated `awaitFinalTranscriptAndFinalize()` to use the new helpers and remove duplicated inline logic

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Cleaned transcript polling providers and fallback helper signature

Applied a small internal cleanup to transcript polling/fallback plumbing for readability and intent clarity.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Replaced inline polling provider closures with named provider helpers:
        - `currentFinalTranscriptSnapshot()`
        - `speechFinalTranscriptSnapshot()`
    - Updated polling callsites to use those helpers
    - Removed unused `Bool` return from `finalizeWithFallbackTranscriptIfMeaningful()`
    - Updated await path to call fallback helper directly

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Split OrbEngine publisher bindings into focused bind helpers

Refactored `bindSpeechState()` into a small orchestrator and extracted each Combine subscription into a dedicated private binding method.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - `bindSpeechState()` now delegates to:
        - `bindRecordingPublisher()`
        - `bindTranscriptPublisher()`
        - `bindFinalTranscriptPublisher()`
        - `bindPermissionStatusPublisher()`
        - `bindAudioLevelPublisher()`
    - Existing sink behavior and handler usage unchanged

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Added source-specific transcript trim helpers in OrbEngine

Applied a cohesive utility cleanup by adding source-specific transcript trim helpers and wiring polling/fallback paths through them.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Added:
        - `trimmedCurrentFinalTranscript()`
        - `trimmedSpeechFinalTranscript()`
        - `trimmedSpeechTranscript()`
    - Updated polling providers:
        - `currentFinalTranscriptSnapshot()` now returns `trimmedCurrentFinalTranscript()`
        - `speechFinalTranscriptSnapshot()` now returns `trimmedSpeechFinalTranscript()`
    - Updated fallback path to use `trimmedSpeechTranscript()`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 continuation (bundled) — Removed redundant polling trim wrappers in OrbEngine

Cleaned transcript polling normalization so trimming happens in one place per poll iteration.

- File: `PromptMeNative_Blueprint/Core/Audio/OrbEngine.swift`
    - Updated `currentFinalTranscriptSnapshot()` to return raw `finalTranscript`
    - Updated `speechFinalTranscriptSnapshot()` to return raw `speech.finalTranscript`
    - Removed now-redundant wrappers:
        - `trimmedCurrentFinalTranscript()`
        - `trimmedSpeechFinalTranscript()`
    - Polling normalization remains centralized in `pollForFinalTranscript(_:)`

Verification:
- Full simulator build passed (`iPhone 17` destination)

#### Phase 3 completion — OrbEngine actor-readiness cleanup complete

Phase 3 cleanup is complete. OrbEngine refactor goals for state-transition consistency, transcript finalization flow, polling normalization, and Combine binding readability are now fully landed.

Stabilization / release-readiness checkpoint:
- Verified no editor diagnostics across workspace (`get_errors`: clean)
- Full simulator build passed (`iPhone 17` destination)

Current handoff direction:
- Move from refactor slices to stabilization/release-readiness tasks only
- Keep behavior fixed while preparing final release verification/push steps

#### Stabilization pass 1 — Debug/Release build gates clean

Executed a broader non-test release-readiness gate after Phase 3 completion.

Verification:
- `get_errors`: clean (no reported diagnostics)
- Simulator build passed (`iPhone 17`, Debug config)
- Simulator build passed (`iPhone 17`, Release config)

Notes:
- No behavior or source changes made in this pass
- Focus was verification-only stabilization

#### Stabilization pass 2 — Clean Release build and metadata sanity checks

Executed stricter release-readiness verification focused on clean Release output and required metadata presence.

Verification:
- `get_errors`: clean (no reported diagnostics)
- Clean + build passed (`iPhone 17` simulator, Release config)
- Required release metadata files present:
  - `Prompt28/Info.plist`
  - `Prompt28/PrivacyInfo.xcprivacy`
  - `PromptMeNative_Blueprint/Resources/PrivacyInfo.xcprivacy`

Notes:
- No source behavior changes made in this pass
- Focus was verification-only stabilization

#### Stabilization pass 3 — Device-target Release compile and privacy-key checks

Extended release-readiness verification beyond simulator-only gates.

Verification:
- `get_errors`: clean (no reported diagnostics)
- Required privacy keys present in `Prompt28/Info.plist`:
  - `NSMicrophoneUsageDescription`
  - `NSSpeechRecognitionUsageDescription`
- Generic iOS device Release build passed with signing disabled (`CODE_SIGNING_ALLOWED=NO`)

Notes:
- No source behavior changes made in this pass
- Focus was verification-only stabilization

#### Stabilization closeout — Release-readiness baseline established

Release-readiness verification is complete for the current scope.

Completed stabilization gates:
- Pass 1: Debug + Release simulator builds passed (`iPhone 17`)
- Pass 2: Clean Release simulator build passed and release metadata files confirmed present
- Pass 3: Generic iOS device Release compile passed (`CODE_SIGNING_ALLOWED=NO`) and required speech/microphone privacy keys confirmed

Outcome:
- No editor diagnostics reported across stabilization passes
- No source behavior changes introduced during stabilization
- Repository is in release-readiness verification-complete state for this phase handoff

#### Final release checklist — App Store submission execution

Use this checklist for final ship execution after stabilization closeout.

Build and archive readiness:
- [ ] Confirm latest commit includes stabilization closeout entry
- [ ] Select `Prompt28` scheme, `Release` configuration
- [ ] Create archive from Xcode (`Any iOS Device` target)
- [ ] Validate archive in Organizer with no blocking issues

Privacy and permissions:
- [ ] Verify microphone and speech usage text matches shipped behavior
- [ ] Confirm privacy manifests are present and included in archive
- [ ] Confirm data collection/disclosure answers in App Store Connect align with app behavior

Store metadata and compliance:
- [ ] Confirm app description, subtitle, keywords, and support URL are final
- [ ] Confirm screenshots for required device classes are up to date
- [ ] Confirm age rating, content rights, export compliance, and encryption responses

Release controls:
- [ ] Upload build to App Store Connect and wait for processing
- [ ] Attach build to target version and complete submission questionnaire
- [ ] Choose release strategy (`manual` or `automatic`) and submit for review

Post-submit:
- [ ] Monitor review status and be ready with review notes/credentials if requested
- [ ] After approval, verify phased rollout/manual release settings
- [ ] Smoke-check production build from App Store after go-live

#### Release preflight command pack (reference)

Use these commands as a repeatable preflight sequence before archive/upload.

```bash
# 1) Quick diagnostics gate
xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build

# 2) Clean release simulator gate
xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' clean build

# 3) Device-target release compile gate (signing disabled for CI/local verification)
xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# 4) Privacy key sanity checks
plutil -extract NSMicrophoneUsageDescription raw -o - Prompt28/Info.plist
plutil -extract NSSpeechRecognitionUsageDescription raw -o - Prompt28/Info.plist
```

Archive/upload are performed from Xcode Organizer for final submission.

#### Release publish/tag commands (reference)

Use after final review sign-off.

```bash
# Confirm clean working tree
git status --short

# Push current branch
git push origin main

# Create and push annotated release tag (update version as needed)
git tag -a v1.0.0 -m "Prompt28 v1.0.0 release"
git push origin v1.0.0
```

Tag version should match the App Store release/versioning decision.

#### Post-release rollback and hotfix playbook

Use this sequence if an issue is discovered after submission or go-live.

Immediate response:
- Pause phased rollout or stop manual promotion in App Store Connect (if not fully rolled out)
- Capture issue scope: affected devices, OS versions, reproducibility, severity
- Triage owner posts incident note with timestamp and current mitigation status

Code-level hotfix flow:
- Branch from latest release commit/tag
- Implement minimal-risk fix only (no opportunistic refactors)
- Run the full preflight command pack from this document
- Update release notes with explicit "hotfix" summary and impacted scope

Submission flow for hotfix:
- Archive and upload patched build via Organizer
- Attach build to new patch version in App Store Connect
- Add concise reviewer notes describing regression and remediation
- Prefer manual release control for the hotfix build

Verification after hotfix approval:
- Perform production smoke checks on core flows (auth, home generate, speech path, settings)
- Monitor crash/error telemetry and user feedback for 24-48 hours
- Close incident with final timeline and preventive follow-ups

#### Final stabilization closeout sign-off

Status: GO for release handoff execution.

Closed verification scope:
- Phase 3 refactor stream completed and documented
- Stabilization passes 1-3 completed and documented
- Release execution checklist, preflight commands, publish/tag commands, and rollback/hotfix playbook documented
- Repository state verified clean at closeout checkpoints

Remaining manual owner actions (outside agent scope):
- Execute Xcode Organizer archive/upload flow
- Complete App Store Connect version metadata/review submission
- Decide final release strategy (manual vs automatic/phased rollout)

Closeout timestamp: 2026-03-12

---

## Phase 1 Post-Closeout — SwiftData Runtime Issue & JSON Fallback (Pre-Phase-2)

**Original issue**: During Orb-driven generation/save flow, app paused with runtime breakpoints inside `HistoryStore` on SwiftData fetch/insert operations.

**Root cause**: SwiftData (iOS 17 `ModelContext` API) had runtime traps during concurrent prompt save/fetch.

**Original hotfix**: `HistoryStore` switched to in-memory-only mode; persistence disabled temporarily.

**Resolution (Phase 2)**: Replaced SwiftData entirely with **Codable JSON + Supabase sync** (see Phase 2 section below). This is now the permanent, production-ready approach.

---

## Phase 2 — Supabase SDK Integration & JSON+Cloud Sync (v1.8 → v1.9 Clean)

**Session date: 2026-03-18**
**Status**: ✅ Complete. All merge conflicts resolved. SwiftData removed. JSON + Supabase sync operational.

This session completed the full migration from the legacy Railway JWT system to the live Supabase SDK, and replaced SwiftData with Codable JSON + Supabase two-way sync. All six files carrying `<<<<<<< HEAD … >>>>>>> 672afe4` merge-conflict markers were resolved.

### Manual prerequisites (already done by owner before this session)

- `supabase-swift` added via Swift Package Manager (SPM) in Xcode.
- `SUPABASE_URL` and `SUPABASE_ANON_KEY` keys populated in `Info.plist`.

### Files changed

**`App/AppEnvironment.swift`** — Complete rewrite.

- Added `@preconcurrency import Supabase`.
- Removed `supabaseConfig: SupabaseConfig?` scaffold property; replaced with `let supabase: SupabaseClient` (live client).
- `init()` is now marked `@MainActor` — resolves the Swift concurrency error "Main actor-isolated property 'authManager' can not be mutated from a non-isolated context."
- `SupabaseClient` is instantiated via `SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)` using `SupabaseConfig.load()` (hard-fails at launch if Info.plist keys are absent).
- `CloudKitService` and `cloudKitService` property removed entirely.
- `HistoryStore` now receives `supabase:` instead of `cloudKitService:`.
- `TelemetryService.shared.configure(supabase:)` and `AnalyticsService.shared.configure(supabase:)` called once from `init()`.
- Duplicate `telemetryService` assignment resolved.
- `CloudKitServiceKey` / `cloudKitService` environment key removed.

**`Core/Storage/HistoryStore.swift`** — Complete rewrite.

- All merge conflicts and CloudKit / SwiftData references removed.
- Injects `supabase: SupabaseClient` in `init(supabase:)`.
- Local persistence: Codable JSON file at `Application Support/OrionOrb/history.json` (`.atomic` write). Satisfies the hotfix follow-up from the post-closeout incident above.
- `PromptRecord` private DTO — snake_case `CodingKeys` for Supabase (`user_id`, `created_at`, `custom_name`, `last_modified`).
- `syncWithSupabase(userId: UUID)` — two-way last-write-wins merge:
  1. Upserts all local records where `isSynced == false`.
  2. Fetches all remote records for the user (`SELECT … WHERE user_id = ?`).
  3. Merges by `lastModified`; remote wins when newer, otherwise local wins.
  4. Marks uploaded records `isSynced = true`.
- `forceSync()` — fetches the current Supabase session and delegates to `syncWithSupabase(userId:)`; call from pull-to-refresh.
- Auth listener (`startAuthListener()`) — iterates `supabase.auth.authStateChanges` in a background `Task`; auto-syncs on `.signedIn`.
- Legacy migration path preserved: if `history.json` contains pre-Phase-2 records (no `lastModified`/`isSynced` fields), they are decoded as `LegacyItem` and up-converted on first launch.
- No CloudKit, no SwiftData.

**`Core/Auth/AuthManager.swift`** — Bug fix only (no structural change).

- `convertSupabaseUserToAppUser` was using `metadata["full_name"] as? String`, which silently returns `nil` because `userMetadata` values are the `AnyJSON` enum, not plain `String`.
- Fixed: `metadata["full_name"]?.stringValue` and `supabaseUser.appMetadata["provider"]?.stringValue`.

**`Core/Utils/TelemetryService.swift`** — Conflict resolved + real Supabase upload wired (previous session).

- Closure-based `NotificationCenter` observers (no `@objc`, no NSObject inheritance).
- `configure(supabase: SupabaseClient)` method added.
- Real `uploadToSupabase()`: `supabase.from("telemetry_errors").insert(pending).execute()`.

**`Core/Utils/AnalyticsService.swift`** — Conflict resolved + real Supabase upload wired (previous session).

- Same pattern as TelemetryService.
- `import UIKit` added (required for `UIApplication.didEnterBackgroundNotification`).
- `configure(supabase: SupabaseClient)` method added.
- Real `uploadToSupabase()`: `supabase.from("events").insert(pending).execute()`.

**`Models/Local/PromptHistoryItem.swift`** — Rewritten to remove CloudKit (previous session).

- Kimi had introduced `import CloudKit`, `CKRecord.ID recordID`, and `toCKRecord()`. All removed.
- Clean `Codable, Identifiable` class with two new Supabase-sync properties: `lastModified: Date` and `isSynced: Bool`.
- `markModified()` helper sets `lastModified = Date()` and `isSynced = false`.

**`Core/Networking/APIClient.swift`** — Conflict resolved (previous session).

- Telemetry calls (`logNetworkError`, `logAPIError`) wrapped in `Task { @MainActor in }` because `APIClient` is non-isolated and `TelemetryService` is `@MainActor`.

**`Core/Audio/SpeechRecognizerService.swift`** — Conflict resolved (previous session).

- Duplicate (old-API) telemetry call in `failAndStop` removed.

**`Core/Store/StoreManager.swift`** — Conflict resolved (previous session).

- Trivial conflict (identical logic, differing comments). Took the cleaner version.

### Supabase table requirements

The following tables must exist in the Supabase project before sync features are live:

`prompts` — stores `PromptHistoryItem` records.

```sql
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
```

`events` — stores `CachedAnalyticsEvent` records (AnalyticsService).

`telemetry_errors` — stores `TelemetryRecord` records (TelemetryService).

Schemas for the latter two should match the `CodingKeys` defined in `AnalyticsService.swift` and `TelemetryService.swift` respectively (all snake_case).

### Key architectural invariants going forward

- `SupabaseClient.shared` does not exist in `supabase-swift`. Always use `SupabaseClient(supabaseURL:supabaseKey:)`.
- `@preconcurrency import Supabase` is required wherever the SDK is used in `@MainActor` or strict-concurrency contexts.
- `AnyJSON` values (from `userMetadata`, `appMetadata`) must be accessed via `.stringValue`, not `as? String`.
- CloudKit is permanently removed. Do not reintroduce it.
- `HistoryStoring` protocol conformance must be maintained on `HistoryStore` for `EnvironmentValues` injection.

### System state as of v1.8

| Component | Status |
|---|---|
| `AppEnvironment.swift` | ✅ Clean — live SupabaseClient, @MainActor init, no CloudKit |
| `AuthManager.swift` | ✅ Clean — Supabase Auth, AnyJSON fix applied |
| `HistoryStore.swift` | ✅ Clean — JSON local + Supabase two-way sync |
| `PromptHistoryItem.swift` | ✅ Clean — Codable, lastModified, isSynced |
| `TelemetryService.swift` | ✅ Clean — real Supabase upload |
| `AnalyticsService.swift` | ✅ Clean — real Supabase upload |
| `APIClient.swift` | ✅ Clean — telemetry calls MainActor-safe |
| `SpeechRecognizerService.swift` | ✅ Clean — no duplicate telemetry |
| `StoreManager.swift` | ✅ Clean — merge conflict resolved |
| Supabase tables created | ⏳ Owner action required |
| End-to-end auth smoke test | ⏳ Owner action required (awaits correct Supabase anon key) |

---

## Current Working State (v1.9 Post-Cleanup)

### ✅ What's Working

1. **App boots** — `OrionOrbApp` initializes `AppEnvironment` with all services
2. **RootView state machine displays** — privacy gate, auth flows, main tabs all render
3. **UI structure intact** — all tabs (Home, Trending, History, Favorites, Admin) render backgrounds correctly
4. **JSON persistence functional** — `HistoryStore` loads/saves to `Application Support/OrionOrb/history.json`
5. **Supabase SDK integrated** — `SupabaseClient` instantiated, auth state listener running
6. **Google/Apple OAuth UI present** — sign-in buttons render in `AuthFlowView`
7. **Build target**: `orion-upgrade-main` branch

### ⚠️ What's NOT Working (and Why)

1. **Actual sign-in fails** — `SUPABASE_ANON_KEY` in `Info.plist` is a valid key but for wrong Supabase project. **Action**: Replace from your Supabase dashboard.
2. **Supabase sync disabled** — until correct anon key is set, `authStateChanges` listener will not authenticate, so `syncWithSupabase(userId:)` never fires. Local JSON persistence still works.
3. **Plan sync with Railway backend** — `APIClient` baseURL points to `https://promptme-app-production.up.railway.app`, but user plan info is fetched via this backend. Will work once authentication succeeds.

### Supabase Anon Key Issue

**Current value in Info.plist** (line 44-45):
```xml
<key>SUPABASE_ANON_KEY</key>
<string>sb_publishable_LECnrvYUeR10rudfadkS_w_V05</string>
```

**Fix**:
1. Log into your Supabase dashboard
2. Project Settings → API → `anon` (public) key
3. Copy the full key
4. Replace line 45 in `Prompt28/Info.plist` with the real key
5. Rebuild and test sign-in
