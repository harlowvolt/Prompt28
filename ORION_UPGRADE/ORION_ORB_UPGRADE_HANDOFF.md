# ORION Orb Upgrade — Handoff Document

**Version:** 1.7
**Created:** 2026-03-14
**Last Updated:** 2026-03-17
**Status:** Phase 1 immediate priorities complete — ready for Phase 2 Supabase SDK integration
**Source Root:** `PromptMeNative_Blueprint/`  

---

## 1. Current Architecture Summary

Prompt28 is an AI-powered prompt generation iOS app built with SwiftUI and the Observation framework (`@Observable`).

**Platform Requirements:**
- iOS 17+ (required for SwiftData `@Model` on `PromptHistoryItem`)
- Swift 5.0+
- Bundle ID: `com.prompt28.prompt28`

**Architecture Pattern:** MVVM with centralized dependency injection via `AppEnvironment`

**Key Characteristics:**
- Single-window SwiftUI app with `WindowGroup`
- Tab-based navigation on iPhone, sidebar navigation on iPad
- Freemium subscription model with usage tracking
- Voice-first input via custom "Orb" UI component
- Local-only prompt history (current state)

---

## 2. Confirmed Entry Point

**File:** `PromptMeNative_Blueprint/PromptMeNativeApp.swift`

```swift
@main
struct PromptMeNativeApp: App {
    @State private var env = AppEnvironment()
    @State private var errorState = ErrorState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .environment(\.historyStore, env.historyStore)
                .environment(\.authManager, env.authManager)
                .environment(\.appRouter, env.router)
                .environment(\.errorState, errorState)
                .environment(\.apiClient, env.apiClient)
                .environment(\.preferencesStore, env.preferencesStore)
                .environment(\.usageTracker, env.usageTracker)
                .environment(\.storeManager, env.storeManager)
                .environment(\.keychainService, env.keychain)
                .environment(\.speechRecognizerFactory, env.speechRecognizerFactory)
                .environment(\.orbEngineFactory, env.orbEngineFactory)
        }
    }
}
```

**Window Background Setup (Critical):**
```swift
init() {
    UIWindow.appearance().backgroundColor = UIColor(red: 14/255, green: 12/255, blue: 22/255, alpha: 1)
    UIView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self]).backgroundColor = .clear
}
```

---

## 3. Confirmed Root Navigation

**File:** `PromptMeNative_Blueprint/App/RootView.swift`

### State Machine Flow

```
App Launch
    │
    ├── hasAcceptedPrivacy = false ──→ PrivacyConsentView
    │                                      (blocks all UI, bootstrap runs in background)
    │
    └── hasAcceptedPrivacy = true
            │
            ├── didBootstrap = false ──→ launchView (spinner with "Loading Prompt28")
            │
            └── bootstrap() completes ──→ didBootstrap = true
                    │
                    ├── isAuthenticated = false ──→ AuthFlowView
                    │
                    ├── isAuthenticated = true, hasSeenOnboarding = false ──→ OnboardingView
                    │
                    └── isAuthenticated = true, hasSeenOnboarding = true
                            │
                            ├── horizontalSizeClass == .regular (iPad) ──→ iPadSidebar (NavigationSplitView)
                            │
                            └── horizontalSizeClass == .compact (iPhone) ──→ mainTabs (TabView)
```

### Tab Structure (iPhone)

**File:** `PromptMeNative_Blueprint/App/Routing/AppRouter.swift`

```swift
enum MainTab: Hashable {
    case home
    case trending
    case history
    case favorites
    case admin
}
```

**Tab Order in UI:**
1. Home (house.fill)
2. Favorites (star.fill)
3. History (clock.arrow.circlepath)
4. Trending (flame.fill)

**Admin tab:** Phone-only, redirects to Home on iPad

### Navigation Rules (Critical)

1. **Background Layer:** Every view with `NavigationStack` must place `PromptPremiumBackground().ignoresSafeArea()` as the FIRST child in its outermost ZStack
2. **Screens with their own backgrounds:**
   - HomeView
   - HistoryView
   - FavoritesView
   - TrendingView

3. **Toolbar visibility:** Main tab screens use `.toolbar(.hidden, for: .navigationBar)`

---

## 4. Confirmed Dependency Injection

**File:** `PromptMeNative_Blueprint/App/AppEnvironment.swift`

### Container Definition

```swift
@Observable
@MainActor
final class AppEnvironment {
    let apiClient: APIClient
    let keychain: KeychainService
    let authManager: AuthManager
    let historyStore: HistoryStore
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager
    let usageTracker: UsageTracker
    let speechRecognizerFactory: any SpeechRecognizerFactoryProtocol
    let orbEngineFactory: any OrbEngineFactoryProtocol
}
```

### Service Initialization Order

```swift
init() {
    // 1. Base infrastructure
    let baseURL = URL(string: "https://promptme-app-production.up.railway.app")!
    let keychain = KeychainService()
    let apiClient = APIClient(baseURL: baseURL)

    // 2. Auth (depends on keychain, apiClient)
    self.authManager = AuthManager(apiClient: apiClient, keychain: keychain)
    
    // 3. Usage tracking (depends on keychain)
    self.usageTracker = UsageTracker(keychain: keychain)

    // 4. SwiftData container for history
    let container = try? ModelContainer(for: PromptHistoryItem.self)
    self.historyStore = HistoryStore(modelContext: container.mainContext)

    // 5. Other stores
    self.preferencesStore = PreferencesStore()
    self.router = AppRouter()
    self.storeManager = StoreManager()
    
    // 6. Factory seams for testing
    self.speechRecognizerFactory = LiveSpeechRecognizerFactory()
    self.orbEngineFactory = LiveOrbEngineFactory(speechFactory: speechRecognizerFactory)
}
```

### Environment Key Injection

All services are injected via custom `EnvironmentKey` implementations:

```swift
// Access patterns in views:
@Environment(AppEnvironment.self) private var env
@Environment(\.historyStore) private var historyStore
@Environment(\.authManager) private var authManager
@Environment(\.appRouter) private var appRouter
```

**Rule:** Never instantiate stores directly in views. Always use environment injection.

---

## 5. Confirmed AI/Prompt Pipeline

### Generation Flow

**Files:**
- `Features/Home/ViewModels/GenerateViewModel.swift`
- `Features/Home/ViewModels/HomeViewModel.swift`
- `Core/Audio/OrbEngine.swift`
- `Core/Networking/APIClient.swift`

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Voice Input   │     │   Text Input     │     │  History Item   │
│   (OrbEngine)   │     │ (TypePromptView) │     │  (Restore)      │
└────────┬────────┘     └────────┬─────────┘     └────────┬────────┘
         │                       │                        │
         └───────────────────────┼────────────────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │  GenerateViewModel      │
                    │  - inputText            │
                    │  - selectedMode (.ai/   │
                    │    .human)              │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  Build GenerateRequest  │
                    │  - input: String        │
                    │  - refinement: String?  │
                    │  - mode: PromptMode     │
                    │  - systemPrompt: String │
                    │    (hardcoded)          │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  APIClient.generate()   │
                    │  POST /api/generate     │
                    │  Authorization: Bearer  │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  GenerateResponse       │
                    │  - professional: String │
                    │  - template: String     │
                    │  - prompts_used: Int    │
                    │  - prompts_remaining:   │
                    │    Int?                 │
                    └───────────┬─────────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
        ┌───────────┐   ┌───────────┐   ┌───────────────┐
        │  Display  │   │  History  │   │ UsageTracker  │
        │  Result   │   │  Store    │   │  (sync count) │
        └───────────┘   └───────────┘   └───────────────┘
```

### System Prompts (Hardcoded)

**Location:** `GenerateViewModel.swift` lines 97-103

```swift
switch selectedMode {
case .ai:
    systemPrompt = "You are an expert AI prompt engineer. Transform the user's raw spoken idea into a precise, structured prompt optimised for AI language models. Maximise clarity, specificity, and instructional detail."
case .human:
    systemPrompt = "You are an expert communicator and copywriter. Transform the user's raw spoken idea into clear, compelling, human-centred communication. Use natural language, conversational tone, and emotional clarity."
}
```

### Voice Input State Machine

**File:** `Core/Audio/OrbEngine.swift`

```swift
enum State: Equatable {
    case idle
    case listening
    case transcribing
    case ready(text: String)
    case generating
    case success
    case failure(String)
}
```

**Minimum Requirements:**
- Listening duration: 0.7 seconds minimum
- Meaningful transcript: 3+ characters with alphanumeric content
- Polling: 30 attempts × 50ms = 1.5s max for final transcript

---

## 6. Confirmed HistoryStore State

**File:** `PromptMeNative_Blueprint/Core/Storage/HistoryStore.swift`

### Current Implementation Status

```swift
@Observable
@MainActor
final class HistoryStore {
    private(set) var items: [PromptHistoryItem] = []
    private let persistenceEnabled = false  // ← DISABLED
    // ...
}
```

**CRITICAL:** Persistence is currently **DISABLED**. All history exists only in memory.

### Data Model

**File:** `PromptMeNative_Blueprint/Models/Local/PromptHistoryItem.swift`

```swift
@Model
final class PromptHistoryItem {
    @Attribute(.unique) var id: UUID = UUID()
    var createdAt: Date = Date()
    var mode: PromptMode = .ai          // .ai or .human
    var input: String = ""              // User's raw input
    var professional: String = ""       // AI-generated prompt
    var template: String = ""           // Template version
    var favorite: Bool = false
    var customName: String? = nil
}
```

### HistoryStore Protocol

**File:** `PromptMeNative_Blueprint/Core/Storage/HistoryStore.swift` (lines 177-193)

```swift
@MainActor
protocol HistoryStoring: AnyObject {
    var items: [PromptHistoryItem] { get }
    var favorites: [PromptHistoryItem] { get }
    
    func add(_ item: PromptHistoryItem)
    func remove(id: UUID)
    func clearAll()
    func toggleFavorite(id: UUID)
    func rename(id: UUID, customName: String?)
}
```

### Current Behavior

1. **Add:** Inserts at index 0, prunes to max 200 items
2. **Favorites:** Computed property filtering `favorite == true`
3. **Save:** Returns `true` immediately (no-op)
4. **Persistence:** None - data lost on app termination
5. **Legacy Migration:** Code exists but never runs due to `persistenceEnabled = false`

---

## 7. Current Backend/API Observations

### Base URL
```
https://promptme-app-production.up.railway.app
```

### Existing Endpoints

**File:** `PromptMeNative_Blueprint/Core/Networking/APIEndpoint.swift`

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/auth/register` | None | Email registration |
| POST | `/api/auth/login` | None | Email login |
| POST | `/api/auth/google` | None | Google OAuth |
| POST | `/api/auth/apple` | None | Apple Sign-In |
| GET | `/api/me` | Bearer | Get current user |
| POST | `/api/update-plan` | Bearer | Update subscription |
| DELETE | `/api/user` | Bearer | Delete account |
| POST | `/api/reset-usage` | Bearer | Reset usage (admin) |
| POST | `/api/generate` | Bearer | Generate prompt |
| GET | `/api/config` | None | App configuration |
| GET | `/api/settings` | None | App settings |
| GET | `/prompts_trending.json` | None | Trending prompts |
| POST | `/api/admin/verify` | Admin | Verify admin key |
| GET | `/api/admin/settings` | Admin | Get settings |
| POST | `/api/admin/settings` | Admin | Update settings |
| GET | `/api/admin/prompts` | Admin | Get prompts |
| POST | `/api/admin/prompts` | Admin | Update prompts |

### Auth Patterns

```swift
enum APIAuthRequirement {
    case none
    case bearer      // JWT from Keychain
    case admin       // Admin API key
}
```

### User Model

**File:** `PromptMeNative_Blueprint/Models/API/User.swift`

```swift
struct User: Decodable {
    let id: String
    let email: String
    let name: String
    let provider: String
    let plan: PlanType          // starter, pro, unlimited, dev
    let prompts_used: Int
    let prompts_remaining: Int?
    let period_end: String
}
```

### Plan Types

```swift
enum PlanType: String, Codable {
    case starter      // Free: 10 generations/month
    case pro          // Paid tier
    case unlimited    // Paid tier
    case dev          // Developer/admin
}
```

### Current Limitations

1. **No history endpoints** - History is purely local (and currently non-persistent)
2. **No real-time sync** - All data is device-local
3. **No offline queue** - Failed generations are lost
4. **System prompts are hardcoded** - Not configurable from server

---

## 8. Risks and Technical Debt

### 🔴 Critical (P0)

| Issue | Location | Impact |
|-------|----------|--------|
| **History persistence disabled** | `HistoryStore.swift:28` | All prompt history lost on app restart |
| **SwiftData schema migration** | `AppEnvironment.swift:36-47` | Fallback to in-memory on schema errors |

### 🟡 High (P1)

| Issue | Location | Impact |
|-------|----------|--------|
| No cloud sync for history | Entire storage layer | No cross-device support, data siloed per device |
| Hardcoded system prompts | `GenerateViewModel:98-102` | Cannot A/B test or modify without app update |
| No offline generation queue | `GenerateViewModel` | Network failures = lost user input |
| No pagination in history | `HistoryStore` | Performance degradation at scale |

### 🟢 Medium (P2)

| Issue | Location | Impact |
|-------|----------|--------|
| Combine usage in OrbEngine | `OrbEngine.swift:77` | Could use Observation framework directly |
| Duplicate protocol definitions | `HistoryStore.swift` vs `StorageProtocols.swift` | Maintenance overhead |
| Factory pattern inconsistencies | `AppEnvironment.swift` | Some factories use `any`, others concrete types |

### Architecture Constraints

1. **Minimum iOS 17** - Cannot lower deployment target due to SwiftData
2. **Observation framework** - Do not use `@StateObject` or `@ObservedObject`
3. **NavigationStack backgrounds** - Critical visual requirement, see AGENTS.md
4. **Keychain for auth** - Never store tokens in UserDefaults

---

## 9. Recommended Upgrade Order

### Phase 1: Foundation (Week 1)

**Goal:** Fix critical data loss issue and establish sync infrastructure

1. **Fix History Persistence**
   - Enable SwiftData persistence (`persistenceEnabled = true`)
   - OR implement UserDefaults fallback if SwiftData issues persist
   - Add migration test for legacy JSON data

2. **Extend Data Model for Sync**
   - Add `syncStatus` field to `PromptHistoryItem`
   - Add `cloudID` field for server-side identifiers
   - Add `lastModified` timestamp for conflict resolution

### Phase 2: Cloud API (Week 2)

**Goal:** Add backend endpoints for history sync

1. **Extend APIClient**
   - Add `GET /api/history` endpoint
   - Add `POST /api/history` endpoint
   - Add `PUT /api/history/:id` endpoint
   - Add `DELETE /api/history/:id` endpoint

2. **Create CloudHistoryService**
   - New file: `Core/Storage/CloudHistoryService.swift`
   - Handle network operations
   - Manage sync state transitions

### Phase 3: Sync Logic (Week 3)

**Goal:** Implement bidirectional sync

1. **Sync Engine**
   - Two-way sync on app launch
   - Push on local changes
   - Background sync when app enters foreground

2. **Conflict Resolution**
   - Last-write-wins strategy
   - Or server-wins with client notification

### Phase 4: UI/UX (Week 4)

**Goal:** Sync status visibility and offline support

1. **Sync Indicators**
   - Add sync status to history list
   - Show pending uploads
   - Error retry UI

2. **Offline Queue**
   - Queue failed generations
   - Retry when connectivity restored

---

## 10. Most Important Files (Priority Order)

### Tier 1: Core Infrastructure (Modify First)

| File | Lines | Why |
|------|-------|-----|
| `Core/Storage/HistoryStore.swift` | 193 | **CRITICAL:** Data persistence disabled here. Fix first. |
| `Models/Local/PromptHistoryItem.swift` | 41 | May need sync metadata fields (syncStatus, cloudID) |
| `Core/Networking/APIClient.swift` | 188 | Add history sync endpoints here |
| `Core/Networking/APIEndpoint.swift` | 118 | Define new endpoint cases |

### Tier 2: Cloud Integration (Modify Second)

| File | Lines | Why |
|------|-------|-----|
| `App/AppEnvironment.swift` | 180 | Add CloudHistoryService dependency |
| `Core/Storage/CloudHistoryService.swift` | **NEW** | Create this file for cloud sync logic |
| `Core/Protocols/StorageProtocols.swift` | 34 | Extend with cloud-related protocols |
| `Features/History/ViewModels/HistoryViewModel.swift` | ~100 | Add sync triggers |

### Tier 3: Pipeline Integration (Modify Third)

| File | Lines | Why |
|------|-------|-----|
| `Features/Home/ViewModels/GenerateViewModel.swift` | 229 | Save to cloud after local save |
| `Features/History/Views/HistoryView.swift` | ~200 | Add sync status UI |
| `Features/History/Views/FavoritesView.swift` | ~150 | Add sync status UI |

### Tier 4: Polish (Modify Last)

| File | Lines | Why |
|------|-------|-----|
| `Core/Audio/OrbEngine.swift` | 377 | Modernize (remove Combine) if needed |
| `App/RootView.swift` | 416 | Global sync status indicators |
| `Core/Utils/AnalyticsService.swift` | ~100 | Track sync events |

---

## Appendix A: File Structure Reference

```
PromptMeNative_Blueprint/
├── App/
│   ├── AppEnvironment.swift          # Dependency container
│   ├── AppUI.swift                   # Design tokens
│   ├── PremiumTabScreen.swift        # Tab wrapper
│   ├── RootView.swift                # Root state machine
│   └── Routing/
│       └── AppRouter.swift           # Navigation enums
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift         # JWT session management
│   │   ├── KeychainService.swift     # Secure storage
│   │   └── OAuthCoordinator.swift    # Google/Apple OAuth
│   ├── Networking/
│   │   ├── APIClient.swift           # HTTP client
│   │   ├── APIEndpoint.swift         # Endpoint definitions
│   │   ├── NetworkError.swift        # Error types
│   │   └── RequestBuilder.swift      # Request construction
│   ├── Storage/
│   │   ├── HistoryStore.swift        # ⚠️ PERSISTENCE DISABLED
│   │   ├── PreferencesStore.swift    # UserDefaults prefs
│   │   └── SecureStore.swift         # Generic secure storage
│   ├── Store/
│   │   ├── StoreConfig.swift         # IAP product IDs
│   │   ├── StoreManager.swift        # StoreKit 2 wrapper
│   │   └── UsageTracker.swift        # Freemium counter
│   ├── Audio/
│   │   ├── OrbEngine.swift           # Voice input state machine
│   │   └── SpeechRecognizerService.swift
│   └── Utils/
│       ├── AnalyticsService.swift
│       └── HapticService.swift
├── Features/
│   ├── Auth/                         # Login/signup flows
│   ├── History/                      # History + Favorites views
│   ├── Home/                         # Main generation UI
│   ├── Settings/                     # Settings + Upgrade
│   └── Trending/                     # Prompt catalog
├── Models/
│   ├── API/                          # Server response models
│   └── Local/                        # SwiftData models
└── PromptMeNativeApp.swift           # @main entry point
```

---

## Appendix B: External Dependencies

**Swift Package Manager:**
- GoogleSignIn (9.1.0)
- AppAuth (2.0.0)
- GTMAppAuth (5.0.0)
- GTMSessionFetcher (3.5.0)

**Frameworks:**
- SwiftUI (primary UI)
- SwiftData (persistence - currently disabled)
- Observation (@Observable)
- Speech (SFSpeechRecognizer)
- AVFoundation
- StoreKit 2

---

**Document History:**
- v1.0 (2026-03-14) - Initial architecture audit and handoff document
- v1.6 (2026-03-17) - Full codebase rescan after Kimi session. See Section 11 below.
- v1.7 (2026-03-17) - Immediate priorities (Tasks 1–5) executed. See Section 12 below.

---

## 11. Current State Corrections (v1.6 — 2026-03-17)

**READ THIS BEFORE SECTIONS 1–10.** Sections 1–10 reflect the state as of v1.0 (March 14). Multiple changes were made after that. This section is the accurate current baseline.

---

### 11.1 What Changed Since v1.0

#### Deleted by Kimi (no longer in codebase)
| File | What was lost |
|------|--------------|
| `Core/Storage/CloudKitService.swift` | Full CloudKit two-way sync with conflict resolution and custom zone |
| `Core/Utils/TelemetryService.swift` | Structured error logging (device model, iOS version, app state, UserDefaults cache) |

#### Modified by Kimi
| File | Change |
|------|--------|
| `Core/Utils/AnalyticsService.swift` | Replaced Phase 1 local-caching implementation with a thin debug-only wrapper. `CachedAnalyticsEvent`, `setUserId()`, `uploadToSupabase()`, UserDefaults caching, and `@MainActor` are all gone. Current version is a singleton with a single `track()` that `print()`s in DEBUG only. Drop-in comments for Mixpanel/Amplitude/Firebase are present. |
| `Core/Storage/HistoryStore.swift` | Reverted from Codable JSON + CloudKit to SwiftData with `persistenceEnabled = false`. Data is still lost on restart. `@Model PromptHistoryItem` is back. This is identical to the broken state described in Section 6. |
| `App/AppEnvironment.swift` | Reverted from Codable JSON + CloudKit init to SwiftData `ModelContainer`. `telemetryService` and `cloudKitService` properties are gone. `storeManager = StoreManager()` — no AuthManager injection. |
| `Core/Store/StoreManager.swift` | Reverted to no `AuthManager` injection. `init()` takes no parameters. `refreshMe()` is not called after purchase. **The plan sync bug is back.** |

#### Added by Kimi
| File | What it does |
|------|-------------|
| `Core/Auth/SupabaseConfig.swift` | Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Info.plist via `SupabaseConfig.load()`. Not injected into `AppEnvironment`. Not wired anywhere. Struct only — no SDK dependency. |

#### Changed by this session (2026-03-17) — still in place
| File | Change |
|------|--------|
| `Features/Home/Views/ShareCardView.swift` | Branding updated: "PROMPT²⁸" → "ORION ORB", "Made with PROMPT²⁸" → "Refined by Orion Orb" |
| `Components/Glassmorphism.swift` | **DELETED** — was dead code never used in production. Authoritative glass system is `.appGlassCard()` in `App/AppUI.swift`. Do not recreate. |

---

### 11.2 Accurate Current State of Every Major System

| System | File | State |
|--------|------|-------|
| App entry / DI | `App/AppEnvironment.swift` | SwiftData + no telemetry + no CloudKit. `StoreManager()` with no AuthManager. |
| Auth | `Core/Auth/AuthManager.swift` | Railway JWT. Stable. Not yet migrated to Supabase. |
| Supabase config | `Core/Auth/SupabaseConfig.swift` | Config struct only. Not wired. Requires Info.plist keys. |
| History | `Core/Storage/HistoryStore.swift` | **SwiftData, `persistenceEnabled = false`. Data lost on restart. P0 bug.** |
| History model | `Models/Local/PromptHistoryItem.swift` | `@Model` SwiftData class. No CloudKit fields. |
| Analytics | `Core/Utils/AnalyticsService.swift` | Debug print only. No caching, no upload, no user ID tracking. |
| Telemetry | — | **FILE DELETED. Does not exist.** |
| CloudKit sync | — | **FILE DELETED. Does not exist.** |
| StoreKit | `Core/Store/StoreManager.swift` | On-device flow works. `refreshMe()` not called after purchase — **plan sync bug is present.** |
| Usage tracking | `Core/Store/UsageTracker.swift` | Keychain-backed client-side counter. Unchanged. |
| OrbEngine | `Core/Audio/OrbEngine.swift` | Full state machine. Unchanged. No Metal shader. |
| ShareCard | `Features/Home/Views/ShareCardView.swift` | Complete, wired into ResultView. Branding correct (fixed). |
| Glassmorphism | — | **FILE DELETED.** Use `.appGlassCard()` in `AppUI.swift` for all glass UI. |
| Trending | `Features/Trending/ViewModels/TrendingViewModel.swift` | Bundled JSON + Railway API poll. No Realtime. |
| RLHF / feedback | — | Not started. |
| Metal Orb | — | Not started. |
| FeatureFlagService | — | Not started. |

---

### 11.3 Architecture Decision (Updated for v1.6)

The v1.5 decision (Option A: keep CloudKit + add Supabase) is **no longer applicable** because CloudKit was deleted.

**Current direction: Supabase as the primary data backend.**

| Layer | System | Status |
|-------|--------|--------|
| History persistence | SwiftData → **needs fix** | `persistenceEnabled = false` is a P0 bug. Options: re-enable SwiftData OR migrate to Supabase `prompts` table. |
| Auth | Railway JWT → Supabase Auth | Not started. `SupabaseConfig.swift` is the first step. |
| Analytics upload | Supabase `events` table | Not started. AnalyticsService needs local caching re-added + upload wired. |
| Error telemetry | Supabase `telemetry_errors` table | TelemetryService needs to be recreated. |
| Feature flags | Supabase `feature_flags` table | Not started. |
| RLHF | Supabase `prompts` table | Not started. |
| Real-time trending | Supabase Realtime | Not started. |
| Server-side metering | Supabase Edge Function | Not started. |

**Rules going forward:**
- Do NOT re-introduce CloudKit. That work is gone.
- `SupabaseConfig.swift` is the correct foundation — wire it into `AppEnvironment` as the next step.
- Do NOT store Supabase keys in source code. They must come from Info.plist via `SupabaseConfig.load()`.
- Do NOT use `@StateObject` or `@ObservedObject`. The app uses `@Observable` throughout.
- Do NOT use `NavigationView`. Use `NavigationStack`.
- Do NOT put glass UI in new standalone files. Extend `AppUI.swift`.

---

### 11.4 Immediate Priorities (in order)

| # | Task | File(s) | Why |
|---|------|---------|-----|
| 1 | Fix StoreKit plan sync bug | `Core/Store/StoreManager.swift`, `App/AppEnvironment.swift` | Purchase succeeds but paywall doesn't clear. `StoreManager` must inject `AuthManager` and call `refreshMe()` after `transaction.finish()`. |
| 2 | Fix history persistence | `Core/Storage/HistoryStore.swift` | P0 — data lost on every restart. Either re-enable SwiftData (`persistenceEnabled = true`) with tested migration, or move to Supabase `prompts` table. |
| 3 | Wire SupabaseConfig + SDK | `App/AppEnvironment.swift`, `Core/Auth/SupabaseConfig.swift` | Everything in the Supabase pipeline depends on this. Add `supabase-swift` via SPM, initialize client in `AppEnvironment`, inject as environment value. |
| 4 | Recreate TelemetryService | `Core/Utils/TelemetryService.swift` | Production app has zero error visibility right now. |
| 5 | Restore AnalyticsService caching | `Core/Utils/AnalyticsService.swift` | Current version drops all events. Restore local cache + wire Supabase upload. |

---

## 12. Execution Log (v1.7 — 2026-03-17)

**READ THIS BEFORE SECTION 11.4.** All five immediate-priority tasks from Section 11.4 have been executed. Section 11.2's state table is superseded by Section 12.2 below.

---

### 12.1 Changes Made in This Session

#### Task 1 — StoreKit Plan Sync Fix ✅

**Files:** `Core/Store/StoreManager.swift`, `App/AppEnvironment.swift`

- Added `private let authManager: AuthManager` property to `StoreManager`.
- Changed `init()` → `init(authManager: AuthManager)`.
- Added `await authManager.refreshMe()` in `purchase()` after `transaction.finish()`.
- Added `await self.authManager.refreshMe()` in `listenForTransactions()` after `transaction.finish()` (covers renewals, restores, family-sharing).
- Updated `AppEnvironment.init()`: `StoreManager()` → `StoreManager(authManager: authManager)`.

**Result:** Purchasing a subscription now immediately syncs the server-side plan tier. The paywall will clear without requiring a manual refresh or app restart.

---

#### Task 2 — HistoryStore Persistence Fix ✅

**File:** `Core/Storage/HistoryStore.swift`

- Changed `persistenceEnabled = false` → `persistenceEnabled = true`.
- **Also fully wired the SwiftData persistence layer** (the flag was enabled but the backing methods were all stubs):
  - `add()` — now calls `modelContext.insert(newItem)` when persistence is enabled, so SwiftData tracks the item.
  - `remove()` — now calls `modelContext.delete(item)` via a context fetch by ID.
  - `clearAll()` — now calls `modelContext.delete()` on every item before clearing the in-memory array.
  - `pruneIfNeeded()` — now calls `modelContext.delete()` on pruned items.
  - `save()` — now calls `try modelContext.save()` (was returning `true` immediately as a no-op).
  - `refreshCache()` — now fetches from `modelContext` with a sorted `FetchDescriptor` (was just sorting the in-memory array without fetching persisted records).
  - `fetchByID()` — now queries the context with `#Predicate` when persistence is enabled (was a linear scan of the in-memory array only).

**Result:** Prompt history now persists across app restarts. Legacy JSON migration path activates automatically on first launch post-update.

---

#### Task 3 — AnalyticsService Local Caching Restored ✅

**File:** `Core/Utils/AnalyticsService.swift`

- Reinstated `@MainActor` on the class.
- Added `CachedAnalyticsEvent: Codable` struct with `name`, `properties: [String: String]`, `timestamp`, `userId`.
- Added `setUserId(_ id: String?)` method.
- `track()` now builds a `CachedAnalyticsEvent` and calls `appendToCache()` in addition to the debug print.
- `appendToCache()` — loads, appends, FIFO-trims to 100, saves via `UserDefaults`.
- Added `loadCache() -> [CachedAnalyticsEvent]`, `saveCache()`, `clearCache()`.
- Added `uploadToSupabase() async` stub with Phase 2 TODO comment.
- The `AnalyticsEvent` enum and all cases are **unchanged**.

**Result:** All tracked events are cached locally (max 100, FIFO). Nothing is dropped. Ready for Phase 2 Supabase `events` table upload.

---

#### Task 4 — TelemetryService Recreated ✅

**New File:** `Core/Utils/TelemetryService.swift`

- `TelemetryRecord: Codable` struct: `id`, `error_domain`, `error_code`, `error_message`, `device_model`, `ios_version`, `app_state`, `timestamp`, `user_id`.
- `@MainActor` singleton.
- UserDefaults FIFO cache (max 50 records), with `loadCache()` / `saveCache()` / `clearCache()`.
- `logNetworkError(_:endpoint:appState:)` — for `APIClient` transport failures.
- `logSpeechError(_:appState:)` — for `SpeechRecognizerService` failures.
- `log(domain:code:message:appState:)` — general-purpose fallback.
- `uploadToSupabase() async` stub (Phase 2 TODO).
- Auto-flush on `UIApplication.didEnterBackgroundNotification` via `NotificationCenter`.
- Device model string read from `uname()`. iOS version from `UIDevice.current.systemVersion`.

**Integrated into:**
- `App/AppEnvironment.swift` — `let telemetryService: TelemetryService = TelemetryService.shared` added as a property and set in `init()`.
- `Core/Networking/APIClient.swift` — `Task { @MainActor in TelemetryService.shared.logNetworkError(...) }` in the transport `catch` block.
- `Core/Audio/SpeechRecognizerService.swift` — `TelemetryService.shared.log(...)` called at the end of `failAndStop()`, the single funnel all speech recognition errors pass through.

---

#### Task 5 — AppEnvironment Supabase Scaffolding ✅

**Files:** `Core/Auth/SupabaseConfig.swift`, `App/AppEnvironment.swift`

- Added `tryLoad()` static method to `SupabaseConfig` — non-fatal variant that returns `Optional<SupabaseConfig>` instead of `fatalError`-ing when Info.plist keys are absent. Safe for use during scaffolding.
- Added `let supabaseConfig: SupabaseConfig?` to `AppEnvironment`.
- Set `self.supabaseConfig = SupabaseConfig.tryLoad()` in `AppEnvironment.init()`.
- Added Phase 2 comment in AppEnvironment explaining the exact steps to replace `supabaseConfig` with a live `SupabaseClient` once the SPM package is added.

**Result:** The wiring seam is in place. No crash if Info.plist keys are missing. When the user adds `supabase-swift` via SPM and populates Info.plist, they replace `supabaseConfig: SupabaseConfig?` with `supabaseClient: SupabaseClient` using the config URL and anon key — one edit.

---

### 12.2 Updated System State Table (as of v1.7)

| System | File | State |
|--------|------|-------|
| App entry / DI | `App/AppEnvironment.swift` | ✅ StoreManager(authManager:), TelemetryService, supabaseConfig all wired |
| Auth | `Core/Auth/AuthManager.swift` | Railway JWT. Stable. Not yet migrated to Supabase. |
| Supabase config | `Core/Auth/SupabaseConfig.swift` | ✅ `tryLoad()` added. Config wired into AppEnvironment. **Next:** add `supabase-swift` SPM, populate Info.plist. |
| History | `Core/Storage/HistoryStore.swift` | ✅ **SwiftData persistence ENABLED.** Full context insert/delete/fetch/save wired. History survives restart. |
| History model | `Models/Local/PromptHistoryItem.swift` | `@Model` SwiftData class. Unchanged. |
| Analytics | `Core/Utils/AnalyticsService.swift` | ✅ `@MainActor`, `CachedAnalyticsEvent`, UserDefaults cache (max 100), `setUserId()`, `uploadToSupabase()` stub. |
| Telemetry | `Core/Utils/TelemetryService.swift` | ✅ **RECREATED.** `TelemetryRecord`, UserDefaults cache (max 50 FIFO), `logNetworkError()`, `logSpeechError()`, auto-flush on background. |
| CloudKit sync | — | FILE DELETED. Do not reintroduce. Direction is Supabase. |
| StoreKit | `Core/Store/StoreManager.swift` | ✅ **Plan sync bug FIXED.** `authManager.refreshMe()` called after `transaction.finish()` in both purchase paths. |
| Usage tracking | `Core/Store/UsageTracker.swift` | Keychain-backed client-side counter. Unchanged. |
| OrbEngine | `Core/Audio/OrbEngine.swift` | Full state machine. No Metal shader yet. |
| ShareCard | `Features/Home/Views/ShareCardView.swift` | Complete, wired into ResultView. Branding correct. |
| Glassmorphism | — | FILE DELETED. Use `.appGlassCard()` in `AppUI.swift`. |
| Trending | `Features/Trending/ViewModels/TrendingViewModel.swift` | Bundled JSON + Railway API poll. No Realtime yet. |
| RLHF / feedback | — | Not started (Phase 4). |
| Metal Orb | — | Not started (Phase 4, requires FeatureFlagService first). |
| FeatureFlagService | — | Not started (Phase 2). |

---

### 12.3 Next Priorities (Phase 2 Entry Gate)

These must be done **by the developer in Xcode** before any further code changes can be made:

| # | Action | Where | Notes |
|---|--------|--------|-------|
| 1 | Add `supabase-swift` SPM package | Xcode → Package Dependencies | `https://github.com/supabase/supabase-swift` |
| 2 | Set `SUPABASE_URL` in Info.plist | `PromptMeNative_Blueprint/Info.plist` | Project dashboard → Settings → API |
| 3 | Set `SUPABASE_ANON_KEY` in Info.plist | Same file | Use anon/public key only |
| 4 | Replace `supabaseConfig: SupabaseConfig?` in AppEnvironment with live `SupabaseClient` | `App/AppEnvironment.swift` | See Phase 2 comment in that file |

Once those four steps are done, the following code tasks unlock:

| # | Task | File(s) | Depends on |
|---|------|---------|------------|
| 6 | Supabase Auth migration | `Core/Auth/AuthManager.swift`, `Core/Auth/SupabaseConfig.swift` | SPM + Info.plist |
| 7 | FeatureFlagService | `Core/Utils/FeatureFlagService.swift` (NEW) | Supabase client |
| 8 | Supabase `prompts` table sync (full history migration) | `Core/Storage/HistoryStore.swift` | Supabase Auth |
| 9 | Wire `AnalyticsService.uploadToSupabase()` | `Core/Utils/AnalyticsService.swift` | Supabase client |
| 10 | Wire `TelemetryService.uploadToSupabase()` | `Core/Utils/TelemetryService.swift` | Supabase client |
| 11 | Apple Sign-In (App Store mandatory) | `Core/Auth/OAuthCoordinator.swift` | Supabase Auth |
| 12 | StoreKit webhook → Edge Function | Supabase Edge Function (Deno) | Supabase project |
| 13 | Metal Orb rollout | `Core/Audio/OrbEngine.swift`, `Views/OrbView.swift` | FeatureFlagService |
| 14 | RLHF feedback UI | `Features/Home/Views/ResultView.swift` | Supabase prompts table |
| 15 | Real-time Trending | `Features/Trending/ViewModels/TrendingViewModel.swift` | Supabase Realtime |

