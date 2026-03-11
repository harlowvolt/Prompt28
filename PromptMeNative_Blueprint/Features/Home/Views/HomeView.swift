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

    @EnvironmentObject private var env: AppEnvironment
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
        GeometryReader { proxy in
            let topSafe = proxy.safeAreaInsets.top

            ZStack(alignment: .topTrailing) {
                PromptPremiumBackground()
                    .ignoresSafeArea()

                VStack(spacing: AppSpacing.sectionTight) {
                    headerSection

                    modePicker

                    orbSection(screenWidth: proxy.size.width)

                    transcriptSection

                    if hasResult {
                        resultSection
                            .frame(maxHeight: .infinity)
                    }

                    typeInsteadButton
                }
                .padding(.top, topSafe + AppSpacing.top)
                .padding(.bottom, AppSpacing.bottomContentClearance)
                .frame(width: proxy.size.width, alignment: .top)

                // Floating gear — sits at top-right independently
                Button { activeSheet = .settings } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(12)
                        .background(Color.white.opacity(0.06), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                }
                .padding(.top, topSafe - 32)
                .padding(.trailing, AppSpacing.screenHorizontal)
            }
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .center, spacing: AppSpacing.elementTight) {
            Text("\(firstName),")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("What do you want to make today?")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)

            if let remaining = promptsRemaining {
                Button { activeSheet = .upgrade } label: {
                    HStack(spacing: 5) {
                        Image(systemName: remaining > 0 ? "bolt.fill" : "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(remaining > 0
                             ? "\(remaining) prompt\(remaining == 1 ? "" : "s") left"
                             : "Upgrade for more")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(remaining > 0
                                     ? PromptTheme.softLilac.opacity(0.88)
                                     : Color.yellow.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(remaining > 0
                                  ? PromptTheme.mutedViolet.opacity(0.22)
                                  : Color.yellow.opacity(0.12))
                            .overlay(Capsule().stroke(
                                remaining > 0
                                ? PromptTheme.softLilac.opacity(0.28)
                                : Color.yellow.opacity(0.30),
                                lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .animation(.easeInOut(duration: 0.25), value: remaining)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: AppSpacing.element) {
            modePill(label: "AI Mode", mode: .ai)
            modePill(label: "Human Mode", mode: .human)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.screenHorizontal)
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
        // Removed the hardcoded maxWidth that was breaking alignment
    }

    // MARK: - Orb + Transcript + Result

    private func orbSection(screenWidth: CGFloat) -> some View {
        let restingOrb = min(screenWidth * 0.84, 330)
        let resultOrb = min(screenWidth * 0.60, 240)

        return OrbView(engine: orbEngine, onTranscript: generateFromText)
            .frame(width: hasResult ? resultOrb : restingOrb, height: hasResult ? resultOrb : restingOrb)
            .frame(maxWidth: .infinity)
    }

    private var transcriptSection: some View {
        Text(primaryTranscriptText)
            .font(PromptTheme.Typography.rounded(16, .regular))
            .foregroundStyle(PromptTheme.paleLilacWhite.opacity(hasResult ? 0.82 : 0.72))
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private var resultSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.element) {
                ResultView(viewModel: generateViewModel)

                if let err = generateViewModel.errorMessage {
                    errorBanner(text: err)
                }

                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.element)
        }
    }
    
    // MARK: - Type Instead

    private var typeInsteadButton: some View {
        Button { activeSheet = .typePrompt } label: {
            Text("Type instead")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .padding(.horizontal, 32)
                .frame(height: AppHeights.segmentedControl)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.16), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
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

    // MARK: - Helpers

    private var hasResult: Bool { !generateViewModel.latestPromptText.isEmpty }

    /// Returns remaining prompt count from the most recent API response, or nil before first generation.
    private var promptsRemaining: Int? {
        guard let remaining = generateViewModel.latestResult?.prompts_remaining else { return nil }
        return remaining
    }

    private var firstName: String {
        let full = env.authManager.currentUser?.name ?? ""
        let first = full.components(separatedBy: " ").first ?? ""
        return first.isEmpty ? "there" : first
    }

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
