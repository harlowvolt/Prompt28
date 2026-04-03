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
    case trendingDetail(id: String)
}

enum HomeSheet: String, Identifiable, Hashable {
    case settings
    case upgrade

    var id: String { rawValue }
}

@Observable
@MainActor
final class AppRouter {
    var rootRoute: RootRoute = .launching
    var selectedTab: MainTab = .home
    var path = NavigationPath()
    var homeSheet: HomeSheet?
    var isAuthSheetPresented = false

    func switchTab(_ tab: MainTab) {
        selectedTab = tab
    }

    func push(_ destination: AppDestination) {
        path.append(destination)
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func presentHomeSheet(_ sheet: HomeSheet) {
        homeSheet = sheet
    }

    func dismissHomeSheet() {
        homeSheet = nil
    }

    func presentAuthSheet() {
        isAuthSheetPresented = true
    }

    func dismissAuthSheet() {
        isAuthSheetPresented = false
    }
}

struct AppDestinationHost: View {
    let destination: AppDestination
    let promptItemForID: (String) -> PromptItem?

    var body: some View {
        switch destination {
        case .trendingDetail(let id):
            if let item = promptItemForID(id) {
                PromptDetailView(item: item)
            } else {
                ContentUnavailableView("Prompt not available", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
