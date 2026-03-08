import SwiftUI

struct ResultView: View {
    @ObservedObject var viewModel: GenerateViewModel
    @State private var copied = false

    var body: some View {
        Group {
            if let result = viewModel.latestResult {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Generated Prompt")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(viewModel.selectedMode == .ai ? "AI" : "Human")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.12), in: Capsule())
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Text(result.professional)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    if !result.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider().overlay(Color.white.opacity(0.15))
                        Text("Template")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                        Text(result.template)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .textSelection(.enabled)
                    }

                    Divider().overlay(Color.white.opacity(0.15))

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
                        .tint(Color(red: 0.12, green: 0.55, blue: 0.92))

                        ShareLink(item: result.professional) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.8))

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
                        .tint(viewModel.isLatestFavorite ? .yellow : .white.opacity(0.8))
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
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "text.quote")
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Generated prompt will appear here")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }
}
