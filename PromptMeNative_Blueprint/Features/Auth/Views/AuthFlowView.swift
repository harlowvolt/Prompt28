import AuthenticationServices
import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var isSignup = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var googleCredential = ""
    @FocusState private var focusedField: AuthInputField?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        Text("PromptMe")
                            .font(.largeTitle.weight(.bold))

                        EmailAuthView(
                            isSignup: $isSignup,
                            name: $name,
                            email: $email,
                            password: $password,
                            focusedField: $focusedField,
                            isLoading: env.authManager.isAuthenticating,
                            canSubmit: canSubmitEmail
                        ) {
                            await submitEmail()
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                                .focused($focusedField, equals: .googleToken)
                                .submitLabel(.done)
                                .onSubmit {
                                    focusedField = nil
                                }

                            Button("Continue with Google token") {
                                focusedField = nil
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

                        Color.clear
                            .frame(height: 120)
                    }
                    .padding()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { _, field in
                    guard field != nil else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo("authSubmitButton", anchor: .center)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    private var canSubmitEmail: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if isSignup {
            return !trimmedName.isEmpty && isValidEmail && trimmedPassword.count >= 6
        }

        return isValidEmail && !trimmedPassword.isEmpty
    }

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private var validationMessage: String? {
        if isSignup {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Enter your name to create an account."
            }
            if !isValidEmail {
                return "Enter a valid email address."
            }
            if password.count < 6 {
                return "Use at least 6 characters for password."
            }
            return nil
        }

        if !isValidEmail {
            return "Enter a valid email address."
        }
        if password.isEmpty {
            return "Enter your password to continue."
        }
        return nil
    }

    private func submitEmail() async {
        focusedField = nil

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
            focusedField = nil
            env.authManager.lastError = nil
        }
    }
}
