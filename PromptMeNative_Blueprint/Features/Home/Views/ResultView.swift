import SwiftUI

struct ResultView: View {
    @ObservedObject var viewModel: GenerateViewModel
    @State private var copied = false
    @State private var isPreparingShare = false
    @State private var isShareSheetPresented = false
    @State private var shareItems: [Any] = []
    @State private var shareError: String?

    var body: some View {
        Group {
            if viewModel.isGenerating {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(PromptTheme.softLilac)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Generating Prompt")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                        Text("Sending your transcript to Prompt28...")
                            .font(.footnote)
                            .foregroundStyle(PromptTheme.softLilac.opacity(0.76))
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(PromptTheme.glassFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PromptTheme.glassStroke, lineWidth: 1)
                        )
                )
            } else if let result = viewModel.latestResult {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Generated Prompt")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                        Spacer()
                        Text(viewModel.selectedMode == .ai ? "AI" : "Human")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(PromptTheme.glassFill, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(PromptTheme.glassStroke, lineWidth: 1)
                            )
                            .foregroundStyle(PromptTheme.softLilac)
                    }

                    Text(result.professional)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.96))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    if !result.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider().overlay(PromptTheme.softLilac.opacity(0.22))
                        Text("Template")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PromptTheme.softLilac.opacity(0.78))
                        Text(result.template)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(PromptTheme.softLilac.opacity(0.84))
                            .textSelection(.enabled)
                    }

                    Divider().overlay(PromptTheme.softLilac.opacity(0.22))

                    HStack(spacing: 10) {
                        Button(copied ? "Copied" : "Copy") {
                            UIPasteboard.general.string = result.professional
                            copied = true
                            NotificationCenter.default.post(name: .prompt28DidCopyPrompt, object: nil)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                copied = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PromptTheme.mutedViolet)

                        Button {
                            Task { await prepareAndShareCard(for: result) }
                        } label: {
                            if isPreparingShare {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Preparing...")
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(PromptTheme.softLilac.opacity(0.86))
                        .disabled(isPreparingShare)

                        Button {
                            viewModel.toggleFavoriteForLatest()
                        } label: {
                            Label(
                                viewModel.isLatestFavorite ? "Favorited" : "Favorite",
                                systemImage: viewModel.isLatestFavorite ? "star.fill" : "star"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(viewModel.isLatestFavorite ? PromptTheme.softLilac : PromptTheme.softLilac.opacity(0.86))
                    }

                    TextField("Refine request", text: $viewModel.refinementText)
                        .textFieldStyle(.roundedBorder)

                    Button("Refine") {
                        Task { await viewModel.refine() }
                    }
                    .buttonStyle(.bordered)
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
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "text.quote")
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.78))
                    Text("Generated prompt will appear here")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.82))
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PromptTheme.glassFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PromptTheme.glassStroke, lineWidth: 1)
                        )
                )
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(items: shareItems)
        }
        .alert("Unable to Share Card", isPresented: shareErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareError ?? "Please try again.")
        }
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareError != nil },
            set: { shouldShow in
                if !shouldShow {
                    shareError = nil
                }
            }
        )
    }

    @MainActor
    private func prepareAndShareCard(for result: GenerateResponse) async {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        do {
            let url = try renderShareCardImageURL(for: result)
            shareItems = [url]
            isShareSheetPresented = true
        } catch {
            shareError = error.localizedDescription
        }
    }

    @MainActor
    private func renderShareCardImageURL(for result: GenerateResponse) throws -> URL {
        let cardView = PromptShareCardView(
            promptText: result.professional,
            mode: viewModel.selectedMode
        )
        .frame(width: 1080, height: 1350)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 1

        guard let image = renderer.uiImage else {
            throw ShareCardError.renderFailed
        }

        guard let imageData = image.pngData() else {
            throw ShareCardError.encodingFailed
        }

        let filename = "prompt28-share-\(UUID().uuidString).png"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try imageData.write(to: outputURL, options: [.atomic])
        return outputURL
    }
}

private struct PromptShareCardView: View {
    let promptText: String
    let mode: PromptMode

    private var modeTitle: String {
        mode == .ai ? "AI MODE" : "HUMAN MODE"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "05040A"),
                    Color(hex: "12091E"),
                    Color(hex: "1D1330")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    Text("PROMPT28")
                        .font(.system(size: 42, weight: .semibold, design: .serif))
                        .foregroundStyle(PromptTheme.paleLilacWhite)

                    Spacer()

                    Text(modeTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(PromptTheme.glassFill, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(PromptTheme.glassStroke, lineWidth: 2)
                        )
                }

                Text("Generated Prompt")
                    .font(.system(size: 44, weight: .medium, design: .serif))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.9))

                ScrollView {
                    Text(promptText)
                        .font(.system(size: 40, weight: .regular, design: .serif))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .padding(34)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                        )
                )

                HStack {
                    Spacer()
                    Text("Made with PROMPT²⁸")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.9))
                }
            }
            .padding(56)
        }
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum ShareCardError: LocalizedError {
    case renderFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "The share card could not be rendered."
        case .encodingFailed:
            return "The share card image could not be encoded."
        }
    }
}
