import SwiftUI

struct PromptShareCard: View {
    let promptText: String
    let modeName: String

    private var cleanedPrompt: String {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Generated prompt" : trimmed
    }

    var body: some View {
        ZStack {
            PromptPremiumBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    OrbitLogoView()
                        .frame(width: 44, height: 44)

                    Spacer()

                    Text(modeName)
                        .font(PromptTheme.Typography.rounded(12, .semibold))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(PromptTheme.glassFill, in: Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Orbit Orb")
                        .font(PromptTheme.Typography.rounded(28, .bold))
                        .foregroundStyle(PromptTheme.paleLilacWhite)

                    Text("Prompt ready to share")
                        .font(PromptTheme.Typography.rounded(14, .medium))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.82))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("EXPERT PROMPT")
                        .font(PromptTheme.Typography.rounded(11, .semibold))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.72))

                    Text(cleanedPrompt)
                        .font(PromptTheme.Typography.rounded(17, .medium))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(20)
                .background(PromptTheme.glassCard(cornerRadius: 26))

                HStack {
                    Text("orbitorb.app")
                        .font(PromptTheme.Typography.rounded(13, .medium))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.78))

                    Spacer()

                    Text("Turn messy ideas into polished prompts.")
                        .font(PromptTheme.Typography.rounded(12, .medium))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.64))
                }
            }
            .padding(24)
            .frame(width: 380, height: 480, alignment: .topLeading)
        }
        .frame(width: 380, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}
