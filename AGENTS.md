# Prompt28 — AI Agent Guide

**Last updated: 2026-03-14**

This document provides essential information for AI coding agents working on the Prompt28 iOS project.

---

## Project Overview

Prompt28 is an AI-powered prompt generation iOS app built with SwiftUI. Users can speak or type their ideas, and the app generates professional prompts using AI. The app features a freemium subscription model, prompt history with favorites, trending prompts catalog, and voice input capabilities.

- **Platform**: iOS 26.2+ (Swift 5.0+)
- **Architecture**: SwiftUI with Observation framework (`@Observable`)
- **Minimum Deployment**: iOS 17+ (required for SwiftData `@Model` on `PromptHistoryItem`)
- **Bundle ID**: `com.prompt28.prompt28`
- **Backend**: https://promptme-app-production.up.railway.app

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI with Observation framework |
| Persistence | SwiftData (PromptHistoryItem), UserDefaults (preferences), Keychain (auth tokens) |
| Authentication | JWT tokens stored in Keychain; Google Sign-In, Apple Sign-In, Email/Password |
| Networking | URLSession with async/await |
| Audio | Speech framework (SFSpeechRecognizer), AVFoundation |
| In-App Purchases | StoreKit 2 |
| External Dependencies | GoogleSignIn (via Swift Package Manager) |

---

## Project Structure

```
PromptMeNative_Blueprint/          # Source root
├── App/                           # App-level components
│   ├── AppEnvironment.swift       # Dependency container (@Observable)
│   ├── AppUI.swift                # Design tokens, reusable UI components
│   ├── PremiumTabScreen.swift     # Tab screen wrapper
│   ├── RootView.swift             # Root state machine, PromptTheme, PromptPremiumBackground
│   └── Routing/
│       └── AppRouter.swift        # Navigation enums (RootRoute, MainTab)
├── Core/                          # Core business logic
│   ├── Auth/                      # Authentication (AuthManager, KeychainService, OAuthCoordinator)
│   ├── Networking/                # API layer (APIClient, APIEndpoint, NetworkError, RequestBuilder)
│   ├── Storage/                   # Data persistence (HistoryStore, PreferencesStore, SecureStore)
│   ├── Store/                     # IAP (StoreConfig, StoreManager, UsageTracker)
│   ├── Audio/                     # Voice input (OrbEngine, SpeechRecognizerService)
│   ├── Notifications/             # Push notifications
│   ├── Protocols/                 # Protocol definitions (APIClientProtocol, StorageProtocols)
│   └── Utils/                     # Utilities (Analytics, Haptics, JSONCoding, Date extensions)
├── Features/                      # Feature modules (MVVM pattern)
│   ├── Admin/                     # Dev-only admin panel
│   ├── Auth/                      # Login/signup flows
│   ├── History/                   # Prompt history and favorites
│   ├── Home/                      # Main generation screen with orb UI
│   ├── Onboarding/                # First-time user onboarding
│   ├── Privacy/                   # Privacy consent (GDPR/App Store compliance)
│   ├── Settings/                  # User settings and upgrade
│   └── Trending/                  # Trending prompts catalog
├── Models/                        # Data models
│   ├── API/                       # Server response models (User, AuthModels, GenerateModels, etc.)
│   └── Local/                     # Local storage models (PromptHistoryItem, AppPreferences)
├── Resources/                     # Bundled resources
│   ├── trending_prompts.json      # Bundled prompt catalog (44 prompts, 6 categories)
│   └── PrivacyInfo.xcprivacy      # Apple privacy manifest
└── PromptMeNativeApp.swift        # App entry point (@main)

Prompt28/                          # Xcode project configuration
├── Info.plist                     # App configuration, permissions, Google Sign-In
├── PrivacyInfo.xcprivacy          # Privacy manifest (duplicate)
└── Prompt28.entitlements          # App entitlements

Prompt28Tests/                     # Unit tests (Swift Testing framework)
Prompt28UITests/                   # UI tests (XCTest)
```

---

## Build Commands

### Build
```bash
xcodebuild -project Prompt28.xcodeproj -scheme Prompt28 -destination "platform=iOS Simulator,name=iPhone 17" build
```

### Test
```bash
# Run unit tests
xcodebuild test -project Prompt28.xcodeproj -scheme Prompt28 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:Prompt28Tests

# Run UI tests
xcodebuild test -project Prompt28.xcodeproj -scheme Prompt28 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:Prompt28UITests
```

### Clean Build
```bash
xcodebuild clean -project Prompt28.xcodeproj -scheme Prompt28
```

---

## Architecture Patterns

### Dependency Injection
All dependencies are centralized in `AppEnvironment` and injected via SwiftUI's environment:

```swift
@Observable @MainActor final class AppEnvironment {
    let apiClient: APIClient
    let keychain: KeychainService
    let authManager: AuthManager
    let historyStore: HistoryStore
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager
    let usageTracker: UsageTracker
}
```

Access in views:
```swift
@Environment(AppEnvironment.self) private var env
// Or specific values:
@Environment(\.authManager) private var authManager
```

**Rule**: Never instantiate stores directly in views. Always use environment injection.

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

### Unit Tests (Prompt28Tests/)
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

### UI Tests (Prompt28UITests/)
Uses standard XCTest framework for end-to-end testing.

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
2. Never remove window background color setup in `PromptMeNativeApp.init()` (prevents black flash)
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

### PromptHistoryItem (SwiftData Model)
```swift
@Model
final class PromptHistoryItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var mode: PromptMode  // ai, human
    var input: String
    var professional: String
    var template: String
    var favorite: Bool
    var customName: String?
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
| `/api/auth/me` | GET | Bearer |
| `/api/generate` | POST | Bearer |
| `/api/config` | GET | None |
| `/api/settings` | GET | None |
| `/api/prompts/trending` | GET | None |

---

## Resources

- **HANDOFF.md**: Comprehensive developer handoff document with detailed architecture
- **trending_prompts.json**: Bundled catalog with 44 prompts across 6 categories (email, content, career, creative, coding, research)
- **PrivacyInfo.xcprivacy**: Apple privacy manifest for App Store compliance
