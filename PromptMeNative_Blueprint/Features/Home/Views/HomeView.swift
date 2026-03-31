import SwiftUI
@preconcurrency import Supabase

struct HomeView: View {
    @Environment(\.errorState) private var errorState
    @AppStorage(ExperimentFlags.RootBackground.home) private var useRootBackgroundExperiment = false
    @State private var orbEngine: OrbEngine
    @State private var generateViewModel: GenerateViewModel
    @State private var settingsViewModel = SettingsViewModel()
    @State private var lastPresentedGlobalError = ""
    @State private var showPlatformDropdown = false
    @State private var isListening = false
    @State private var showTrending = false
    @State private var showPanel = false

    private let authManager: AuthManager
    private let router: AppRouter
    private let apiClient: any APIClientProtocol
    private let preferencesStore: any PreferenceStoring
    private let historyStore: any HistoryStoring
    private let usageTracker: UsageTracker

    init(
        authManager: AuthManager,
        router: AppRouter,
        apiClient: any APIClientProtocol,
        preferencesStore: any PreferenceStoring,
        historyStore: any HistoryStoring,
        usageTracker: UsageTracker,
        orbEngineFactory: any OrbEngineFactoryProtocol,
        storeManager: StoreManager? = nil,
        supabase: SupabaseClient? = nil
    ) {
        self.authManager = authManager
        self.router = router
        self.apiClient = apiClient
        self.preferencesStore = preferencesStore
        self.historyStore = historyStore
        self.usageTracker = usageTracker
        self._orbEngine = State(wrappedValue: orbEngineFactory.makeOrbEngine())
        self._generateViewModel = State(
            wrappedValue: GenerateViewModel(
                authManager: authManager,
                historyStore: historyStore,
                preferencesStore: preferencesStore,
                usageTracker: usageTracker,
                storeManager: storeManager,
                supabase: supabase
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                if useRootBackgroundExperiment {
                    Color.clear.ignoresSafeArea()
                } else {
                    PromptPremiumBackground().ignoresSafeArea()
                }

                if hasResult {
                    // ── Result state: show result screen ──────────────────
                    VStack(spacing: 0) {
                        navBar
                        resultSection(hPad: 0)
                            .frame(maxHeight: .infinity)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, AppSpacing.bottomContentClearance)
                } else {
                    // ── Idle state: main home layout ──────────────────────
                    VStack(spacing: 0) {
                        navBar
                        centerContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        bottomArea
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Dropdown overlay
                if showPlatformDropdown {
                    platformDropdownOverlay
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .promptClearNavigationSurfaces()
        }
        .overlay(alignment: .bottom) { copiedToast }
        .sheet(isPresented: $showTrending) {
            TrendingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showPanel) {
            panelSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#02060D"))
                .presentationCornerRadius(32)
        }
        .sheet(item: Binding(
            get: { router.homeSheet },
            set: { router.homeSheet = $0 }
        )) { sheet in
            switch sheet {
            case .typePrompt:
                TypePromptView(viewModel: generateViewModel)
            case .settings:
                SettingsView { router.dismissHomeSheet() }
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
            if show {
                router.presentHomeSheet(.upgrade)
                generateViewModel.showPaywall = false
            }
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
                authManager: authManager,
                preferencesStore: preferencesStore,
                historyStore: historyStore
            )
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack(spacing: 10) {
            // Left: settings (hamburger style)
            Button { router.presentHomeSheet(.settings) } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(navIconBackground)
            }
            .buttonStyle(.plain)

            // Brand name
            Text("Orbit Orb")
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .tracking(-0.3)

            Spacer()

            // Right: panel button (History / Saves / Share Cards / Settings)
            Button {
                showPanel = true
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(navIconBackground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var navIconBackground: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(PromptTheme.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 0) {
            // Permission banners
            if case .microphoneDenied = orbEngine.permissionStatus {
                permissionDeniedBanner(message: "Microphone access is required for voice input.")
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            } else if case .speechDenied = orbEngine.permissionStatus {
                permissionDeniedBanner(message: "Speech recognition is required for voice input.")
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            // Platform dropdown — top center
            platformDropdownButton
                .padding(.top, 18)

            Spacer()

            // Logo — small, dark, centered
            OrbitLogoView()
                .frame(width: 82, height: 82)
                .opacity(0.28)
                .colorMultiply(Color(hex: "#2A1A4A"))
                .allowsHitTesting(false)

            Spacer()
        }
    }

    // MARK: - Mode Pill

    private func modePill(label: String, mode: PromptMode) -> some View {
        let isOn = generateViewModel.selectedMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                generateViewModel.selectedMode = mode
            }
            HapticService.selection()
            AnalyticsService.shared.track(.modeSwitched(to: mode.rawValue))
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundStyle(isOn ? PromptTheme.paleLilacWhite : PromptTheme.mutedViolet)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    Capsule()
                        .fill(isOn
                              ? LinearGradient(
                                    colors: [Color(hex: "#8B8FFF").opacity(0.28),
                                             Color(hex: "#A78BFA").opacity(0.16)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing)
                              : LinearGradient(
                                    colors: [PromptTheme.glassFill, PromptTheme.glassFill],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                        .overlay(
                            Capsule()
                                .stroke(isOn
                                        ? Color(hex: "#8B8FFF").opacity(0.45)
                                        : Color.white.opacity(0.08),
                                        lineWidth: 1)
                        )
                }
                .shadow(color: isOn ? Color(hex: "#8B8FFF").opacity(0.22) : .clear,
                        radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isOn)
    }

    // MARK: - Platform Dropdown

    private var platformDropdownButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                showPlatformDropdown = true
            }
            HapticService.selection()
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color(hex: generateViewModel.selectedPlatform.accentHex))
                    .frame(width: 7, height: 7)
                Text(generateViewModel.selectedPlatform.displayName)
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(PromptTheme.softLilac)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PromptTheme.mutedViolet)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(PromptTheme.glassFill))
                    .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var platformDropdownOverlay: some View {
        ZStack(alignment: .top) {
            // Dismiss tap
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.20)) {
                        showPlatformDropdown = false
                    }
                }

            VStack(spacing: 0) {
                // Position roughly below nav + logo area
                Spacer().frame(height: 90)

                dropdownSheet
                    .padding(.horizontal, 70)
                    .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
            }
        }
    }

    private var dropdownSheet: some View {
        VStack(spacing: 0) {
            Text("Format for")
                .font(.system(size: 10, weight: .bold, design: .default))
                .foregroundStyle(PromptTheme.mutedViolet)
                .tracking(0.8)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(TargetPlatform.allCases) { platform in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        generateViewModel.selectedPlatform = platform
                        showPlatformDropdown = false
                    }
                    HapticService.selection()
                } label: {
                    HStack(spacing: 11) {
                        Circle()
                            .fill(Color(hex: platform.accentHex))
                            .frame(width: 9, height: 9)
                        Text(platform.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                        Spacer()
                        if generateViewModel.selectedPlatform == platform {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#8B8FFF"))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        generateViewModel.selectedPlatform == platform
                            ? Color(hex: "#8B8FFF").opacity(0.10)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)

                if platform != TargetPlatform.allCases.last {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.horizontal, 12)
                }
            }

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 12)

            Text("Adapts prompt style for each platform")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(PromptTheme.mutedViolet.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "#0D1525"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: "#8B8FFF").opacity(0.20), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        .shadow(color: Color(hex: "#8B8FFF").opacity(0.10), radius: 20, y: 4)
    }

    // MARK: - Bottom Area

    private var bottomArea: some View {
        VStack(spacing: 12) {
            trendingPill
            modePillRow
            inputBar
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 28)
    }

    private var trendingPill: some View {
        Button { showTrending = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#8B8FFF"))
                Text("See What's Trending")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(PromptTheme.softLilac)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PromptTheme.mutedViolet)
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(PromptTheme.glassFill))
                    .overlay(Capsule().stroke(Color(hex: "#8B8FFF").opacity(0.20), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var modePillRow: some View {
        HStack(spacing: 12) {
            modePill(label: "✦  AI Mode", mode: .ai)
            modePill(label: "✧  Human Mode", mode: .human)
        }
    }

    private var trendingStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                trendingChip(label: "Trending", isTag: true)
                trendingChip(label: "Rewrite my bio")
                trendingChip(label: "Plan my week")
                trendingChip(label: "Cold email")
                trendingChip(label: "Say no nicely")
                trendingChip(label: "Better LinkedIn")
            }
            .padding(.horizontal, 2)
        }
    }

    private func trendingChip(label: String, isTag: Bool = false) -> some View {
        Button {
            if !isTag {
                generateViewModel.inputText = label
                router.presentHomeSheet(.typePrompt)
            }
        } label: {
            HStack(spacing: 5) {
                if isTag {
                    Circle()
                        .fill(Color(hex: "#8B8FFF"))
                        .frame(width: 5, height: 5)
                }
                Text(label)
                    .font(.system(size: 11, weight: isTag ? .bold : .semibold, design: .default))
                    .foregroundStyle(isTag ? PromptTheme.softLilac : PromptTheme.mutedViolet)
                    .tracking(isTag ? 0.3 : 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(PromptTheme.glassFill))
                    .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            // + button → type prompt sheet
            Button { router.presentHomeSheet(.typePrompt) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PromptTheme.mutedViolet)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)

            // Tappable placeholder → type prompt
            Button { router.presentHomeSheet(.typePrompt) } label: {
                Text(orbEngine.isRecording ? primaryTranscriptText : "Just talk. Messy is fine.")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(
                        orbEngine.isRecording
                            ? PromptTheme.softLilac.opacity(0.80)
                            : PromptTheme.mutedViolet.opacity(0.65)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(.plain)

            // Mic button — toggles voice input
            Button {
                HapticService.impact(.medium)
                if orbEngine.isRecording {
                    orbEngine.stopListening()
                    isListening = false
                } else {
                    let engine = orbEngine
                    let vm = generateViewModel
                    engine.onFinalTranscript = { transcript in
                        Task { @MainActor in
                            engine.markGenerating()
                            await vm.generateFromOrb(text: transcript)
                            if let err = vm.errorMessage {
                                engine.markFailure(err)
                            } else {
                                engine.markSuccess()
                            }
                            engine.markIdle()
                        }
                    }
                    engine.startListening()
                    isListening = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(orbEngine.isRecording
                              ? Color(hex: "#8B8FFF").opacity(0.20)
                              : Color.white.opacity(0.07))
                        .overlay(
                            Circle()
                                .stroke(orbEngine.isRecording
                                        ? Color(hex: "#8B8FFF").opacity(0.50)
                                        : Color.white.opacity(0.10),
                                        lineWidth: 1)
                        )
                    Image(systemName: orbEngine.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(orbEngine.isRecording
                                         ? Color(hex: "#8B8FFF")
                                         : PromptTheme.softLilac)
                }
                .frame(width: 40, height: 40)
                .shadow(color: orbEngine.isRecording ? Color(hex: "#8B8FFF").opacity(0.30) : .clear,
                        radius: 8)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: orbEngine.isRecording)

            // Send / Transform button
            Button {
                guard !generateViewModel.inputText.isEmpty else {
                    router.presentHomeSheet(.typePrompt)
                    return
                }
                Task { await generateViewModel.generate() }
                HapticService.impact(.medium)
            } label: {
                Image(systemName: generateViewModel.isGenerating ? "ellipsis" : "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#8B8FFF"), Color(hex: "#A78BFA")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color(hex: "#8B8FFF").opacity(0.30), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(generateViewModel.isGenerating)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#07101E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: "#8B8FFF").opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.30), radius: 10, y: 4)
        )
    }

    // MARK: - Result Section

    private func resultSection(hPad: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.element) {
                ResultView(viewModel: generateViewModel)
                if let err = generateViewModel.errorMessage {
                    errorBanner(text: err).padding(.horizontal, hPad)
                }
                Color.clear.frame(height: 20)
            }
            .padding(.top, AppSpacing.element)
        }
    }

    // MARK: - Usage Pill

    @ViewBuilder
    private func usagePill(remaining: Int) -> some View {
        let isCritical = remaining <= 2
        Button { generateViewModel.showPaywall = true } label: {
            HStack(spacing: 5) {
                Image(systemName: remaining == 0 ? "lock.fill" : "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isCritical ? .yellow.opacity(0.90) : PromptTheme.softLilac.opacity(0.72))
                Text(remaining == 0
                     ? "Upgrade"
                     : "\(remaining) left")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(isCritical ? .white.opacity(0.92) : PromptTheme.softLilac.opacity(0.78))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isCritical ? Color.yellow.opacity(0.10) : PromptTheme.glassFill)
                    .overlay(Capsule().stroke(isCritical ? Color.yellow.opacity(0.30) : Color.white.opacity(0.09), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toast

    private var copiedToast: some View {
        Group {
            if generateViewModel.showCopiedToast {
                Text("Copied to clipboard")
                    .font(.system(size: 13, weight: .semibold, design: .default))
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

    // MARK: - Panel Sheet

    private var panelSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#02060D").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Orbit Orb")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                        Spacer()
                        Button { showPanel = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PromptTheme.mutedViolet)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                    // Rows
                    VStack(spacing: 2) {
                        NavigationLink(destination: HistoryView().toolbar(.hidden, for: .navigationBar)) {
                            panelRow(icon: "clock.arrow.circlepath", label: "History",
                                     subtitle: "Your generated prompts")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: FavoritesView().toolbar(.hidden, for: .navigationBar)) {
                            panelRow(icon: "star.fill", label: "Saves",
                                     subtitle: "Bookmarked prompts")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: shareCardsPlaceholder.toolbar(.hidden, for: .navigationBar)) {
                            panelRow(icon: "square.and.arrow.up.fill", label: "Share Cards",
                                     subtitle: "Cards from your prompts")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Settings pinned at bottom
                    Button {
                        showPanel = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            router.presentHomeSheet(.settings)
                        }
                    } label: {
                        panelRow(icon: "gearshape.fill", label: "Settings",
                                 subtitle: "Preferences & account")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func panelRow(icon: String, label: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#8B8FFF").opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(hex: "#8B8FFF"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(PromptTheme.mutedViolet)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PromptTheme.mutedViolet.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private var shareCardsPlaceholder: some View {
        ZStack {
            Color(hex: "#02060D").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(hex: "#8B8FFF").opacity(0.6))
                Text("Share Cards")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                Text("Generate a prompt to create\na shareable card.")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(PromptTheme.mutedViolet)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    private var hasResult: Bool {
        !generateViewModel.latestPromptText.isEmpty
    }

    private func generateFromText(_ finalText: String) {
        Task {
            let engine = orbEngine
            engine.markGenerating()
            await generateViewModel.generateFromOrb(text: finalText)
            if let error = generateViewModel.errorMessage {
                engine.markFailure(error)
            } else {
                engine.markSuccess()
            }
            engine.markIdle()
        }
    }

    private var primaryTranscriptText: String {
        let live = orbEngine.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if orbEngine.isRecording, !live.isEmpty { return live }
        let final = orbEngine.finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !final.isEmpty { return final }
        return "Listening..."
    }

    // MARK: - Banners

    private func permissionDeniedBanner(message: String) -> some View {
        VStack(spacing: AppSpacing.elementTight) {
            HStack(spacing: 10) {
                Image(systemName: "mic.slash.fill").foregroundStyle(.yellow)
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open iOS Settings")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
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
    }

    private func errorBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .default))
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
