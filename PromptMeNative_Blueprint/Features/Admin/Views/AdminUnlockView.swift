import SwiftUI

struct AdminUnlockView: View {
	@Bindable var viewModel: AdminViewModel

	var body: some View {
		VStack(spacing: 14) {
			Text("Admin Access")
				.font(.title3)
				.bold()

			SecureField("Admin key", text: $viewModel.adminKeyInput)
				.textFieldStyle(.roundedBorder)

			Button(viewModel.isLoading ? "Verifying..." : "Unlock") {
				Task { await viewModel.verifyAndUnlock() }
			}
			.buttonStyle(.borderedProminent)
			.disabled(viewModel.isLoading)

			if let message = viewModel.errorMessage {
				Text(message)
					.foregroundStyle(.red)
					.font(.footnote)
					.multilineTextAlignment(.center)
			}
		}
		.padding()
	}
}
