import SwiftUI

struct HomeView: View {
    private enum ActiveSheet: Identifiable {
        case history
        case typePrompt
        case settings

        var id: String {
            switch self {
            case .history:
                return "history"
            case .typePrompt:
                return "typePrompt"
            case .settings:
                return "settings"
            }
        }
    }

    @ObservedObject private var appEnvironment: AppEnvironment
    @StateObject private var orbEngine = OrbEngine.makeDefault()
    @StateObject private var generateViewModel: GenerateViewModel

    @State private var activeSheet: ActiveSheet?
    @State private var showCopiedToast = false

    init(appEnvironment: AppEnvironment) {
        self._appEnvironment = ObservedObject(wrappedValue: appEnvironment)
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
        GeometryReader { proxy in
            let compactHeight = proxy.size.height < 760
            let narrowWidth = proxy.size.width < 380
            let headerToOrb: CGFloat = compactHeight ? 20 : 28
            let orbHeight = min(360, max(278, proxy.size.height * (compactHeight ? 0.35 : 0.40)))
            let orbToTranscript: CGFloat = compactHeight ? 20 : 28
            let transcriptToResult: CGFloat = compactHeight ? 22 : 30
            let bottomProtectedInset = max(proxy.safeAreaInsets.bottom + 74, 98)

            ZStack {
                PromptTheme.backgroundGradient
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prompt28")
                                .font(.system(size: compactHeight ? 31 : 35, weight: .semibold, design: .rounded))
                                .foregroundStyle(PromptTheme.paleLilacWhite)

                            Text(greetingLine)
                                .font(.system(size: compactHeight ? 16 : 17, weight: .medium, design: .rounded))
                                .foregroundStyle(PromptTheme.softLilac.opacity(0.9))
                                .lineLimit(1)

                            if let subtitle = greetingSubtitle {
                                Text(subtitle)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(PromptTheme.softLilac.opacity(0.72))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: compactHeight ? 14 : 16)

                        if narrowWidth {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Text("Home")
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundStyle(PromptTheme.paleLilacWhite)

                                    Spacer(minLength: 8)

                                    topActionIconButton(systemImage: "gearshape.fill") {
                                        activeSheet = .settings
                                    }
                                }

                                HStack(spacing: 10) {
                                    topActionButton(title: "Type", systemImage: "keyboard") {
                                        activeSheet = .typePrompt
                                    }

                                    topActionButton(title: "History", systemImage: "clock.arrow.circlepath") {
                                        activeSheet = .history
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            HStack(spacing: 10) {
                                Text("Home")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PromptTheme.paleLilacWhite)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.95)
                                    .layoutPriority(1)

                                Spacer(minLength: 8)

                                topActionIconButton(systemImage: "gearshape.fill") {
                                    activeSheet = .settings
                                }

                                topActionButton(title: "Type", systemImage: "keyboard") {
                                    activeSheet = .typePrompt
                                }

                                topActionButton(title: "History", systemImage: "clock.arrow.circlepath") {
                                    activeSheet = .history
                                }
                            }
                        }

                        Spacer(minLength: headerToOrb)

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
                        .frame(height: orbHeight)

                        Spacer(minLength: orbToTranscript)

                        statusTranscriptCard

                        Spacer(minLength: transcriptToResult)

                        ResultView(viewModel: generateViewModel)

                        if let errorMessage = generateViewModel.errorMessage {
                            Spacer(minLength: 12)
                            errorBanner(text: errorMessage)
                        }

                        Color.clear
                            .frame(height: bottomProtectedInset)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, compactHeight ? 16 : 22)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .history:
                HistoryView { item in
                    generateViewModel.restoreFromHistory(item)
                    orbEngine.markSuccess()
                    activeSheet = nil
                }
                .environmentObject(appEnvironment)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
            case .settings:
                NavigationStack {
                    SettingsView()
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

    private func topActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PromptTheme.glassFill, in: Capsule())
                .overlay(
                    Capsule()
                    .stroke(PromptTheme.glassStroke, lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
        }
            .foregroundStyle(PromptTheme.softLilac)
        .buttonStyle(.plain)
    }

    private func topActionIconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PromptTheme.glassFill, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(PromptTheme.glassStroke, lineWidth: 1)
                )
        }
        .foregroundStyle(PromptTheme.softLilac)
        .buttonStyle(.plain)
    }

    private var statusTranscriptCard: some View {
        let status = homeStatusText
        let transcript = activeTranscriptText

        return VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.7))

            Text(status)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(statusTint)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Transcript")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.7))

            Text(transcript)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.94))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(2)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PromptTheme.glassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PromptTheme.glassStroke, lineWidth: 1)
                )
        )
    }

    private var greetingLine: String {
        let rawName = appEnvironment.authManager.currentUser?.name ?? ""
        let cleaned = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = cleaned.split(separator: " ").first, !first.isEmpty {
            return "Welcome back, \(first)"
        }

        return "What do you want to make today?"
    }

    private var greetingSubtitle: String? {
        if generateViewModel.latestPromptText.isEmpty {
            return "Speak naturally and Prompt28 will craft it professionally."
        }

        return "Refine, favorite, or share your latest result."
    }

    private var homeStatusText: String {
        if let error = generateViewModel.errorMessage,
           !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if error.localizedCaseInsensitiveContains("sign in") || error.localizedCaseInsensitiveContains("unauthorized") {
                return "Auth required"
            }
            return "Error"
        }

        if generateViewModel.isGenerating || orbEngine.state == .generating || orbEngine.state == .transcribing {
            return "Processing"
        }

        if orbEngine.isRecording || orbEngine.state == .listening {
            return "Listening"
        }

        switch orbEngine.state {
        case .failure(let message):
            return message.localizedCaseInsensitiveContains("no speech") ? "No speech detected" : "Error"
        case .success:
            return "Ready"
        default:
            return "Tap to speak"
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

    private var statusTint: Color {
        let status = homeStatusText
        if status == "Error" || status == "No speech detected" || status == "Auth required" {
            return .red.opacity(0.9)
        }
        if status == "Listening" {
            return PromptTheme.softLilac
        }
        if status == "Processing" {
            return PromptTheme.mutedViolet
        }
        return PromptTheme.paleLilacWhite
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
