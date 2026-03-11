import SwiftUI

struct TrendingView: View {
    @Environment(AppEnvironment.self) private var env
    @StateObject private var viewModel = TrendingViewModel()
    @State private var searchQuery = ""
    @State private var showCopiedToast = false
    @State private var expandedItemIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    PromptPremiumBackground()
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Trending")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(PromptTheme.paleLilacWhite)
                                .padding(.top, proxy.safeAreaInsets.top + 18)

                            Text("Copy-paste prompts people actually use")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.68))
                                .padding(.top, 8)

                            searchBar
                                .padding(.top, 20)

                            content

                            Color.clear.frame(height: AppHeights.tabBarClearance)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.55))

            TextField("Search trending prompts...", text: $searchQuery)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 0.6))
        )
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.categories) { category in
                    let isSelected = viewModel.selectedCategory?.key == category.key
                    Button {
                        viewModel.selectCategory(category.key)
                    } label: {
                        Text(category.name)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(isSelected ? .white : PromptTheme.softLilac.opacity(0.65))
                            .padding(.horizontal, 20)
                            .frame(height: 46)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(LinearGradient(colors: [Color(red: 0.39, green: 0.31, blue: 0.65), Color(red: 0.24, green: 0.20, blue: 0.42)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.30), lineWidth: 1))
                                        .shadow(color: Color(red: 0.63, green: 0.40, blue: 1.0).opacity(0.34), radius: 10)
                                } else {
                                    Capsule()
                                        .fill(Color.white.opacity(0.07))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.13), lineWidth: 1))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
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

            VStack(spacing: AppSpacing.sectionTight) {
                categoryPicker

                // Section header
                HStack(spacing: 6) {
                    Text(category.name.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.55))

                    Text("·")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.35))

                    Text("\(items.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
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
                    LazyVStack(spacing: AppSpacing.sectionTight) {
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

        return VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(item.title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            // Prompt text (expandable)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.prompt)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
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
                        .font(.system(size: 16, weight: .medium, design: .rounded))
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
            HStack(spacing: 10) {
                NavigationLink(destination: PromptDetailView(item: item)) {
                    HStack(spacing: 6) {
                        Image(systemName: "star")
                            .font(.system(size: 17, weight: .medium))
                        Text("Save")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.76))
                    .frame(width: 110, height: 44)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    UIPasteboard.general.string = item.prompt
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showCopiedToast = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Copy")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 100, height: 44)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.56, green: 0.26, blue: 0.95), Color(red: 0.48, green: 0.20, blue: 0.89)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.22), lineWidth: 1))
                            .shadow(color: Color(red: 0.56, green: 0.26, blue: 0.95).opacity(0.38), radius: 12)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
                )
        )
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
        .padding(AppSpacing.cardInset)
        .appGlassCard()
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
        .padding(AppSpacing.cardInset)
        .appGlassCard()
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
        .padding(AppSpacing.cardInset)
        .appGlassCard()
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
        .padding(AppSpacing.cardInset)
        .appGlassCard()
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
