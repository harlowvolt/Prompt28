import SwiftUI
import UIKit

struct ResultView: View {
    @ObservedObject var viewModel: GenerateViewModel
    @State private var copied = false
    @State private var shareImage: UIImage?
    @State private var shareURL: URL?

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

                        if let shareURL, let shareImage {
                            ShareLink(
                                item: shareURL,
                                preview: SharePreview("PROMPT²⁸", image: Image(uiImage: shareImage))
                            ) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(PromptTheme.softLilac.opacity(0.86))
                        } else {
                            Label("Preparing Share...", systemImage: "hourglass")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PromptTheme.softLilac.opacity(0.75))
                                .frame(maxWidth: .infinity)
                        }

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
        .onChange(of: viewModel.latestPromptText) { _, newPrompt in
            Task { @MainActor in
                regenerateShareCard(using: newPrompt)
            }
        }
        .onAppear {
            Task { @MainActor in
                regenerateShareCard(using: viewModel.latestPromptText)
            }
        }
        .onDisappear {
            ShareCardFileStore.removeFileIfNeeded(at: shareURL)
            shareURL = nil
            shareImage = nil
        }
    }

    @MainActor
    private func regenerateShareCard(using promptText: String) {
        let cleanedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedPrompt.isEmpty else {
            ShareCardFileStore.removeFileIfNeeded(at: shareURL)
            shareImage = nil
            shareURL = nil
            return
        }

        let image = ShareCardRenderer.render(
            rawInput: viewModel.latestInput,
            generatedPrompt: cleanedPrompt,
            modeName: viewModel.selectedMode == .ai ? "AI Mode" : "Human Mode"
        )

        ShareCardFileStore.removeFileIfNeeded(at: shareURL)

        shareImage = image

        if let image {
            shareURL = ShareCardFileStore.writePNG(image)
        } else {
            shareURL = nil
        }
    }
}
