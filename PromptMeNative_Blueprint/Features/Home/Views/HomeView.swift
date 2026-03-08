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
            let headerToOrb: CGFloat = compactHeight ? 12 : 18
            let orbHeight = min(390, max(300, proxy.size.height * (compactHeight ? 0.40 : 0.44)))
            let orbToTranscript: CGFloat = compactHeight ? 18 : 24
            let transcriptToResult: CGFloat = compactHeight ? 20 : 26
            let bottomBreathing = max(proxy.safeAreaInsets.bottom + 110, 132)

            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.04, green: 0.08, blue: 0.11), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Prompt28")
                                .font(.system(size: compactHeight ? 30 : 34, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .layoutPriority(1)

                            Spacer()

                            Button {
                                activeSheet = .typePrompt
                            } label: {
                                Label("Type", systemImage: "keyboard")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.1), in: Capsule())
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(.white)
                            .buttonStyle(.plain)

                            Button {
                                activeSheet = .history
                            } label: {
                                Label("History", systemImage: "clock.arrow.circlepath")
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

                        if !orbEngine.finalTranscript.isEmpty {
                            transcriptCard(text: orbEngine.finalTranscript)
                        }

                        Spacer(minLength: transcriptToResult)

                        ResultView(viewModel: generateViewModel)

                        if let errorMessage = generateViewModel.errorMessage {
                            Spacer(minLength: 12)
                            errorBanner(text: errorMessage)
                        }

                        Spacer(minLength: bottomBreathing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, compactHeight ? 18 : 24)
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

    private func transcriptCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text(text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
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
