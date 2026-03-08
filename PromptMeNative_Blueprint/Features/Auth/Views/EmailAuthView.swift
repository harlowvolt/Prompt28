import SwiftUI

struct EmailAuthView: View {
    @Binding var isSignup: Bool
    @Binding var name: String
    @Binding var email: String
    @Binding var password: String
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
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textFieldStyle(.roundedBorder)

            SecureField("Password (min 6)", text: $password)
                .textFieldStyle(.roundedBorder)

            Button {
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
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || !canSubmit)
        }
    }
}
