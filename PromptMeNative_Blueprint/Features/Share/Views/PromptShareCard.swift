import SwiftUI

struct PromptShareCard: View {
    static let exportSize = CGSize(width: 360, height: 640) // 3x export = 1080 x 1920

    let promptText: String
    let beforeText: String?
    let modeName: String
    let handle: String
    let includeHashtag: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var cleanedPrompt: String {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your refined prompt will appear here." : trimmed
    }

    private var cleanedBefore: String? {
        guard let beforeText else { return nil }
        let trimmed = beforeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var watermarkText: String {
        includeHashtag
            ? "Made with Orion Orb ✨  \(handle)  #OrionOrb"
            : "Made with Orion Orb ✨  \(handle)"
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(alignment: .leading, spacing: 20) {
                header
                modePill

                if let cleanedBefore {
                    beforeSnippet(cleanedBefore)
                }

                promptPanel

                Spacer(minLength: 0)

                footer
            }
            .padding(28)
            .frame(width: Self.exportSize.width, height: Self.exportSize.height, alignment: .topLeading)
        }
        .frame(width: Self.exportSize.width, height: Self.exportSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.16), lineWidth: 1)
        )
    }

    private var backgroundLayer: some View {
        ZStack {
            PromptTheme.backgroundBase

            LinearGradient(
                colors: [
                    PromptTheme.backgroundGradientTop,
                    PromptTheme.backgroundGradientUpperMid,
                    PromptTheme.backgroundBase,
                    PromptTheme.backgroundGradientBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [PromptTheme.secondaryOrbGlow.opacity(colorScheme == .dark ? 0.34 : 0.24), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 240
            )
            .offset(x: 30, y: -30)

            RadialGradient(
                colors: [PromptTheme.primaryOrbGlow.opacity(colorScheme == .dark ? 0.42 : 0.26), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 260
            )
            .offset(x: -40, y: 40)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.015 : 0.05))
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            OrbitLogoView()
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Orion Orb")
                    .font(PromptTheme.Typography.rounded(24, .bold))
                    .foregroundStyle(PromptTheme.paleLilacWhite)

                Text("AI Prompt Refiner")
                    .font(PromptTheme.Typography.rounded(13, .semibold))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.84))
            }

            Spacer()
        }
    }

    private var modePill: some View {
        Text(modeName)
            .font(PromptTheme.Typography.rounded(12, .semibold))
            .foregroundStyle(PromptTheme.paleLilacWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(PromptTheme.glassFill)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }

    private func beforeSnippet(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before")
                .font(PromptTheme.Typography.rounded(12, .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.72))

            Text(text)
                .font(PromptTheme.Typography.rounded(14, .medium))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.66))
                .lineSpacing(3)
                .lineLimit(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var promptPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Refined Prompt")
                .font(PromptTheme.Typography.rounded(13, .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.80))

            Text(cleanedPrompt)
                .font(PromptTheme.Typography.rounded(28, .medium))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .lineLimit(15)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            LinearGradient(
                colors: [.clear, PromptTheme.backgroundBase.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 34)
            .allowsHitTesting(false)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PromptTheme.glassFill.opacity(colorScheme == .dark ? 1 : 0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.14), lineWidth: 1)
                )
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            OrbitLogoView()
                .frame(width: 20, height: 20)
                .opacity(0.78)

            Text(watermarkText)
                .font(PromptTheme.Typography.rounded(12, .semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()
        }
    }
}

#Preview {
    PromptShareCard(
        promptText: "Rewrite this customer support email so it sounds calm, premium, and reassuring while clearly explaining the refund timeline and next steps.",
        beforeText: "make this email better",
        modeName: "AI Mode",
        handle: "@harlowvolt",
        includeHashtag: true
    )
}
