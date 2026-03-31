import SwiftUI

struct TypePromptView: View {
    @Bindable var viewModel: GenerateViewModel
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        ZStack {
            PromptPremiumBackground()
                .ignoresSafeArea()

            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text("Describe what you want to generate…")
                        .font(PromptTheme.Typography.rounded(16, .regular))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 16)
                        .padding(.leading, 20)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.inputText)
                    .font(PromptTheme.Typography.rounded(16, .regular))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .focused($isTextEditorFocused)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isTextEditorFocused = true
            }
        }
        .presentationCornerRadius(32)
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
