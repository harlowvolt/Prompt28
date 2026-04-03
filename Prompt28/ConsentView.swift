import SwiftUI

struct ConsentView: View {
    @Environment(\.preferencesStore) private var scopedPreferencesStore

    private let privacyPolicyURL = URL(string: "https://orbitorb.app/privacy")!

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PromptPremiumBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer(minLength: proxy.safeAreaInsets.top + 36)

                        OrbitLogoView()
                            .frame(width: 94, height: 94)

                        VStack(spacing: 10) {
                            Text("Orbit Orb AI Consent")
                                .font(PromptTheme.Typography.rounded(28, .bold))
                                .foregroundStyle(PromptTheme.paleLilacWhite)
                                .multilineTextAlignment(.center)

                            Text("Review how Orbit Orb sends your request for AI generation before continuing.")
                                .font(PromptTheme.Typography.rounded(15, .regular))
                                .foregroundStyle(PromptTheme.softLilac.opacity(0.82))
                                .multilineTextAlignment(.center)
                        }

                        VStack(alignment: .leading, spacing: 18) {
                            Text("Your prompt and any personal information it contains will be sent to third-party AI providers (Anthropic and/or OpenAI) to generate a response. This data is processed only for your request and not stored by the AI provider beyond the generation step.")
                                .font(PromptTheme.Typography.rounded(16, .regular))
                                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.94))
                                .fixedSize(horizontal: false, vertical: true)

                            Link("Learn more", destination: privacyPolicyURL)
                                .font(PromptTheme.Typography.rounded(15, .semibold))
                                .foregroundStyle(PromptTheme.softLilac)
                        }
                        .padding(24)
                        .frame(maxWidth: 560, alignment: .leading)
                        .background(PromptTheme.glassCard(cornerRadius: 28))

                        Button {
                            scopedPreferencesStore?.update { $0.hasAcceptedAIConsent = true }
                        } label: {
                            Text("Allow & Continue")
                                .font(PromptTheme.Typography.rounded(17, .semibold))
                                .foregroundStyle(PromptTheme.paleLilacWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(PromptTheme.mutedViolet.opacity(0.72))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .stroke(PromptTheme.softLilac.opacity(0.28), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: 560)

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
    }
}
