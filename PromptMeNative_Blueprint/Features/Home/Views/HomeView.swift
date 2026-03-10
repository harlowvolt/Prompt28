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
        ZStack(alignment: .top) {
            PromptPremiumBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                modePicker
                orbSection
                typeInsteadButton
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

            case .settings:
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(firstName),")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("What do you want to make today?")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button { activeSheet = .settings } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(10)
                    .background(.white.opacity(0.1), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 10) {
            modePill(label: "AI Mode", mode: .ai)
            modePill(label: "Human Mode", mode: .human)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func modePill(label: String, mode: PromptMode) -> some View {
        let isSelected = generateViewModel.selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                generateViewModel.selectedMode = mode
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background {
                    Capsule()
                        .fill(isSelected
                              ? PromptTheme.mutedViolet.opacity(0.6)
                              : Color.white.opacity(0.07))
                        .overlay(
                            Capsule()
                                .stroke(isSelected
                                        ? PromptTheme.softLilac.opacity(0.5)
                                        : Color.white.opacity(0.1),
                                        lineWidth: 1)
                        )
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Orb + Transcript + Result

    private var orbSection: some View {
        GeometryReader { proxy in
            let orbSize   = min(proxy.size.width * 0.72, 320)
            let smallOrb  = min(proxy.size.width * 0.52, 220)

            VStack(spacing: 0) {
                if hasResult {
                    OrbView(engine: orbEngine, onTranscript: generateFromText)
                        .frame(width: smallOrb, height: smallOrb)
                        .padding(.top, 8)

                    Text(primaryTranscriptText)
                        .font(PromptTheme.Typography.rounded(15, .regular))
                        .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PromptTheme.Spacing.l)
                        .padding(.top, PromptTheme.Spacing.s)

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

                } else {
                    Spacer()

                    OrbView(engine: orbEngine, onTranscript: generateFromText)
                        .frame(width: orbSize, height: orbSize)

                    Text(primaryTranscriptText)
                        .font(PromptTheme.Typography.rounded(16, .regular))
                        .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PromptTheme.Spacing.l)
                        .padding(.top, PromptTheme.Spacing.m)

                    Spacer()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    // MARK: - Type Instead

    private var typeInsteadButton: some View {
        Button { activeSheet = .typePrompt } label: {
            Text("Type instead")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
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
        let full = env.authManager.currentUser?.name ?? "there"
        return full.components(separatedBy: " ").first ?? full
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
