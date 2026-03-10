import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                CyberBackgroundGradient()

                VStack(spacing: geo.size.height * 0.042) {
                    Spacer(minLength: geo.size.height * 0.07)

                    Text("PROMPT²⁸")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("What do you want to make today?")
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    VoiceOrbView(isRecording: $viewModel.isRecording)
                        .frame(width: min(geo.size.width * 0.58, 310))
                        .onTapGesture {
                            viewModel.toggleRecording()
                        }

                    ModePillsView(selectedMode: $viewModel.selectedMode)

                    Spacer(minLength: geo.size.height * 0.14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                SettingsButton {
                    viewModel.openSettings()
                }
                .padding(.top, geo.safeAreaInsets.top + 18)
                .padding(.trailing, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
}
