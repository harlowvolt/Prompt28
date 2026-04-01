import SwiftUI
import PhotosUI
@preconcurrency import Supabase

struct HomeView: View {
    @Environment(\.dismiss) private var dismiss
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
    @State private var showLeftPanel = false
    @State private var ghostMode = false
    // Image picker state
    @State private var showImagePicker = false
    @State private var imagePickerItem: PhotosPickerItem?
    @State private var attachedImage: UIImage?
    @FocusState private var isInputFocused: Bool

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

private struct GhostGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let bottomY = height * 0.88
        let waveWidth = width / 3

        path.move(to: CGPoint(x: width * 0.18, y: bottomY))
        path.addLine(to: CGPoint(x: width * 0.18, y: height * 0.42))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.50, y: height * 0.10),
            control: CGPoint(x: width * 0.18, y: height * 0.12)
        )
        path.addQuadCurve(
            to: CGPoint(x: width * 0.82, y: height * 0.42),
            control: CGPoint(x: width * 0.82, y: height * 0.12)
        )
        path.addLine(to: CGPoint(x: width * 0.82, y: bottomY))

        path.addQuadCurve(
            to: CGPoint(x: waveWidth * 2.15, y: bottomY - height * 0.10),
            control: CGPoint(x: width * 0.76, y: bottomY)
        )
        path.addQuadCurve(
            to: CGPoint(x: waveWidth * 1.5, y: bottomY),
            control: CGPoint(x: waveWidth * 1.9, y: bottomY + height * 0.06)
        )
        path.addQuadCurve(
            to: CGPoint(x: waveWidth * 0.85, y: bottomY - height * 0.10),
            control: CGPoint(x: waveWidth * 1.1, y: bottomY)
        )
        path.addQuadCurve(
            to: CGPoint(x: width * 0.18, y: bottomY),
            control: CGPoint(x: waveWidth * 0.6, y: bottomY + height * 0.06)
        )

        path.closeSubpath()
        return path
    }
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
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if showLeftPanel {
                    leftPanelOverlay
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .promptClearNavigationSurfaces()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !showLeftPanel {
                bottomArea
            }
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
                .presentationBackground(PromptTheme.panelBackground)
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
        .onAppear {
            guard !hasResult else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isInputFocused = true
            }
        }
        .onChange(of: showLeftPanel) { _, isPresented in
            if isPresented {
                isInputFocused = false
            }
        }
        .onChange(of: ghostMode) { _, enabled in
            generateViewModel.privacyMode = enabled
            if !enabled {
                // When privacy mode is disabled, nothing special needed —
                // history resumes from the next generation onwards.
            }
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
            // Left: main menu panel
            Button {
                isInputFocused = false
                withAnimation(.easeInOut(duration: 0.22)) {
                    showLeftPanel = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(navIconBackground)
            }
            .buttonStyle(.plain)

            Spacer()

            // Platform dropdown — centered in nav bar
            platformDropdownButton

            Spacer()

            // Right: privacy / ghost mode toggle — when active, NO history is saved
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { ghostMode.toggle() }
                HapticService.impact(ghostMode ? .light : .medium)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(ghostMode
                              ? PromptTheme.orbAccent.opacity(0.18)
                              : Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(ghostMode ? PromptTheme.orbAccent.opacity(0.10) : PromptTheme.glassFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(ghostMode
                                        ? PromptTheme.orbAccent.opacity(0.45)
                                        : Color.white.opacity(0.10),
                                        lineWidth: ghostMode ? 1 : 0.5)
                        )

                    ghostGlyph(isActive: ghostMode)
                }
                .frame(width: 36, height: 36)
                .shadow(color: ghostMode ? PromptTheme.orbAccent.opacity(0.25) : .clear, radius: 8)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: ghostMode)
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

            Spacer()

            // Logo — centered
            OrbitLogoView()
                .frame(width: 128, height: 128)
                .opacity(0.50)
                .colorMultiply(PromptTheme.logoDimTint)
                .allowsHitTesting(false)

            Spacer()
        }
    }

    // MARK: - Top Center Action

    private func modePill(label: String, mode: PromptMode) -> some View {
        let isOn = generateViewModel.selectedMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                generateViewModel.selectedMode = mode
            }
            preferencesStore.setMode(mode)
            HapticService.selection()
            AnalyticsService.shared.track(.modeSwitched(to: mode.rawValue))
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.50))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    Capsule()
                        .fill(isOn
                              ? LinearGradient(
                                    colors: [PromptTheme.orbAccent.opacity(0.28),
                                             PromptTheme.orbAccentLight.opacity(0.16)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing)
                              : LinearGradient(
                                    colors: [PromptTheme.glassFill, PromptTheme.glassFill],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                        .overlay(
                            Capsule()
                                .stroke(isOn
                                        ? PromptTheme.orbAccent.opacity(0.45)
                                        : Color.white.opacity(0.08),
                                        lineWidth: 1)
                        )
                }
                .shadow(color: isOn ? PromptTheme.orbAccent.opacity(0.22) : .clear,
                        radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isOn)
    }

    private var platformDropdownButton: some View {
        Button {
            showTrending = true
            HapticService.selection()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PromptTheme.orbAccent)
                Text("Power Prompts")
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .frame(width: 132, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PromptTheme.glassFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func ghostGlyph(isActive: Bool) -> some View {
        let ghostColor = isActive ? PromptTheme.orbAccent : Color.white.opacity(0.82)

        GhostGlyphShape()
            .fill(ghostColor)
            .frame(width: 15, height: 16)
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
                .foregroundStyle(.white.opacity(0.55))
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
                            .foregroundStyle(.white)
                        Spacer()
                        if generateViewModel.selectedPlatform == platform {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PromptTheme.orbAccent)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        generateViewModel.selectedPlatform == platform
                            ? PromptTheme.orbAccent.opacity(0.10)
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
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PromptTheme.dropdownBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PromptTheme.orbAccent.opacity(0.20), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        .shadow(color: PromptTheme.orbAccent.opacity(0.10), radius: 20, y: 4)
    }

    // MARK: - Bottom Area

    private var bottomArea: some View {
        VStack(spacing: 12) {
            if !hasResult {
                modePillRow
            }
            inputBar
        }
        .padding(.horizontal, 15)
        .padding(.bottom, isInputFocused ? 10 : 28)
    }

    private var modePillRow: some View {
        HStack(spacing: 12) {
            modePill(label: "✦  AI Mode", mode: .ai)
            modePill(label: "✧  Human Mode", mode: .human)
        }
    }

    private var trendingPill: some View {
        Button { showTrending = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PromptTheme.orbAccent)
                Text("See What's Trending")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(PromptTheme.glassFill))
                    .overlay(Capsule().stroke(PromptTheme.orbAccent.opacity(0.20), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
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
                isInputFocused = true
            }
        } label: {
            HStack(spacing: 5) {
                if isTag {
                    Circle()
                        .fill(PromptTheme.orbAccent)
                        .frame(width: 5, height: 5)
                }
                Text(label)
                    .font(.system(size: 11, weight: isTag ? .bold : .semibold, design: .default))
                    .foregroundStyle(isTag ? Color.white : Color.white.opacity(0.55))
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
        VStack(spacing: 0) {
            // Attached image thumbnail row (shown only when image is selected)
            if let attachedImage {
                HStack(spacing: 10) {
                    Image(uiImage: attachedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(PromptTheme.orbAccent.opacity(0.45), lineWidth: 1)
                        )

                    Text("Image attached")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            self.attachedImage = nil
                            self.imagePickerItem = nil
                            generateViewModel.attachedImage = nil
                        }
                        HapticService.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                // + button — opens PhotosPicker (Photos + Camera)
                PhotosPicker(
                    selection: $imagePickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(attachedImage != nil
                                  ? PromptTheme.orbAccent.opacity(0.22)
                                  : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(attachedImage != nil
                                            ? PromptTheme.orbAccent.opacity(0.45)
                                            : Color.white.opacity(0.08),
                                            lineWidth: attachedImage != nil ? 1 : 0.5)
                            )
                        Image(systemName: attachedImage != nil ? "photo.fill" : "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(attachedImage != nil
                                             ? PromptTheme.orbAccent
                                             : Color.white.opacity(0.82))
                    }
                    .frame(width: 36, height: 36)
                    .shadow(color: attachedImage != nil
                            ? PromptTheme.orbAccent.opacity(0.20)
                            : .clear, radius: 6)
                }
                .buttonStyle(.plain)
                .onChange(of: imagePickerItem) { _, newItem in
                    Task {
                        guard let newItem,
                              let data = try? await newItem.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            attachedImage = image
                            generateViewModel.attachedImage = image
                        }
                        HapticService.impact(.light)
                    }
                }

                ZStack(alignment: .leading) {
                    if generateViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Just talk. Messy is fine.")
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .foregroundStyle(Color.white.opacity(0.34))
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $generateViewModel.inputText)
                        .font(.system(size: 17, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.92))
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.go)
                        .focused($isInputFocused)
                        .onSubmit {
                            let trimmed = generateViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty, !generateViewModel.isGenerating else { return }
                            Task { await generateViewModel.generate() }
                        }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PromptTheme.inputBarBackground)
                .shadow(color: .black.opacity(0.24), radius: 14, y: 6)
        )
        .animation(.easeInOut(duration: 0.2), value: attachedImage != nil)
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
                    .foregroundStyle(isCritical ? .yellow.opacity(0.90) : .white.opacity(0.72))
                Text(remaining == 0
                     ? "Upgrade"
                     : "\(remaining) left")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(isCritical ? .white.opacity(0.92) : .white.opacity(0.78))
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
                    .foregroundStyle(.white)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Left Panel (Grok-style)

    private var leftPanelOverlay: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showLeftPanel = false
                    }
                }

            leftPanelContent
                .frame(maxWidth: 320)
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.22), value: showLeftPanel)
    }

    private var leftPanelContent: some View {
        ZStack {
            PromptTheme.panelBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────
                HStack(spacing: 12) {
                    // Avatar circle
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [PromptTheme.orbAccentMuted, PromptTheme.orbAccent],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Text("O")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Text("Orbit Orb")
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundStyle(.white)

                    Spacer()

                    // Close / go-back button
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showLeftPanel = false
                        }
                    } label: {
                        HStack(spacing: 1) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.60))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 20)

                // ── Promo Banner ─────────────────────────────────────
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Try 10 prompts for free")
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .foregroundStyle(.white)
                        Text("No account needed to start")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showLeftPanel = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            router.presentHomeSheet(.upgrade)
                        }
                    } label: {
                        Text("Try Now")
                            .font(.system(size: 13, weight: .bold, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.22)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [PromptTheme.orbAccentMuted, PromptTheme.orbAccent],
                            startPoint: .leading, endPoint: .trailing))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

                // ── Nav Rows ─────────────────────────────────────────
                VStack(spacing: 2) {
                    NavigationLink(destination: FavoritesView().toolbar(.hidden, for: .navigationBar)) {
                        leftPanelRow(icon: "star.fill", label: "Favorites")
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: ShareCardsPlaceholderView().toolbar(.hidden, for: .navigationBar)) {
                        leftPanelRow(icon: "square.and.arrow.up.fill", label: "Share Cards")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("History")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.46))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    VStack(spacing: 8) {
                        ForEach(recentHistoryItems, id: \.id) { item in
                            Button {
                                generateViewModel.restoreFromHistory(item)
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    showLeftPanel = false
                                }
                            } label: {
                                historyPreviewRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 20)

                // ── Search / Settings / New Chat ─────────────────────
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.white.opacity(0.36))

                        Text("Search")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.38))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                    )

                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showLeftPanel = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            router.presentHomeSheet(.settings)
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        generateViewModel.resetConversation()
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showLeftPanel = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isInputFocused = true
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    private func leftPanelRow(icon: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.70))
                .frame(width: 26)
            Text(label)
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.30))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var recentHistoryItems: [PromptHistoryItem] {
        historyStore.items
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
    }

    private func historyPreviewRow(_ item: PromptHistoryItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.customName ?? item.input)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)

                Text(leftPanelHistoryTimestamp(for: item.createdAt))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
            }

            Spacer()

            Text(item.mode == .ai ? "AI" : "Human")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(item.mode == .ai ? PromptTheme.orbAccent : .white.opacity(0.72))
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.04))
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.6))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func leftPanelHistoryTimestamp(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: date)
    }

    // MARK: - Panel Sheet

    private var panelSheet: some View {
        NavigationStack {
            ZStack {
                PromptTheme.panelBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Orbit Orb")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundStyle(.white)
                        Spacer()
                        Button { showPanel = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
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

                        NavigationLink(destination: ShareCardsPlaceholderView().toolbar(.hidden, for: .navigationBar)) {
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
                    .fill(PromptTheme.orbAccent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(PromptTheme.orbAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.40))
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
                    .foregroundStyle(.white)
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PromptTheme.Spacing.s)
        .background(PromptTheme.premiumMaterial,
                    in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

private struct ShareCardsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PromptTheme.panelBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.7))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(PromptTheme.orbAccent.opacity(0.6))
                    Text("Share Cards")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                    Text("Generate a prompt to create\na shareable card.")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
        }
    }
}
