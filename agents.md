# Current Status
Last updated: April 3, 2026
Phases completed: All phases completed

# Apple Approval Roadmap — April 2026

**Codex — Updated Apple Approval Roadmap for Orion Orb (Prompt28) – April 3, 2026**

The repository now has commits for **Phase 1** (`feat: Phase 1 — Apple compliance...`) and **Phase 3** (`feat: Phase 3 — iPad + performance polish`). However, `agents.md` does not show the full roadmap content on GitHub yet, README.md is still missing, and Phase 2 appears incomplete.

Please execute **exactly in this order** and update the repository cleanly.

### 🥇 PHASE 1: Mandatory Compliance (Legal Layer) — Verify & Complete
Even though a Phase 1 commit exists, double-check and finish these items:

1. **AI Consent Gate**  
   - Ensure `ConsentView.swift` exists inside the `Prompt28/` folder.  
   - Confirm `hasAcceptedAIConsent` is stored (in AppPreferences or @AppStorage).  
   - Make sure `RootView.swift` shows the ConsentView as a **hard gate** until the user accepts.  
   - Use this exact disclosure text:  
     “Your prompt and any personal information it contains will be sent to third-party AI providers (Anthropic and/or OpenAI) to generate a response. This data is processed only for your request and not stored by the AI provider beyond the generation step.”  
   - Add a “Learn more” link that opens the privacy policy.

2. **Account Deletion**  
   - Confirm a red “Delete Account” button exists in `SettingsView.swift`.  
   - Ensure it calls a Supabase Edge Function that **permanently deletes** the user’s data (not just logout).

3. **AI Disclaimer**  
   - Add this exact footer in every results screen (`ResultView.swift` or equivalent):  
     “AI-generated content may be inaccurate or inappropriate.”

4. **Sign in with Apple**  
   - Confirm the “Sign in with Apple” button is added in `AuthFlowView.swift`.

After verifying/finishing Phase 1, commit with:  
`feat: Phase 1 — Complete Apple compliance (AI consent + account deletion + Sign in with Apple)`

### 🥈 PHASE 2: Transformation Value (Approval Layer) — This is the missing piece
5. **Prompt Refinement Tools**  
   - Make refinement buttons (“Make more professional”, “Make more detailed”, “Make shorter”, etc.) prominent and always visible in the result screen.

6. **Categorized Templates / Use Cases**  
   - Expand/create a “Templates” or “Use Cases” section with clear categories (Business, School, Creative, Marketing, Personal, etc.). Use or improve the existing TrendingView if present.

7. **Remove All Placeholders**  
   - Find and remove or fully implement every “Coming Soon”, placeholder view, or dead navigation link (especially old Share Card destinations).

Commit after Phase 2:  
`feat: Phase 2 — transformation value, templates & placeholder cleanup`

### 🥉 PHASE 3: Technical & UX Polish (Speed Layer) — Verify & Finalize
8. **iPad Support**  
   - Confirm `HomeView.swift` uses `.frame(maxWidth: 800)` for proper iPad layout.  
   - Use native `ShareLink` in result screens to avoid popover issues.

9. **Performance Optimization**  
   - Confirm `ImageRenderer` in the view model is lazy (only renders when user taps “Share Card”).

Commit (if changes needed):  
`feat: Phase 3 — Final iPad + performance polish`

### Final Tasks
10. **Update agents.md**  
    - Create or fully overwrite `agents.md` in the repository root.  
    - Paste the **entire roadmap above** (this message) under the heading:  
      `# Apple Approval Roadmap — April 2026`  
    - At the very top, add:  
      `# Current Status`  
      `Last updated: April 3, 2026`  
      `Phases completed: Phase 1 (partial), Phase 3 (partial), Phase 2 (pending)`  
    - After you finish all phases, update the status to “All phases completed”.

11. **Create README.md**  
    - Add a clean README.md in the root with:  
      - App name: Orion Orb (Prompt28)  
      - Short description  
      - Key features (AI prompt transformation, power prompts, etc.)  
      - Screenshots section (placeholder for now)  
      - “Built with SwiftUI + Supabase”

Once everything is done, reply to me with:  
**“✅ All phases implemented — agents.md and README.md updated”**

Start working on this now, beginning with verifying Phase 1 and completing Phase 2.

---
