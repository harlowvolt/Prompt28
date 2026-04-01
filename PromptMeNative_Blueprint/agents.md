# Orbit Orb — Agent & Developer Reference

> Last updated: 2026-03-31
> Target: iOS 17+, SwiftUI, Swift 6 strict concurrency

---

## 1. App Architecture

Orbit Orb follows a **Feature-first MVVM** architecture with a single shared dependency container (`AppEnvironment`).

```
OrionOrbApp (entry point)
└── AppEnvironment  (all services, created once on main actor)
└── RootView        (routing shell: privacy → onboarding → auth → home)
    └── HomeView    (primary screen — all prompt-generation logic lives here)
        ├── GenerateViewModel   (prompt generation, history, privacy gate)
        ├── OrbEngine           (voice/speech state machine)
        └── ResultView          (rendered result, copy, share, favorite, refine)
```

### Key principles
- **One screen at a time.** The app is effectively a single-screen product. All flows (settings, trending, type-prompt) open as sheets from `HomeView`.
- **No global state mutation outside `@MainActor`.** All view models are `@Observable @MainActor`.
- **Dependency injection via SwiftUI Environment.** `AppEnvironment` seeds all services into the tree via `EnvironmentKey`s in `AppEnvironment.swift`.

---

## 2. Key Components

| File | Role |
|------|------|
| `OrionOrbApp.swift` | `@main` entry point; injects `AppEnvironment` into SwiftUI environment |
| `AppEnvironment.swift` | Dependency container: Supabase, auth, history, preferences, usage, router, telemetry, speech/orb factories |
| `RootView.swift` | Routing: privacy consent → onboarding → auth gate → `HomeView`; also holds `PromptTheme`, `PromptPremiumBackground`, `Color(hex:)` extension |
| `HomeView.swift` | Primary UI: nav bar, orb, mode pills, input bar (+/image picker), ghost mode toggle, sheets |
| `GenerateViewModel.swift` | Prompt generation via Supabase Edge Function; history saving; privacy mode gate; image attachment state |
| `OrbEngine.swift` | Voice recording state machine (idle → listening → transcribing → done/failure); drives orb animation |
| `ResultView.swift` | Displays generated prompt; copy, share (ShareLink + ImageRenderer), favorite, feedback, refine |
| `ShareCardView.swift` | SwiftUI view rendered off-screen to produce the share card image |
| `ShareCardRenderer.swift` | `ImageRenderer` wrapper — renders `ShareCardView` at @3x into `UIImage` |
| `ShareCardFileStore.swift` | Writes the share image to a temp file; cleans up on dismiss |
| `HistoryStore.swift` | `@Observable` local + Supabase-backed prompt history |
| `PreferencesStore.swift` | `@Observable` user preferences (mode, save-history flag) persisted via `UserDefaults` |
| `UsageTracker.swift` | Keychain-backed monthly generation counter for freemium gate |
| `AppRouter.swift` | `@Observable` navigation state: selected tab, active home sheet |

---

## 3. State Management

### `@Observable` (Swift Observation framework, iOS 17+)
All view models and stores use `@Observable` — no `ObservableObject`/`@Published` anywhere.
Views that consume observable objects use `@State` (for locally owned VMs) or `@Environment` (for shared services).

### Environment injection pattern
```swift
// Declare in AppEnvironment.swift
private struct HistoryStoreKey: EnvironmentKey { ... }
extension EnvironmentValues { var historyStore: (any HistoryStoring)? { ... } }

// Inject at root (OrionOrbApp.swift)
.environment(\.historyStore, env.historyStore)

// Consume in child view
@Environment(\.historyStore) private var historyStore
```

### Privacy Mode (Ghost Mode)
`HomeView` holds `@State private var ghostMode: Bool`.
On toggle, it sets `generateViewModel.privacyMode = enabled`.
`GenerateViewModel.runGenerate()` checks `!privacyMode` before writing to `HistoryStore`.
Nothing is written to disk, Supabase, or notification service when privacy mode is active.
Visual indicator: ghost icon glows purple + background fill changes on the nav icon.

---

## 4. Feature Breakdown

### 4.1 Input System
- `HomeView.inputBar` — bottom-anchored input bar containing the `+` (image picker) button and a `TextField`.
- Placeholder text: *"Just talk. Messy is fine."*
- `submitLabel(.go)` — pressing Return triggers `generateViewModel.generate()`.
- Mode pills (AI Mode / Human Mode) above the input bar select `PromptMode` stored in `GenerateViewModel.selectedMode`.

### 4.2 Image Upload (+ Button)
- Implemented with `PhotosPicker` (SwiftUI native, iOS 16+, no UIKit required).
- State: `@State private var imagePickerItem: PhotosPickerItem?` and `@State private var attachedImage: UIImage?`.
- On selection: loads `Data` via `loadTransferable(type: Data.self)`, converts to `UIImage`, stores in both `HomeView.attachedImage` (for thumbnail) and `GenerateViewModel.attachedImage` (for backend).
- Thumbnail row appears above the text field when an image is attached.
- `×` button clears `attachedImage`, `imagePickerItem`, and `generateViewModel.attachedImage`.
- The + button icon changes to `photo.fill` and glows purple while an image is attached.
- **To wire image data to generation:** In `GenerateViewModel.runGenerate()`, encode `attachedImage` to base64 and append to the `GenerateRequest` body when the backend supports it.

### 4.3 Privacy Mode
- Toggle: ghost icon in top-right nav bar.
- **Active (ghostMode = true):**
  - `GenerateViewModel.privacyMode = true`
  - History is NOT written (`HistoryStore.add()` is skipped)
  - `latestHistoryItemID` remains `nil` (no favorites possible)
  - Low-usage notification scheduling is skipped
  - Visual: ghost icon fills with purple glow, background tint changes
- **Inactive (ghostMode = false):**
  - Normal history behavior resumes for the next generation
  - No retroactive deletion of current session output (it was never written)

### 4.4 Prompt Generation
Flow: `HomeView` → `generateViewModel.generate()` → `runGenerate()` →
Supabase Edge Function (`SUPABASE_GENERATE_FUNCTION` key in Info.plist) →
`GenerateResponse` → update `latestResult` → `ResultView` renders output.

Key guards in order:
1. Input length ≥ 3 characters
2. Auth token present
3. Usage count not exhausted (StoreKit plan or starter limit)
4. Privacy mode does not affect generation, only storage

### 4.5 Share Cards
- `ResultView` calls `ShareCardRenderer.render(rawInput:generatedPrompt:modeName:)` whenever `latestPromptText` changes.
- `ShareCardRenderer` uses `ImageRenderer` (iOS 16+) at `scale: 3.0` to render `ShareCardView` (400×650 pt) into a `UIImage`.
- `ShareCardFileStore` writes the PNG to `FileManager.temporaryDirectory` and returns a `URL`.
- `ShareLink(item: shareURL, preview: SharePreview("Orbit Orb", image: ...))` triggers the native iOS share sheet.
- File is cleaned up in `ResultView.onDisappear`.

---

## 5. Design System — Color Token Source of Truth

**RULE: No inline hex literals anywhere in the codebase. Every color usage must reference a `PromptTheme` token defined in `RootView.swift`.**

All tokens are declared in `enum PromptTheme` inside `RootView.swift`.

### 5.1 Background Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `PromptTheme.backgroundBase` | `#0B0C18` | Deepest layer — matches the logo's outer dark field |
| `PromptTheme.deepShadow` | `#0D0E1E` | Mid-depth gradient layer |
| `PromptTheme.plum` | `#100C20` | Darkest plum for layered depth |
| `PromptTheme.panelBackground` | `#0B0C18` | Full-screen sheets, drawers, left panel, presentation backgrounds |
| `PromptTheme.dropdownBackground` | `#0D0E1C` | Dropdowns and popover sheets |
| `PromptTheme.inputBarBackground` | `#111320` | Input bar / text field row fill |
| `PromptTheme.previewBackground` | `#0B0C18` | `#Preview` blocks only |

### 5.2 Accent & Glow Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `PromptTheme.mutedViolet` | `#6C4BFF` | Primary CTA buttons, tints |
| `PromptTheme.orbAccent` | `#8B8FFF` | **Primary UI accent** — active states, ghost mode glow, trending icons, active borders, image-picker glow, mode pill active border |
| `PromptTheme.orbAccentLight` | `#A78BFA` | Lighter accent — mode pill fill gradient end, ring2Start in OrbitLogoView |
| `PromptTheme.orbAccentMuted` | `#5D628A` | Muted accent — avatar gradient start, ring2End in OrbitLogoView |
| `PromptTheme.logoDimTint` | `#2A1A4A` | `colorMultiply` tint on the centered logo in HomeView idle state |
| `PromptTheme.orbIdleGlow` | `#6C4BFF` | Orb idle pulse glow |
| `PromptTheme.orbActiveGlow` | `#9B7BFF` | Orb active/listening glow |
| `PromptTheme.orbProcessingGlow` | `#C4B5FD` | Orb processing/generating glow |

### 5.3 Text Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `PromptTheme.paleLilacWhite` | `#EDE9FE` | Primary text — near-white warm tint |
| `PromptTheme.softLilac` | `#C4B5FD` | Secondary text, labels, subtle tints |
| `.white` | system | Most foreground text (direct) |

### 5.4 Glass Surface Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `PromptTheme.glassFill` | `rgba(28, 23, 56, 0.75)` | All card/surface fill layers |
| `PromptTheme.glassStroke` | `white 11%` | All card/surface border strokes |
| `PromptTheme.premiumMaterial` | `.ultraThinMaterial` | Native material blur base |

### 5.5 Tab Bar Tokens (UIKit)

| Token | Value | Usage |
|-------|-------|-------|
| `PromptTheme.tabBackground` | `UIColor rgba(10, 10, 26, 0.94)` | Tab bar background |
| `PromptTheme.tabSelected` | `UIColor rgba(107, 74, 255, 1.0)` | Selected tab icon + label |
| `PromptTheme.tabUnselected` | `white 40%` | Unselected tab icons |

### 5.6 Background Component

`PromptPremiumBackground` — full-screen `ZStack` (in `RootView.swift`):
- Base: `backgroundBase` (`#0B0C18`)
- Linear depth gradient: `#10122A → #0D0E20 → #0B0C18 → #090A14`
- Primary radial glow: `#3D2B8A @ 28%` centred at `(0.50, 0.42)`, radius `0.75w`
- Secondary radial glow: `#6C4BFF @ 10%` offset to `(0.58, 0.52)`, radius `0.44w`
- Shimmer overlay: `.softLight` blend, `white 1.2%` → clear

### 5.7 App Icon

File: `Resources/Assets.xcassets/AppIcon.appiconset/icon.png`
Format: iOS universal 1024×1024 PNG (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`)
The icon is the Orbit Orb logo — orbital rings on dark navy background.

### 5.8 Typography
`PromptTheme.Typography.rounded(_ size: CGFloat, _ weight: Font.Weight)` → `.system(design: .rounded)`.
**All text must be white** — use `.white`, `paleLilacWhite`, or `softLilac` with opacity.

### 5.9 Glass Card Helper
`PromptTheme.glassCard(cornerRadius:)` — `.ultraThinMaterial` + `glassFill` fill overlay + `glassStroke` border.

---

## 6. Naming Conventions

| Context | Convention |
|---------|-----------|
| App brand | **Orbit Orb** (two words, title-case) |
| Internal storage keys | `promptme_*` (unchanged — modifying breaks existing user data) |
| StoreKit product IDs | `com.prompt28.*` (unchanged — tied to App Store Connect) |
| Notification identifiers | `com.prompt28.*` (unchanged — system-registered) |
| View files | `<Feature>View.swift` in `Features/<Feature>/Views/` |
| ViewModel files | `<Feature>ViewModel.swift` in `Features/<Feature>/ViewModels/` |
| Service files | `<Name>Service.swift` or `<Name>Store.swift` in `Core/` |

---

## 7. Future Scalability Notes

### Adding image generation context
`GenerateViewModel.attachedImage: UIImage?` is already wired.
To send to the backend: base64-encode inside `runGenerate()` and add an `imageBase64: String?` field to `GenerateRequest`.

### Extending privacy mode
Currently blocks `HistoryStore.add()`. To add ephemeral Supabase blocking, add a guard in `invokeEdgeFunction` — pass a `no_log: true` header when `privacyMode == true`.

### Adding a second screen
Use `AppRouter.selectedTab` + the existing `TabView`/sidebar infrastructure in `RootView`.
Add a new `MainTab` case and corresponding `View` in `Features/`.

### Supabase Edge Function
Name is read from `Info.plist["SUPABASE_GENERATE_FUNCTION"]`.
The function receives `GenerateRequest` (see `Models/API/GenerateModels.swift`) and returns `GenerateResponse`.
JWT is forwarded automatically by the Supabase Swift client.

### Analytics
`AnalyticsService.shared.track(.eventName)` — add new events in `AnalyticsService.swift`.
All events are queued locally and flushed to the `events` Supabase table.

### Orb animation
`OrbEngine` drives the orb state machine (`idle → listening → transcribing → done/failure`).
`OrbView` renders a SwiftUI fallback; `MetalOrbView` + `Orb.metal` is the GPU shader variant (toggled by `ExperimentFlags.Orb.metalOrb`).
