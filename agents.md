# Current Status
Last updated: 2026-04-03
Phase completed: Phase 1, Phase 2, Phase 3

# Apple Approval Roadmap — April 2026
Codex — New Apple Approval Roadmap for Orion Orb (Prompt28)
We are now executing the final unified execution plan to guarantee App Store approval in 2026. Implement exactly in this order. Do not skip or reorder any step.
🥇 PHASE 1: Mandatory Compliance (Legal Layer) — Must be done first

AI Consent Gate
Create a new file ConsentView.swift in the main Prompt28 target.
Add hasAcceptedAIConsent to AppPreferences.swift (or create it if it doesn’t exist).
Make the consent screen a hard gate: RootView.swift must show ConsentView() until the user taps “Allow & Continue”.
Exact disclosure text (use this verbatim):
“Your prompt and any personal information it contains will be sent to third-party AI providers (Anthropic and/or OpenAI) to generate a response. This data is processed only for your request and not stored by the AI provider beyond the generation step.”
Add a “Learn more” link that opens the privacy policy.

Account Deletion
In SettingsView.swift, add a prominent red “Delete Account” button.
The button must call a Supabase Edge Function that permanently deletes the user’s row, all related data, and revokes any Sign in with Apple tokens.

AI Disclaimer
In every ResultView.swift (or wherever generated content is shown), add this exact footer text at the bottom:
“AI-generated content may be inaccurate or inappropriate.”

Sign in with Apple
Add a “Sign in with Apple” button in AuthFlowView.swift (alongside existing Supabase providers).


After finishing Phase 1, commit with message: feat: Phase 1 — Apple compliance (AI consent + account deletion + Sign in with Apple)
🥈 PHASE 2: Transformation Value (Approval Layer)

Prompt Refinement Tools
Make “Make more professional”, “Make more detailed”, “Make shorter”, etc. buttons prominent and always visible in ResultView.swift.

Categorized Templates / Use Cases
Expand or create a “Templates” section (use existing TrendingView if present) with clear categories: Business, School, Creative, Marketing, Personal, etc.

Remove All Placeholders
Delete or fully implement every “Coming Soon” view and any dead navigation links (especially old Share Card destinations).


Commit: feat: Phase 2 — transformation value & cleanup
🥉 PHASE 3: Technical & UX Polish (Speed Layer)

iPad Support
In HomeView.swift, constrain main content with .frame(maxWidth: 800) for iPad.
Use native ShareLink in ResultView.swift (fix any popover crashes).

Performance
In GenerateViewModel.swift, make ImageRenderer lazy — only render the PNG when the user actually taps “Share Card”.

App Review Notes
Prepare the exact text (I will give it to you after you confirm Phase 3 is done).


Commit: feat: Phase 3 — iPad + performance polish
Final Instructions for you, Codex:

After you complete all three phases, create a new file in the repository root called agents.md.
In agents.md, paste the entire roadmap above (this message) under a new heading # Apple Approval Roadmap — April 2026.
Also add a section at the top:
# Current Status
Last updated: [today’s date]
Phase completed: [list which phases you finished]

Once done, reply to me with “✅ All phases implemented and agents.md updated” so I can give you the final App Review Notes text and submission checklist.
Start with Phase 1 now.
