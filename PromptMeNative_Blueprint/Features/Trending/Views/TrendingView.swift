import SwiftUI

struct TrendingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var viewModel = TrendingViewModel()
    @State private var searchQuery = ""
    @State private var showCopiedToast = false
    @State private var expandedItemIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            PremiumTabScreen(title: "Trending") {
                searchBar

                content
            }
            .task {
                await viewModel.loadIfNeeded(apiClient: env.apiClient)
            }
            .refreshable {
                await viewModel.refresh(apiClient: env.apiClient)
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    copiedToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: PromptTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                .font(.system(size: 14, weight: .medium))

            TextField("Search prompts", text: $searchQuery)
                .font(PromptTheme.Typography.rounded(15, .medium))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(PromptTheme.softLilac)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PromptTheme.Spacing.s)
        .padding(.vertical, PromptTheme.Spacing.xs)
        .background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PromptTheme.Spacing.xs) {
                ForEach(viewModel.categories) { category in
                    let isSelected = viewModel.selectedCategory?.key == category.key
                    Button {
                        viewModel.selectCategory(category.key)
                    } label: {
                        Text(category.name)
                            .font(PromptTheme.Typography.rounded(13, .semibold))
                            .foregroundStyle(isSelected ? .white : PromptTheme.softLilac.opacity(0.65))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(PromptTheme.mutedViolet.opacity(0.55))
                                        .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.30), lineWidth: 1))
                                } else {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, PromptTheme.Spacing.xxs)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.catalog == nil {
            loadingState

        } else if let message = viewModel.errorMessage, viewModel.catalog == nil {
            errorState(message: message)

        } else if let category = viewModel.selectedCategory {
            let items = filteredItems(from: category)

            VStack(spacing: PromptTheme.Spacing.s) {
                categoryPicker

                // Section header
                HStack(spacing: 6) {
                    Text(category.name.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.55))

                    Text("·")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.35))

                    Text("\(items.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.55))

                    Spacer()

                    if searchQuery.isEmpty == false {
                        Text("Filtered")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PromptTheme.mutedViolet.opacity(0.9))
                    }
                }
                .padding(.horizontal, 4)

                if items.isEmpty {
                    noResultsState
                } else {
                    LazyVStack(spacing: PromptTheme.Spacing.s) {
                        ForEach(items) { item in
                            trendingCard(item)
                        }
                    }
                }
            }
        } else {
            emptyState
        }
    }

    // MARK: - Trending Card

    private func trendingCard(_ item: PromptItem) -> some View {
        let isExpanded = expandedItemIDs.contains(item.id)

        return VStack(alignment: .leading, spacing: PromptTheme.Spacing.xs) {
            // Title
            Text(item.title)
                .font(PromptTheme.Typography.rounded(16, .semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            // Prompt text (expandable)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.prompt)
                    .font(PromptTheme.Typography.rounded(13, .regular))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.78))
                    .lineLimit(isExpanded ? nil : 3)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)

                // Expand / Collapse toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedItemIDs.remove(item.id)
                        } else {
                            expandedItemIDs.insert(item.id)
                        }
                    }
                } label: {
                    Text(isExpanded ? "Collapse" : "Expand")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(PromptTheme.mutedViolet.opacity(0.9))
                }
                .buttonStyle(.plain)
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
                .padding(.vertical, 2)

            // Action row
            HStack(spacing: 8) {
                // Copy button
                trendingActionButton(icon: "doc.on.doc.fill", label: "Copy", color: PromptTheme.softLilac) {
                    UIPasteboard.general.string = item.prompt
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showCopiedToast = false
                    }
                }

                Spacer()

                // Full detail link
                NavigationLink(destination: PromptDetailView(item: item)) {
                    HStack(spacing: 4) {
                        Text("View Full")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PromptTheme.Spacing.s)
        .background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Action Button

    private func trendingActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
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
                    .stroke(color.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Helper

    private func filteredItems(from category: PromptCategory) -> [PromptItem] {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return category.items
        }
        let q = searchQuery.lowercased()
        return category.items.filter {
            $0.title.lowercased().contains(q) || $0.prompt.lowercased().contains(q)
        }
    }

    // MARK: - State Views

    private var loadingState: some View {
        VStack(spacing: PromptTheme.Spacing.xs) {
            ProgressView()
                .tint(PromptTheme.softLilac)
            Text("Loading prompts...")
                .font(PromptTheme.Typography.rounded(14, .medium))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.65))
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

    private func errorState(message: String) -> some View {
        VStack(spacing: PromptTheme.Spacing.xs) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.6))

            Text("Could not load trending prompts")
                .font(PromptTheme.Typography.rounded(16, .semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Text(message)
                .font(PromptTheme.Typography.rounded(13, .medium))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.65))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.refresh(apiClient: env.apiClient) }
            }
            .font(PromptTheme.Typography.rounded(15, .semibold))
            .buttonStyle(.borderedProminent)
            .tint(PromptTheme.mutedViolet)
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

    private var emptyState: some View {
        VStack(spacing: PromptTheme.Spacing.xs) {
            Image(systemName: "flame")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.6))
            Text("No Prompts")
                .font(PromptTheme.Typography.rounded(18, .semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite)
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

    private var noResultsState: some View {
        VStack(spacing: PromptTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.5))
            Text("No results for \"\(searchQuery)\"")
                .font(PromptTheme.Typography.rounded(15, .semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.8))
        }
        .padding(PromptTheme.Spacing.l)
        .background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toast

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
