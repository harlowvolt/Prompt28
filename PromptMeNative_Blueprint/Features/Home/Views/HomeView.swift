import SwiftUI

struct HomeView: View {
    private enum ActiveSheet: Identifiable {
        case typePrompt

        var id: String {
            switch self {
            case .typePrompt:
                return "typePrompt"
            }
        }
    }

    @StateObject private var orbEngine = OrbEngine.makeDefault()
    @StateObject private var generateViewModel: GenerateViewModel

    @State private var activeSheet: ActiveSheet?
    @State private var showCopiedToast = false

    init(appEnvironment: AppEnvironment) {
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)

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
                        .frame(maxHeight: 380)

                        Spacer(minLength: 30)

                        Text(activeTranscriptText)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.94))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .textSelection(.enabled)

                        Spacer(minLength: 40)

                        ResultView(viewModel: generateViewModel)

                        if let errorMessage = generateViewModel.errorMessage {
                            Spacer(minLength: 12)
                            errorBanner(text: errorMessage)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("PROMPT²⁸")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .typePrompt
                    } label: {
                        Image(systemName: "keyboard")
                            .foregroundStyle(PromptTheme.softLilac)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .typePrompt:
                    NavigationStack {
                        TypePromptView(viewModel: generateViewModel)
                            .navigationTitle("Type Prompt")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") {
                                        activeSheet = nil
                                    }
                                }
                            }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
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
