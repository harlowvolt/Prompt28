import Foundation

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

@Observable
@MainActor
final class AppRouter {
    var rootRoute: RootRoute = .launching
    var selectedTab: MainTab = .home
}
