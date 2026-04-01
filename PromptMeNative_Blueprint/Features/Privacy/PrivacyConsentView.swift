import SwiftUI

/// Shown once on first launch, before any auth, data collection, or API calls.
/// Satisfies App Store Review Guideline 5.1.2(i) — explicit user consent for data use.
struct PrivacyConsentView: View {
    var onAccept: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 64)

                // Shield icon
                ZStack {
                    Circle()
                        .fill(PromptTheme.mutedViolet.opacity(0.22))
                        .overlay(Circle().stroke(PromptTheme.softLilac.opacity(0.22), lineWidth: 0.8))
                        .frame(width: 88, height: 88)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(PromptTheme.softLilac)
                }
                .padding(.bottom, 24)

                // Title
                Text("Before You Begin")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .padding(.bottom, 10)

                Text("Orbit Orb uses the following to deliver its service.\nYour privacy matters to us.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)

                // Data disclosure rows
                VStack(spacing: 12) {
                    dataRow(
                        icon: "mic.fill",
                        iconColor: Color(hex: "#95A7FF"),
                        title: "Microphone & Speech",
                        detail: "Your voice is converted to text on-device by Apple. Audio is never stored or transmitted."
                    )
                    dataRow(
                        icon: "arrow.up.doc.fill",
                        iconColor: Color(hex: "#7FC9FF"),
                        title: "Prompt Input",
                        detail: "Your typed or spoken idea is sent to our server to generate a polished prompt. We do not sell this data."
                    )
                    dataRow(
                        icon: "chart.bar.fill",
                        iconColor: Color(hex: "#A0CFFF"),
                        title: "Anonymous Analytics",
                        detail: "We collect anonymous usage events (e.g. buttons tapped) to improve the app. No personal data is sent."
                    )
                    dataRow(
                        icon: "clock.fill",
                        iconColor: Color(hex: "#CFD7FF"),
                        title: "Prompt History",
                        detail: "Saved prompts are stored locally on your device. You can disable this in Settings at any time."
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                // Privacy policy link
                Button {
                    if let url = URL(string: "https://orbitorb.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("View Privacy Policy →")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.72))
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.bottom, 28)

                // Accept CTA
                Button(action: onAccept) {
                    Text("Accept & Continue")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#7F7FD5"), Color(hex: "#6E55D8")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(PromptTheme.softLilac.opacity(0.28), lineWidth: 0.5)
                                )
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.24))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Data Row

    private func dataRow(icon: String, iconColor: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .overlay(Circle().stroke(iconColor.opacity(0.22), lineWidth: 0.5))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                Text(detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.50))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(PromptTheme.glassCard(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
