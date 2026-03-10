import AuthenticationServices
import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var appleHelper = AppleSignInHelper()

    @State private var isSignup = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: AuthInputField?

    var body: some View {
        ZStack {
            PromptPremiumBackground()
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 52)

                        brandHeader
                            .padding(.bottom, 40)

                        VStack(spacing: 16) {
                            socialButtons

                            orDivider

                            modeToggle

                            formFields

                            submitButton
                                .id("authSubmitButton")

                            if let error = env.authManager.lastError, !error.isEmpty {
                                Text(error)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.48))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 28)

                        termsFooter
                            .padding(.top, 32)
                            .padding(.horizontal, 28)

                        Spacer(minLength: 48)
                    }
                    .frame(minHeight: 700)
                    .simultaneousGesture(TapGesture().onEnded { _ in
                        focusedField = nil
                    })
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
                Button("Done") { focusedField = nil }
            }
        }
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("Prompt")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Me")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PromptTheme.softLilac, PromptTheme.mutedViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Turn your ideas into expert AI prompts")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Social Buttons

    private var socialButtons: some View {
        VStack(spacing: 12) {
            // Google
            Button {
                focusedField = nil
                Task {
                    do {
                        let idToken = try await OAuthCoordinator.googleIDToken()
                        await env.authManager.loginWithGoogle(credential: idToken)
                        routeIfAuthenticated()
                    } catch {
                        env.authManager.lastError = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    googleGLogo
                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.15))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(env.authManager.isAuthenticating)

            // Apple
            Button {
                focusedField = nil
                Task {
                    do {
                        let authorization = try await appleHelper.signIn()
                        await handleAppleAuth(authorization)
                    } catch {
                        env.authManager.lastError = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Continue with Apple")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(env.authManager.isAuthenticating)
        }
    }

    private var googleGLogo: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
            Text("G")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
        }
        .frame(width: 24, height: 24)
    }

    // MARK: - Or Divider

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.13))
                .frame(height: 1)
            Text("or")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.32))
            Rectangle()
                .fill(Color.white.opacity(0.13))
                .frame(height: 1)
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { signupValue in
                let isActive = isSignup == signupValue
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSignup = signupValue
                    }
                } label: {
                    Text(signupValue ? "Sign Up" : "Log In")
                        .font(.system(size: 15, weight: isActive ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.40))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(PromptTheme.mutedViolet.opacity(0.55))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(PromptTheme.softLilac.opacity(0.30), lineWidth: 1)
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    // MARK: - Form Fields

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 12) {
            if isSignup {
                nameField
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }

            emailField

            passwordField

            if let msg = validationMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.60))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSignup)
    }

    private var nameField: some View {
        glassField(isFocused: focusedField == .name) {
            HStack(spacing: 10) {
                Image(systemName: "person")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                    .frame(width: 18)
                TextField("Full Name", text: $name)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .tint(PromptTheme.softLilac)
            }
        }
    }

    private var emailField: some View {
        glassField(isFocused: focusedField == .email) {
            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                    .frame(width: 18)
                TextField("Email", text: $email)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .tint(PromptTheme.softLilac)
            }
        }
    }

    private var passwordField: some View {
        glassField(isFocused: focusedField == .password) {
            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                    .frame(width: 18)
                SecureField("Password", text: $password)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                    .textContentType(isSignup ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(canSubmitEmail ? .go : .done)
                    .onSubmit {
                        if canSubmitEmail {
                            focusedField = nil
                            Task { await submitEmail() }
                        } else {
                            focusedField = nil
                        }
                    }
                    .tint(PromptTheme.softLilac)
            }
        }
    }

    private func glassField<Content: View>(isFocused: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isFocused
                                    ? PromptTheme.softLilac.opacity(0.45)
                                    : Color.white.opacity(0.09),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            focusedField = nil
            Task { await submitEmail() }
        } label: {
            HStack(spacing: 10) {
                if env.authManager.isAuthenticating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                Text(isSignup ? "Create Account" : "Log In")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: canSubmitEmail
                                ? [PromptTheme.mutedViolet, Color(red: 0.29, green: 0.21, blue: 0.50)]
                                : [PromptTheme.mutedViolet.opacity(0.35), Color(red: 0.29, green: 0.21, blue: 0.50).opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PromptTheme.softLilac.opacity(canSubmitEmail ? 0.32 : 0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(env.authManager.isAuthenticating || !canSubmitEmail)
        .animation(.easeInOut(duration: 0.15), value: canSubmitEmail)
    }

    // MARK: - Terms Footer

    private var termsFooter: some View {
        VStack(spacing: 5) {
            Text("By continuing you agree to our")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.28))
            HStack(spacing: 4) {
                Text("Terms of Service")
                    .underline()
                Text("and")
                Text("Privacy Policy")
                    .underline()
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(PromptTheme.softLilac.opacity(0.45))
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Auth Logic (preserved exactly)

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
            if !isValidEmail { return "Enter a valid email address." }
            if password.count < 6 { return "Use at least 6 characters for password." }
            return nil
        }
        if !isValidEmail { return "Enter a valid email address." }
        if password.isEmpty { return "Enter your password to continue." }
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
