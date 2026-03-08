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
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
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

            tabContent {
                SettingsView()
            }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(MainTab.settings)
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
            LinearGradient(
                colors: [Color.black, Color(red: 0.04, green: 0.08, blue: 0.11), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                Text("Loading Prompt28")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
