import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var isSignup = false
    @Published var googleCredential = ""

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var canSubmitEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 6
    }

    func submitEmail() async {
        if isSignup {
            await authManager.register(email: email, password: password, name: name.isEmpty ? nil : name)
        } else {
            await authManager.login(email: email, password: password)
        }
    }

    func submitGoogle() async {
        guard !googleCredential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await authManager.loginWithGoogle(credential: googleCredential)
    }

    func submitApple(identityToken: String, firstName: String?, lastName: String?, email: String?) async {
        await authManager.loginWithApple(identityToken: identityToken, firstName: firstName, lastName: lastName, email: email)
    }
}
