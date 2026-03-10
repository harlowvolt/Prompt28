import SwiftUI

struct HomeView: View {
    private enum ActiveSheet: Identifiable {
        case typePrompt, settings

        var id: String {
            switch self {
            case .typePrompt: return "typePrompt"
            case .settings:   return "settings"
            }
        }
    }

    @EnvironmentObject private var env: AppEnvironment
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

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let topSafe = proxy.safeAreaInsets.top
            let topSpacing = min(64, max(52, proxy.size.height * 0.07))
            let bottomBreathing = min(34, max(26, proxy.size.height * 0.034))

            ZStack {
                PromptPremiumBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, topSafe + topSpacing)

                    modePicker
                        .padding(.top, 36)

                    modeDescriptionLine
                        .padding(.top, 24)

                    orbSection
                        .padding(.top, 36)

                    transcriptSection
                        .padding(.top, 24)

                    if hasResult {
                        resultSection
                            .padding(.top, 18)
                            .frame(maxHeight: .infinity)
                    } else {
                        Spacer(minLength: 40)
                    }

                    typeInsteadButton
                        .padding(.top, hasResult ? 14 : 24)
                        .padding(.bottom, bottomBreathing + 18)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prompt28DidCopyPrompt)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = false }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                Text("\(firstName),")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("What do you want to make today?")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Button { activeSheet = .settings } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
            }
            .shadow(color: .white.opacity(0.08), radius: 10, y: 3)
            .padding(.trailing, 2)
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                modePill(label: "AI Mode", mode: .ai)
                modePill(label: "Human Mode", mode: .human)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var modeDescriptionLine: some View {
        Text(modeDescription)
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.42))
            .multilineTextAlignment(.center)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.2), value: generateViewModel.selectedMode)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
    }

    private var modeDescription: String {
        switch generateViewModel.selectedMode {
        case .ai:    return "Standard AI prompt style"
        case .human: return "Sounds like a real human wrote it"
        }
    }

    private func modePill(label: String, mode: PromptMode) -> some View {
        let isSelected = generateViewModel.selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                generateViewModel.selectedMode = mode
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(PromptTheme.mutedViolet.opacity(0.4))
                            .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.45), lineWidth: 1.1))
                            .shadow(color: PromptTheme.softLilac.opacity(0.18), radius: 12, y: 3)
                    } else {
                        Capsule()
                            .fill(PromptTheme.deepShadow.opacity(0.48))
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 252)
    }

    // MARK: - Orb + Transcript + Result

    private var orbSection: some View {
        let restingOrb = min(UIScreen.main.bounds.width * 0.90, 360)
        let resultOrb = min(UIScreen.main.bounds.width * 0.70, 286)

        return OrbView(engine: orbEngine, onTranscript: generateFromText)
            .frame(width: hasResult ? resultOrb : restingOrb, height: hasResult ? resultOrb : restingOrb)
            .frame(maxWidth: .infinity)
    }

    private var transcriptSection: some View {
        Text(primaryTranscriptText)
            .font(PromptTheme.Typography.rounded(16, .regular))
            .foregroundStyle(PromptTheme.paleLilacWhite.opacity(hasResult ? 0.82 : 0.72))
            .multilineTextAlignment(.center)
            .padding(.horizontal, PromptTheme.Spacing.l)
    }

    private var resultSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ResultView(viewModel: generateViewModel)

                if let err = generateViewModel.errorMessage {
                    errorBanner(text: err)
                }

                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, PromptTheme.Spacing.m)
            .padding(.top, PromptTheme.Spacing.m)
        }
    }
    // MARK: - Type Instead

    private var typeInsteadButton: some View {
        Button { activeSheet = .typePrompt } label: {
            Text("Type instead")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    Capsule()
                        .fill(PromptTheme.deepShadow.opacity(0.5))
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.16), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
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
