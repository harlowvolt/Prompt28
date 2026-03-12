# Prompt28 — AI Handoff Document

**Last updated: 2026-03-12. Safe for Codex, Gemini, ChatGPT, and future Claude sessions.**

---

## 1. Architecture Summary

Prompt28 is a SwiftUI iOS app (Swift 5.9+, **iOS 17+**) built with the Observation framework (`@Observable`).

> ⚠️ **Minimum deployment target is iOS 17**, required by SwiftData (`@Model` on `PromptHistoryItem`). Do not lower this to iOS 16 — the `HistoryStore` `ModelContext` APIs are unavailable there.

It uses a single shared `AppEnvironment` injected via `.environment()` at the root.

### Entry Point
`PromptMeNative_Blueprint/` is the source root. All Swift source is inside here.

### State Machine (RootView)
```
App launch
  └── hasAcceptedPrivacy = false  →  PrivacyConsentView  (blocks ALL other UI; bootstrap fires in bg)
  └── hasAcceptedPrivacy = true
        └── didBootstrap = false  →  launchView (spinner)
        └── bootstrap() runs      →  didBootstrap = true
              ├── isAuthenticated = false  →  AuthFlowView
              ├── isAuthenticated = true, hasSeenOnboarding = false  →  OnboardingView
              └── isAuthenticated = true, hasSeenOnboarding = true
                    ├── iPhone (.compact)  →  mainTabs (TabView)
                    └── iPad (.regular)    →  iPadSidebar (NavigationSplitView)
```
Privacy gate satisfies App Store Review Guideline 5.1.2(i). Consent flag stored in `@AppStorage("hasAcceptedPrivacy")`.

### AppEnvironment (the dependency container)
```swift
// File: App/AppEnvironment.swift
@Observable @MainActor final class AppEnvironment {
    let apiClient: APIClient         // API base: https://promptme-app-production.up.railway.app
    let keychain: KeychainService
    let authManager: AuthManager
    let historyStore: HistoryStore
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager
    let usageTracker: UsageTracker    // ← Keychain-backed freemium monthly counter
}
```
Pass `env` to views via `@Environment(AppEnvironment.self)`. Never instantiate stores directly in a view.

### Tab System
```swift
// File: App/Routing/AppRouter.swift
enum MainTab: Hashable { case home, trending, history, favorites, admin }
```
- iPhone: `TabView(selection: $selectedTab)` in `RootView.mainTabs`
- iPad: `NavigationSplitView` in `RootView.iPadSidebar` — admin tab is phone-only (redirects to home on iPad)
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
│   │   ├── HistoryStore.swift        ← SwiftData-backed prompt history (ModelContext CRUD)
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
│       ├── BundleCatalogLoader.swift ← loads bundled trending_prompts.json for zero-latency launch
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
│       └── PromptHistoryItem.swift   ← @Model class (SwiftData, iOS 17+)
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
1. `PromptMeNative_Blueprint/PromptMeNativeApp.swift` (root container creation + scoped key injection source)

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

