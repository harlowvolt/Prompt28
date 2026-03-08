import SwiftUI

struct HomeView: View {
    @ObservedObject private var appEnvironment: AppEnvironment
    @StateObject private var orbEngine = OrbEngine.makeDefault()
    @StateObject private var generateViewModel: GenerateViewModel

    @State private var showHistory = false
    @State private var showCopiedToast = false

    init(appEnvironment: AppEnvironment) {
        self._appEnvironment = ObservedObject(wrappedValue: appEnvironment)
        self._generateViewModel = StateObject(
            wrappedValue: GenerateViewModel(
                apiClient: appEnvironment.apiClient,
                authManager: appEnvironment.authManager,
                historyStore: appEnvironment.historyStore,
                preferencesStore: appEnvironment.preferencesStore
            )
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.04, green: 0.08, blue: 0.11), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    HStack {
                        Text("Prompt28")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showHistory = true
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.1), in: Capsule())
                        }
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                    }

                    OrbView(engine: orbEngine) { finalText in
                        Task {
                            orbEngine.markGenerating()
                            await generateViewModel.generateFromOrb(text: finalText)

                            if let error = generateViewModel.errorMessage {
                                orbEngine.markFailure(error)
                            } else {
                                orbEngine.markSuccess()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)

                    if !orbEngine.finalTranscript.isEmpty {
                        transcriptCard(text: orbEngine.finalTranscript)
                    }

                    ResultView(viewModel: generateViewModel)

                    if let errorMessage = generateViewModel.errorMessage {
                        errorBanner(text: errorMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 26)
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView { item in
                generateViewModel.restoreFromHistory(item)
                orbEngine.markSuccess()
                showHistory = false
            }
            .environmentObject(appEnvironment)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prompt28DidCopyPrompt)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedToast = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopiedToast = false
                }
            }
        }
    }

    private func transcriptCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text(text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func errorBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.red.opacity(0.42), lineWidth: 1)
                )
        )
    }
}

extension Notification.Name {
    static let prompt28DidCopyPrompt = Notification.Name("prompt28.didCopyPrompt")
}
