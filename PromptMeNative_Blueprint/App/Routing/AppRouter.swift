import Foundation
import SwiftUI

enum RootRoute {
    case launching
    case auth
    case main
}

enum MainTab: Hashable {
    case home
    case trending
    case history
    case favorites
    case admin
}

enum AppDestination: Hashable {
    case trendingDetail(PromptItem)
}

@Observable
@MainActor
final class AppRouter {
    var rootRoute: RootRoute = .launching
    var selectedTab: MainTab = .home
    var path = NavigationPath()

    func switchTab(_ tab: MainTab) {
        selectedTab = tab
    }

    func push(_ destination: AppDestination) {
        path.append(destination)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
