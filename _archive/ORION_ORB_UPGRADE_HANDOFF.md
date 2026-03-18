# ORION Orb Upgrade — Handoff Document

**Version:** 1.0  
**Created:** 2026-03-14  
**Status:** Architecture audit complete, ready for upgrade planning  
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
