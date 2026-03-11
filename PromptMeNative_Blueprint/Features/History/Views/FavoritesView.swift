import SwiftUI
import UIKit

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var env
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            PremiumTabScreen(title: "Favorites") {
                searchField

                if viewModel.favoriteItems.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: PromptTheme.Spacing.s) {
                        ForEach(viewModel.favoriteItems) { item in
                            favoriteCard(item)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    copiedToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
                }
            }
        }
        .onAppear {
            viewModel.bind(historyStore: env.historyStore)
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        AppSearchField(placeholder: "Search favorites", text: $viewModel.query)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PromptTheme.Spacing.xs) {
            Image(systemName: "star")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.6))

            Text("No Favorites Yet")
                .font(PromptTheme.Typography.rounded(18, .semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Text("Favorite generated prompts to find them quickly.")
                .font(PromptTheme.Typography.rounded(14, .medium))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.60))
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.cardInset)
        .appGlassCard()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260, alignment: .center)
    }

    // MARK: - Favorite Card

    private func favoriteCard(_ item: PromptHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: mode badge + date
            HStack(alignment: .center) {
                modeBadge(item.mode)
                Spacer()
                Text(item.createdAt, style: .date)
                    .font(PromptTheme.Typography.rounded(11, .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.45))
            }
            .padding(.bottom, 8)

            // Title + preview
            VStack(alignment: .leading, spacing: 5) {
                Text(item.customName ?? item.input)
                    .font(PromptTheme.Typography.rounded(16, .semibold))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.professional)
                    .font(PromptTheme.Typography.rounded(13, .regular))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.72))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
                .padding(.vertical, 10)

            // Action row
            HStack(spacing: 8) {
                favoriteActionButton(icon: "doc.on.doc.fill", label: "Copy", color: PromptTheme.softLilac) {
                    UIPasteboard.general.string = item.professional
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showCopiedToast = false
                    }
                }

                Spacer()

                favoriteActionButton(icon: "star.slash.fill", label: "Remove", color: Color(red: 1.0, green: 0.38, blue: 0.44)) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleFavorite(item)
                    }
                }
            }
        }
        .padding(AppSpacing.cardInset)
        .appGlassCard()
    }

    // MARK: - Shared Helpers

    private func favoriteActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(color.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func modeBadge(_ mode: PromptMode) -> some View {
        Text(mode == .ai ? "AI" : "HUMAN")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(
                    mode == .ai
                        ? LinearGradient(
                            colors: [PromptTheme.mutedViolet, Color(red: 0.29, green: 0.21, blue: 0.50)],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                        : LinearGradient(
                            colors: [Color(red: 0.18, green: 0.55, blue: 0.88), Color(red: 0.00, green: 0.38, blue: 0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                )
            )
    }

    private var copiedToast: some View {
        Text("Copied to clipboard")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(PromptTheme.paleLilacWhite)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(PromptTheme.glassFill)
                    .overlay(Capsule().stroke(PromptTheme.glassStroke, lineWidth: 1))
            )
            .padding(.bottom, 18)
    }
}
