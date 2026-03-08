import AuthenticationServices
import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var isSignup = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var googleCredential = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("PromptMe")
                        .font(.largeTitle.weight(.bold))

                    EmailAuthView(
                        isSignup: $isSignup,
                        name: $name,
                        email: $email,
                        password: $password,
                        isLoading: env.authManager.isAuthenticating,
                        canSubmit: canSubmitEmail
                    ) {
                        await submitEmail()
                    }

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task {
                            switch result {
                            case .success(let authorization):
                                await handleAppleAuth(authorization)
                            case .failure(let error):
                                env.authManager.lastError = error.localizedDescription
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Google ID token")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Paste Google credential", text: $googleCredential)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        Button("Continue with Google token") {
                            Task {
                                await env.authManager.loginWithGoogle(credential: googleCredential)
                                routeIfAuthenticated()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(env.authManager.isAuthenticating || googleCredential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let error = env.authManager.lastError, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
        }
    }

    private var canSubmitEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 6
    }

    private func submitEmail() async {
        if isSignup {
            await env.authManager.register(email: email, password: password, name: name.isEmpty ? nil : name)
        } else {
            await env.authManager.login(email: email, password: password)
        }

        routeIfAuthenticated()
    }

    private func handleAppleAuth(_ authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            env.authManager.lastError = "Unable to read Apple identity token."
            return
        }

        await env.authManager.loginWithApple(
            identityToken: token,
            firstName: credential.fullName?.givenName,
            lastName: credential.fullName?.familyName,
            email: credential.email
        )

        routeIfAuthenticated()
    }

    private func routeIfAuthenticated() {
        if env.authManager.isAuthenticated {
            env.router.rootRoute = .main
        }
    }
}
