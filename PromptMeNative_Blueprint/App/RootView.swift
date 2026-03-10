import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var didBootstrap = false
    @State private var selectedTab: MainTab = .home
    private let tabBarProtectedInset: CGFloat = 84

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = PromptTheme.tabBackground
        appearance.shadowColor = PromptTheme.tabShadow

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
                mainTabs
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
            let maxDimension = max(size.width, size.height)

            ZStack {
                PromptTheme.backgroundBase

                LinearGradient(
                    colors: [
                        PromptTheme.deepShadow.opacity(0.96),
                        PromptTheme.plum.opacity(0.84),
                        PromptTheme.backgroundBase.opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        PromptTheme.plum.opacity(0.62),
                        PromptTheme.deepShadow.opacity(0.26),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.22),
                    startRadius: maxDimension * 0.03,
                    endRadius: maxDimension * 0.74
                )

                RadialGradient(
                    colors: [
                        PromptTheme.mutedViolet.opacity(0.25),
                        .clear
                    ],
                    center: UnitPoint(x: 0.84, y: 0.06),
                    startRadius: maxDimension * 0.02,
                    endRadius: maxDimension * 0.42
                )
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }
}

enum PromptTheme {
    static let backgroundBase = Color(hex: "#08070D")
    static let deepShadow = Color(hex: "#151021")
    static let plum = Color(hex: "#24192F")
    static let mutedViolet = Color(hex: "#6F5AA8")
    static let softLilac = Color(hex: "#CFC3F6")
    static let paleLilacWhite = Color(hex: "#EEE9FF")

    static let glassFill = Color(red: 0.17, green: 0.13, blue: 0.22).opacity(0.52)
    static let glassStroke = Color(red: 0.72, green: 0.67, blue: 0.82).opacity(0.26)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundBase, deepShadow, plum, backgroundBase],
        startPoint: .top,
        endPoint: .bottom
    )

    static let orbIdleGlow = Color(hex: "#6F5AA8")
    static let orbActiveGlow = Color(hex: "#8A74BE")
    static let orbProcessingGlow = Color(hex: "#9D8ACB")

    static let tabBackground = UIColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 0.64)
    static let tabShadow = UIColor(red: 0.78, green: 0.74, blue: 0.88, alpha: 0.07)
    static let tabSelected = UIColor(red: 0.81, green: 0.76, blue: 0.96, alpha: 1.0)
    static let tabUnselected = UIColor(red: 0.57, green: 0.52, blue: 0.67, alpha: 1.0)

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
