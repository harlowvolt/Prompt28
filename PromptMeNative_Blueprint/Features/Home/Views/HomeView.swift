import SwiftUI
import UIKit

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
            ZStack {
                PromptPremiumBackground()
                    .ignoresSafeArea()

                VStack(spacing: AppSpacing.section) {
                    headerSection
                        .padding(.top, proxy.safeAreaInsets.top + 6)

                    subtitleLine

                    modeSelector

                    Text(modeDescription)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.6))
                        .multilineTextAlignment(.center)

                    Spacer(minLength: hasResult ? 8 : 24)

                    orbButton(proxy: proxy)

                    if hasResult {
                        transcriptSection
                        resultSection
                    } else {
                        transcriptSection
                    }

                    Spacer(minLength: 0)

                    typeInsteadButton
                        .padding(.bottom, max(12, proxy.safeAreaInsets.bottom + 6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, AppSpacing.screenHorizontal)
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
        HStack {
            Color.clear
                .frame(width: 42, height: 42)

            VStack(spacing: 6) {
                Text(firstName)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                activeSheet = .settings
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
    }

    private var subtitleLine: some View {
        Text("What do you want to make today?")
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .multilineTextAlignment(.center)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: AppSpacing.element) {
            modePill(label: "AI Mode", mode: .ai)
            modePill(label: "Human Mode", mode: .human)
        }
    }

    private var modeDescription: String {
        switch generateViewModel.selectedMode {
        case .ai:    return "Standard AI prompt style"
        case .human: return "Sounds like a real human wrote it"
        }
    }

    private func modePill(label: String, mode: PromptMode) -> some View {
        let selected = generateViewModel.selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                generateViewModel.selectedMode = mode
            }
        } label: {
            Text(label)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppHeights.segmentedControl)
                .background {
                    Capsule()
                        .fill(
                            selected
                            ? LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.55),
                                    Color.purple.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    Capsule()
                        .stroke(
                            selected
                            ? LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.cyan.opacity(0.8),
                                    Color.purple.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.18)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: selected ? 2 : 1
                        )
                }
                .shadow(color: selected ? Color.blue.opacity(0.35) : .clear, radius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Orb + Transcript + Result

    private func orbButton(proxy: GeometryProxy) -> some View {
        let restingOrb = min(proxy.size.width * 0.80, 318)
        let resultOrb = min(proxy.size.width * 0.70, 286)
        let orbSize = hasResult ? resultOrb : restingOrb

        return Button {
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
            Task {
                if orbEngine.isRecording {
                    if let final = await orbEngine.stopListeningAndFinalize() {
                        generateFromText(final)
                    }
                } else {
                    orbEngine.startListening()
                }
            }
        } label: {
            orbSection(proxy: proxy)
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    Image(systemName: orbEngine.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: orbEngine.isRecording ? 44 : 58, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.94))
                        .shadow(color: .white.opacity(0.24), radius: 8)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }

    private func orbSection(proxy: GeometryProxy) -> some View {
        let restingOrb = min(proxy.size.width * 0.76, 300)
        let resultOrb = min(proxy.size.width * 0.70, 286)

        return OrbView()
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

    // HTML #type-btn: pill, rgba(255,255,255,0.07), border rgba(255,255,255,0.14),
    //   text rgba(255,255,255,0.62), shadow 0 12px 28px rgba(0,0,0,0.45)
    private var typeInsteadButton: some View {
        Button { activeSheet = .typePrompt } label: {
            Text("Type instead")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .frame(height: AppHeights.typeButton)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                        .shadow(color: .black.opacity(0.45), radius: 14, y: 12)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
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
        .background { PromptTheme.glassCard(cornerRadius: PromptTheme.Radius.large) }
    }
}

extension Notification.Name {
    static let prompt28DidCopyPrompt = Notification.Name("prompt28.didCopyPrompt")
}
