import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var didBootstrap = false
    @State private var selectedTab: MainTab = .home
    private let tabBarProtectedInset: CGFloat = AppSpacing.bottomContentClearance

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        appearance.backgroundColor = PromptTheme.tabBackground
        appearance.shadowColor = PromptTheme.tabShadow
        appearance.stackedItemPositioning = .centered
        appearance.stackedItemSpacing = 4
        appearance.selectionIndicatorImage = UIImage.tabSelectionIndicator(
            color: UIColor(white: 1.0, alpha: 0.10),   // HTML: rgba(255,255,255,0.10)
            stroke: UIColor(white: 1.0, alpha: 0.16)   // HTML: rgba(255,255,255,0.16)
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

            ZStack {
                // Base: Railway dark charcoal — #13111c → #110f1a → #0b0913
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#13111c"), location: 0.00),
                        .init(color: Color(hex: "#110f1a"), location: 0.40),
                        .init(color: Color(hex: "#0b0913"), location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Subtle purple radial ellipse at ~40% from top (HTML: 50% 40%)
                RadialGradient(
                    stops: [
                        .init(color: Color(red: 120/255, green: 80/255, blue: 220/255).opacity(0.13), location: 0.0),
                        .init(color: Color(red: 80/255,  green: 40/255, blue: 160/255).opacity(0.07), location: 0.4),
                        .init(color: .clear, location: 0.70)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.40),
                    startRadius: 0,
                    endRadius: size.height * 0.55
                )

                // Darken top edge
                LinearGradient(
                    colors: [Color.black.opacity(0.30), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.25)
                )

                // Darken bottom edge
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.45)],
                    startPoint: UnitPoint(x: 0.5, y: 0.40),
                    endPoint: .bottom
                )
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }
}

enum PromptTheme {
    // ── Background palette (Railway dark charcoal) ──────────────────────
    static let backgroundBase = Color(hex: "#0e0c16")   // --bgDeep
    static let deepShadow     = Color(hex: "#110f1a")   // --bgMid
    static let plum           = Color(hex: "#13111c")   // --bgTop
    static let bgBot          = Color(hex: "#0b0913")   // --bgBot

    // ── Accent ──────────────────────────────────────────────────────────
    // Violet used for AI-mode active pill glow (HTML --purple / accentBlue)
    static let mutedViolet    = Color(hex: "#6428dc")   // deep violet
    // Lavender used for tints, borders, highlights (HTML --cyan = b47eff)
    static let softLilac      = Color(hex: "#b47eff")
    // Near-white body text (HTML --text = rgba(230,233,242))
    static let paleLilacWhite = Color(red: 0.90, green: 0.92, blue: 0.95)

    // ── Glass system (HTML --glass / --stroke) ───────────────────────────
    static let glassFill   = Color.white.opacity(0.06)  // --glass
    static let glassStroke = Color.white.opacity(0.10)  // --stroke

    static let backgroundGradient = LinearGradient(
        colors: [plum, deepShadow, bgBot],
        startPoint: .top,
        endPoint: .bottom
    )

    // ── Orb: cool blue-white rim (HTML rgba(190,210,255)) ───────────────
    static let orbIdleGlow       = Color(red: 0.82, green: 0.89, blue: 1.00)
    static let orbActiveGlow     = Color(red: 0.86, green: 0.92, blue: 1.00)
    static let orbProcessingGlow = Color(red: 0.90, green: 0.95, blue: 1.00)

    // ── Tab bar (HTML #bottom-nav rgba(255,255,255,0.08)) ────────────────
    static let tabBackground  = UIColor(white: 1.0, alpha: 0.09)
    static let tabShadow      = UIColor(white: 1.0, alpha: 0.10)
    static let tabSelected    = UIColor(white: 1.0, alpha: 0.95)
    static let tabUnselected  = UIColor(white: 1.0, alpha: 0.45)

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

    /// Reusable glass card view — matches HTML .h-item / .card glass style.
    /// Usage: .background { PromptTheme.glassCard(cornerRadius: PromptTheme.Radius.medium) }
    static func glassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                GeometryReader { geo in
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.10), location: 0.0),
                            .init(color: Color.clear, location: 0.55)
                        ],
                        center: UnitPoint(x: 0.15, y: 0.0),
                        startRadius: 0,
                        endRadius: geo.size.width * 0.6
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
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

private extension UIImage {
    static func tabSelectionIndicator(color: UIColor, stroke: UIColor) -> UIImage {
        let size = CGSize(width: 90, height: AppHeights.floatingTabBar)
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 9)
        let radius: CGFloat = 22

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
