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
    @Environment(\.storeManager) private var scopedStoreManager
    @Environment(\.supabase) private var scopedSupabase
    @State private var didBootstrap = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = PromptTheme.tabBackground
        appearance.shadowColor = UIColor.clear
        appearance.selectionIndicatorImage = UIImage.tabSelectionIndicator(
            color: UIColor(red: 0.43, green: 0.31, blue: 0.82, alpha: 0.25)
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
                if scopedAuthManager == nil || appRouter == nil || !didBootstrap || scopedAuthManager?.isBootstrapping == true {
                    // Splash — shown only while services initialise (< 1 second in practice)
                    launchView
                } else if scopedAuthManager?.isAuthenticated == true {
                    // Authenticated → straight to app.
                    // iPad uses sidebar, iPhone uses full-screen home.
                    if horizontalSizeClass == .regular {
                        iPadSidebar
                    } else {
                        mainTabs
                    }
                } else {
                    // Not authenticated → sign-in screen.
                    // Privacy disclosure is in the auth screen footer (T&C + Privacy Policy links).
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
            .navigationTitle("Orbit Orb")
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

    // MARK: - iPhone (no tab bar)

    private var mainTabs: some View {
        homeView
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
                orbEngineFactory: orbEngineFactory,
                storeManager: scopedStoreManager,
                supabase: scopedSupabase
            )
        } else {
            launchView
        }
    }

    private var launchView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(PromptTheme.softLilac)
            Text("Loading Orbit Orb")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.9))
        }
    }
}

/// Full-screen background that exactly mirrors the Orbit Orb logo colour field:
/// deep navy-indigo base with two concentric radial glows in logo purple.
struct PromptPremiumBackground: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                // Base — deepest navy from the logo's outer field
                Color(hex: "#0B0C18")

                // Vertical depth gradient
                LinearGradient(
                    colors: [
                        Color(hex: "#10122A"),
                        Color(hex: "#0D0E20"),
                        Color(hex: "#0B0C18"),
                        Color(hex: "#090A14")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Primary orbital glow — large soft purple radial (logo ring colour)
                RadialGradient(
                    colors: [
                        Color(hex: "#3D2B8A").opacity(0.28),
                        Color(hex: "#251A5C").opacity(0.14),
                        .clear
                    ],
                    center: .init(x: 0.50, y: 0.42),
                    startRadius: 10,
                    endRadius: size.width * 0.75
                )

                // Secondary glow — smaller, offset right; mimics logo's inner burst
                RadialGradient(
                    colors: [
                        Color(hex: "#6C4BFF").opacity(0.10),
                        .clear
                    ],
                    center: .init(x: 0.58, y: 0.52),
                    startRadius: 6,
                    endRadius: size.width * 0.44
                )

                // Subtle top-edge shimmer
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.012),
                        .clear,
                        Color.white.opacity(0.008)
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

// MARK: - Orbit Orb Design System — Single Source of Truth
//
// ALL color usage in the app must reference these tokens.
// Never use inline hex literals; add a new token here instead.
// See agents.md for full documentation.
enum PromptTheme {

    // ── Backgrounds ──────────────────────────────────────────────────────
    /// Deepest background layer — matches the dark field of the logo
    static let backgroundBase    = Color(hex: "#0B0C18")
    /// Mid-depth layer for nested surfaces
    static let deepShadow        = Color(hex: "#0D0E1E")
    /// Darkest plum for layered depth
    static let plum              = Color(hex: "#100C20")
    /// Full-screen panels, sheets, drawers (replaces the old #02060D)
    static let panelBackground   = Color(hex: "#0B0C18")
    /// Dropdown / popover background
    static let dropdownBackground = Color(hex: "#0D0E1C")
    /// Input bar fill (text field row)
    static let inputBarBackground = Color(hex: "#111320")
    /// Logo preview background (used only in #Preview blocks)
    static let previewBackground  = Color(hex: "#0B0C18")

    // ── Accents ───────────────────────────────────────────────────────────
    /// Primary CTA tint — deep logo indigo
    static let mutedViolet       = Color(hex: "#6C4BFF")
    /// Orbital ring accent — the periwinkle blue-purple of the logo rings
    /// Used for active states, glows, borders, badges
    static let orbAccent         = Color(hex: "#8B8FFF")
    /// Lighter ring highlight (used for ring1End, shimmer passes)
    static let orbAccentLight    = Color(hex: "#A78BFA")
    /// Muted ring tone (avatar gradient start, ring2End)
    static let orbAccentMuted    = Color(hex: "#5D628A")
    /// Deep logo tint used for colorMultiply tinting
    static let logoDimTint       = Color(hex: "#2A1A4A")

    // ── Text ─────────────────────────────────────────────────────────────
    /// Secondary text / labels / soft accents (lilac)
    static let softLilac         = Color(hex: "#C4B5FD")
    /// Primary text — near-white with warm tint
    static let paleLilacWhite    = Color(hex: "#EDE9FE")

    // ── Glass surfaces ────────────────────────────────────────────────────
    /// Card and surface fill (use with .ultraThinMaterial overlay)
    static let glassFill         = Color(red: 0.11, green: 0.09, blue: 0.22).opacity(0.75)
    /// Card and surface border stroke
    static let glassStroke       = Color.white.opacity(0.11)

    // ── Orb state glows ───────────────────────────────────────────────────
    static let orbIdleGlow       = Color(hex: "#6C4BFF")
    static let orbActiveGlow     = Color(hex: "#9B7BFF")
    static let orbProcessingGlow = Color(hex: "#C4B5FD")

    // ── Tab bar (UIKit) ───────────────────────────────────────────────────
    static let tabBackground  = UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 0.94)
    static let tabShadow      = UIColor(red: 0.42, green: 0.29, blue: 1.00, alpha: 0.14)
    static let tabSelected    = UIColor(red: 0.42, green: 0.29, blue: 1.00, alpha: 1.0)
    static let tabUnselected  = UIColor.white.withAlphaComponent(0.40)

    // ── Computed ──────────────────────────────────────────────────────────
    static let backgroundGradient = LinearGradient(
        colors: [backgroundBase, deepShadow, plum, backgroundBase],
        startPoint: .top,
        endPoint: .bottom
    )

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
