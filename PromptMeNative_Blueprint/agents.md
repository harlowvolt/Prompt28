# Orbit Orb — Agent & Developer Reference

> **Single Source of Truth** — All architecture, design system, naming, and App Store compliance notes live here.
> Last updated: 2026-04-03
> Target: iOS 17+, SwiftUI, Swift 6 strict concurrency

---

## 1. App Identity

| Property | Value |
|----------|-------|
| **Brand name** | **Orbit Orb** (two words, title-case, always) |
| **Bundle ID** | `com.prompt28.app` (App Store Connect — do not change) |
| `CFBundleDisplayName` | `Orbit Orb` (drives iOS system permission dialogs) |
| StoreKit product IDs | `com.prompt28.*` (tied to App Store Connect — do not change) |
| Internal UserDefaults keys | `promptme_*` (changing breaks existing user data — do not rename) |
| Notification identifiers | `com.prompt28.*` (system-registered — do not change) |
| Website | `orbitorb.app` |
| Terms URL | `https://orbitorb.app/terms` |
| Privacy URL | `https://orbitorb.app/privacy` |

**RULE:** The brand name is always **Orbit Orb** everywhere — in UI text, comments, system dialogs, share cards, analytics events, and this document. Never "Orion Orb", "Prompt28", "PromptMe", or any other variant.

---

## 2. Architecture

Orbit Orb follows **Feature-first MVVM** with a single shared dependency container (`AppEnvironment`).

```
OrionOrbApp.swift          @main entry point
└── AppEnvironment          All services created once on @MainActor
└── RootView                Routing shell: loading → auth gate → home
    └── HomeView            Primary screen — all prompt generation logic
        ├── GenerateViewModel   Prompt generation, history, privacy gate
        ├── OrbEngine           Voice/speech state machine
        └── ResultView          Rendered result: copy, share, favorite, refine
```

### Key principles

- **One screen at a time.** The app is a single-screen product. All flows open as sheets from `HomeView`.
- **No global state mutation outside `@MainActor`.** All view models are `@Observable @MainActor`.
- **Observation Framework:** All state management must use iOS 17 `@Observable`. No `ObservableObject`, no `@Published`, and no Combine `AnyPublisher`-driven view state.
- **Dependency injection via SwiftUI Environment.** `AppEnvironment` seeds all services into the tree via `EnvironmentKey`s defined in `AppEnvironment.swift`.
- **Design System Strictness:** No inline hex colors or ad hoc `Color(hex:)` usage are allowed in Views or Models. Every app color must reference a named `PromptTheme` token (see Section 6).
- **Frictionless Input:** Prompt typing must happen inline in `HomeView` using native `TextField(axis: .vertical)` fields. Do not present modal typing sheets.
- **iPad Support (Universal App):** All major content surfaces must constrain readable width on iPad, use native SwiftUI presentation APIs, and respect `.horizontalSizeClass`.
- **Guest Mode First:** The app never hard-blocks launch with a forced login wall. All users can start in local guest mode; authentication is requested only when the user explicitly needs sync/account features or hits the free guest limit.

---

## 3. User Flow (Approved — App Store Compliant)

```
App Launch
    │
    ▼
Bootstrap loading (< 1 s)  ← ProgressView spinner, "Loading Orbit Orb" label
    │
    ▼
HomeView opens immediately in guest mode
    │
    ├─ Guest under local limit ──▶ Continue using app normally
    ├─ User taps a sync/account action ──▶ AuthFlowView sheet
    └─ Guest hits free limit ──▶ AuthFlowView sheet
```

**Removed screens (do not re-add):**
- ~~PrivacyConsentView~~ — replaced by T&C + Privacy links in `AuthFlowView` footer (Guideline 5.1.2 compliant)
- ~~OnboardingView~~ — removed to reduce friction; new users land directly in the app

**Apple App Store compliance:**
- **Guideline 5.1.2(i):** Privacy disclosure is satisfied by the Terms of Service and Privacy Policy links visible in `AuthFlowView.termsFooter` before the user submits any credentials. This is the same pattern used by Linear, ChatGPT, and Notion.
- **Guideline 4.8:** Sign In with Apple uses `SignInWithAppleButton` natively (not a custom button).
- **Guideline 2.1:** App works without any additional gate screens after download.
- **Guideline 2.1 / iPad UX:** Share flows must prefer native `ShareLink`, and iPad layouts must use constrained readable columns instead of full-width stretched composition surfaces.

---

## 4. File Map — Every Source File

### App Layer (`PromptMeNative_Blueprint/App/`)

| File | Role |
|------|------|
| `OrionOrbApp.swift` | `@main` entry; injects `AppEnvironment` into SwiftUI environment; sets `UIWindow` background to `#0B0C18` |
| `AppEnvironment.swift` | DI container: Supabase, auth, history, preferences, usage, router, telemetry, speech/orb factories |
| `RootView.swift` | Routing shell + `PromptTheme` enum (color token source of truth) + `PromptPremiumBackground` + `Color(hex:)` extension |
| `AppUI.swift` | Shared UI constants: `AppSpacing`, `AppHeights`, `AppRadii`, `AppGlassField`, `AppPrimaryButton` |
| `PremiumTabScreen.swift` | Paywall/upgrade tab placeholder |
| `Routing/AppRouter.swift` | `@Observable` navigation state: `selectedTab`, `activeHomeSheet`, auth/paywall sheet routing |

### Core Layer (`PromptMeNative_Blueprint/Core/`)

| File | Role |
|------|------|
| `Auth/AuthManager.swift` | Supabase auth: email login/register, Google OAuth, Apple Sign In, token refresh, `isBootstrapping` flag |
| `Auth/OAuthCoordinator.swift` | Google OAuth: presents `ASWebAuthenticationSession`, returns ID token |
| `Auth/KeychainService.swift` | Keychain CRUD wrapper |
| `Auth/SupabaseConfig.swift` | Reads `SUPABASE_URL` + `SUPABASE_ANON_KEY` from `Info.plist` |
| `Audio/OrbEngine.swift` | Voice state machine: `idle → listening → transcribing → done/failure`; drives orb animation |
| `Audio/SpeechRecognizerService.swift` | `SFSpeechRecognizer` wrapper; transcribes live audio to text |
| `Networking/APIClient.swift` | URLSession wrapper; JWT-authenticated requests to Supabase Edge Functions |
| `Networking/APIEndpoint.swift` | Endpoint definitions |
| `Networking/NetworkError.swift` | Typed network error enum |
| `Networking/RequestBuilder.swift` | Builds `URLRequest` from `APIEndpoint` |
| `Notifications/NotificationService.swift` | Low-usage nudge notifications (skipped when `privacyMode == true`) |
| `Storage/HistoryStore.swift` | `@Observable` local + Supabase-backed prompt history; `add()` is guarded by `privacyMode` |
| `Storage/PreferencesStore.swift` | `@Observable` user preferences (`PromptMode`, `saveHistory`) — persisted via `UserDefaults` |
| `Storage/SecureStore.swift` | Keychain-backed secure storage wrapper |
| `Store/StoreManager.swift` | StoreKit 2 subscription management |
| `Store/StoreConfig.swift` | Product ID constants (`com.prompt28.*`) |
| `Store/UsageTracker.swift` | Keychain-backed monthly generation counter (freemium gate) |
| `Utils/AnalyticsService.swift` | `track(.eventName)` — queues events to `events` Supabase table |
| `Utils/TelemetryService.swift` | Crash/performance telemetry |
| `Utils/HapticService.swift` | Haptic feedback wrapper |
| `Utils/JSONCoding.swift` | Shared JSON encoder/decoder |
| `Utils/Date+Extensions.swift` | `Date` helpers |

### Features Layer (`PromptMeNative_Blueprint/Features/`)

| File | Role |
|------|------|
| `Auth/Views/AuthFlowView.swift` | Sign-in/sign-up screen: Google, Apple, email/password; brand header with `OrbitLogoView`; T&C + Privacy footer |
| `Auth/Views/EmailAuthView.swift` | Email-only auth variant (sheet) |
| `Auth/ViewModels/AuthViewModel.swift` | Auth screen state |
| `Home/Views/HomeView.swift` | Primary UI: nav bar, orb, mode pills, input bar (`+` image picker, text field), ghost mode toggle, sheets |
| `Home/Views/OrbView.swift` | SwiftUI orb animation (fallback) |
| `Home/Views/MetalOrbView.swift` | GPU shader orb variant (toggled by `ExperimentFlags.Orb.metalOrb`) |
| `Home/Views/OrbitLogoView.swift` | Orbital rings SVG-style logo — used in `AuthFlowView` header and `HomeView` idle state |
| `Home/Views/ResultView.swift` | Displays generated prompt; copy, share (`ShareLink`), favorite, feedback, refine |
| `Home/Views/PromptShareCard.swift` | On-demand SwiftUI share-card view rendered with `ImageRenderer` for sharing |
| `Home/ViewModels/GenerateViewModel.swift` | Prompt generation: calls Supabase Edge Function, saves to `HistoryStore` if `!privacyMode`, `attachedImage` for future image context |
| `Home/ViewModels/HomeViewModel.swift` | Additional home-screen state (not the primary VM) |
| `History/Views/HistoryView.swift` | Prompt history list |
| `History/Views/FavoritesView.swift` | Favorited prompts list |
| `History/ViewModels/HistoryViewModel.swift` | History screen state |
| `Settings/Views/SettingsView.swift` | User settings; links to `orbitorb.app/privacy` and `orbitorb.app/terms` |
| `Settings/Views/UpgradeView.swift` | Upgrade/paywall screen |
| `Settings/ViewModels/SettingsViewModel.swift` | Settings screen state |
| `Trending/Views/TrendingView.swift` | Trending prompts feed |
| `Trending/Views/PromptDetailView.swift` | Individual trending prompt detail |
| `Trending/ViewModels/TrendingViewModel.swift` | Trending screen state |
| `Admin/Views/AdminDashboardView.swift` | Admin dashboard (phone-only; iPad redirects to Home) |
| `Admin/Views/AdminCategoriesView.swift` | Admin category management |
| `Admin/Views/AdminPromptsView.swift` | Admin prompt management |
| `Admin/Views/AdminPromptEditorSheet.swift` | Admin prompt editor sheet |
| `Admin/Views/AdminTextSettingsView.swift` | Admin text settings |
| `Admin/Views/AdminUnlockView.swift` | Admin unlock gate |
| `Admin/ViewModels/AdminViewModel.swift` | Admin screen state |
| `Onboarding/Views/OnboardingView.swift` | **DEAD CODE** — no longer referenced in routing; safe to delete |
| `Privacy/PrivacyConsentView.swift` | **DEAD CODE** — no longer referenced in routing; safe to delete |

### Models (`PromptMeNative_Blueprint/Models/`)

| File | Role |
|------|------|
| `API/GenerateModels.swift` | `GenerateRequest` / `GenerateResponse` — Supabase Edge Function payload |
| `API/AuthModels.swift` | Auth request/response types |
| `API/User.swift` | `User` model |
| `API/PromptCatalogModels.swift` | Trending/catalog prompt models |
| `API/SettingsModels.swift` | Settings API models |
| `Local/AppPreferences.swift` | `AppPreferences` struct persisted by `PreferencesStore` |
| `Local/PromptHistoryItem.swift` | Local history item model |

### Resources

| Path | Role |
|------|------|
| `Resources/Assets.xcassets/AppIcon.appiconset/icon.png` | **App icon** — iOS universal 1024×1024 PNG, Orbit Orb orbital rings logo on `#0B0C18` navy |
| `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | Declares `icon.png` as universal iOS icon |
| `Resources/Assets.xcassets/AccentColor.colorset/Contents.json` | Accent color `#6C4BFF` (matches `PromptTheme.mutedViolet`) |
| `Prompt28/Info.plist` | App configuration, API keys, permission usage strings, URL schemes |
| `Prompt28/PrivacyInfo.xcprivacy` | App Store privacy nutrition label |

### Xcode Project

| Path | Role |
|------|------|
| `Prompt28.xcodeproj/project.pbxproj` | Project structure; `Assets.xcassets` must be in `PBXResourcesBuildPhase` for icon to compile |

---

## 5. State Management

### `@Observable` (Swift Observation, iOS 17+)
All view models and stores use `@Observable`. No `ObservableObject` / `@Published` anywhere, and no Combine `AnyPublisher` view-state bridge layers are allowed.
Views that consume observable objects use `@State` (locally owned VMs) or `@Environment` (shared services).

Types that must stay outside observation, such as rendered share images or platform framework helpers, should use `@ObservationIgnored` where appropriate.

### Environment injection pattern
```swift
// 1. Declare EnvironmentKey in AppEnvironment.swift
private struct HistoryStoreKey: EnvironmentKey {
    static let defaultValue: (any HistoryStoring)? = nil
}
extension EnvironmentValues {
    var historyStore: (any HistoryStoring)? {
        get { self[HistoryStoreKey.self] }
        set { self[HistoryStoreKey.self] = newValue }
    }
}

// 2. Inject at root in OrionOrbApp.swift
.environment(\.historyStore, env.historyStore)

// 3. Consume in any child view
@Environment(\.historyStore) private var historyStore
```

---

## 6. Design System — Color Token Source of Truth

**ABSOLUTE RULE: No inline hex literals anywhere in the codebase.** Every color must reference a `PromptTheme` token. All tokens are declared in `enum PromptTheme` inside `RootView.swift`.

If you need a new color, add a named token to `PromptTheme` first, document it here, then use the token.

Views and models may not store raw hex strings as styling data. If a feature needs a semantic color, add a named theme token or a semantic mapping that returns theme tokens.

### 6.1 Background Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `PromptTheme.backgroundBase` | `#0B0C18` | Deepest layer — matches the logo's outer dark navy field; also `UIWindow` background |
| `PromptTheme.deepShadow` | `#0D0E1E` | Mid-depth gradient layer |
| `PromptTheme.plum` | `#100C20` | Darkest plum for layered depth |
| `PromptTheme.panelBackground` | `#0B0C18` | Full-screen sheets, drawers, left panel, presentation backgrounds |
| `PromptTheme.dropdownBackground` | `#0D0E1C` | Dropdowns and popover sheets |
| `PromptTheme.inputBarBackground` | `#111320` | Input bar / text field row fill |
| `PromptTheme.previewBackground` | `#0B0C18` | `#Preview` blocks only |

### 6.2 Accent & Glow Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `PromptTheme.mutedViolet` | `#6C4BFF` | Primary CTA buttons, tints, accent color asset |
| `PromptTheme.orbAccent` | `#8B8FFF` | **Primary UI accent** — active states, ghost mode glow, trending icons, active borders, image-picker glow, mode pill active border |
| `PromptTheme.orbAccentLight` | `#A78BFA` | Lighter accent — mode pill fill gradient end, `ring2Start` in `OrbitLogoView` |
| `PromptTheme.orbAccentMuted` | `#5D628A` | Muted accent — avatar gradient start, `ring2End` in `OrbitLogoView` |
| `PromptTheme.logoDimTint` | `#2A1A4A` | `colorMultiply` tint on the centered logo in `HomeView` idle state |
| `PromptTheme.orbIdleGlow` | `#6C4BFF` | Orb idle pulse glow |
| `PromptTheme.orbActiveGlow` | `#9B7BFF` | Orb active/listening glow |
| `PromptTheme.orbProcessingGlow` | `#C4B5FD` | Orb processing/generating glow |

### 6.3 Text Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `PromptTheme.paleLilacWhite` | `#EDE9FE` | Primary text — near-white warm tint for body and headings |
| `PromptTheme.softLilac` | `#C4B5FD` | Secondary text, labels, subtle accent tints |
| `.white` (system) | — | Most foreground text, used directly |

**RULE: All text must be white or a white-adjacent token.** Never use dark text on the app's dark backgrounds. Never use `Color.black` or any gray for text.

### 6.4 Glass Surface Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `PromptTheme.glassFill` | `Color(red:0.11, green:0.09, blue:0.22).opacity(0.75)` | All card / surface fill layers |
| `PromptTheme.glassStroke` | `Color.white.opacity(0.11)` | All card / surface border strokes |
| `PromptTheme.premiumMaterial` | `.ultraThinMaterial` | Native material blur base under glass surfaces |

### 6.5 Tab Bar Tokens (UIKit — `RootView.swift` init)

| Token | Value | Usage |
|-------|-------|-------|
| `PromptTheme.tabBackground` | `UIColor rgba(10, 10, 26, 0.94)` | Tab bar fill |
| `PromptTheme.tabShadow` | `UIColor rgba(107, 74, 255, 0.14)` | Tab bar shadow |
| `PromptTheme.tabSelected` | `UIColor rgba(107, 74, 255, 1.0)` | Selected tab icon + label |
| `PromptTheme.tabUnselected` | `UIColor.white.withAlphaComponent(0.40)` | Unselected tab icons |

### 6.6 Full-Screen Background Component

`PromptPremiumBackground` (in `RootView.swift`) — placed outside `TabView` and `NavigationStack` so it fills the full screen including under the status bar and home indicator.

Layer stack (bottom to top):
1. **Base** — `backgroundBase` (`#0B0C18`) solid fill
2. **Vertical depth gradient** — `#10122A → #0D0E20 → #0B0C18 → #090A14` (top to bottom)
3. **Primary orbital glow** — `RadialGradient` with `#3D2B8A @ 28%` opacity, centred at `(0.50, 0.42)`, end radius `0.75 × screen width`
4. **Secondary glow** — `RadialGradient` with `#6C4BFF @ 10%` opacity, offset to `(0.58, 0.52)`, end radius `0.44 × screen width`
5. **Shimmer** — `LinearGradient` `.softLight` blend, `white 1.2% → clear → white 0.8%`, top-leading to bottom-trailing

### 6.7 App Icon

| Property | Value |
|----------|-------|
| File | `Resources/Assets.xcassets/AppIcon.appiconset/icon.png` |
| Format | iOS universal 1024×1024 PNG |
| Setting | `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` |
| Visual | Orbital rings on deep navy `#0B0C18` background with purple glow centre |

For the icon to compile into the app bundle, `Assets.xcassets` must appear in `PBXResourcesBuildPhase` inside `project.pbxproj`.

### 6.8 Typography

`PromptTheme.Typography.rounded(_ size: CGFloat, _ weight: Font.Weight)` returns `.system(size:weight:design:.rounded)`.

Use `.rounded` design for all UI text. Match weight to hierarchy: `.bold`/`.semibold` for headings, `.medium` for labels, `.regular` for body.

### 6.9 Spacing & Radius Constants

```swift
PromptTheme.Spacing.xxs  = 6pt
PromptTheme.Spacing.xs   = 10pt
PromptTheme.Spacing.s    = 14pt
PromptTheme.Spacing.m    = 18pt
PromptTheme.Spacing.l    = 24pt
PromptTheme.Spacing.xl   = 32pt

PromptTheme.Radius.medium = 16pt
PromptTheme.Radius.large  = 24pt
```

Shared app-wide constants also live in `AppUI.swift`:
```swift
AppSpacing.screenTopLarge     // top safe area padding
AppSpacing.screenHorizontal   // horizontal screen padding
AppSpacing.section            // major section gap
AppSpacing.sectionTight       // tighter section gap
AppSpacing.element            // element-to-element gap
AppHeights.primaryButton      // standard CTA height
AppHeights.segmented          // segmented control height
AppRadii.control              // standard control corner radius
```

### 6.10 Glass Card Helper

`PromptTheme.glassCard(cornerRadius:)` modifier applies:
- `.ultraThinMaterial` background
- `glassFill` fill overlay
- `glassStroke` border stroke

---

## 7. Feature Reference

### 7.1 Prompt Generation

**Flow:** `HomeView` → `generateViewModel.generate()` → `runGenerate()` → Supabase Edge Function → `GenerateResponse` → `latestResult` → `ResultView`

Edge function name is read from `Info.plist["SUPABASE_GENERATE_FUNCTION"]` (currently `"generate"`).

Guards in order:
1. Input length ≥ 3 characters
2. Auth token present (`AuthManager.token != nil`)
3. Usage count not exhausted (`UsageTracker` — StoreKit plan or starter limit)
4. Privacy mode does not block generation, only storage

`GenerateRequest` and `GenerateResponse` are defined in `Models/API/GenerateModels.swift`.
JWT is forwarded automatically by the Supabase Swift client.

### 7.2 Image Attachment (+ Button)

- Implemented with `PhotosPicker` (PhotosUI, iOS 16+, native, no UIKit required)
- `HomeView` state: `@State private var imagePickerItem: PhotosPickerItem?` and `@State private var attachedImage: UIImage?`
- On selection: loads `Data` via `loadTransferable(type: Data.self)`, converts to `UIImage`, stores in `HomeView.attachedImage` (thumbnail) and `GenerateViewModel.attachedImage` (backend)
- Thumbnail row animates in above the text field when an image is attached; `×` button clears all state
- `+` icon changes to `photo.fill` and glows `PromptTheme.orbAccent` while an image is attached
- **To send image to backend:** base64-encode `attachedImage` in `GenerateViewModel.runGenerate()` and add `imageBase64: String?` to `GenerateRequest`

### 7.3 Privacy / Ghost Mode

Toggle: ghost icon (`👻` / `person.fill.viewfinder`) in top-right nav bar of `HomeView`.

**When active (`ghostMode = true`):**
- `generateViewModel.privacyMode = true` (set via `onChange(of: ghostMode)`)
- `HistoryStore.add()` is skipped — nothing written to disk or Supabase
- `latestHistoryItemID` stays `nil` — no favorites possible for that generation
- `NotificationService` low-usage scheduling is skipped
- Visual: ghost icon fills with `PromptTheme.orbAccent` glow; background tint changes

**When inactive (`ghostMode = false`):**
- Normal history behavior resumes on next generation
- Current session output is never retroactively written (it was never saved)

**Extending privacy mode:** to block Supabase Edge Function logging, add a `no_log: true` header in `GenerateViewModel.invokeEdgeFunction` when `privacyMode == true`.

### 7.4 Share Cards

- Share cards are rendered on demand with `ImageRenderer` from a SwiftUI `PromptShareCard` view
- The generated image is held in memory on the view model and shared with native `ShareLink`
- Do not use file-backed temporary share-card stores or custom UIKit share-sheet wrappers
- This is required for safe iPad popover behavior and frictionless universal sharing
- Shareable assets must be rendered in-memory using `ImageRenderer` and shared via native `ShareLink`
- Do not create "Coming Soon" or placeholder share screens for shipping functionality

### 7.5 Input System

- `HomeView.inputBar` — bottom-anchored row with `PhotosPicker` (`+` / `photo.fill`) button and `TextField`
- Placeholder: *"Just talk. Messy is fine."*
- Prompt typing happens inline, not in a separate modal sheet
- Use `TextField(axis: .vertical)` with a bounded line limit for expanding composition
- `submitLabel(.go)` — pressing Return triggers `generateViewModel.generate()`
- Mode pills above input bar select `PromptMode` stored in `GenerateViewModel.selectedMode`

### 7.6 iPad Layout

- Constrain primary readable content on iPad to a centered column; avoid full-width edge-to-edge composition surfaces
- `HomeView` input and result content should use a readable max width (currently `800pt`)
- Prefer native SwiftUI APIs (`ShareLink`, sheets, `NavigationStack`, `NavigationSplitView`) so iPad behavior is correct by default

### 7.7 Voice / Orb

`OrbEngine` drives the voice state machine:
```
idle → listening → transcribing → done
                               → failure
```
`OrbView` renders the SwiftUI fallback animation.
`MetalOrbView` + `Orb.metal` is the GPU shader variant (toggled by `ExperimentFlags.Orb.metalOrb`).

Orb glow colors by state:
- Idle: `PromptTheme.orbIdleGlow` (`#6C4BFF`)
- Listening/active: `PromptTheme.orbActiveGlow` (`#9B7BFF`)
- Processing: `PromptTheme.orbProcessingGlow` (`#C4B5FD`)

### 7.8 Analytics

```swift
AnalyticsService.shared.track(.eventName)
```
Add new event cases in `AnalyticsService.swift`. All events are queued locally and flushed to the `events` Supabase table.

---

## 8. Naming Conventions

| Context | Convention | Example |
|---------|-----------|---------|
| Brand (all UI) | "Orbit Orb" | `Text("Orbit Orb")` |
| View files | `<Feature>View.swift` | `HomeView.swift` |
| ViewModel files | `<Feature>ViewModel.swift` | `GenerateViewModel.swift` |
| Service / Store files | `<Name>Service.swift`, `<Name>Store.swift` | `HistoryStore.swift` |
| Internal storage keys | `promptme_*` | `promptme_preferences` |
| StoreKit product IDs | `com.prompt28.*` | `com.prompt28.monthly` |
| Share card temp file | `orbit-orb-share-card-*.png` | — |

---

## 9. Info.plist Keys

| Key | Value | Purpose |
|-----|-------|---------|
| `CFBundleDisplayName` | `Orbit Orb` | Name shown under app icon and in system permission dialogs |
| `GIDClientID` | `225609678073-...` | Google Sign-In client ID |
| `CFBundleURLSchemes` | `com.googleusercontent.apps.225609678073-...` | Google OAuth redirect |
| `NSMicrophoneUsageDescription` | "Orbit Orb uses the microphone…" | Required for voice recording |
| `NSSpeechRecognitionUsageDescription` | "Orbit Orb uses speech recognition…" | Required for transcription |
| `NSPhotoLibraryUsageDescription` | "Orbit Orb lets you attach a photo…" | Required for `PhotosPicker` |
| `SUPABASE_URL` | `https://jzwerkqoczhtkyhigigf.supabase.co` | Supabase project URL |
| `SUPABASE_ANON_KEY` | `sb_publishable_...` | Supabase anon/publishable key |
| `SUPABASE_GENERATE_FUNCTION` | `generate` | Edge function name for prompt generation |

---

## 10. Files to Delete (Junk — Not Part of the App)

The following files are in the workspace root but are NOT part of the Xcode project and should be deleted:

```
/Prompt28/home_screen_mockup.html         ← design prototype, not used
/Prompt28/home_screen_mockup_v2.html      ← design prototype, not used
/Prompt28/home_screen_mockup_v3.html      ← design prototype, not used
/Prompt28/home_screen_mockup_v4.html      ← design prototype, not used
/Prompt28/home_screen_mockup_v5.html      ← design prototype, not used
/Prompt28/home_screen_mockup_v6.html      ← design prototype, not used
/Prompt28/home_screen_mockup_v7.html      ← design prototype, not used
/Prompt28/HANDOFF.md                      ← old handoff doc, superseded by agents.md
/Prompt28/CURRENT_STATE_CLEAN_ROADMAP.md  ← old roadmap doc, superseded by agents.md
/Prompt28/AGENTS.md                       ← root-level duplicate; agents.md is in Blueprint/
/Prompt28/_archive/                       ← old code archive, not referenced anywhere
/Prompt28/Orion Orb App Concept-2/        ← React/TypeScript web concept, not the iOS app
```

Dead code inside the Xcode project (safe to delete + remove from `project.pbxproj`):
```
Features/Onboarding/Views/OnboardingView.swift    ← removed from routing
Features/Privacy/PrivacyConsentView.swift         ← removed from routing
```

Test files with wrong brand name (update or delete):
```
OrionOrbTests/Prompt28Tests.swift
OrionOrbUITests/Prompt28UITests.swift
OrionOrbUITests/Prompt28UITestsLaunchTests.swift
```

Legacy share-card files to remove:
```
Features/Home/Views/ShareCardView.swift
Features/Home/Views/ShareCardRenderer.swift
Features/Home/Views/ShareCardFileStore.swift
Features/Home/Views/TypePromptView.swift
```

---

## 11. Future Scalability

### Adding image context to generation
`GenerateViewModel.attachedImage: UIImage?` is already wired. To send to backend:
1. Base64-encode in `runGenerate()`: `let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString()`
2. Add `imageBase64: String?` field to `GenerateRequest` in `GenerateModels.swift`
3. Update the Supabase Edge Function to accept and process the image field

### Extending privacy mode
Currently blocks `HistoryStore.add()`. To also block server-side logging:
```swift
// In GenerateViewModel.invokeEdgeFunction
if privacyMode {
    request.setValue("true", forHTTPHeaderField: "X-No-Log")
}
```

### Adding a second screen / tab
1. Add a new case to `MainTab` in `AppRouter.swift`
2. Add `Label(...)` row to `iPadSidebar` in `RootView.swift`
3. Create `Features/<NewFeature>/Views/<Name>View.swift`
4. Add the case to the `detail` switch in `iPadSidebar`

### Adding analytics events
1. Add a case to the `AnalyticsEvent` enum in `AnalyticsService.swift`
2. Call `AnalyticsService.shared.track(.<newEvent>)` at the relevant callsite

### Supabase Edge Functions
- Function name read from `Info.plist["SUPABASE_GENERATE_FUNCTION"]`
- JWT forwarded automatically by the Supabase Swift client
- Add new functions by adding a new key to `Info.plist` and a new `APIEndpoint` case

---

## 12. Apple Compliance Additions (April 2026)

- AI consent is a hard gate before the main app experience. `RootView` must show a dedicated `ConsentView` until `AppPreferences.hasAcceptedAIConsent == true`.
- The AI consent disclosure text must remain verbatim in the UI: `Your prompt and any personal information it contains will be sent to third-party AI providers (Anthropic and/or OpenAI) to generate a response. This data is processed only for your request and not stored by the AI provider beyond the generation step.`
- Generated-output surfaces must include the footer text `AI-generated content may be inaccurate or inappropriate.`
- Authentication options must include native Sign in with Apple alongside the other providers in `AuthFlowView`.
- Account deletion must remain available from Settings and must call the `delete-account` Supabase Edge Function to remove the user account plus related server-side records before local logout.
- Result screens should surface one-tap transformation actions prominently (for example: more professional, more detailed, shorter) so the app's refinement value is obvious without extra typing.
- The templates/trending surface should present broad user-facing categories such as Business, School, Creative, Marketing, and Personal, even if multiple backend categories are grouped underneath.
- Home and result composition areas must stay constrained to a readable column on iPad (`maxWidth: 800`) rather than stretching edge-to-edge.
- Share cards must remain lazily rendered in memory and shared with native `ShareLink` so iPad popover anchoring is handled by the system.
