import SwiftUI

struct HomeView: View {
    @ObservedObject private var appEnvironment: AppEnvironment
    @StateObject private var orbEngine = OrbEngine.makeDefault()
    @StateObject private var generateViewModel: GenerateViewModel

    @State private var showTypePrompt = false
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
        NavigationStack {
            ZStack {
                PromptTheme.backgroundGradient
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

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
                    .frame(maxWidth: 430)

                    transcriptText
                        .padding(.top, 14)

                    Spacer(minLength: 18)

                    ResultView(viewModel: generateViewModel)

                    if let errorMessage = generateViewModel.errorMessage {
                        errorBanner(text: errorMessage)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .navigationTitle("PROMPT²⁸")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTypePrompt = true
                } label: {
                    Image(systemName: "keyboard")
                }
            }
        }
        .navigationDestination(isPresented: $showTypePrompt) {
            TypePromptView(viewModel: generateViewModel)
                .navigationTitle("Type Prompt")
                .navigationBarTitleDisplayMode(.inline)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 8)
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(PromptTheme.glassFill)
                            .overlay(Capsule().stroke(PromptTheme.glassStroke, lineWidth: 1))
                    )
                    .foregroundStyle(PromptTheme.paleLilacWhite)
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

    private var transcriptText: some View {
        VStack(spacing: 6) {
            Text(homeStatusText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(statusTint)

            Text(activeTranscriptText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(1.5)
                .frame(maxWidth: .infinity)
                .textSelection(.enabled)
        }
    }

    private var homeStatusText: String {
        if let error = generateViewModel.errorMessage,
           !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if error.localizedCaseInsensitiveContains("sign in") || error.localizedCaseInsensitiveContains("unauthorized") {
                return "Auth required"
            }
            return "Error"
        }

        if generateViewModel.isGenerating || orbEngine.state == .generating || orbEngine.state == .transcribing {
            return "Processing"
        }

        if orbEngine.isRecording || orbEngine.state == .listening {
            return "Listening"
        }

        switch orbEngine.state {
        case .failure(let message):
            return message.localizedCaseInsensitiveContains("no speech") ? "No speech detected" : "Error"
        case .success:
            return "Ready"
        default:
            return "Tap to speak"
        }
    }

    private var activeTranscriptText: String {
        if let error = generateViewModel.errorMessage,
           !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return error
        }

        let live = orbEngine.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if orbEngine.isRecording, !live.isEmpty {
            return live
        }

        let finalized = orbEngine.finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalized.isEmpty {
            return finalized
        }

        if generateViewModel.isGenerating {
            return "Sending your input to Prompt28..."
        }

        let latest = generateViewModel.latestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !latest.isEmpty {
            return latest
        }

        return "Tap the orb and speak your prompt. Your live transcript and final text will appear here."
    }

    private var statusTint: Color {
        let status = homeStatusText
        if status == "Error" || status == "No speech detected" || status == "Auth required" {
            return .red.opacity(0.9)
        }
        if status == "Listening" {
            return PromptTheme.softLilac
        }
        if status == "Processing" {
            return PromptTheme.mutedViolet
        }
        return PromptTheme.paleLilacWhite
    }

    private func errorBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.28, green: 0.13, blue: 0.22).opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(red: 0.60, green: 0.36, blue: 0.52).opacity(0.5), lineWidth: 1)
                )
        )
    }
}

extension Notification.Name {
    static let prompt28DidCopyPrompt = Notification.Name("prompt28.didCopyPrompt")
}
