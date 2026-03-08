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

    private let idleBottomPadding: CGFloat = PromptTheme.Spacing.l
    private let resultTopSpacing: CGFloat = PromptTheme.Spacing.l
    private let orbToTranscriptSpacing: CGFloat = PromptTheme.Spacing.s
    private let transcriptToResultSpacing: CGFloat = PromptTheme.Spacing.m

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

                GeometryReader { proxy in
                    let orbHeight = min(proxy.size.height * 0.42, 420)
                    let compactOrbHeight = min(proxy.size.height * 0.32, 320)
                    let bottomSafeSpacer = proxy.safeAreaInsets.bottom + idleBottomPadding

                    Group {
                        if hasResult {
                            VStack(spacing: 0) {
                                Spacer(minLength: resultTopSpacing)

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
                                .frame(maxWidth: 420)
                                .frame(height: compactOrbHeight)

                                Spacer(minLength: orbToTranscriptSpacing)

                                Text(primaryTranscriptText)
                                    .font(PromptTheme.Typography.rounded(16, .regular))
                                    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.94))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, PromptTheme.Spacing.l)
                                    .textSelection(.enabled)

                                Spacer(minLength: transcriptToResultSpacing)

                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 12) {
                                        ResultView(viewModel: generateViewModel)

                                        if let errorMessage = generateViewModel.errorMessage {
                                            errorBanner(text: errorMessage)
                                        }

                                        Color.clear
                                            .frame(height: bottomSafeSpacer)
                                    }
                                    .padding(.horizontal, PromptTheme.Spacing.m)
                                }
                            }
                        } else {
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
                                .frame(maxWidth: 420)
                                .frame(height: orbHeight)

                                Spacer(minLength: orbToTranscriptSpacing)

                                Text(primaryTranscriptText)
                                    .font(PromptTheme.Typography.rounded(16, .regular))
                                    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.94))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, PromptTheme.Spacing.l)
                                    .textSelection(.enabled)

                                Spacer(minLength: bottomSafeSpacer)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: proxy.size.height, maxHeight: .infinity)
                        }
                    }
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

    private var hasResult: Bool {
        !generateViewModel.latestPromptText.isEmpty
    }

    private var primaryTranscriptText: String {
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

        if generateViewModel.isGenerating || orbEngine.state == .transcribing || orbEngine.state == .generating {
            return "Processing..."
        }

        if orbEngine.isRecording || orbEngine.state == .listening {
            return "Listening..."
        }

        return "Tap to speak"
    }

    private func errorBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(text)
                .font(PromptTheme.Typography.rounded(14, .medium))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PromptTheme.Spacing.s)
        .background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

extension Notification.Name {
    static let prompt28DidCopyPrompt = Notification.Name("prompt28.didCopyPrompt")
}
