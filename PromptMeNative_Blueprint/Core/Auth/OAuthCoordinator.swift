import Combine
import Foundation
import SwiftUI
import Combine

final class OAuthCoordinator: ObservableObject {

    @Published var isAuthenticated: Bool = false

    func signIn() {
        isAuthenticated = true
    }

    func signOut() {
        isAuthenticated = false
    }
}
