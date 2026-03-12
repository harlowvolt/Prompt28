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

