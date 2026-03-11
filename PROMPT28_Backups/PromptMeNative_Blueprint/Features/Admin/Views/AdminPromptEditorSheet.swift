import SwiftUI

struct AdminPromptEditorSheet: View {
	@Environment(\.dismiss) private var dismiss

	let initialID: String
	let initialTitle: String
	let initialPrompt: String
	let onSave: (PromptItem) -> Void

	@State private var id: String
	@State private var title: String
	@State private var prompt: String

	init(initialID: String, initialTitle: String, initialPrompt: String, onSave: @escaping (PromptItem) -> Void) {
		self.initialID = initialID
		self.initialTitle = initialTitle
		self.initialPrompt = initialPrompt
		self.onSave = onSave
		_id = State(initialValue: initialID)
		_title = State(initialValue: initialTitle)
		_prompt = State(initialValue: initialPrompt)
	}

	var body: some View {
		NavigationStack {
			Form {
				Section("Metadata") {
					TextField("Prompt ID", text: $id)
					TextField("Title", text: $title)
				}

				Section("Prompt") {
					TextEditor(text: $prompt)
						.frame(minHeight: 220)
				}
			}
			.navigationTitle("Edit Prompt")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						let item = PromptItem(
							id: id.trimmingCharacters(in: .whitespacesAndNewlines),
							title: title.trimmingCharacters(in: .whitespacesAndNewlines),
							prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines)
						)
						onSave(item)
						dismiss()
					}
					.disabled(!canSave)
				}
			}
		}
	}

	private var canSave: Bool {
		!id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		&& !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		&& !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}
}
