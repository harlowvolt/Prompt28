import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var didBootstrap = false
    @State private var selectedTab: MainTab = .home
    /// List(selection:) requires an optional binding — synced with selectedTab via onChange
    @State private var sidebarSelection: MainTab? = .home
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let tabBarProtectedInset: CGFloat = 84

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        appearance.backgroundColor = PromptTheme.tabBackground
        appearance.shadowColor = PromptTheme.tabShadow
        appearance.selectionIndicatorImage = UIImage.tabSelectionIndicator(
            color: UIColor(red: 0.80, green: 0.82, blue: 0.90, alpha: 0.18),
            stroke: UIColor(red: 0.92, green: 0.94, blue: 1.0, alpha: 0.18)
        )

        appearance.stackedLayoutAppearance.selected.iconColor = PromptTheme.tabSelected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: PromptTheme.tabSelected]
        appearance.stackedLayoutAppearance.normal.iconColor = PromptTheme.tabUnselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: PromptTheme.tabUnselected]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().tintColor = PromptTheme.tabSelected
        UITabBar.appearance().unselectedItemTintColor = PromptTheme.tabUnselected
    }

    var body: some View {
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
            tabContent {
                HomeView(appEnvironment: env)
            }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            tabContent {
                FavoritesView()
            }
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
                .tag(MainTab.favorites)

            tabContent {
                HistoryView()
            }
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(MainTab.history)

            tabContent {
                TrendingView()
            }
                .tabItem {
                    Label("Trending", systemImage: "flame.fill")
                }
                .tag(MainTab.trending)
        }
        .background(TabBarRaiser(extraInset: 20))
    }

    private func tabContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: tabBarProtectedInset)
                    .allowsHitTesting(false)
            }
    }

    private var launchView: some View {
        ZStack {
            PromptPremiumBackground()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(PromptTheme.softLilac)
                Text("Loading Prompt28")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.9))
            }
        }
    }
}

struct PromptPremiumBackground: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                PromptTheme.backgroundBase

                LinearGradient(
                    colors: [
                        PromptTheme.backgroundBase.opacity(1.0),
                        PromptTheme.deepShadow.opacity(0.98),
                        PromptTheme.plum.opacity(0.88),
                        PromptTheme.backgroundBase.opacity(1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                PromptTheme.softLilac.opacity(0.11),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width * 0.34)
                    .position(x: size.width * 0.5, y: size.height * 0.52)
                    .blur(radius: 50)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                PromptTheme.mutedViolet.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width * 0.16)
                    .position(x: size.width * 0.28, y: size.height * 0.46)
                    .blur(radius: 44)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                PromptTheme.mutedViolet.opacity(0.07),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width * 0.14)
                    .position(x: size.width * 0.74, y: size.height * 0.48)
                    .blur(radius: 42)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.18),
                        .clear,
                        Color.black.opacity(0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }
}

enum PromptTheme {
    static let backgroundBase = Color(hex: "#04050C")
    static let deepShadow = Color(hex: "#0A0D1A")
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

    static let tabBackground = UIColor(red: 0.08, green: 0.09, blue: 0.15, alpha: 0.72)
    static let tabShadow = UIColor(red: 0.83, green: 0.87, blue: 0.98, alpha: 0.10)
    static let tabSelected = UIColor(red: 0.92, green: 0.94, blue: 1.0, alpha: 1.0)
    static let tabUnselected = UIColor(red: 0.61, green: 0.63, blue: 0.72, alpha: 1.0)

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
    static func tabSelectionIndicator(color: UIColor, stroke: UIColor) -> UIImage {
        let size = CGSize(width: 108, height: 72)
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 7)
        let radius: CGFloat = 26

        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            color.setFill()
            path.fill()
            stroke.setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }

        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: radius, left: radius, bottom: radius, right: radius),
            resizingMode: .stretch
        )
    }
}
