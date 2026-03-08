import SwiftUI

struct HomeView: View {
    private enum ActiveSheet: Identifiable {
        case history
        case typePrompt

        var id: String {
            switch self {
            case .history:
                return "history"
            case .typePrompt:
                return "typePrompt"
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
                LinearGradient(
                    colors: [Color.black, Color(red: 0.04, green: 0.08, blue: 0.11), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if narrowWidth {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Prompt28")
                                    .font(.system(size: compactHeight ? 30 : 34, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.95)

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
                                Text("Prompt28")
                                    .font(.system(size: compactHeight ? 30 : 34, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.95)
                                    .layoutPriority(1)

                                Spacer(minLength: 8)

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
            }
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
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
                .background(.white.opacity(0.1), in: Capsule())
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var statusTranscriptCard: some View {
        let status = homeStatusText
        let transcript = activeTranscriptText

        return VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text(status)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(statusTint)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Transcript")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text(transcript)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(2)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
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
            return .teal
        }
        if status == "Processing" {
            return .mint
        }
        return .white
    }

    private func errorBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.red.opacity(0.42), lineWidth: 1)
                )
        )
    }
}

extension Notification.Name {
    static let prompt28DidCopyPrompt = Notification.Name("prompt28.didCopyPrompt")
}
