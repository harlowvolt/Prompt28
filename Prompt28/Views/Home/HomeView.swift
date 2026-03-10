import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CyberBackgroundGradient()

                VStack(spacing: AppSpacing.section) {
                    Spacer(minLength: max(geo.size.height * 0.03, AppSpacing.element))

                    VStack(spacing: AppSpacing.element) {
                        Text("\(firstName),")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .minimumScaleFactor(0.85)
                            .lineLimit(1)

                        Text("What do you want to make today?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                            .multilineTextAlignment(.center)
                    }
                    ModePillsView(selectedMode: $viewModel.selectedMode)
                        .padding(.horizontal, -AppSpacing.screenHorizontal)

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
                                    .fill(.regularMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                                            .stroke(Color.white.opacity(0.20), lineWidth: 1.2)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                    }
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: max(geo.size.height * 0.07, AppSpacing.section))
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, geo.safeAreaInsets.top + AppSpacing.top)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, AppSpacing.element))

                SettingsButton {
                    viewModel.openSettings()
                }
                .padding(.top, geo.safeAreaInsets.top + AppSpacing.section)
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

    private var firstName: String {
        let envName = ProcessInfo.processInfo.environment["PROMPT28_FIRST_NAME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let envName, !envName.isEmpty {
            return envName
        }

        let mirror = Mirror(reflecting: viewModel)
        for child in mirror.children {
            guard let label = child.label else { continue }
            if label == "firstName" || label == "name" {
                if let value = child.value as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
        }

        return "there"
    }
}
