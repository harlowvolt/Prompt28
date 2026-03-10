import SwiftUI
import UIKit

struct HistoryView: View {
    private enum ActiveSheet: Identifiable {
        case rename(PromptHistoryItem)
        case detail(PromptHistoryItem)

        var id: String {
            switch self {
            case .rename(let item): return "rename-\(item.id.uuidString)"
            case .detail(let item): return "detail-\(item.id.uuidString)"
            }
        }
    }

    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var viewModel = HistoryViewModel()
    @State private var activeSheet: ActiveSheet?
    @State private var renameText = ""
    @State private var showClearAllConfirm = false
    @State private var showCopiedToast = false
    let onSelect: ((PromptHistoryItem) -> Void)?

    init(onSelect: ((PromptHistoryItem) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            PremiumTabScreen(title: "History") {
                searchField

                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: PromptTheme.Spacing.s) {
                        ForEach(viewModel.filteredItems) { item in
                            historyCard(item)
                        }
                    }
                }
            }
            .toolbar {
                if !viewModel.items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showClearAllConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PromptTheme.softLilac.opacity(0.75))
                        }
                    }
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $showClearAllConfirm) {
                Button("Clear All", role: .destructive) {
                    viewModel.clearAll()
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .rename(let item):
                    NavigationStack {
                        Form {
                            TextField("Custom title", text: $renameText)
                        }
                        .navigationTitle("Rename")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { activeSheet = nil }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    viewModel.rename(item, to: renameText)
                                    activeSheet = nil
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                    .presentationCornerRadius(32)
                    .presentationBackground(.regularMaterial)

                case .detail(let item):
                    NavigationStack {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                // Mode badge + title
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.customName ?? item.input)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(PromptTheme.paleLilacWhite)
                                    }
                                    Spacer()
                                    modeBadge(item.mode)
                                }

                                Text(item.professional)
                                    .font(PromptTheme.Typography.rounded(15, .regular))
                                    .foregroundStyle(PromptTheme.softLilac.opacity(0.9))
                                    .textSelection(.enabled)
                                    .lineSpacing(4)

                                if !item.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Divider()
                                        .overlay(Color.white.opacity(0.1))
                                    Text("Template")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PromptTheme.softLilac.opacity(0.5))
                                    Text(item.template)
                                        .font(.footnote)
                                        .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                                        .textSelection(.enabled)
                                }

                                HStack(spacing: 10) {
                                    Button {
                                        UIPasteboard.general.string = item.professional
                                        showCopiedToast = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                            showCopiedToast = false
                                        }
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(PromptTheme.mutedViolet)

                                    ShareLink(item: item.professional) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(PromptTheme.softLilac.opacity(0.8))

                                    Button(item.favorite ? "Unfavorite" : "Favorite") {
                                        viewModel.toggleFavorite(item)
                                        if let updated = viewModel.items.first(where: { $0.id == item.id }) {
                                            activeSheet = .detail(updated)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(PromptTheme.softLilac.opacity(0.8))
                                }
                            }
                            .padding(PromptTheme.Spacing.l)
                        }
                        .navigationTitle("Prompt Detail")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { activeSheet = nil }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(32)
                    .presentationBackground(.regularMaterial)
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
        HStack(spacing: PromptTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                .font(.system(size: 14, weight: .medium))

            TextField("Search history", text: $viewModel.query)
                .font(PromptTheme.Typography.rounded(15, .medium))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(PromptTheme.softLilac)
        }
        .padding(.horizontal, PromptTheme.Spacing.s)
        .padding(.vertical, PromptTheme.Spacing.xs)
        .background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PromptTheme.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.6))

            Text("No History Yet")
                .font(PromptTheme.Typography.rounded(18, .semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Text("Your generated prompts will appear here.")
                .font(PromptTheme.Typography.rounded(14, .medium))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.60))
                .multilineTextAlignment(.center)
        }
        .padding(PromptTheme.Spacing.l)
        .background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260, alignment: .center)
    }

    // MARK: - History Card

    private func historyCard(_ item: PromptHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: mode badge
            HStack(alignment: .center) {
                modeBadge(item.mode)
                Spacer()
                Text(item.createdAt, style: .date)
                    .font(PromptTheme.Typography.rounded(11, .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.50))
            }
            .padding(.bottom, 8)

            // Title + preview (tappable)
            Button {
                if let onSelect {
                    onSelect(item)
                } else {
                    activeSheet = .detail(item)
                }
            } label: {
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
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
                .padding(.vertical, 10)

            // Action row
            HStack(spacing: 6) {
                cardActionButton(icon: "doc.on.doc.fill", label: "Copy", color: PromptTheme.softLilac) {
                    UIPasteboard.general.string = item.professional
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showCopiedToast = false
                    }
                }

                cardActionButton(icon: "arrow.up.right.circle.fill", label: "Use", color: PromptTheme.mutedViolet) {
                    if let onSelect {
                        onSelect(item)
                    } else {
                        activeSheet = .detail(item)
                    }
                }

                Spacer()

                // Rename
                Button {
                    activeSheet = .rename(item)
                    renameText = item.customName ?? ""
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.50))
                        .frame(width: 32, height: 28)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                cardActionButton(icon: "trash.fill", label: "Delete", color: Color(red: 1.0, green: 0.38, blue: 0.44)) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.delete(item)
                    }
                }
            }
        }
        .padding(PromptTheme.Spacing.s)
        .background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Shared Helpers

    private func cardActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.22), lineWidth: 1)
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
