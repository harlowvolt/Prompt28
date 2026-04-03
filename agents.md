# Current Status
Last updated: April 3, 2026
Phases completed: All phases completed

# Apple Approval Roadmap — April 2026

## Phase 1 — Mandatory Compliance (Legal Layer)

- AI consent must be a hard gate before the main app experience.
- `ConsentView.swift` must live inside the `Prompt28/` folder.
- Consent acceptance must be stored locally through app preferences.
- `RootView.swift` must present `ConsentView()` until the user accepts.
- The consent screen must include this exact disclosure text:
  “Your prompt and any personal information it contains will be sent to third-party AI providers (Anthropic and/or OpenAI) to generate a response. This data is processed only for your request and not stored by the AI provider beyond the generation step.”
- The consent screen must include a `Learn more` link to the privacy policy.
- `SettingsView.swift` must contain a prominent red `Delete Account` button.
- The delete-account flow must call a Supabase Edge Function that permanently deletes the user account and related user data, not just logs the user out.
- Generated-results screens must include this exact footer text:
  “AI-generated content may be inaccurate or inappropriate.”
- `AuthFlowView.swift` must include native `Sign in with Apple`.

## Phase 2 — Transformation Value (Approval Layer)

- The result screen must expose always-visible refinement actions.
- Refinement actions should clearly include options such as:
  `Make more professional`
  `Make more detailed`
  `Make shorter`
  `Make more persuasive`
- The app must provide a `Templates` or `Use Cases` surface for reusable prompt ideas.
- Template categories must clearly cover:
  `Business`
  `School`
  `Creative`
  `Marketing`
  `Personal`
- `TrendingView` may be used as the implementation surface if it behaves like a categorized template library.
- No shipping placeholder or `Coming Soon` views should remain.
- Old share-card placeholder destinations and dead navigation links must be removed.

## Phase 3 — Technical & UX Polish (Speed Layer)

- `HomeView.swift` must constrain readable iPad content to `.frame(maxWidth: 800)`.
- Result sharing must use native `ShareLink` to avoid iPad popover-anchor issues.
- Share-card rendering must stay lazy.
- `ImageRenderer` should only render the share image when the user taps `Share Card`.
- Share-card generation should not run automatically during normal prompt generation flow.
