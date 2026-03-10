import GoogleSignIn
import UIKit

// MARK: - Errors

enum OAuthError: LocalizedError {
    case noWindow
    case missingToken

    var errorDescription: String? {
        switch self {
        case .noWindow:     return "Unable to find the app window to present sign-in."
        case .missingToken: return "Google did not return an ID token."
        }
    }
}

// MARK: - Helpers

/// Walks the VC hierarchy to find whatever is currently on top.
private func topmostViewController(from base: UIViewController) -> UIViewController {
    if let nav = base as? UINavigationController,
       let visible = nav.visibleViewController {
        return topmostViewController(from: visible)
    }
    if let tab = base as? UITabBarController,
       let selected = tab.selectedViewController {
        return topmostViewController(from: selected)
    }
    if let presented = base.presentedViewController {
        return topmostViewController(from: presented)
    }
    return base
}

// MARK: - Google Sign-In

@MainActor
final class OAuthCoordinator {

    /// Presents the Google Sign-In sheet and returns the ID token your backend expects.
    static func googleIDToken() async throws -> String {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let rootVC = windowScene.keyWindow?.rootViewController
        else {
            throw OAuthError.noWindow
        }

        let presenter = topmostViewController(from: rootVC)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)

        guard let idToken = result.user.idToken?.tokenString else {
            throw OAuthError.missingToken
        }

        return idToken
    }
}
