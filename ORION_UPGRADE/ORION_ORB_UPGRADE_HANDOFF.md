# ORION Orb Upgrade — Handoff Document

**Version:** 1.2  
**Last Updated:** 2026-03-14  
**Status:** ✅ Phase 1 Complete, Phase 2 Ready to Start  
**Project Name:** Orion Orb (formerly Prompt28)  
**Source Root:** `PromptMeNative_Blueprint/`  

---

## Document Purpose

This is the **single source of truth** for the Orion Orb upgrade. Any AI assistant working on this project must read this document first and update it after making changes.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **App Name** | Orion Orb |
| **Bundle ID** | `com.harlowvolt.orionorb` |
| **Scheme** | OrionOrb |
| **iOS Target** | 17+ |
| **Backend** | Not yet migrated (currently Railway, moving to Supabase) |
| **Auth** | JWT (moving to Supabase Auth) |
| **History** | In-memory only (`persistenceEnabled = false`) |

---

## Current Status Summary

### ✅ Completed
1. **Project Rename:** Prompt28 → Orion Orb (all targets, schemes, bundle IDs)
2. **Phase 1 - AnalyticsService:** Local caching implemented, events stored in UserDefaults, ready for Supabase upload
3. **Phase 1 - TelemetryService:** Created with structured error logging for speech, network, and API errors
4. **Phase 1 - Error Tracking:** Integrated into SpeechRecognizerService, APIClient, and AppEnvironment
5. **Phase 1 - HistoryStore:** In-memory hotfix active, Codable conformance ready for Phase 2 sync

### 🔄 Ready to Start
1. **Phase 2 - Supabase Integration:** Auth, database, Edge Functions
2. **Phase 3 - StoreKit 2 Server Validation**
3. **Phase 4 - Metal Orb & RLHF**
4. **Phase 5 - MCP & Intent Routing

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

### Phase 2: Supabase Infrastructure & Remote Configuration
**Goal:** Cloud-backed distributed system with strict client/server boundaries.

#### 2.1 Supabase Auth ❌ NOT STARTED
**Files to Modify:**
- `Core/Auth/AuthManager.swift`
- `Features/Auth/Views/AuthFlowView.swift`
- `Features/Auth/Views/EmailAuthView.swift`

**Requirements:**
- Integrate `supabase-swift` SDK
- Wire Apple Sign-In (mandatory for App Store)
- Store JWT in KeychainService
- Bind `AppEnvironment.isAuthenticated` to Supabase session

---

#### 2.2 Database Schema ❌ NOT STARTED
**Supabase Tables to Create:**

```sql
-- users (managed by Supabase Auth, add custom fields)
- subscription_tier: text (free, pro, unlimited)
- created_at: timestamp

-- prompts (RLS: user can only read their own)
- id: uuid
- user_id: uuid (references auth.users)
- intent: text (user's original speech)
- original_speech: text
- generated_prompt: text
- is_favorite: boolean
- user_rating: integer (1-5, for RLHF)
- feedback_notes: text
- created_at: timestamp

-- events (analytics ingestion)
- id: uuid
- user_id: uuid
- event_name: text
- properties: jsonb
- created_at: timestamp

-- telemetry_errors
- id: uuid
- user_id: uuid
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
- StoreKit 2 integrated for product fetching
- On-device purchase flow working
- ❌ No server-side receipt validation
- ❌ No webhook sync with Supabase

**TODO:**
- Implement App Store Server Notifications webhook
- Sync `users.subscription_tier` with purchases/cancellations
- Add server-side subscription status check

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

#### 4.1 Metal Orb ❌ NOT STARTED
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

#### 4.3 Shareable Prompt Cards ❌ NOT STARTED
**File:** `Features/Home/Views/ShareCardView.swift`

**Requirements:**
- Connect to `ResultView`
- Use `ImageRenderer` for watermarked social cards
- Viral growth loop

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

### Critical Path (Phase 1 ✅ COMPLETE)

| File | Status | Notes |
|------|--------|-------|
| `Core/Utils/AnalyticsService.swift` | ✅ Complete | Local caching ready, Phase 2: add Supabase upload |
| `Core/Utils/TelemetryService.swift` | ✅ Complete | Error logging ready, Phase 2: add Supabase upload |
| `App/AppEnvironment.swift` | ✅ Complete | Telemetry injected, user ID sync active |

### For Phase 2 (Supabase)

| File | Status | Notes |
|------|--------|-------|
| `Core/Auth/AuthManager.swift` | 🔴 Needs Rewrite | Replace JWT with Supabase Auth |
| `Core/Storage/HistoryStore.swift` | 🔴 Needs Rewrite | Replace SwiftData with Supabase |
| `Core/Networking/APIClient.swift` | 🔴 Needs Rewrite | Route to Edge Functions |
| `Core/Networking/APIEndpoint.swift` | 🟡 Stable | Add Edge Function endpoints |

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
│   │   ├── StoreManager.swift        # 🟡 Add server validation
│   │   └── UsageTracker.swift        # 🟡 Client-side only
│   └── Utils/
│       ├── AnalyticsService.swift    # 🟡 Add caching
│       └── TelemetryService.swift    # 🔴 CREATE THIS
├── Features/
│   ├── Auth/                         # Login flows
│   ├── History/                      # History + Favorites
│   ├── Home/                         # Main generation UI
│   ├── Onboarding/                   # First-time experience
│   ├── Settings/                     # Settings + Upgrade
│   └── Trending/                     # Prompt catalog
└── Models/
    ├── API/                          # Server response models
    └── Local/                        # PromptHistoryItem, etc.
```

---

**Last Updated By:** AI Assistant (Kimi)  
**Update Notes (v1.2):** Completed Phase 1 implementation:
- AnalyticsService: Added local caching with UserDefaults, CachedAnalyticsEvent struct, batch upload placeholder
- TelemetryService: Created new service with structured error logging, device info capture, app state monitoring
- AppEnvironment: Injected TelemetryService, added user ID syncing, app_open tracking
- SpeechRecognizerService: Added telemetry logging for START_FAILED, RECOGNITION_ERROR, CRITICAL_FAILURE
- APIClient: Added telemetry logging for network errors and HTTP status codes
- Status: Phase 1 COMPLETE, ready for Phase 2 (Supabase integration)

