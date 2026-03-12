import SwiftUI
import UIKit

struct FavoritesView: View {
    @Environment(\.historyStore) private var historyStore
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = HistoryViewModel()
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    PromptPremiumBackground()
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            headerRow
                                .padding(.top, 8)

                            controlsRow
                                .padding(.top, 10)

                            if viewModel.favoriteItems.isEmpty {
                                emptyState
                                    .padding(.top, 42)
                            } else {
                                LazyVStack(spacing: 14) {
                                    ForEach(viewModel.favoriteItems) { item in
                                        favoriteCard(item)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: viewModel.favoriteItems.map(\.id))
                                .padding(.top, 14)
                            }

                            Color.clear
                                .frame(height: AppHeights.tabBarClearance)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .promptClearNavigationSurfaces()
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    copiedToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
                }
            }
        }
        .onAppear {
            if let historyStore {
                viewModel.bind(historyStore: historyStore)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.7))
                    )
            }
            .buttonStyle(.plain)

            Text("Favorites")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Spacer()
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.55))

                TextField("Search favorites...", text: $viewModel.query)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(PromptTheme.glassFill)
                    .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            )

            ShareLink(item: viewModel.favoriteItems.map { "[\($0.mode == .ai ? "AI" : "Human")] \($0.customName ?? $0.input)\n\($0.professional)" }.joined(separator: "\n\n---\n\n")) {
                Text("Export")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.84))
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(
                        Capsule()
                            .fill(PromptTheme.glassFill)
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.query = ""
            } label: {
                Text("Clear")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.78))
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(
                        Capsule()
                            .fill(PromptTheme.glassFill)
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PromptTheme.Spacing.xs) {
            Image(systemName: "star")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.72))

            Text("No Favorites Yet")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Text("Favorite generated prompts to find them quickly.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PromptTheme.glassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.28), radius: 16, y: 10)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220, alignment: .top)
        .padding(.horizontal, 4)
    }

    // MARK: - Favorite Card

    private func favoriteCard(_ item: PromptHistoryItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(item.customName ?? item.input)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            modeBadge(item.mode)

            Button {
                viewModel.toggleFavorite(id: item.id)
            } label: {
                Text("Remove")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.80))
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
                )
                .overlay(
                    RadialGradient(
                        colors: [Color.white.opacity(0.10), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 220
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
        )
    }

    // MARK: - Shared Helpers

    private func modeBadge(_ mode: PromptMode) -> some View {
        Text(mode == .ai ? "AI" : "HUMAN")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(mode == .ai ? Color(red: 0.70, green: 0.53, blue: 1.0) : .white.opacity(0.85))
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule().stroke(
                    mode == .ai ? Color(red: 0.18, green: 0.63, blue: 0.90).opacity(0.9) : Color.white.opacity(0.35),
                    lineWidth: 1.2
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
