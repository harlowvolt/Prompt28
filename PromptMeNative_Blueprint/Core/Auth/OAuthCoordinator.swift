import AuthenticationServices
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

// MARK: - Private helpers

/// Walks the VC hierarchy to find whatever is currently on top.
private func topmostViewController(from base: UIViewController) -> UIViewController {
    if let nav = base as? UINavigationController, let visible = nav.visibleViewController {
        return topmostViewController(from: visible)
    }
    if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
        return topmostViewController(from: selected)
    }
    if let presented = base.presentedViewController {
        return topmostViewController(from: presented)
    }
    return base
}

private func foregroundKeyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first(where: { $0.activationState == .foregroundActive })?
        .keyWindow
}

// MARK: - Google Sign-In

@MainActor
final class OAuthCoordinator {

    static func googleIDToken() async throws -> String {
        guard let rootVC = foregroundKeyWindow()?.rootViewController else {
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
// Kept in this file so no new Xcode project registration is needed.

@MainActor
final class AppleSignInHelper: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    func signIn() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email, .fullName]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Prefer the active key window; fall back to the first available window scene key window.
        if let window = foregroundKeyWindow() {
            return window
        }
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .compactMap({ $0.keyWindow })
            .first {
            return window
        }
        fatalError("Unable to find a valid window for Apple Sign In")
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
