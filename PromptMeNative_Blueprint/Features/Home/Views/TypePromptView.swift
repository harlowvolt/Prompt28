import SwiftUI

struct TypePromptView: View {
    @Bindable var viewModel: GenerateViewModel
    @FocusState private var isTextEditorFocused: Bool

    private var trimmedInput: String {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PromptPremiumBackground()
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.05),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )

            composerCard
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isTextEditorFocused = true
            }
        }
        .presentationDetents([.height(250), .medium])
        .presentationBackground(.clear)
        .presentationCornerRadius(32)
        .presentationDragIndicator(.hidden)
    }

    private var composerCard: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.24))
                .frame(width: 36, height: 5)

            ZStack(alignment: .topLeading) {
                if trimmedInput.isEmpty {
                    Text("Just talk. Messy is fine.")
                        .font(PromptTheme.Typography.rounded(17, .regular))
                        .foregroundStyle(.white.opacity(0.34))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.inputText)
                    .font(PromptTheme.Typography.rounded(17, .regular))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 88, maxHeight: 140)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .focused($isTextEditorFocused)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: "#141828").opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
        )
    }
}
