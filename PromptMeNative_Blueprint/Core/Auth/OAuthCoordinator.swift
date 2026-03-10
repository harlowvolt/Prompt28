import AuthenticationServices
import GoogleSignIn
import UIKit

// MARK: - Shared errors

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

// MARK: - Shared helper

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

private func foregroundWindowScene() -> UIWindowScene? {
    UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
}

// MARK: - Google Sign-In

@MainActor
final class OAuthCoordinator {

    /// Presents the Google Sign-In sheet and returns the ID token your backend expects.
    static func googleIDToken() async throws -> String {
        guard
            let windowScene = foregroundWindowScene(),
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

// MARK: - Apple Sign-In

/// Bridges ASAuthorizationController (UIKit delegate pattern) to async/await.
/// Using a plain SwiftUI Button + this helper avoids UIKit/SwiftUI gesture
/// conflicts that make SignInWithAppleButton unresponsive inside ScrollViews.
@MainActor
final class AppleSignInHelper: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    func signIn() async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email, .fullName]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = foregroundWindowScene(),
              let window = scene.keyWindow else {
            // Fallback: create a window attached to the scene if possible
            if let scene = foregroundWindowScene() {
                return UIWindow(windowScene: scene)
            }
            return UIWindow()
        }
        return window
    }

    // MARK: ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
