import SwiftUI

/// OrionMainContainer - Root container view for the Orion Orb app
/// 
/// This is the main entry point view that wraps the entire app structure.
/// It handles the state machine, environment injection, and global UI elements.
@MainActor
struct OrionMainContainer: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.errorState) private var errorState
    @Environment(\.appRouter) private var appRouter
    @AppStorage("hasAcceptedPrivacy") private var hasAcceptedPrivacy = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var didBootstrap = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init() {
        // Configure tab bar appearance
        configureTabBar()
    }
    
    var body: some View {
        ZStack {
            // Global background
            PromptPremiumBackground()
                .ignoresSafeArea()
            
            // Content based on app state
            content
        }
        .task {
            await bootstrap()
        }
        .alert(item: errorBinding) { presented in
            Alert(
                title: Text(presented.title),
                message: Text(presented.message),
                dismissButton: .default(Text("OK")) {
                    errorState?.clear()
                }
            )
        }
    }
    
    // MARK: - Content State Machine
    
    @ViewBuilder
    private var content: some View {
        if !hasAcceptedPrivacy {
            privacyView
        } else if !didBootstrap || env.authManager.isBootstrapping == true {
            launchView
        } else if env.authManager.isAuthenticated == true {
            authenticatedContent
        } else {
            AuthFlowView()
        }
    }
    
    @ViewBuilder
    private var authenticatedContent: some View {
        if !hasSeenOnboarding {
            onboardingView
        } else if horizontalSizeClass == .regular {
            iPadSidebar
        } else {
            iPhoneTabs
        }
    }
    
    // MARK: - Subviews
    
    private var launchView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(PromptTheme.softLilac)
            Text("Loading Orion Orb")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.9))
        }
    }
    
    private var privacyView: some View {
        PrivacyConsentView {
            withAnimation(.easeInOut(duration: 0.35)) {
                hasAcceptedPrivacy = true
            }
        }
    }
    
    private var onboardingView: some View {
        OnboardingView {
            withAnimation(.easeInOut(duration: 0.35)) {
                hasSeenOnboarding = true
            }
        }
    }
    
    // MARK: - iPad Sidebar
    
    private var iPadSidebar: some View {
        NavigationSplitView {
            List(selection: tabBinding) {
                Label("Home", systemImage: "house.fill")
                    .tag(MainTab.home)
                Label("Favorites", systemImage: "star.fill")
                    .tag(MainTab.favorites)
                Label("History", systemImage: "clock.arrow.circlepath")
                    .tag(MainTab.history)
                Label("Trending", systemImage: "flame.fill")
                    .tag(MainTab.trending)
            }
            .navigationTitle("ORION ORB")
            .listStyle(.sidebar)
        } detail: {
            tabContent
        }
        .promptClearNavigationSurfaces()
    }
    
    // MARK: - iPhone Tabs
    
    private var iPhoneTabs: some View {
        TabView(selection: tabBinding) {
            homeTab
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(MainTab.home)
            
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "star.fill") }
                .tag(MainTab.favorites)
            
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(MainTab.history)
            
            TrendingView()
                .tabItem { Label("Trending", systemImage: "flame.fill") }
                .tag(MainTab.trending)
        }
        .scrollContentBackground(.hidden)
        .toolbarBackground(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(TabBarRaiser(extraInset: 4))
        .promptClearNavigationSurfaces()
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var tabContent: some View {
        switch appRouter?.selectedTab ?? .home {
        case .home:
            homeTab
        case .favorites:
            FavoritesView()
        case .history:
            HistoryView()
        case .trending:
            TrendingView()
        case .admin:
            homeTab // Admin not available on iPad
        }
    }
    
    private var homeTab: some View {
        Group {
            HomeView(
                authManager: env.authManager,
                router: env.router,
                apiClient: env.apiClient,
                preferencesStore: env.preferencesStore,
                historyStore: env.historyStore,
                usageTracker: env.usageTracker,
                orbEngineFactory: env.orbEngineFactory
            )
        }
    }
    
    // MARK: - Bindings
    
    private var tabBinding: Binding<MainTab?> {
        Binding(
            get: { appRouter?.selectedTab },
            set: { tab in
                guard let tab = tab else { return }
                appRouter?.switchTab(tab)
            }
        )
    }
    
    private var errorBinding: Binding<ErrorState.PresentedError?> {
        Binding(
            get: { errorState?.presented },
            set: { _ in errorState?.clear() }
        )
    }
    
    // MARK: - Bootstrap
    
    private func bootstrap() async {
        guard !didBootstrap else { return }
        await env.authManager.bootstrap()
        didBootstrap = true
    }
    
    // MARK: - Tab Bar Configuration
    
    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = PromptTheme.tabBackground
        appearance.shadowColor = UIColor.clear
        
        appearance.stackedLayoutAppearance.selected.iconColor = PromptTheme.tabSelected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: PromptTheme.tabSelected,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = PromptTheme.tabUnselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: PromptTheme.tabUnselected,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().tintColor = PromptTheme.tabSelected
        UITabBar.appearance().unselectedItemTintColor = PromptTheme.tabUnselected
    }
}

// MARK: - TabBarRaiser

// Raises the native tab bar off the bottom edge by adding extra bottom safe area
private struct TabBarRaiser: UIViewRepresentable {
    let extraInset: CGFloat
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let vc = uiView.parentViewController else { return }
            if vc.additionalSafeAreaInsets.bottom != extraInset {
                vc.additionalSafeAreaInsets.bottom = extraInset
            }

            guard let tabBar = vc.tabBarController?.tabBar else { return }

            // Container polish: rounded floating material with subtle edge and deep shadow.
            tabBar.layer.cornerRadius = 28
            tabBar.layer.cornerCurve = .continuous
            tabBar.layer.masksToBounds = false
            tabBar.layer.borderWidth = 0.5
            tabBar.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
            tabBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.40).cgColor
            tabBar.layer.shadowOpacity = 1
            tabBar.layer.shadowRadius = 16
            tabBar.layer.shadowOffset = CGSize(width: 0, height: 10)

            // Keep symbols visually consistent and closer to the requested 20pt sizing.
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            tabBar.items?.forEach { item in
                if let image = item.image?.withRenderingMode(.alwaysTemplate) {
                    item.image = image.applyingSymbolConfiguration(symbolConfig)
                }
                if let selectedImage = item.selectedImage?.withRenderingMode(.alwaysTemplate) {
                    item.selectedImage = selectedImage.applyingSymbolConfiguration(symbolConfig)
                }
            }
        }
    }
}

private extension UIView {
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController {
                return vc
            }
            responder = r.next
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    OrionMainContainer()
        .environment(AppEnvironment())
}
