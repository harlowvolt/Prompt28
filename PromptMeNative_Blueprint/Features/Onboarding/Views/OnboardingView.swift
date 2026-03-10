import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkles",
            iconColor: Color(red: 0.81, green: 0.85, blue: 1.0),
            title: "Welcome to Prompt28",
            subtitle: "Turn any idea into an expert AI prompt — in seconds."
        ),
        OnboardingPage(
            icon: "waveform",
            iconColor: Color(red: 0.70, green: 0.80, blue: 1.0),
            title: "Tap the Orb to Speak",
            subtitle: "Just say what you want to create and we'll handle the rest."
        ),
        OnboardingPage(
            icon: "person.2.fill",
            iconColor: Color(red: 0.60, green: 0.75, blue: 1.0),
            title: "Two Modes, One Tap",
            subtitle: "AI Mode makes structured prompts. Human Mode sounds like you wrote it yourself."
        )
    ]

    var body: some View {
        ZStack {
            PromptPremiumBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                Spacer()

                // Dot indicator
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage
                                  ? PromptTheme.softLilac
                                  : PromptTheme.softLilac.opacity(0.25))
                            .frame(width: index == currentPage ? 20 : 7, height: 7)
                            .clipShape(Capsule())
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                .padding(.bottom, 36)

                // Button
                AppPrimaryButton(
                    title: currentPage == pages.count - 1 ? "Get Started" : "Next"
                ) {
                    HapticService.impact(.medium)
                    if currentPage < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    } else {
                        AnalyticsService.shared.track(.onboardingCompleted)
                        onComplete()
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, 52)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: AppSpacing.section) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.10))
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle().stroke(page.iconColor.opacity(0.20), lineWidth: 1.5)
                    )
                    .shadow(color: page.iconColor.opacity(0.25), radius: 28, y: 8)

                Image(systemName: page.icon)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.iconColor, PromptTheme.mutedViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: AppSpacing.element) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - Model

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}
