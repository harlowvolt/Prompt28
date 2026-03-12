import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.authManager) private var scopedAuthManager
    @Environment(\.appRouter) private var appRouter
    @Environment(\.errorState) private var errorState
    @Environment(\.apiClient) private var scopedAPIClient
    @Environment(\.preferencesStore) private var scopedPreferencesStore
    @Environment(\.historyStore) private var scopedHistoryStore
    @Environment(\.usageTracker) private var scopedUsageTracker
    @Environment(\.orbEngineFactory) private var scopedOrbEngineFactory
    @AppStorage("hasAcceptedPrivacy") private var hasAcceptedPrivacy = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var didBootstrap = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = PromptTheme.tabBackground
        appearance.shadowColor = UIColor.clear
        appearance.selectionIndicatorImage = UIImage.tabSelectionIndicator(
            color: UIColor(red: 0.30, green: 0.34, blue: 0.43, alpha: 0.62)
        )

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

    var body: some View {
        // PromptPremiumBackground lives here — outside TabView and NavigationStack —
        // so it fills the FULL screen including under the status bar and home indicator.
        ZStack {
            PromptPremiumBackground()
                .ignoresSafeArea()

            Group {
                if scopedAuthManager == nil || appRouter == nil {
                    launchView
                } else if !hasAcceptedPrivacy {
                    // Privacy consent modal — must be accepted before auth or data collection.
                    // Satisfies App Store Review Guideline 5.1.2(i).
                    PrivacyConsentView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            hasAcceptedPrivacy = true
                        }
                    }
                } else if !didBootstrap || scopedAuthManager?.isBootstrapping == true {
                    launchView
                } else if scopedAuthManager?.isAuthenticated == true {
                    if !hasSeenOnboarding {
                        OnboardingView {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                hasSeenOnboarding = true
                            }
                        }
                    } else {
                        // iPad (.regular) gets a sidebar; iPhone (.compact) keeps the tab bar
                        if horizontalSizeClass == .regular {
                            iPadSidebar
                        } else {
                            mainTabs
                        }
                    }
                } else {
                    AuthFlowView()
                }
            }
        }
        .task {
            guard !didBootstrap else { return }
            guard let authManager = scopedAuthManager else { return }
            await authManager.bootstrap()
            didBootstrap = true
        }
        .onChange(of: scopedAuthManager?.token) { _, token in
            if token == nil {
                appRouter?.switchTab(.home)
                appRouter?.popToRoot()
            }
        }
        .alert(item: Binding(
            get: { errorState?.presented },
            set: { _ in errorState?.clear() }
        )) { presented in
            Alert(
                title: Text(presented.title),
                message: Text(presented.message),
                dismissButton: .default(Text("OK")) {
                    errorState?.clear()
                }
            )
        }
    }

    // MARK: - iPad Sidebar (NavigationSplitView)

    private var iPadSidebar: some View {
        let router = appRouter

        return NavigationSplitView {
            // List requires Binding<SelectionValue?> — use sidebarSelection and sync below
            List(selection: Binding(
                get: { router?.selectedTab as MainTab? },
                set: { tab in
                    guard let tab else { return }
                    router?.switchTab(tab)
                }
            )) {
                Label("Home", systemImage: "house.fill")
                    .tag(MainTab.home as MainTab?)
                Label("Favorites", systemImage: "star.fill")
                    .tag(MainTab.favorites as MainTab?)
                Label("History", systemImage: "clock.arrow.circlepath")
                    .tag(MainTab.history as MainTab?)
                Label("Trending", systemImage: "flame.fill")
                    .tag(MainTab.trending as MainTab?)
            }
            .navigationTitle("PROMPT28")
            .listStyle(.sidebar)
        } detail: {
            switch router?.selectedTab ?? .home {
            case .home:
                homeView
            case .favorites:
                FavoritesView()
            case .history:
                HistoryView()
            case .trending:
                TrendingView()
            case .admin:
                // Admin is phone-only; redirect to Home on iPad
                homeView
            }
        }
        .promptClearNavigationSurfaces()
    }

    // MARK: - iPhone Tab Bar

    private var mainTabs: some View {
        TabView(selection: Binding(
            get: { appRouter?.selectedTab ?? .home },
            set: { tab in
                appRouter?.switchTab(tab)
            }
        )) {
            homeView
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
                .tag(MainTab.favorites)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(MainTab.history)

            TrendingView()
                .tabItem {
                    Label("Trending", systemImage: "flame.fill")
                }
                .tag(MainTab.trending)
        }
        .scrollContentBackground(.hidden)
        .toolbarBackground(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(TabBarRaiser(extraInset: 4))
        .promptClearNavigationSurfaces()
    }

    @ViewBuilder
    private var homeView: some View {
        if let authManager = scopedAuthManager,
           let router = appRouter,
           let apiClient = scopedAPIClient,
           let preferencesStore = scopedPreferencesStore,
           let historyStore = scopedHistoryStore,
           let usageTracker = scopedUsageTracker,
           let orbEngineFactory = scopedOrbEngineFactory {
            HomeView(
                authManager: authManager,
                router: router,
                apiClient: apiClient,
                preferencesStore: preferencesStore,
                historyStore: historyStore,
                usageTracker: usageTracker,
                orbEngineFactory: orbEngineFactory
            )
        } else {
            launchView
        }
    }

    private var launchView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(PromptTheme.softLilac)
            Text("Loading Prompt28")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.9))
        }
    }
}

struct PromptPremiumBackground: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                Color(hex: "#02040F")

                LinearGradient(
                    colors: [
                        Color(hex: "#0D1A40"),
                        Color(hex: "#0A1431"),
                        Color(hex: "#061022"),
                        Color(hex: "#02040F")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color(hex: "#1A2E59").opacity(0.30),
                        Color(hex: "#0D1A40").opacity(0.16),
                        .clear
                    ],
                    center: .init(x: 0.50, y: 0.40),
                    startRadius: 14,
                    endRadius: size.width * 0.72
                )

                RadialGradient(
                    colors: [
                        Color(hex: "#1A2E59").opacity(0.08),
                        Color(hex: "#0D1A40").opacity(0.04),
                        .clear
                    ],
                    center: .init(x: 0.64, y: 0.60),
                    startRadius: 8,
                    endRadius: size.width * 0.50
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.015),
                        .clear,
                        Color.white.opacity(0.01)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.softLight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

enum PromptTheme {
    static let backgroundBase = Color(hex: "#02060D")
    static let deepShadow = Color(hex: "#050A16")
    static let plum = Color(hex: "#07101E")
    static let mutedViolet = Color(hex: "#5D628A")
    static let softLilac = Color(hex: "#CFD7FF")
    static let paleLilacWhite = Color(hex: "#F2F5FF")

    static let glassFill = Color(red: 0.15, green: 0.17, blue: 0.22).opacity(0.72)
    static let glassStroke = Color.white.opacity(0.14)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundBase, deepShadow, plum, backgroundBase],
        startPoint: .top,
        endPoint: .bottom
    )

    static let orbIdleGlow = Color(hex: "#95A7FF")
    static let orbActiveGlow = Color(hex: "#A9BAFF")
    static let orbProcessingGlow = Color(hex: "#B9C6FF")

    static let tabBackground = UIColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 0.9)
    static let tabShadow = UIColor(red: 0.83, green: 0.87, blue: 0.98, alpha: 0.10)
    static let tabSelected = UIColor.white.withAlphaComponent(0.96)
    static let tabUnselected = UIColor.white.withAlphaComponent(0.56)

    enum Typography {
        static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }

    enum Spacing {
        static let xxs: CGFloat = 6
        static let xs: CGFloat = 10
        static let s: CGFloat = 14
        static let m: CGFloat = 18
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    static let premiumMaterial: Material = .ultraThinMaterial
}

extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

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
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

private extension UIImage {
    static func tabSelectionIndicator(color: UIColor) -> UIImage {
        let size = CGSize(width: 96, height: 72)
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 6)
        let radius: CGFloat = 24

        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            color.setFill()
            path.fill()
        }

        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: radius, left: radius, bottom: radius, right: radius),
            resizingMode: .stretch
        )
    }
}
