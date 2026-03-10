import SwiftUI

@main
struct Prompt28App: App {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.12)

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.white.withAlphaComponent(0.98)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.98)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.50)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.50)
        ]

        appearance.selectionIndicatorImage = UIImage.tabSelectionIndicator(
            color: UIColor.white.withAlphaComponent(0.09),
            stroke: UIColor.white.withAlphaComponent(0.18)
        )

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
    }

    var body: some Scene {
        WindowGroup {
            RootTabsView()
                .preferredColorScheme(.dark)
        }
    }
}

private struct RootTabsView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            PlaceholderTabView(title: "Favorites")
                .tabItem {
                    Label("Favorites", systemImage: "star")
                }
                .tag(MainTab.favorites)

            PlaceholderTabView(title: "History")
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(MainTab.history)

            PlaceholderTabView(title: "Trending")
                .tabItem {
                    Label("Trending", systemImage: "waveform.path.ecg")
                }
                .tag(MainTab.trending)
        }
    }
}

private enum MainTab: Hashable {
    case home
    case favorites
    case history
    case trending
}

private struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        ZStack {
            CyberBackgroundGradient()

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

private extension UIImage {
    static func tabSelectionIndicator(color: UIColor, stroke: UIColor) -> UIImage {
        let size = CGSize(width: 92, height: 46)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 3)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 20)

            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.fillPath()

            context.cgContext.setStrokeColor(stroke.cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.strokePath()
        }
        .resizableImage(withCapInsets: UIEdgeInsets(top: 22, left: 46, bottom: 22, right: 46))
    }
}
