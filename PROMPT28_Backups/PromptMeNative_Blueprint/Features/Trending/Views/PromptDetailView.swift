import SwiftUI

struct PromptDetailView: View {
	let item: PromptItem
	@State private var copied = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				Text(item.title)
					.font(.title3)
					.bold()

				Text(item.prompt)
					.textSelection(.enabled)

				Button(copied ? "Copied" : "Copy Prompt") {
					UIPasteboard.general.string = item.prompt
					copied = true
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
						copied = false
					}
				}
				.buttonStyle(.borderedProminent)
			}
			.padding()
		}
		.navigationTitle("Prompt")
		.navigationBarTitleDisplayMode(.inline)
	}
}
