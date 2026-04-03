# Current Status
Last updated: April 3, 2026
Phases completed: All phases completed
Status: Ready for App Store submission

# Apple Approval Roadmap — April 2026

## Phase 1: Mandatory Compliance (Legal Layer)

1. AI Consent Gate
- `ConsentView.swift` must exist inside the `Prompt28/` folder.
- `hasAcceptedAIConsent` must be stored locally in app preferences.
- `RootView.swift` must show `ConsentView()` as a hard gate until the user accepts.
- The consent screen must include this exact disclosure text:
  “Your prompt and any personal information it contains will be sent to third-party AI providers (Anthropic and/or OpenAI) to generate a response. This data is processed only for your request and not stored by the AI provider beyond the generation step.”
- The consent screen must include a `Learn more` link that opens the privacy policy.

2. Account Deletion
- `SettingsView.swift` must contain a prominent red `Delete Account` button.
- That button must call a Supabase Edge Function that permanently deletes the user record and related user data instead of only logging the user out.

3. AI Disclaimer
- Every generated-results surface must include this exact footer text:
  “AI-generated content may be inaccurate or inappropriate.”

4. Sign in with Apple
- `AuthFlowView.swift` must include a native `Sign in with Apple` button alongside the other auth providers.

Phase 1 commit:
- `feat: Phase 1 — Complete Apple compliance (AI consent + account deletion + Sign in with Apple)`

## Phase 2: Transformation Value (Approval Layer)

5. Prompt Refinement Tools
- The result screen must make prompt refinement actions prominent and always visible.
- Examples include:
  `Make more professional`
  `Make more detailed`
  `Make shorter`
  `Make more persuasive`

6. Categorized Templates / Use Cases
- The app must expose a `Templates` or `Use Cases` surface.
- Categories should clearly cover:
  `Business`
  `School`
  `Creative`
  `Marketing`
  `Personal`
- The existing `TrendingView` can be used as the implementation surface if it is updated to behave like a template library.

7. Remove All Placeholders
- Remove or fully implement every `Coming Soon` surface, placeholder sharing screen, or dead navigation link.
- Old share-card placeholder destinations should not remain in shipping navigation.

Phase 2 commit:
- `feat: Phase 2 — transformation value, templates & placeholder cleanup`

## Phase 3: Technical & UX Polish (Speed Layer)

8. iPad Support
- `HomeView.swift` must constrain its main readable content to `.frame(maxWidth: 800)` for iPad layouts.
- Sharing in result screens must use native `ShareLink` to avoid iPad popover-anchor issues.

9. Performance Optimization
- `ImageRenderer` work for share cards must be lazy.
- The share image should only be rendered when the user taps `Share Card`, not during normal generation flow.

Phase 3 commit:
- `feat: Phase 3 — Final iPad + performance polish`
