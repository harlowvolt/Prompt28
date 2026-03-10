import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CyberBackgroundGradient()

                VStack(spacing: AppSpacing.section) {
                    Spacer(minLength: max(geo.size.height * 0.03, 14))

                    VStack(spacing: AppSpacing.element) {
                        Text("Natalie,")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .minimumScaleFactor(0.85)
                            .lineLimit(1)

                        Text("What do you want to make today?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    ModePillsView(selectedMode: $viewModel.selectedMode)

                    Text(helperText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.36))

                    VoiceOrbView(isRecording: $viewModel.isRecording)
                        .frame(width: min(geo.size.width * 0.70, 360))
                        .contentShape(Circle())
                        .onTapGesture {
                            viewModel.toggleRecording()
                        }

                    Text("Tap to speak")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))

                    Button {
                        // Presentation-only control on this screen for now.
                    } label: {
                        Text("Type instead")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: AppHeights.floatingTabBar)
                            .background {
                                RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                                            .stroke(Color.white.opacity(0.20), lineWidth: 1.2)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.10), Color.clear],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    Spacer(minLength: max(geo.size.height * 0.07, 18))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, geo.safeAreaInsets.top + 26)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 12))

                SettingsButton {
                    viewModel.openSettings()
                }
                .padding(.top, geo.safeAreaInsets.top + 18)
                .padding(.trailing, AppSpacing.screenHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var helperText: String {
        switch viewModel.selectedMode {
        case .ai:
            return "Standard AI prompt style"
        case .human:
            return "Human-like tone and phrasing"
        }
    }
}
