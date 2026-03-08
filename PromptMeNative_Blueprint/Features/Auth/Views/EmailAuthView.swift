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
        VStack(spacing: 12) {
            Picker("Mode", selection: $isSignup) {
                Text("Login").tag(false)
                Text("Sign Up").tag(true)
            }
            .pickerStyle(.segmented)

            if isSignup {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .email
                    }
                    .textFieldStyle(.roundedBorder)
            }

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
                .textFieldStyle(.roundedBorder)

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
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Dismiss Keyboard") {
                    focusedField = nil
                }
                .font(.footnote.weight(.semibold))
                .opacity(focusedField == nil ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: focusedField)
            }

            Button {
                focusedField = nil
                Task { await onSubmit() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(isSignup ? "Create Account" : "Login")
                }
                .frame(maxWidth: .infinity)
            }
            .id("authSubmitButton")
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || !canSubmit)
        }
    }
}
