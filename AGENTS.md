# Prompt28 (Orion Orb) — AI Agent Guide (Phase 2.5 Hardening)

**Last updated: 2026-03-19 | Version v2.2 (Phase 2 hardening / Phase 2.5)**

This document provides essential information for AI coding agents working on the Prompt28 iOS project (marketed as "Orion Orb"). **SwiftData has been removed. CloudKit has been removed. Persistence is now Codable JSON + Supabase sync.**

---

## Project Overview

Prompt28 is an AI-powered prompt generation iOS app built with SwiftUI. Users can speak or type their ideas, and the app generates professional prompts using AI. The app features a freemium subscription model, prompt history with favorites, trending prompts catalog, and voice input capabilities.

- **Platform**: iOS 17.0+ (Swift 5.0+)
- **Architecture**: SwiftUI with Observation framework (`@Observable`)
- **App Name**: Orion Orb (display name), Prompt28 (project name)
- **Bundle ID**: `com.prompt28.prompt28`
- **Backend**: https://promptme-app-production.up.railway.app

## Current State

- **Current phase:** Phase 2 hardening / Phase 2.5
- **Architecture:** native iOS 17+ SwiftUI app
- **Persistence:** no SwiftData, no CloudKit
- **Auth:** Supabase Auth integrated
- **OAuth:** Google sign-in working; Apple sign-in flow exists in code
- **Hybrid backend status:** Railway remains only for legacy endpoints during migration
- **Validation truth:** implementation has improved, but Phase 2 hardening is not fully validated unless `xcodebuild test` has returned real pass/fail results

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI with Observation framework |
| Persistence | **Codable JSON** (local @ `Application Support/OrionOrb/history.json`), pending deletes @ `Application Support/OrionOrb/history_pending_deletes.json`, **Supabase** (two-way sync, last-write-wins, delete propagation), UserDefaults (preferences), Keychain (auth tokens) |
| Authentication | **Supabase Auth** with JWT stored in Keychain; Google Sign-In, Apple Sign-In, Email/Password |
| Database Backend | **Supabase PostgreSQL** (prompts, events, telemetry_errors tables) |
| Legacy API | Railway backend (https://promptme-app-production.up.railway.app) — for plan info during bootstrap |
| Networking | URLSession with async/await |
| Audio | Speech framework (SFSpeechRecognizer), AVFoundation |
| In-App Purchases | StoreKit 2 |
| External Dependencies | GoogleSignIn (9.1.0) via Swift Package Manager |

---

## Project Structure

```
PromptMeNative_Blueprint/          # Source root
├── App/                           # App-level components
│   ├── AppEnvironment.swift       # Dependency container (@Observable)
│   ├── AppUI.swift                # Design tokens, reusable UI components, spacing constants
│   ├── OrionMainContainer.swift   # Main container view
│   ├── PremiumTabScreen.swift     # Tab screen wrapper
│   ├── RootView.swift             # Root state machine, PromptTheme, PromptPremiumBackground
│   └── Routing/
│       └── AppRouter.swift        # Navigation enums (RootRoute, MainTab, HomeSheet)
├── Components/                    # Reusable UI components
│   └── Glassmorphism.swift        # GlassContainer, GlassButton, GlassCard, GlassOrb
├── Core/                          # Core business logic
│   ├── Auth/                      # Authentication (AuthManager, KeychainService, OAuthCoordinator)
│   ├── Networking/                # API layer (APIClient, APIEndpoint, NetworkError, RequestBuilder)
│   ├── Storage/                   # Data persistence (HistoryStore, PreferencesStore, SecureStore)
│   ├── Store/                     # IAP (StoreConfig, StoreManager, UsageTracker)
│   ├── Audio/                     # Voice input (OrbEngine, SpeechRecognizerService)
│   ├── Notifications/             # Push notifications (NotificationService)
│   ├── Protocols/                 # Protocol definitions (APIClientProtocol, StorageProtocols)
│   └── Utils/                     # Utilities (Analytics, Haptics, JSONCoding, Date extensions, Telemetry)
├── Features/                      # Feature modules (MVVM pattern)
│   ├── Admin/                     # Dev-only admin panel (AdminDashboardView, AdminPromptsView, etc.)
│   ├── Auth/                      # Login/signup flows (AuthFlowView, EmailAuthView, AuthViewModel)
│   ├── History/                   # Prompt history and favorites (HistoryView, FavoritesView, HistoryViewModel)
│   ├── Home/                      # Main generation screen with orb UI
│   │   ├── Views/                 # HomeView, OrbView, ResultView, TypePromptView, ShareCardView, etc.
│   │   └── ViewModels/            # GenerateViewModel, HomeViewModel
│   ├── Onboarding/                # First-time user onboarding (OnboardingView)
│   ├── Privacy/                   # Privacy consent (PrivacyConsentView)
│   ├── Settings/                  # User settings and upgrade (SettingsView, UpgradeView, SettingsViewModel)
│   └── Trending/                  # Trending prompts catalog (TrendingView, PromptDetailView, TrendingViewModel)
├── Models/                        # Data models
│   ├── API/                       # Server response models (User, AuthModels, GenerateModels, PromptCatalogModels, SettingsModels)
│   └── Local/                     # Local storage models (PromptHistoryItem, AppPreferences)
├── Resources/                     # Bundled resources
│   ├── trending_prompts.json      # Bundled prompt catalog (44 prompts, 7 categories)
│   └── PrivacyInfo.xcprivacy      # Apple privacy manifest
└── OrionOrbApp.swift              # App entry point (@main) - OrionOrbApp

Prompt28/                          # Xcode project configuration
├── Info.plist                     # App configuration, permissions, Google Sign-In
├── PrivacyInfo.xcprivacy          # Privacy manifest
└── Prompt28.entitlements          # App entitlements

OrionOrbTests/                     # Unit tests (Swift Testing framework)
OrionOrbUITests/                   # UI tests (XCTest)
```

---

## Build Commands

### Build
```bash
xcodebuild -project Prompt28.xcodeproj -scheme OrionOrb -destination "platform=iOS Simulator,name=iPhone 16" build
```

### Test
```bash
# Run unit tests
xcodebuild test -project Prompt28.xcodeproj -scheme OrionOrb -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:OrionOrbTests

# Run UI tests
xcodebuild test -project Prompt28.xcodeproj -scheme OrionOrb -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:OrionOrbUITests
```

Important current note:
- The shared `OrionOrb` scheme is now focused on unit-test execution and no longer includes `Prompt28UITests` in the main `TestAction`.
- Do not assume Phase 2 hardening is validated unless `xcodebuild test` completes and reports real pass/fail results.

### Clean Build
```bash
xcodebuild clean -project Prompt28.xcodeproj -scheme OrionOrb
```

---

## Architecture Patterns

### Dependency Injection
All dependencies are centralized in `AppEnvironment` and injected via SwiftUI's environment:

```swift
@Observable @MainActor final class AppEnvironment {
    let supabase: SupabaseClient              // Live Supabase auth & database
    let apiClient: APIClient                  // Legacy Railway API (for bootstrap user plan info)
    let keychain: KeychainService
    let authManager: AuthManager              // Supabase Auth
    let historyStore: HistoryStore            // JSON + Supabase sync
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager            // StoreKit 2
    let usageTracker: UsageTracker
    let telemetryService: TelemetryService    // Uploads to Supabase telemetry_errors
    let speechRecognizerFactory: SpeechRecognizerFactoryProtocol
    let orbEngineFactory: OrbEngineFactoryProtocol
}
```

Access in views:
```swift
@Environment(AppEnvironment.self) private var env
// Or specific values:
@Environment(\.authManager) private var authManager
```

**Rule**: Never instantiate stores directly in views. Always use environment injection.

### HistoryStore Current Behavior

`HistoryStore` is the source of truth for current prompt history persistence behavior:

- Local-first JSON persistence remains primary.
- Supabase sync remains secondary / best-effort.
- Immediate best-effort sync now occurs after:
  - `add(_:)`
  - `toggleFavorite(id:)`
  - `rename(id:customName:)`
- Launch-time sync runs if an authenticated Supabase session already exists.
- Sync also responds to:
  - `.signedIn`
  - `.tokenRefreshed`
  - `.userUpdated`
- On:
  - `.signedOut`
  - `.userDeleted`
  local history state is cleared from memory and disk to prevent cross-user contamination.
- Delete propagation now exists:
  - pending delete IDs are persisted in `history_pending_deletes.json`
  - pending deletes retry on future sync
- Merge behavior is last-write-wins by `lastModified`:
  - unsynced local records upsert first
  - remote records fetch and merge after upload

### State Machine (RootView)
```
App launch
  └── hasAcceptedPrivacy = false  →  PrivacyConsentView
  └── hasAcceptedPrivacy = true
        └── didBootstrap = false  →  launchView (spinner)
        └── bootstrap() runs      →  didBootstrap = true
              ├── isAuthenticated = false  →  AuthFlowView
              ├── isAuthenticated = true, hasSeenOnboarding = false  →  OnboardingView
              └── isAuthenticated = true, hasSeenOnboarding = true
                    ├── iPhone (.compact)  →  mainTabs (TabView)
                    └── iPad (.regular)    →  iPadSidebar (NavigationSplitView)
```

### Navigation Rules

**⚠️ CRITICAL**: Every view containing a `NavigationStack` must place `PromptPremiumBackground().ignoresSafeArea()` as the FIRST item in its top-level ZStack. The NavigationStack's opaque `UINavigationController` layer blocks parent backgrounds.

Screens with NavigationStack that own their background:
- HomeView
- HistoryView
- FavoritesView
- TrendingView

---

## Design System

All design tokens are centralized in two files:

### PromptTheme (RootView.swift)
```swift
enum PromptTheme {
    static let backgroundBase = Color(hex: "#02060D")
    static let deepShadow = Color(hex: "#050A16")
    static let plum = Color(hex: "#07101E")
    static let mutedViolet = Color(hex: "#5D628A")
    static let softLilac = Color(hex: "#CFD7FF")
    static let paleLilacWhite = Color(hex: "#F2F5FF")
    
    static let glassFill = Color(red: 0.15, green: 0.17, blue: 0.22).opacity(0.72)
    static let glassStroke = Color.white.opacity(0.14)
    
    // Typography helper
    static func Typography.rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font
}
```

### Spacing/Heights/Radii (AppUI.swift)
```swift
AppSpacing.screenHorizontal = 18
AppSpacing.section = 24
AppSpacing.element = 12
AppSpacing.bottomContentClearance = 88  // clears floating tab bar

AppHeights.searchBar = 56
AppHeights.primaryButton = 56
AppHeights.tabBarClearance = 102  // spacer at bottom of scroll views

AppRadii.card = 24
AppRadii.control = 22
AppRadii.field = 18
```

### Glass Card System
Use the single source of truth for glass cards:
```swift
// Background only
.background { PromptTheme.glassCard(cornerRadius: AppRadii.card) }

// Background + shadow
.appGlassCard(radius: AppRadii.card)
```

---

## Code Style Guidelines

1. **SwiftUI Views**: Use `@ViewBuilder` for complex conditional views
2. **Observable Pattern**: Use `@Observable @MainActor` for view models
3. **Access Control**: Mark services as `final class`, use `private(set)` for published properties
4. **Error Handling**: Use custom `NetworkError` enum with user-friendly messages
5. **Comments**: Document workarounds and non-obvious behavior; don't state the obvious
6. **Formatting**: Use 4-space indentation, trailing closures on new lines for complex blocks

---

## Testing Strategy

### Unit Tests (OrionOrbTests/)
Uses the Swift Testing framework (modern replacement for XCTest):

```swift
import Testing
@testable import Prompt28

@Suite("UsageTracker")
struct UsageTrackerTests {
    @Test("Starter plan: first 10 generations are allowed")
    func starterAllowsTenGenerations() {
        // Test implementation
    }
}
```

Key test suites:
- `UsageTrackerTests` - Freemium usage counter logic
- `AppPreferencesTests` - Preference serialization
- `PromptModeTests` - Mode enum behavior
- `PlanTypeTests` - Plan type handling
- `SpeechErrorClassificationTests` - Speech recognition error handling
- `HistoryStoreTests` - storage hardening, sync triggers, pending deletes, isolation behavior

### UI Tests (OrionOrbUITests/)
Uses standard XCTest framework for end-to-end testing.

## Testing / Validation Status

- Unit test target now points to the real `OrionOrbTests` folder.
- History tests use MainActor-safe polling.
- `OrionOrbApp` includes a test-mode bypass so unit tests do not bootstrap the full app environment.
- `HistoryStore` includes deterministic test seams/hooks for validation:
  - disable auth listener on init
  - disable automatic lifecycle observation
  - disable initial session reconciliation on init
  - inject session provider
  - inject sync executor
- `HistoryStore` now withholds disk-loaded history from public `items` until initial auth/session reconciliation completes, to prevent stale wrong-user history from appearing during launch/sign-out/account switching.
- `HistoryStore` also persists a local history owner file (`history_owner.txt`) and resets cached local history if a different signed-in user is detected.
- `HistoryStore` persistence now includes deferred owned history during the initial reconciliation window, so early post-launch saves do not drop cached history before it is restored.
- `HistoryStore` now removes existing lifecycle observer tokens before re-registering foreground observers, preventing duplicate retry observers.
- `HistoryStore` now clears ambiguous unowned local history when a signed-in session is resolved and no trusted owner file exists, rather than adopting that cache for the current user.
- All authenticated sync entrypoints now go through one shared preparation path so owner binding and deferred-history restore happen consistently before sync.
- Deferred-history restore and persistence now both exclude pending-deleted IDs, preventing quick post-launch deletes from being reintroduced by hidden cache state.
- `HistoryStore` also has an internal foreground-retry hook used only to make the foreground retry test deterministic without changing production notification behavior.
- Storage hardening code is improved and compiles.
- Simulator ambiguity is resolved by using only:
  - `Prompt28-iPhone17`
  - `06B488AD-877C-4EC1-A472-E2053BD31DB9`
- Confirmed passing hosted test on simulator `Prompt28-iPhone17` (`06B488AD-877C-4EC1-A472-E2053BD31DB9`):
  - `Prompt28Tests/HistoryStoreTests/coldLaunchExistingSessionTriggersSync`
- Current first validation blocker:
  - `Prompt28Tests/HistoryStoreTests/foregroundRetrySyncsPendingWork`
  - initial session reconciliation race already removed for that test
  - direct invocation seam added so the test no longer depends on UIKit foreground notification delivery
  - lifecycle observation is now also disabled for that test, so it no longer depends on hosted app lifecycle behavior
  - hosted run still does not complete with a real pass/fail result
  - latest process inspection showed only `xcodebuild` alive after build/package handoff, with no visible `xctest`/`XCTRunner` process
- Physical-device manual validation is now the primary short-term validation path.
- Hosted simulator test execution remains useful but is now secondary while Phase 2 continues.
- Prompt generation still uses the legacy Railway `/api/generate` endpoint in the current repo state.
- StoreKit product loading does not gate free-tier generation in `GenerateViewModel`.
- `GenerateViewModel` now refreshes the Supabase session before generate and retries once on a legacy 401/session-expired response.
- `APIClient` now exposes raw backend/body text for `/api/generate` failure paths when possible, instead of collapsing them into generic decode/server messages.
- Automated validation completion is still pending unless `xcodebuild test` has completed with real pass/fail output.

## Known Remaining Gaps

- Do not mark Phase 2 hardening as complete until history validation actually finishes end to end.
- Current repo state supports more deterministic testing, but test-execution completion still needs to be proven in a clean run.
- Latest attempted command:
  - `xcodebuild test -project Prompt28.xcodeproj -scheme OrionOrb -destination 'id=06B488AD-877C-4EC1-A472-E2053BD31DB9' -derivedDataPath /tmp/Prompt28DerivedData -only-testing:Prompt28Tests/HistoryStoreTests/foregroundRetrySyncsPendingWork -resultBundlePath /tmp/prompt28-foregroundRetry-4.xcresult`
- Latest result:
  - no real XCTest result returned
- Next recommended move is to continue Phase 2 hardening work and validate on physical iPhone first; revisit the hosted simulator runner issue only if it becomes necessary again.

---

## Critical Rules

### ✅ SAFE — Always Allowed
- Modifying text content, font sizes, font weights
- Changing Color values or opacity
- Adjusting padding, spacing, frame heights
- Adding `@State` variables to existing views
- Modifying ViewModel logic
- Adding cases to ViewModels' `@Published` properties
- Editing API endpoint logic

### ⚠️ CAUTION — Follow Rules
- Adding `PromptPremiumBackground()`: Only if view has NavigationStack and doesn't already have one. Place as first child of outermost ZStack.
- Modifying `PromptTheme` tokens: Search all usages first.
- Modifying `glassCard(cornerRadius:)`: Test all tabs after changes.
- Modifying `TabBarRaiser`: Affects all tab bar behavior.

### ❌ NEVER DO THESE
1. Never remove `PromptPremiumBackground()` from views with NavigationStack
2. Never remove window background color setup in `OrionOrbApp.init()` (prevents black flash)
3. Never use `geo.size.width/height` inside `PromptPremiumBackground`'s inner ZStack frame (use `.frame(maxWidth: .infinity, maxHeight: .infinity)`)
4. Never add NavigationStack to a view that already wraps inside another NavigationStack
5. Never change `.toolbar(.hidden, for: .navigationBar)` on main tab screens
6. Never create a new glass card implementation — use `PromptTheme.glassCard(cornerRadius:)`
7. Never remove `Color.clear.frame(height: AppHeights.tabBarClearance)` from scroll views
8. Never move `PrivacyConsentView` gate below bootstrap/auth checks in `RootView`

---

## Security Considerations

1. **Authentication**: JWT tokens stored in Keychain (never UserDefaults)
2. **OAuth**: Google Sign-In and Apple Sign-In use standard SDK flows
3. **API Keys**: No hardcoded API keys in source; admin operations require admin key
4. **Privacy**: Privacy manifest documents all data collection (email, name, user content, product interaction)
5. **Permissions**: Microphone and Speech Recognition require usage descriptions in Info.plist

---

## External Dependencies

Managed via Swift Package Manager (see Xcode project):
- **GoogleSignIn** (9.1.0) - Google OAuth authentication
- **AppAuth** (2.0.0) - OAuth 2.0 and OpenID Connect client
- **GTMAppAuth** (5.0.0) - Google Toolbox for Mac AppAuth integration
- **GTMSessionFetcher** (3.5.0) - Google HTTP fetcher

---

## Key Models

### User (API Response)
```swift
struct User: Decodable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String
    let provider: String
    let plan: PlanType  // starter, pro, unlimited, dev
    let prompts_used: Int
    let prompts_remaining: Int?
    let period_end: String
}
```

### PromptHistoryItem (Codable Local Model with Supabase Sync)
```swift
final class PromptHistoryItem: Codable, Identifiable {
    var id: UUID
    var createdAt: Date
    var mode: PromptMode  // ai, human
    var input: String
    var professional: String
    var template: String
    var favorite: Bool
    var customName: String?
    var lastModified: Date        // Drives last-write-wins merge
    var isSynced: Bool            // false = queued for Supabase upsert
}
```

### PlanType
```swift
enum PlanType: String, Codable, CaseIterable {
    case starter      // Free: 10 generations/month
    case pro          // Paid
    case unlimited    // Paid
    case dev          // Developer/admin
}
```

---

## API Endpoints

Base URL: `https://promptme-app-production.up.railway.app`

| Endpoint | Method | Auth |
|----------|--------|------|
| `/api/auth/register` | POST | None |
| `/api/auth/login` | POST | None |
| `/api/auth/google` | POST | None |
| `/api/auth/apple` | POST | None |
| `/api/me` | GET | Bearer |
| `/api/generate` | POST | Bearer |
| `/api/config` | GET | None |
| `/api/settings` | GET | None |
| `/api/prompts/trending` | GET | None |

---

## Freemium Model

The app uses a freemium model with the following rules:

- **Starter Plan**: 10 free generations per calendar month
- **Pro/Unlimited/Dev Plans**: Unlimited generations
- Usage is tracked client-side in Keychain (`UsageTracker`) and synced with server
- Counter resets monthly based on calendar month

---

## Resources

- **trending_prompts.json**: Bundled catalog with 44 prompts across 7 categories:
  - Email & Outreach (8 prompts)
  - Content & Social (7 prompts)
  - Career & Resume (7 prompts)
  - Business & Strategy (7 prompts)
  - Creative Writing (6 prompts)
  - Productivity & Planning (7 prompts)
- **PrivacyInfo.xcprivacy**: Apple privacy manifest for App Store compliance
