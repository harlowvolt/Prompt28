import SwiftUI
import UIKit

struct HistoryView: View {
    private enum ActiveSheet: Identifiable {
        case rename(UUID)
        case detail(UUID)

        var id: String {
            switch self {
            case .rename(let id): return "rename-\(id.uuidString)"
            case .detail(let id): return "detail-\(id.uuidString)"
            }
        }
    }

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = HistoryViewModel()
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
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    PromptPremiumBackground()
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        let tabClearance = max(0, AppHeights.tabBarClearance - proxy.safeAreaInsets.bottom)

                        VStack(alignment: .leading, spacing: 0) {
                            headerRow
                                .padding(.top, proxy.safeAreaInsets.top + 2)
                                .background(Color.red.opacity(0.16))

                            searchField
                                .padding(.top, 14)

                            if viewModel.filteredItems.isEmpty {
                                emptyState
                                    .padding(.top, 42)
                            } else {
                                LazyVStack(spacing: 14) {
                                    ForEach(viewModel.filteredItems) { item in
                                        historyCard(item)
                                    }
                                }
                                .padding(.top, 14)
                            }

                            Color.blue.opacity(0.16)
                                .frame(height: tabClearance)
                        }
                        .padding(.horizontal, 24)
                        .background(Color.green.opacity(0.12))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("Clear all history?", isPresented: $showClearAllConfirm) {
                Button("Clear All", role: .destructive) {
                    viewModel.clearAll()
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .rename(let id):
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
                                    viewModel.rename(id: id, to: renameText)
                                    activeSheet = nil
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                    .presentationCornerRadius(32)
                    .presentationBackground(.regularMaterial)

                case .detail(let id):
                    NavigationStack {
                        Group {
                            if let item = viewModel.item(id: id) {
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
                                                viewModel.toggleFavorite(id: id)
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(PromptTheme.softLilac.opacity(0.8))
                                        }
                                    }
                                    .padding(PromptTheme.Spacing.l)
                                }
                            } else {
                                ContentUnavailableView("Prompt not available", systemImage: "exclamationmark.triangle")
                            }
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

            Text("History • LIVE")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Spacer()
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.55))

                TextField("Search your history...", text: $viewModel.query)
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

            ShareLink(item: viewModel.filteredItems.map { "[\($0.mode == .ai ? "AI" : "Human")] \($0.customName ?? $0.input)\n\($0.professional)" }.joined(separator: "\n\n---\n\n")) {
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
                showClearAllConfirm = true
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
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.72))

            Text("No History Yet")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Text("Your generated prompts will appear here.")
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

    // MARK: - History Card

    private func historyCard(_ item: PromptHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title + mode badge on same row (tappable)
            Button {
                if let onSelect {
                    onSelect(item)
                } else {
                    activeSheet = .detail(item.id)
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.customName ?? item.input)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    modeBadge(item.mode)
                }
                .padding(.bottom, 6)

                Text(item.professional)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.72))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
                .padding(.vertical, 10)

            // Action row
            HStack(spacing: 8) {
                cardActionButton(icon: "doc.on.doc.fill", label: "Copy", color: PromptTheme.softLilac) {
                    UIPasteboard.general.string = item.professional
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showCopiedToast = false
                    }
                }

                cardActionButton(icon: "arrow.up.right.circle.fill", label: "Use", color: PromptTheme.softLilac.opacity(0.88)) {
                    if let onSelect {
                        onSelect(item)
                    } else {
                        activeSheet = .detail(item.id)
                    }
                }

                Spacer()

                Text(item.createdAt, style: .date)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.44))

                cardActionButton(icon: "trash.fill", label: "Delete", color: Color(red: 1.0, green: 0.38, blue: 0.44)) {
                    viewModel.delete(id: item.id)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(PromptTheme.glassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Shared Helpers

    private func cardActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(PromptTheme.glassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func modeBadge(_ mode: PromptMode) -> some View {
        Text(mode == .ai ? "AI" : "HUMAN")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(mode == .ai ? Color(red: 0.70, green: 0.53, blue: 1.0) : .white.opacity(0.82))
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule().stroke(
                    mode == .ai ? Color(red: 0.18, green: 0.63, blue: 0.90).opacity(0.9) : Color.white.opacity(0.35),
                    lineWidth: 1
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
