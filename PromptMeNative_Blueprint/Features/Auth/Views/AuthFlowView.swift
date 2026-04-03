import AuthenticationServices
import SwiftUI

struct AuthFlowView: View {
    @Environment(\.authManager) private var scopedAuthManager
    @Environment(\.appRouter) private var appRouter
    // appleHelper removed — SignInWithAppleButton handles the flow natively (Guideline 4.8)

    @State private var isSignup = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: AuthInputField?

    private var authManager: AuthManager? { scopedAuthManager }

    var body: some View {
        ZStack {
            // Constrain form to 420pt so it doesn't stretch full-width on iPad
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: AppSpacing.screenTopLarge + 20)

                        brandHeader
                            .padding(.bottom, AppSpacing.section)

                        VStack(spacing: AppSpacing.sectionTight) {
                            socialButtons

                            orDivider

                            modeToggle

                            formFields

                            submitButton
                                .id("authSubmitButton")

                            if let error = authManager?.lastError, !error.isEmpty {
                                Text(error)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.48))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        termsFooter
                            .padding(.top, AppSpacing.section)
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        Spacer(minLength: 40)
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
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .promptClearNavigationSurfaces()
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        VStack(spacing: 16) {
            // Orbital rings logo
            OrbitLogoView()
                .frame(width: 88, height: 88)

            VStack(spacing: 6) {
                Text("Orbit Orb")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Turn any idea into an expert AI prompt")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Social Buttons

    private var socialButtons: some View {
        VStack(spacing: AppSpacing.element) {
            // Google
            Button {
                focusedField = nil
                Task {
                    do {
                        let idToken = try await OAuthCoordinator.googleIDToken()
                        guard let authManager else { return }
                        await authManager.loginWithGoogle(credential: idToken)
                        routeIfAuthenticated()
                    } catch {
                        authManager?.lastError = error.localizedDescription
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
                .frame(height: AppHeights.primaryButton)
                .background(.white, in: RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(authManager?.isAuthenticating ?? false)

            // Apple — must use SignInWithAppleButton to comply with App Store Guideline 4.8
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                focusedField = nil
                switch result {
                case .success(let authorization):
                    Task { await handleAppleAuth(authorization) }
                case .failure(let error):
                    authManager?.lastError = appleSignInMessage(for: error)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: AppHeights.primaryButton)
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            .disabled(authManager?.isAuthenticating ?? false)
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
                        .frame(height: AppHeights.segmented - 12)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: AppRadii.control - 6, style: .continuous)
                                    .fill(PromptTheme.mutedViolet.opacity(0.55))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadii.control - 6, style: .continuous)
                                            .stroke(PromptTheme.softLilac.opacity(0.30), lineWidth: 1)
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(height: AppHeights.segmented)
        .background(
            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                        .stroke(Color.white.opacity(0.13), lineWidth: 1)
                )
        )
    }

    // MARK: - Form Fields

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: AppSpacing.element) {
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
        AppGlassField(isFocused: focusedField == .name) {
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
        AppGlassField(isFocused: focusedField == .email) {
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
        AppGlassField(isFocused: focusedField == .password) {
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

    // MARK: - Submit Button

    private var submitButton: some View {
        AppPrimaryButton(
            title: isSignup ? "Create Account" : "Log In",
            isLoading: authManager?.isAuthenticating ?? false,
            isEnabled: canSubmitEmail
        ) {
            focusedField = nil
            Task { await submitEmail() }
        }
    }

    // MARK: - Terms Footer

    private var termsFooter: some View {
        VStack(spacing: 5) {
            Text("By continuing you agree to our")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.28))
            HStack(spacing: 4) {
                Button {
                    if let url = URL(string: "https://orbitorb.app/terms") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Terms of Service").underline()
                }
                Text("and")
                Button {
                    if let url = URL(string: "https://orbitorb.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Privacy Policy").underline()
                }
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(PromptTheme.softLilac.opacity(0.45))
            .buttonStyle(.plain)
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
        guard let authManager else { return }
        if isSignup {
            await authManager.register(email: email, password: password, name: name.isEmpty ? nil : name)
        } else {
            await authManager.login(email: email, password: password)
        }
        routeIfAuthenticated()
    }

    private func handleAppleAuth(_ authorization: ASAuthorization) async {
        guard let authManager else { return }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            authManager.lastError = "Unable to read Apple identity token."
            return
        }
        await authManager.loginWithApple(
            identityToken: token,
            firstName: credential.fullName?.givenName,
            lastName: credential.fullName?.familyName,
            email: credential.email
        )
        routeIfAuthenticated()
    }

    private func routeIfAuthenticated() {
        guard let authManager, authManager.isAuthenticated else { return }
        if authManager.isAuthenticated {
            focusedField = nil
            authManager.lastError = nil
            appRouter?.switchTab(.home)
            appRouter?.popToRoot()
            appRouter?.dismissAuthSheet()
        }
    }

    private func appleSignInMessage(for error: Error) -> String? {
        guard let authError = error as? ASAuthorizationError else {
            return error.localizedDescription
        }

        switch authError.code {
        case .canceled:
            return nil
        case .failed:
            return "Apple Sign In failed. Please try again."
        case .invalidResponse:
            return "Apple Sign In returned an invalid response."
        case .notHandled:
            return "Apple Sign In was not handled by the system."
        case .unknown:
            return "Apple Sign In is currently unavailable. Please try again."
        case .notInteractive:
            return "Apple Sign In requires an interactive session."
        case .matchedExcludedCredential:
            return "Selected Apple account is excluded. Choose a different account."
        case .credentialImport:
            return "Apple credential import failed."
        case .credentialExport:
            return "Apple credential export failed."
        default:
            return "Apple Sign In failed with an unknown error."
        }
    }
}
