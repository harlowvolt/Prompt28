import SwiftUI

struct TypePromptView: View {
    @Bindable var viewModel: GenerateViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Mode", selection: $viewModel.selectedMode) {
                Text("AI").tag(PromptMode.ai)
                Text("Human").tag(PromptMode.human)
            }
            .pickerStyle(.segmented)

            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 180)
                .padding(8)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }

            Button {
                Task { await viewModel.generate() }
            } label: {
                HStack {
                    if viewModel.isGenerating { ProgressView() }
                    Text("Generate")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canGenerate)
        }
        .padding()
    }
}
