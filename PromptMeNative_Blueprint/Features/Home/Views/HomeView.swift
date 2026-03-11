import SwiftUI

struct HomeView: View {
    private enum ActiveSheet: Identifiable {
        case typePrompt, settings, upgrade

        var id: String {
            switch self {
            case .typePrompt: return "typePrompt"
            case .settings:   return "settings"
            case .upgrade:    return "upgrade"
            }
        }
    }

    @Environment(AppEnvironment.self) private var env
    @StateObject private var orbEngine = OrbEngine.makeDefault()
    @StateObject private var generateViewModel: GenerateViewModel
    @StateObject private var settingsViewModel = SettingsViewModel()

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: AppSpacing.sectionTight) {
                    // Inline header row — lives INSIDE the ZStack content so it never
                    // overlaps toolbar items in a different z-layer.
                    HStack {
                        Button { activeSheet = .settings } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(10)
                                .background(Color.white.opacity(0.06), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                        }
                        Spacer()
                        Button { activeSheet = .typePrompt } label: {
                            Image(systemName: "keyboard")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(10)
                                .background(Color.white.opacity(0.06), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.element)

                    Spacer()

                    // Header and Mode Picker only show when NO result is active
                    if !hasResult {
                        greetingHeader
                            .padding(.bottom, AppSpacing.elementTight)

                        modePicker(hPad: AppSpacing.screenHorizontal)
                            .padding(.bottom, AppSpacing.element)
                    }

                    // Show permission denied banner if mic/speech access is blocked
                    if case .microphoneDenied = orbEngine.permissionStatus {
                        permissionDeniedBanner(message: "Microphone access is required to use the Orb.")
                    } else if case .speechDenied = orbEngine.permissionStatus {
                        permissionDeniedBanner(message: "Speech recognition access is required to use the Orb.")
                    }

                    OrbView(engine: orbEngine, onTranscript: generateFromText)
                        .frame(
                            width:  hasResult ? 180 : 250,
                            height: hasResult ? 180 : 250
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasResult)

                    transcriptSection(hPad: 0)

                    if hasResult {
                        resultSection(hPad: 0)
                            .frame(maxHeight: .infinity)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, AppSpacing.bottomContentClearance)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .bottom) { copiedToast }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .typePrompt:
                NavigationStack {
                    TypePromptView(viewModel: generateViewModel)
                        .navigationTitle("Type Prompt")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { activeSheet = nil }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(32)

            case .settings:
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
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
        .onReceive(NotificationCenter.default.publisher(for: .prompt28DidCopyPrompt)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = false }
            }
        }
        .onChange(of: generateViewModel.showPaywall) { _, show in
            if show { activeSheet = .upgrade }
        }
        .task {
            settingsViewModel.bind(
                apiClient: env.apiClient,
                authManager: env.authManager,
                preferencesStore: env.preferencesStore,
                historyStore: env.historyStore
            )
        }
    }

    // MARK: - Mode Picker

    private func modePicker(hPad: CGFloat) -> some View {
        HStack(spacing: AppSpacing.element) {
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
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .frame(height: AppHeights.segmentedControl)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(PromptTheme.mutedViolet.opacity(0.4))
                            .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.45), lineWidth: 1.1))
                            .shadow(color: PromptTheme.softLilac.opacity(0.18), radius: 12, y: 3)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Orb + Transcript + Result

    private func transcriptSection(hPad: CGFloat) -> some View {
        Text(primaryTranscriptText)
            .font(PromptTheme.Typography.rounded(16, .regular))
            .foregroundStyle(PromptTheme.paleLilacWhite.opacity(hasResult ? 0.82 : 0.72))
            .multilineTextAlignment(.center)
            .padding(.horizontal, hPad)
    }

    private func resultSection(hPad: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.element) {
                // ResultView is edge-to-edge — no horizontal padding here so the
                // dual-pane glass cards can bleed to the device edges.
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
    }

    // MARK: - Greeting

    private var firstName: String {
        let raw = env.authManager.currentUser?.name ?? ""
        let first = raw.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "there" : first
    }

    private var greetingHeader: some View {
        Text("Hey, \(firstName)!")
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.84))
            .frame(maxWidth: .infinity, alignment: .center)
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
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.yellow.opacity(0.25), lineWidth: 1))
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func errorBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(text)
                .font(PromptTheme.Typography.rounded(14, .medium))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PromptTheme.Spacing.s)
        .background(PromptTheme.premiumMaterial,
                    in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

extension Notification.Name {
    static let prompt28DidCopyPrompt = Notification.Name("prompt28.didCopyPrompt")
}
