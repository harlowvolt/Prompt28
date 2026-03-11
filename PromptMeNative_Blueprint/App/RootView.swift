import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var didBootstrap = false
    @State private var selectedTab: MainTab = .home
    /// List(selection:) requires an optional binding — synced with selectedTab via onChange
    @State private var sidebarSelection: MainTab? = .home
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.clear
        appearance.shadowColor = UIColor.clear
        appearance.selectionIndicatorImage = UIImage.tabSelectionIndicator(
            color: UIColor(PromptTheme.softLilac).withAlphaComponent(0.20)
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
                if !didBootstrap || env.authManager.isBootstrapping {
                    launchView
                } else if env.authManager.isAuthenticated {
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
            await env.authManager.bootstrap()
            didBootstrap = true
        }
        .onChange(of: env.authManager.token) { _, token in
            if token == nil {
                selectedTab = .home
            }
        }
    }

    // MARK: - iPad Sidebar (NavigationSplitView)

    private var iPadSidebar: some View {
        NavigationSplitView {
            // List requires Binding<SelectionValue?> — use sidebarSelection and sync below
            List(selection: $sidebarSelection) {
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
            // Sync optional sidebar selection → non-optional selectedTab
            .onChange(of: sidebarSelection) { _, tab in
                if let tab { selectedTab = tab }
            }
        } detail: {
            switch selectedTab {
            case .home:
                HomeView(appEnvironment: env)
            case .favorites:
                FavoritesView()
            case .history:
                HistoryView()
            case .trending:
                TrendingView()
            case .admin:
                // Admin is phone-only; redirect to Home on iPad
                HomeView(appEnvironment: env)
            }
        }
    }

    // MARK: - iPhone Tab Bar

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView(appEnvironment: env)
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
        .background(TabBarRaiser(extraInset: 10))
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
                Color(hex: "#090B16")

                LinearGradient(
                    colors: [
                        Color(hex: "#19152B"),
                        Color(hex: "#101430"),
                        Color(hex: "#0A0D1D"),
                        Color(hex: "#090B16")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [
                        Color(hex: "#8B5CFF").opacity(0.08),
                        .clear,
                        Color(hex: "#6D28D9").opacity(0.08),
                        .clear,
                        Color(hex: "#7C3AED").opacity(0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.softLight)

                RadialGradient(
                    colors: [
                        Color(hex: "#8B5CFF").opacity(0.20),
                        Color(hex: "#5B3DF5").opacity(0.10),
                        .clear
                    ],
                    center: .init(x: 0.52, y: 0.30),
                    startRadius: 20,
                    endRadius: size.width * 0.78
                )

                RadialGradient(
                    colors: [
                        Color(hex: "#A855F7").opacity(0.14),
                        Color(hex: "#6D28D9").opacity(0.08),
                        .clear
                    ],
                    center: .init(x: 0.68, y: 0.58),
                    startRadius: 10,
                    endRadius: size.width * 0.62
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
    static let backgroundBase = Color(hex: "#070C17")
    static let deepShadow = Color(hex: "#0C1428")
    static let plum = Color(hex: "#131A2A")
    static let mutedViolet = Color(hex: "#5D628A")
    static let softLilac = Color(hex: "#CFD7FF")
    static let paleLilacWhite = Color(hex: "#F2F5FF")

    static let glassFill = Color(red: 0.10, green: 0.12, blue: 0.21).opacity(0.56)
    static let glassStroke = Color(red: 0.76, green: 0.80, blue: 0.93).opacity(0.24)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundBase, deepShadow, plum, backgroundBase],
        startPoint: .top,
        endPoint: .bottom
    )

    static let orbIdleGlow = Color(hex: "#95A7FF")
    static let orbActiveGlow = Color(hex: "#A9BAFF")
    static let orbProcessingGlow = Color(hex: "#B9C6FF")

    static let tabBackground = UIColor(red: 0.08, green: 0.09, blue: 0.15, alpha: 0.62)
    static let tabShadow = UIColor(red: 0.83, green: 0.87, blue: 0.98, alpha: 0.10)
    static let tabSelected = UIColor.white
    static let tabUnselected = UIColor.white.withAlphaComponent(0.55)

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
        let size = CGSize(width: 108, height: 72)
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
        let radius: CGFloat = 22

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
