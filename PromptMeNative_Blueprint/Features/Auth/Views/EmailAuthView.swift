import SwiftUI

enum AuthInputField: Hashable {
    case name
    case email
    case password
    case googleToken
}

struct EmailAuthView: View {
    @Binding var isSignup: Bool
    @Binding var name: String
    @Binding var email: String
    @Binding var password: String
    @FocusState.Binding var focusedField: AuthInputField?
    let isLoading: Bool
    let canSubmit: Bool
    let onSubmit: () async -> Void

    var body: some View {
        VStack(spacing: AppSpacing.element) {
            Picker("Mode", selection: $isSignup) {
                Text("Login").tag(false)
                Text("Sign Up").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(height: AppHeights.segmented)

            if isSignup {
                AppGlassField(isFocused: focusedField == .name) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .email
                        }
                }
            }

            AppGlassField(isFocused: focusedField == .email) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }

            AppGlassField(isFocused: focusedField == .password) {
                SecureField("Password (min 6)", text: $password)
                    .textContentType(isSignup ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(canSubmit ? .go : .done)
                    .onSubmit {
                        if canSubmit {
                            focusedField = nil
                            Task { await onSubmit() }
                        } else {
                            focusedField = nil
                        }
                    }
            }

            HStack {
                Spacer()
                Button("Dismiss Keyboard") {
                    focusedField = nil
                }
                .font(.footnote.weight(.semibold))
                .opacity(focusedField == nil ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: focusedField)
            }

            AppPrimaryButton(
                title: isSignup ? "Create Account" : "Login",
                isLoading: isLoading,
                isEnabled: canSubmit
            ) {
                focusedField = nil
                Task { await onSubmit() }
            }
            .id("authSubmitButton")
        }
    }
}
