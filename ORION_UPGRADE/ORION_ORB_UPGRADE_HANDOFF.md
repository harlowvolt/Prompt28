# ORION Orb Upgrade — Handoff Document

<<<<<<< HEAD
**Version:** 1.7
**Created:** 2026-03-14
**Last Updated:** 2026-03-17
**Status:** Phase 1 immediate priorities complete — ready for Phase 2 Supabase SDK integration
**Source Root:** `PromptMeNative_Blueprint/`  
=======
**Version:** 1.6
**Last Updated:** 2026-03-17
**Status:** ✅ Phase 1 & 2 Complete | Task 3 Complete (Supabase Auth) | Architecture Decision Locked
**Project Name:** Orion Orb (formerly Prompt28)
**Source Root:** `PromptMeNative_Blueprint/`
>>>>>>> 672afe4ae655afe7762f0394bb152c9d4bbe6247

---

## Document Purpose

This is the **single source of truth** for the Orion Orb upgrade. Any AI assistant working on this project must read this document first and update it after making changes.

---

## 🔒 Architecture Decision — CloudKit vs. Supabase (Locked 2026-03-17)

**Decision: Option A — Keep CloudKit + Add Supabase**

| Layer | System | Responsibility |
|-------|--------|----------------|
| History sync | CloudKit | Cross-device `PromptHistoryItem` sync (Apple ecosystem) |
| Analytics pipeline | Supabase | `events` table — upload from `AnalyticsService` |
| Error telemetry | Supabase | `telemetry_errors` table — upload from `TelemetryService` |
| Feature flags | Supabase | `feature_flags` table — fetched by `FeatureFlagService` at launch |
| RLHF / prompt ratings | Supabase | `prompts` table — `user_rating`, `feedback_notes` |
| Real-time trending | Supabase | `trending_prompts` table — Supabase Realtime CDC |
| Server-side usage metering | Supabase Edge Function | Enforced in `generate-prompt` function |
| Subscription tier sync | Supabase | `users.subscription_tier` via App Store Server Notifications webhook |

**Rules that follow from this decision:**
- `HistoryStore.swift` and `CloudKitService.swift` are **NOT to be rewritten** for Supabase
- When a prompt is generated, write to local JSON (CloudKit syncs it) AND send a record to Supabase `prompts` table for the data flywheel — two destinations, same event
- Auth **will** migrate to Supabase Auth (Task 2) — this does not affect CloudKit, which uses iCloud credentials independently
- The `HistoryStore` in `AppEnvironment` should **not** receive a Supabase dependency

---

## 🔧 Supabase Configuration (Task 3 Complete)

**File:** `Core/Networking/SupabaseClient.swift`

**Current Status:**
- ✅ Supabase Swift SDK integrated (v2.41.1)
- ✅ AuthManager migrated to Supabase Auth
- ⚠️ **Placeholder credentials** — must be updated before release

**Required Configuration:**
```swift
// In SupabaseClient.swift, replace these placeholders:
let supabaseURL = URL(string: "https://your-project.supabase.co")!
let supabaseKey = "your-anon-public-key"
```

**Supabase Auth Providers Enabled:**
- Email/Password (with metadata support for full name)
- Google Sign-In (via ID token)
- Apple Sign-In (via ID token, with name capture on first sign-in)

**Backward Compatibility:**
- APIClient continues to route prompt generation to Railway API
- AuthManager syncs plan info from Railway API after Supabase auth
- Token storage continues to use Keychain

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **App Name** | Orion Orb |
| **Bundle ID** | `com.harlowvolt.orionorb` |
| **Scheme** | OrionOrb |
| **iOS Target** | 17+ |
| **Backend** | Railway API + Supabase + iCloud CloudKit |
| **Auth** | Supabase Auth (email/password, Google, Apple) |
| **History** | Codable JSON + iCloud CloudKit sync |

---

## Current Status Summary

### ✅ Completed
1. **Project Rename:** Prompt28 → Orion Orb (all targets, schemes, bundle IDs)
2. **Phase 1 - AnalyticsService:** Local caching implemented, events stored in UserDefaults
3. **Phase 1 - TelemetryService:** Created with structured error logging
4. **Phase 1 - Error Tracking:** Integrated into SpeechRecognizerService, APIClient
5. **Phase 2 - CloudKit Sync:**
   - `PromptHistoryItem` with CloudKit fields (recordID, lastModified, isSynced)
   - `CloudKitService` with two-way sync and conflict resolution
   - `HistoryStore` migrated to Codable JSON + CloudKit
   - iCloud entitlements configured
6. **Architecture Decision (v1.5) — Option A LOCKED:**
   - CloudKit stays for Apple-ecosystem history sync across devices
   - Supabase added for all data pipeline needs (analytics, RLHF, feature flags, server-side metering)
   - `HistoryStore` / `CloudKitService` are NOT to be rewritten
   - See: Architecture Decision section below
7. **Task 1 Fix - StoreKit Plan Sync Bug (v1.5):**
   - `StoreManager` now accepts `AuthManager` via initializer injection
   - `purchase()` calls `await authManager.refreshMe()` after `transaction.finish()`
   - `listenForTransactions()` also calls `refreshMe()` for renewals/Family Sharing
   - `AppEnvironment` updated: `StoreManager(authManager: authManager)`
8. **Task 1 Fix - ShareCard Branding (v1.5):**
   - `ShareCardView.swift` footer text updated to "ORION ORB" and "Refined by Orion Orb"
9. **Task 1 Cleanup - Glassmorphism Dead Code Removed (v1.5):**
   - `Components/Glassmorphism.swift` DELETED — was never used in production
   - Production glass system remains `PromptTheme.glassCard` / `.appGlassCard()` in `AppUI.swift`
10. **Phase 4 - ShareCard System:**
    - `ShareCardView`, `ShareCardRenderer`, `ShareCardFileStore` complete and wired into `ResultView`
    - `ShareLink` functional. Branding now correct (fixed in v1.5)

### ✅ Completed (Task 3 — Supabase SDK Integration + Auth Migration)
1. **Supabase Swift SDK Added:** `supabase-swift` package (v2.41.1) added via SPM
2. **SupabaseClient.swift Created:** Wrapper around Supabase SDK in `Core/Networking/SupabaseClient.swift`
3. **AuthManager Migrated:** Complete rewrite to use Supabase Auth
   - Email/password authentication via `supabase.auth.signIn/signUp`
   - Google Sign-In via `supabase.auth.signInWithIdToken(provider: .google)`
   - Apple Sign-In via `supabase.auth.signInWithIdToken(provider: .apple)`
   - Auth state change listener for automatic session management
   - Backward compatibility: Still syncs plan info from Railway API
4. **AppEnvironment Updated:** Now initializes SupabaseClient and passes to AuthManager
5. **User Model Updated:** Added regular init for programmatic User creation
6. **Build Verified:** Project builds successfully with all changes

### 🔄 Next Up (Task 4 → Task 5)
1. **Task 4 — FeatureFlagService + Edge Function (generate-prompt)**
2. **Task 5 — StoreKit Server Validation + App Store Webhook**

---

## Upgrade Roadmap

### Phase 1: Stabilization, Analytics, & Observability
**Goal:** Fix history, establish conversion funnel, gain visibility before backend changes.

#### 1.1 Analytics Service ✅ COMPLETE
**File:** `Core/Utils/AnalyticsService.swift`

**Current State:**
- ✅ Event enum defined with 15+ events (including `app_open`)
- ✅ Tracking calls integrated in ViewModels
- ✅ Local caching implemented (UserDefaults, max 100 events)
- ✅ `CachedAnalyticsEvent` struct for serialization
- ✅ `setUserId()` for attribution
- ✅ `uploadToSupabase()` placeholder for Phase 2
- ❌ Supabase upload not yet implemented (Phase 2)

**Events Currently Tracked:**
| Event | Location |
|-------|----------|
| `app_open` | Not yet implemented |
| `generate_tapped` | GenerateViewModel.swift:61 |
| `generate_success` | GenerateViewModel.swift:127 |
| `generate_error` | GenerateViewModel.swift:182 |
| `generate_rate_limited` | GenerateViewModel.swift:175 |
| `copy_prompt` | Not yet implemented |
| `share_prompt` | Not yet implemented |
| `favorite_tapped` | GenerateViewModel.swift:211 |
| `refine_prompt` | GenerateViewModel.swift:67 |
| `plan_upgrade_tapped` | StoreManager.swift:45 |
| `plan_upgrade_success` | StoreManager.swift:54 |
| `auth_success` | Not yet implemented |
| `paywall_shown` | GenerateViewModel.swift:88, 139, 176 |
| `onboarding_completed` | OnboardingView.swift:80 |
| `mode_switched` | HomeView.swift:246 |

**TODO:**
- Add local caching (UserDefaults or small SQLite)
- Add batch upload to Supabase
- Add `app_open` tracking in App init

---

#### 1.2 Telemetry Service ✅ COMPLETE
**File:** `Core/Utils/TelemetryService.swift`

**Current State:**
- ✅ Created with `TelemetryRecord` struct
- ✅ Captures: `error_domain`, `error_code`, `error_message`, `stack_trace`, `device_model`, `ios_version`, `app_version`, `app_state`, `timestamp`, `user_id`, `session_id`
- ✅ Local caching (UserDefaults, max 50 records, FIFO)
- ✅ App state monitoring (active, inactive, background, foreground)
- ✅ `uploadToSupabase()` placeholder for Phase 2
- ✅ Auto-upload attempt on app background

**Integration Points:**
- ✅ `SpeechRecognizerService` - logs START_FAILED, RECOGNITION_ERROR, CRITICAL_FAILURE
- ✅ `APIClient` - logs network errors and HTTP status codes
- ✅ `AppEnvironment` - injected and initialized with user ID sync

---

#### 1.3 History Store ✅ HOTFIX ACTIVE (Phase 1 Complete)
**File:** `Core/Storage/HistoryStore.swift`

**Current State:**
```swift
private let persistenceEnabled = false  // SwiftData disabled due to runtime traps
```

**Status:**
- ✅ In-memory storage working (data survives during app lifecycle)
- ✅ `PromptHistoryItem` is Codable-ready
- ❌ Data lost on app restart (acceptable for Phase 1, will fix in Phase 2)
- ❌ No cloud sync (Phase 2)
- ❌ No Supabase integration (Phase 2)

**Phase 2 TODO:**
- Replace SwiftData with Supabase `prompts` table
- Implement offline queue for failed syncs
- Add sync status indicators

---

### Phase 2: iCloud CloudKit Sync ✅ COMPLETE
**Goal:** Cross-device prompt history synchronization using CloudKit.

#### 2.1 PromptHistoryItem ✅ COMPLETE
**File:** `Models/Local/PromptHistoryItem.swift`

**Changes:**
- Migrated from `@Model` (SwiftData) to `Codable` class
- Added CloudKit fields:
  - `recordID: CKRecord.ID?` - CloudKit record identifier
  - `lastModified: Date` - For conflict resolution
  - `isSynced: Bool` - Sync status flag
- Added conversion methods:
  - `toCKRecord()` - Convert to CloudKit record
  - `init(from record: CKRecord)` - Initialize from CloudKit record
  - `update(from record: CKRecord)` - Update existing item from remote
  - `markModified()` - Mark as changed locally

---

#### 2.2 CloudKitService ✅ COMPLETE
**File:** `Core/Storage/CloudKitService.swift` (NEW)

**Features:**
- `@Observable @MainActor` for SwiftUI integration
- Account status monitoring (`checkAccountStatus()`)
- Two-way sync (`sync(items:)`) with conflict resolution
  - Last modified wins strategy
  - Handles both local-only and remote-only items
- Individual operations:
  - `saveToCloud(_:)` - Upload single item
  - `deleteFromCloud(id:)` - Remove from CloudKit
  - `fetchRemoteRecords()` - Download all remote records
- Offline handling: Silently fails, retries on next mutation
- Custom CloudKit zone: "PromptHistoryZone"

---

#### 2.3 HistoryStore ✅ COMPLETE
**File:** `Core/Storage/HistoryStore.swift`

**Changes:**
- Removed SwiftData dependency
- Added `CloudKitService` dependency
- Local persistence: Codable JSON file (`history.json`)
- Auto-sync on all mutations (debounced 2 seconds)
- Manual sync: `forceSync()` for pull-to-refresh
- Sync status exposed: `isSyncing`, `lastSyncError`
- Legacy JSON migration preserved

---

#### 2.4 iCloud Configuration ✅ COMPLETE
**File:** `Prompt28/OrionOrb.entitlements`

**Capabilities Added:**
- `com.apple.developer.icloud-container-identifiers`
  - Container: `iCloud.com.harlowvolt.orionorb`
- `com.apple.developer.icloud-services`
  - Service: `CloudKit`

**Xcode Setup Required:**
1. Target → Signing & Capabilities
2. Ensure iCloud capability is enabled
3. Check "CloudKit" service
4. Container should auto-create on first run

---

### Phase 3: StoreKit 2 Server Validation
**Goal:** Server-validated entitlements and usage metering.
- error_domain: text
- error_code: text
- stack_trace: text
- device_model: text
- ios_version: text
- app_state: text
- created_at: timestamp

-- feature_flags (for remote config)
- key: text (unique)
- is_enabled: boolean
- required_tier: text
- rollout_percentage: integer
```

---

#### 2.3 Edge Functions (AI Gateway) ❌ NOT STARTED
**Purpose:** iOS client never holds LLM API keys.

**Functions to Deploy:**
1. `generate-prompt` - Replaces current `/api/generate`
2. `validate-subscription` - Check usage limits server-side
3. `sync-history` - Bidirectional history sync
4. `app-store-webhook` - Handle subscription events

**iOS Changes:**
- Update `APIEndpoint.swift` to route to Edge Functions
- Remove direct Railway API calls

---

#### 2.4 Feature Flag Service ❌ NOT STARTED
**File to Create:** `Core/Utils/FeatureFlagService.swift`

**Purpose:** Remote toggle for features without app updates.

**Flags to Support:**
- `is_metal_orb_enabled` (Phase 4)
- `new_ai_model` (Phase 5)
- `experimental_ui` (Phase 4)

---

### Phase 3: Business Logic & Monetization
**Goal:** Server-validated entitlements and usage metering.

#### 3.1 StoreKit 2 Integration ⚠️ PARTIAL
**File:** `Core/Store/StoreManager.swift`

**Current State:**
- ✅ StoreKit 2 integrated for product fetching
- ✅ On-device purchase flow working
- ✅ `StoreManager` now injects `AuthManager` via `init(authManager:)` (v1.5)
- ✅ `purchase()` calls `await authManager.refreshMe()` after `transaction.finish()` — clears paywall immediately (v1.5)
- ✅ `listenForTransactions()` also calls `refreshMe()` — handles renewals and Family Sharing (v1.5)
- ❌ No server-side receipt validation (Task 5)
- ❌ No App Store Server Notifications webhook (Task 5)
- ❌ `users.subscription_tier` not yet synced with Supabase (Task 5)

**TODO (Task 5):**
- Implement App Store Server Notifications webhook → Supabase Edge Function
- Sync `users.subscription_tier` with purchases/cancellations/renewals
- Add server-side subscription status check on app launch

---

#### 3.2 Usage Metering ❌ NOT STARTED
**File:** `Core/Store/UsageTracker.swift`

**Current State:**
- Client-side counting only
- ❌ Easily bypassed

**TODO:**
- Enforce limits in Edge Function (Free: 5/month, Pro: Unlimited)
- Return 429 or 402 status from Edge Function
- iOS triggers UpgradeView on these statuses

---

### Phase 4: Core Experience & Data Flywheel
**Goal:** Visual polish + feedback loop for AI improvement.

#### 4.1 Glassmorphism UI Components 🗑️ DELETED (v1.5)
**File:** `Components/Glassmorphism.swift` — **FILE DELETED**

**Why deleted:**
- `GlassContainer`, `GlassButton`, `GlassCard`, `GlassOrb` were never used in any production screen
- All production screens use `PromptTheme.glassCard` / `.appGlassCard()` defined in `App/AppUI.swift`
- The file was a parallel dead glass system that would cause future UI divergence
- The claim in v1.4 that it was "integrated into HomeView and SettingsView" was incorrect

**Authoritative glass system:**
- `App/AppUI.swift` — `.appGlassCard(radius:)` view modifier
- `App/AppUI.swift` — `PromptTheme.glassCard` style token
- Do NOT recreate `Glassmorphism.swift`. Build new glass components as extensions in `AppUI.swift`

#### 4.2 Metal Orb ❌ NOT STARTED
**Files:** `OrbEngine.swift`, `OrbView.swift`

**Requirements:**
- GPU-accelerated Metal shader
- Feature flag controlled (`is_metal_orb_enabled`)
- States: Idle breathing, Listening mic-reactivity, Processing spin, Success flash

---

#### 4.2 Prompt Feedback System (RLHF) ❌ NOT STARTED
**File:** `Features/Home/Views/ResultView.swift`

**Requirements:**
- Thumbs Up / Thumbs Down buttons
- "Regenerate" button
- Send feedback to `prompts.user_rating` and `prompts.feedback_notes`
- Build dataset for fine-tuning

---

#### 4.3 Shareable Prompt Cards ✅ COMPLETE (v1.5 branding fixed)
**Files:**
- `Features/Home/Views/ShareCardView.swift`
- `Features/Home/Views/ShareCardRenderer.swift`
- `Features/Home/Views/ShareCardFileStore.swift`

**Current State:**
- ✅ `ShareCardView` — card layout with BEFORE/AFTER sections, gradient background
- ✅ `ShareCardRenderer` — `ImageRenderer`-based PNG rendering
- ✅ `ShareCardFileStore` — temp file management for `ShareLink`
- ✅ Wired into `ResultView` — share button renders and exports card
- ✅ Branding updated to "ORION ORB" / "Refined by Orion Orb" (v1.5, was "PROMPT²⁸")
- ❌ No watermark enforcement yet (low priority)

**Do not re-implement** — this feature is complete. Next work here is RLHF buttons (4.2).

---

#### 4.4 Real-Time Trending ❌ NOT STARTED
**File:** `Features/Trending/ViewModels/TrendingViewModel.swift`

**Requirements:**
- Supabase Realtime via Postgres CDC
- Opt-in highly rated prompts to `trending_prompts` table
- Push live updates without refresh

---

### Phase 5: Future Architecture
**Goal:** Sophisticated context-aware reasoning engine.

#### 5.1 Intent Routing ❌ NOT STARTED
**Backend Edge Function**

- Fast classifier model (Haiku/Flash) → Intent Category
- Fetch optimized prompt template from DB
- Call heavy reasoning model with template

---

#### 5.2 Result Metadata ("Prompt DNA") ❌ NOT STARTED
**File:** `Features/Home/Views/ResultView.swift`

- Display confidence score, intent category, model latency
- Pro users only

---

#### 5.3 MCP (Model Context Protocol) ❌ NOT STARTED
**Architecture:** iOS stays "dumb", Edge Functions use MCP.

- Edge Functions use MCP tools for external context (web scraping, etc.)
- No iOS updates needed to add MCP capabilities

---

## Most Important Files (Current State)

### Phase 1 ✅ COMPLETE

| File | Status | Notes |
|------|--------|-------|
| `Core/Utils/AnalyticsService.swift` | ✅ Complete | Local caching with UserDefaults (100 events max) |
| `Core/Utils/TelemetryService.swift` | ✅ Complete | Structured error logging, device info capture |
| `App/AppEnvironment.swift` | ✅ Complete | Telemetry injected, user ID sync active |

### Phase 2 ✅ COMPLETE

| File | Status | Notes |
|------|--------|-------|
| `Models/Local/PromptHistoryItem.swift` | ✅ Complete | Codable, CloudKit fields, conversion methods |
| `Core/Storage/CloudKitService.swift` | ✅ Complete | Two-way sync, conflict resolution, offline handling |
| `Core/Storage/HistoryStore.swift` | ✅ Complete | Codable JSON + CloudKit, auto-sync on mutations |
| `Prompt28/OrionOrb.entitlements` | ✅ Complete | iCloud + CloudKit capabilities |
| `App/AppEnvironment.swift` | ✅ Complete | CloudKitService injected, HistoryStore updated |

### For Phase 2 → 5 (Supabase tasks)

| File | Status | Notes |
|------|--------|-------|
| `Core/Auth/AuthManager.swift` | ✅ Task 3 Complete | Migrated to Supabase Auth (Google, Apple, Email) |
| `Core/Storage/HistoryStore.swift` | ✅ DO NOT TOUCH | CloudKit sync is correct and complete. Not replaced by Supabase. |
| `Core/Storage/CloudKitService.swift` | ✅ DO NOT TOUCH | Works correctly. Architecture decision locks this in. |
| `Core/Networking/APIClient.swift` | 🟡 Task 4 | Add Edge Function routing for generate; keep Railway calls for now |
| `Core/Networking/APIEndpoint.swift` | 🟡 Task 4 | Add Edge Function URL entries |
| `Core/Utils/AnalyticsService.swift` | 🟡 Task 3 | Implement `uploadToSupabase()` — local cache is ready |
| `Core/Utils/TelemetryService.swift` | 🟡 Task 3 | Implement `uploadToSupabase()` — local cache is ready |
| `Core/Utils/FeatureFlagService.swift` | 🔴 Task 4 | CREATE — fetches `feature_flags` table at launch |
| `Core/Store/StoreManager.swift` | 🟡 Task 5 | Plan sync fixed (v1.5). Server validation + webhook still needed. |

---

## Working with This Document

### For AI Assistants:

1. **Read this first** before making any changes
2. **Check the Phase status** - don't skip ahead without confirming prerequisites
3. **Update this document** after completing work:
   - Change status emojis (🔴 → 🟡 → ✅)
   - Add implementation details
   - Update the "Current Status Summary" section
4. **Never remove sections** - only mark as complete

### Status Emoji Key:
- 🔴 **Not Started** / Missing
- 🟡 **Partial** / In Progress
- ✅ **Complete**
- ⚠️ **Has Issues** / Needs Attention

---

## Appendix: Project Structure Reference

```
PromptMeNative_Blueprint/
├── App/
│   ├── AppEnvironment.swift          # Dependency container
│   ├── AppUI.swift                   # Design tokens
│   ├── RootView.swift                # Root state machine
│   └── Routing/AppRouter.swift
├── Core/
│   ├── Auth/
│   │   └── AuthManager.swift         # 🔴 Replace with Supabase
│   ├── Networking/
│   │   ├── APIClient.swift           # 🔴 Route to Edge Functions
│   │   └── APIEndpoint.swift
│   ├── Storage/
│   │   └── HistoryStore.swift        # 🔴 Replace with Supabase
│   ├── Store/
│   │   ├── StoreManager.swift        # 🟡 Task 5 — server validation + webhook
│   │   └── UsageTracker.swift        # 🟡 Task 4 — move enforcement to Edge Function
│   └── Utils/
│       ├── AnalyticsService.swift    # 🟡 Task 3 — wire uploadToSupabase()
│       ├── TelemetryService.swift    # 🟡 Task 3 — wire uploadToSupabase()
│       └── FeatureFlagService.swift  # 🔴 Task 4 — CREATE THIS
├── Components/
│   └── (Glassmorphism.swift DELETED v1.5 — was dead code)
├── Features/
│   ├── Auth/                         # Login flows
│   ├── History/                      # History + Favorites
│   ├── Home/                         # Main generation UI + ShareCard (complete)
│   ├── Onboarding/                   # First-time experience
│   ├── Settings/                     # Settings + Upgrade
│   └── Trending/                     # Prompt catalog
└── Models/
    ├── API/                          # Server response models
    └── Local/                        # PromptHistoryItem, etc.
```

---

**Last Updated By:** Claude (Natalie's session)

**Update Notes (v1.6) — 2026-03-17 (Task 3 Complete):**
- Added Supabase Swift SDK (v2.41.1) via SPM
- Created `Core/Networking/SupabaseClient.swift` - wrapper for Supabase SDK
- Migrated `AuthManager.swift` to Supabase Auth with full Google/Apple/Email support
- Updated `AppEnvironment.swift` to initialize SupabaseClient and inject into AuthManager
- Updated `User.swift` with regular init for programmatic creation
- Removed `Glassmorphism.swift` reference from Xcode project (file was already deleted)
- Build verified: Project compiles successfully
- **TODO:** Update Supabase credentials in `SupabaseClient.swift` before release

**Update Notes (v1.5) — 2026-03-17:**
- Locked architecture decision: CloudKit stays for history, Supabase added for data pipeline
- Deleted `Components/Glassmorphism.swift` (dead code, never used in production)
- Fixed StoreKit plan sync bug: `StoreManager` now injects `AuthManager`, calls `refreshMe()` after purchase and in transaction listener
- Fixed ShareCard branding: "ORION ORB" / "Refined by Orion Orb"
- Corrected Phase 4.3 ShareCard status from NOT STARTED → COMPLETE (was already fully wired)
- Corrected Phase 2 Supabase table references to reflect Option A decision
- Updated all file status annotations in reference table

**Update Notes (v1.4) — 2026-03-14 (AI Assistant Kimi):**
- Added TelemetryService.swift and CloudKitService.swift to Xcode project via Python script
- Fixed TelemetryErrorDomain enum - added cloudKit and storage cases
- Fixed CloudKit API calls for iOS 26.3 compatibility (records, save, delete)
- Added logStorageError convenience method
- Status: Phase 1, 2 COMPLETE, Build working, ready for Phase 3

<<<<<<< HEAD
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

=======
>>>>>>> 672afe4ae655afe7762f0394bb152c9d4bbe6247
