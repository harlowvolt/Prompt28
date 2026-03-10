import Combine
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

@MainActor
final class AppRouter: ObservableObject {
    @Published var rootRoute: RootRoute = .launching
    @Published var selectedTab: MainTab = .home
}
