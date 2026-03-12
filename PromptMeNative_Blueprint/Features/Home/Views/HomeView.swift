import SwiftUI

struct HomeView: View {
    @Environment(\.authManager) private var authManager
    @Environment(\.appRouter) private var appRouter
    @Environment(\.errorState) private var errorState
    @Environment(\.apiClient) private var scopedAPIClient
    @Environment(\.preferencesStore) private var scopedPreferencesStore
    @Environment(\.historyStore) private var scopedHistoryStore
    @Environment(\.usageTracker) private var scopedUsageTracker
    @AppStorage("experiment.useRootBackground.home") private var useRootBackgroundExperiment = false
    @State private var orbEngine = OrbEngine.makeDefault()
    @State private var generateViewModel: GenerateViewModel
    @State private var settingsViewModel = SettingsViewModel()
    @State private var lastPresentedGlobalError = ""

    private let fallbackAuthManager: AuthManager
    private let fallbackRouter: AppRouter
    private let fallbackAPIClient: any APIClientProtocol
    private let fallbackPreferencesStore: any PreferenceStoring
    private let fallbackHistoryStore: any HistoryStoring
    private let fallbackUsageTracker: UsageTracker

    private var router: AppRouter {
        appRouter ?? fallbackRouter
    }

    private var apiClient: any APIClientProtocol {
        scopedAPIClient ?? fallbackAPIClient
    }

    private var preferencesStore: any PreferenceStoring {
        scopedPreferencesStore ?? fallbackPreferencesStore
    }

    private var resolvedAuthManager: AuthManager {
        authManager ?? fallbackAuthManager
    }

    private var historyStore: any HistoryStoring {
        scopedHistoryStore ?? fallbackHistoryStore
    }

    private var usageTracker: UsageTracker {
        scopedUsageTracker ?? fallbackUsageTracker
    }

    init(appEnvironment: AppEnvironment) {
        self.fallbackAuthManager = appEnvironment.authManager
        self.fallbackRouter = appEnvironment.router
        self.fallbackAPIClient = appEnvironment.apiClient
        self.fallbackPreferencesStore = appEnvironment.preferencesStore
        self.fallbackHistoryStore = appEnvironment.historyStore
        self.fallbackUsageTracker = appEnvironment.usageTracker

        self._generateViewModel = State(
            wrappedValue: GenerateViewModel(
                apiClient: appEnvironment.apiClient,
                authManager: appEnvironment.authManager,
                historyStore: appEnvironment.historyStore,
                preferencesStore: appEnvironment.preferencesStore,
                usageTracker: appEnvironment.usageTracker
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if useRootBackgroundExperiment {
                    Color.clear
                        .ignoresSafeArea()
                } else {
                    PromptPremiumBackground()
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    if !hasResult {
                        greetingHeader
                            .padding(.top, 16)

                        modePicker(hPad: 32)
                            .padding(.top, 18)

                        Text(generateViewModel.selectedMode == .ai
                             ? "Standard AI prompt style"
                             : "Writes like a real person, not an AI")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.40))
                            .padding(.top, 14)
                    }

                    if case .microphoneDenied = orbEngine.permissionStatus {
                        permissionDeniedBanner(message: "Microphone access is required to use the Orb.")
                            .padding(.top, 18)
                    } else if case .speechDenied = orbEngine.permissionStatus {
                        permissionDeniedBanner(message: "Speech recognition access is required to use the Orb.")
                            .padding(.top, 18)
                    }

                    OrbView(engine: orbEngine, onTranscript: generateFromText)
                        .frame(
                            width: hasResult ? 190 : 300,
                            height: hasResult ? 190 : 300
                        )
                        .shadow(color: PromptTheme.softLilac.opacity(0.42), radius: 26)
                        .padding(.top, hasResult ? 14 : 20)
                        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: hasResult)

                    transcriptSection(hPad: 24)
                        .padding(.top, 14)

                    if hasResult {
                        resultSection(hPad: 0)
                            .frame(maxHeight: .infinity)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button { router.presentHomeSheet(.typePrompt) } label: {
                            Text("Type instead")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                .fill(PromptTheme.glassFill)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 32)
                        .padding(.top, 18)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, AppSpacing.bottomContentClearance)
            }
            .toolbar(.hidden, for: .navigationBar)
            .promptClearNavigationSurfaces()
        }
        .overlay(alignment: .bottom) { copiedToast }
        .sheet(item: Binding(
            get: { router.homeSheet },
            set: { router.homeSheet = $0 }
        )) { sheet in
            switch sheet {
            case .typePrompt:
                NavigationStack {
                    TypePromptView(viewModel: generateViewModel)
                        .navigationTitle("Type Prompt")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { router.dismissHomeSheet() }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(32)

            case .settings:
                SettingsView {
                    router.dismissHomeSheet()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(32)

            case .upgrade:
                UpgradeView(viewModel: settingsViewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.regularMaterial)
                    .presentationCornerRadius(32)
            }
        }
        .onChange(of: generateViewModel.showPaywall) { _, show in
            if show { router.presentHomeSheet(.upgrade) }
        }
        .onChange(of: generateViewModel.errorMessage) { _, message in
            guard let message else { return }
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != lastPresentedGlobalError else { return }
            lastPresentedGlobalError = trimmed
            errorState?.present(title: "Request Failed", message: trimmed)
        }
        .onChange(of: orbEngine.state) { _, state in
            guard case .failure(let message) = state else { return }
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != lastPresentedGlobalError else { return }
            lastPresentedGlobalError = trimmed
            errorState?.present(title: "Voice Error", message: trimmed)
        }
        .task {
            settingsViewModel.bind(
                apiClient: apiClient,
                authManager: resolvedAuthManager,
                preferencesStore: preferencesStore,
                historyStore: historyStore
            )
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            Button { router.presentHomeSheet(.settings) } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(PromptTheme.glassFill))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: .black.opacity(0.20), radius: 10, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Mode Picker

    private func modePicker(hPad: CGFloat) -> some View {
        HStack(spacing: 14) {
            modePill(label: "AI Mode", mode: .ai)
            modePill(label: "Human Mode", mode: .human)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, hPad)
    }

    private func modePill(label: String, mode: PromptMode) -> some View {
        let isSelected = generateViewModel.selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                generateViewModel.selectedMode = mode
            }
            HapticService.selection()
            AnalyticsService.shared.track(.modeSwitched(to: mode.rawValue))
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.66))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#5B6388").opacity(0.90), Color(hex: "#3F4766").opacity(0.88)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.09), .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            )
                            .shadow(color: Color(hex: "#5F709E").opacity(0.20), radius: 12, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .fill(PromptTheme.glassFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Orb + Transcript + Result

    private func transcriptSection(hPad: CGFloat) -> some View {
        Text(primaryTranscriptText)
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.58))
            .multilineTextAlignment(.center)
            .padding(.horizontal, hPad)
    }

    private func resultSection(hPad: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.element) {
                ResultView(viewModel: generateViewModel)

                if let err = generateViewModel.errorMessage {
                    errorBanner(text: err)
                        .padding(.horizontal, hPad)
                }

                Color.clear.frame(height: 20)
            }
            .padding(.top, AppSpacing.element)
        }
    }

    // MARK: - Toast

    private var copiedToast: some View {
        Group {
            if generateViewModel.showCopiedToast {
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
    }

    // MARK: - Greeting

    private var firstName: String {
        let raw = resolvedAuthManager.currentUser?.name ?? ""
        let first = raw.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "there" : first
    }

    private var greetingHeader: some View {
        VStack(spacing: 10) {
            Text("\(firstName),")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("What do you want to make today?")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var hasResult: Bool { !generateViewModel.latestPromptText.isEmpty }

    private func generateFromText(_ finalText: String) {
        Task {
            orbEngine.markGenerating()
            await generateViewModel.generateFromOrb(text: finalText)
            if let error = generateViewModel.errorMessage {
                orbEngine.markFailure(error)
            } else {
                orbEngine.markSuccess()
            }
            orbEngine.markIdle()
        }
    }

    private var primaryTranscriptText: String {
        if let error = generateViewModel.errorMessage,
           !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return error }
        let live = orbEngine.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if orbEngine.isRecording, !live.isEmpty { return live }
        let finalized = orbEngine.finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalized.isEmpty { return finalized }
        if generateViewModel.isGenerating { return "Sending to Prompt28..." }
        let latest = generateViewModel.latestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !latest.isEmpty { return latest }
        if orbEngine.isRecording || orbEngine.state == .listening { return "Listening..." }
        if orbEngine.state == .transcribing || orbEngine.state == .generating { return "Processing..." }
        return "Tap to speak"
    }

    private func permissionDeniedBanner(message: String) -> some View {
        VStack(spacing: AppSpacing.elementTight) {
            HStack(spacing: 10) {
                Image(systemName: "mic.slash.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open iOS Settings")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(PromptTheme.mutedViolet.opacity(0.5)))
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.element)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
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
        .background(
            PromptTheme.premiumMaterial,
            in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

