import SwiftUI
import UIKit

struct ResultView: View {
    @Bindable var viewModel: GenerateViewModel
    @State private var copiedInput = false
    @State private var copiedPrompt = false
    @State private var shareImage: UIImage?
    @State private var shareURL: URL?

    var body: some View {
        Group {
            if viewModel.isGenerating {
                generatingCard
            } else if let result = viewModel.latestResult {
                VStack(alignment: .leading, spacing: PromptTheme.Spacing.s) {
                    yourInputCard
                    expertPromptCard(result: result)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            } else {
                emptyCard
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

    // MARK: - Generating Card

    private var generatingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(PromptTheme.softLilac)
            VStack(alignment: .leading, spacing: 4) {
                Text("Generating Prompt")
                    .font(PromptTheme.Typography.rounded(15, .semibold))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                Text("Sending your transcript to Orion Orb...")
                    .font(PromptTheme.Typography.rounded(13, .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.76))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(PromptTheme.Spacing.s)
        .background { PromptTheme.glassCard(cornerRadius: PromptTheme.Radius.large) }
        .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
    }

    // MARK: - Your Input Card

    private var yourInputCard: some View {
        VStack(alignment: .leading, spacing: PromptTheme.Spacing.xs) {
            HStack {
                Text("Your Input")
                    .font(PromptTheme.Typography.rounded(15, .semibold))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                Spacer()
                Button {
                    UIPasteboard.general.string = viewModel.latestInput
                    copiedInput = true
                    HapticService.impact(.light)
                    viewModel.triggerCopiedToast()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedInput = false }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: copiedInput ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .medium))
                        if copiedInput {
                            Text("Copied")
                                .font(PromptTheme.Typography.rounded(12, .medium))
                        }
                    }
                    .foregroundStyle(copiedInput ? PromptTheme.softLilac : PromptTheme.softLilac.opacity(0.72))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: copiedInput)
            }

            let input = viewModel.latestInput.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(input.isEmpty ? "—" : input)
                .font(PromptTheme.Typography.rounded(14, .regular))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .padding(PromptTheme.Spacing.s)
        .background { PromptTheme.glassCard(cornerRadius: PromptTheme.Radius.large) }
        .shadow(color: .black.opacity(0.30), radius: 10, y: 6)
    }

    // MARK: - Expert Prompt Card

    private func expertPromptCard(result: GenerateResponse) -> some View {
        VStack(alignment: .leading, spacing: PromptTheme.Spacing.s) {
            // Header
            HStack {
                Text("Expert Prompt")
                    .font(PromptTheme.Typography.rounded(18, .semibold))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                Spacer()
                Text(viewModel.selectedMode == .ai ? "AI" : "Human")
                    .font(PromptTheme.Typography.rounded(12, .semibold))
                    .padding(.horizontal, PromptTheme.Spacing.xs)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .foregroundStyle(PromptTheme.softLilac)
            }

            // Generated text
            Text(result.professional)
                .font(PromptTheme.Typography.rounded(16, .regular))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.96))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            // Optional template section
            if !result.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider().overlay(PromptTheme.softLilac.opacity(0.22))
                Text("Template")
                    .font(PromptTheme.Typography.rounded(12, .semibold))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.78))
                Text(result.template)
                    .font(PromptTheme.Typography.rounded(14, .regular))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.84))
                    .textSelection(.enabled)
            }

            Divider().overlay(PromptTheme.softLilac.opacity(0.22))

            // Action buttons
            HStack(spacing: 10) {
                Button(copiedPrompt ? "Copied!" : "Copy") {
                    UIPasteboard.general.string = result.professional
                    copiedPrompt = true
                    HapticService.impact(.light)
                    viewModel.triggerCopiedToast()
                    viewModel.trackCopy()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedPrompt = false }
                }
                .buttonStyle(.borderedProminent)
                .tint(PromptTheme.mutedViolet)

                if let shareURL, let shareImage {
                    ShareLink(
                        item: shareURL,
                        preview: SharePreview("PROMPT²⁸", image: Image(uiImage: shareImage))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(PromptTheme.Typography.rounded(15, .semibold))
                            .padding(.horizontal, PromptTheme.Spacing.s)
                            .padding(.vertical, PromptTheme.Spacing.xs)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(PromptTheme.softLilac.opacity(0.86))
                    .simultaneousGesture(TapGesture().onEnded { viewModel.trackShare() })
                } else {
                    Label("Preparing...", systemImage: "hourglass")
                        .font(PromptTheme.Typography.rounded(15, .semibold))
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

            // Refine row — styled to match the glass design system
            HStack(spacing: 10) {
                TextField("Refine this prompt…", text: $viewModel.refinementText)
                    .font(PromptTheme.Typography.rounded(15, .regular))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PromptTheme.glassFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    )

                Button {
                    Task { await viewModel.refine() }
                } label: {
                    if viewModel.isGenerating {
                        ProgressView()
                            .tint(PromptTheme.softLilac)
                            .frame(width: 58, height: 46)
                    } else {
                        Text("Refine")
                            .font(PromptTheme.Typography.rounded(15, .semibold))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                            .frame(width: 58, height: 46)
                    }
                }
                .background(
                    Capsule()
                        .fill(PromptTheme.mutedViolet.opacity(0.55))
                        .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.28), lineWidth: 0.5))
                )
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating || viewModel.refinementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PromptTheme.Spacing.s)
        .background { PromptTheme.glassCard(cornerRadius: PromptTheme.Radius.large) }
        .shadow(color: .black.opacity(0.50), radius: 20, y: 14)
    }

    // MARK: - Empty Card

    private var emptyCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.quote")
                .foregroundStyle(PromptTheme.softLilac.opacity(0.78))
            Text("Generated prompt will appear here")
                .font(PromptTheme.Typography.rounded(13, .medium))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.82))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(PromptTheme.Spacing.s)
        .background { PromptTheme.glassCard(cornerRadius: PromptTheme.Radius.large) }
    }

    // MARK: - Share Card

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
