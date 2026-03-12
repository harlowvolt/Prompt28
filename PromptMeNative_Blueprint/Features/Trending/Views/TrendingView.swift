import SwiftUI

struct TrendingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.appRouter) private var appRouter
    @State private var viewModel = TrendingViewModel()
    @State private var searchQuery = ""
    @State private var showCopiedToast = false
    @State private var expandedItemIDs: Set<String> = []

    private var router: AppRouter {
        appRouter ?? env.router
    }

    var body: some View {
        NavigationStack(path: Binding(
            get: { router.path },
            set: { router.path = $0 }
        )) {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    PromptPremiumBackground()
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Trending")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(PromptTheme.paleLilacWhite)
                                .padding(.top, 8)

                            Text("Copy-paste prompts people actually use")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.68))
                                .padding(.top, 6)

                            searchBar
                                .padding(.top, 10)

                            content

                            Color.clear.frame(height: AppHeights.tabBarClearance)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .trendingDetail(let id):
                    if let item = viewModel.promptItem(id: id) {
                        PromptDetailView(item: item)
                    } else {
                        ContentUnavailableView("Prompt not available", systemImage: "exclamationmark.triangle")
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
            .promptClearNavigationSurfaces()
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PromptTheme.glassFill)
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        )
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TrendingCategory.allCases, id: \.self) { category in
                    categoryChip(category)
                }
            }
            .padding(.vertical, 12)
        }
        .padding(.bottom, 18)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.catalog == nil {
            loadingState

        } else if let message = viewModel.errorMessage, viewModel.catalog == nil {
            errorState(message: message)

        } else {
            let items = filteredItems(viewModel.filteredPrompts)

            VStack(spacing: AppSpacing.sectionTight) {
                categoryPicker

                // Section header
                HStack(spacing: 6) {
                    Text(viewModel.selectedCategory.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))

                    Text("·")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.35))

                    Text("\(items.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))

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
                    LazyVStack(spacing: 20) {
                        ForEach(items) { item in
                            trendingCard(item)
                        }
                    }
                }
            }
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
                    .foregroundStyle(.white.opacity(0.74))
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
                        .foregroundStyle(Color(hex: "#8A97C3"))
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
                Button {
                    router.push(.trendingDetail(id: item.id))
                } label: {
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
                            .fill(PromptTheme.glassFill)
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
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
                    .frame(width: 118, height: 44)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#586389"), Color(hex: "#3D4665")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.5))
                            .shadow(color: Color(hex: "#52618A").opacity(0.24), radius: 12, y: 5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PromptTheme.glassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Filter Helper

    private func filteredItems(_ items: [PromptItem]) -> [PromptItem] {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return items
        }
        let q = searchQuery.lowercased()
        return items.filter {
            $0.title.lowercased().contains(q) || $0.prompt.lowercased().contains(q)
        }
    }

    private func categoryChip(_ category: TrendingCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category

        return Button {
            viewModel.selectCategory(category)
        } label: {
            Text(category.rawValue)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : PromptTheme.softLilac.opacity(0.65))
                .padding(.horizontal, 20)
                .frame(height: 46)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#5A638A").opacity(0.90), Color(hex: "#3F4766").opacity(0.88)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.8))
                            .shadow(color: Color(hex: "#5E6E9B").opacity(0.20), radius: 10)
                    } else {
                        Capsule()
                            .fill(PromptTheme.glassFill)
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    }
                }
        }
        .buttonStyle(.plain)
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
