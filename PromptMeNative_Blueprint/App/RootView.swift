import SwiftUI

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        TabView {
            HomeView(appEnvironment: env)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            TrendingView()
                .tabItem {
                    Label("Trending", systemImage: "flame.fill")
                }
        }
    }
}
