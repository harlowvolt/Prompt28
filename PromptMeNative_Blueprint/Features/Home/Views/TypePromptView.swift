import SwiftUI

struct TypePromptView: View {
    @Bindable var viewModel: GenerateViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PromptPremiumBackground()
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    // Mode selector
                    HStack(spacing: 0) {
                        ForEach([PromptMode.ai, PromptMode.human], id: \.self) { mode in
                            let isSelected = viewModel.selectedMode == mode
                            Button {
                                viewModel.selectedMode = mode
                            } label: {
                                Text(mode == .ai ? "AI Mode" : "Human Mode")
                                    .font(PromptTheme.Typography.rounded(14, isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? PromptTheme.paleLilacWhite : PromptTheme.softLilac.opacity(0.55))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(isSelected ? PromptTheme.mutedViolet.opacity(0.55) : .clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.18), value: viewModel.selectedMode)
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(PromptTheme.glassFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )

                    // Text input
                    ZStack(alignment: .topLeading) {
                        if viewModel.inputText.isEmpty {
                            Text("Describe what you want to generate…")
                                .font(PromptTheme.Typography.rounded(16, .regular))
                                .foregroundStyle(PromptTheme.softLilac.opacity(0.45))
                                .padding(.top, 12)
                                .padding(.leading, 6)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $viewModel.inputText)
                            .font(PromptTheme.Typography.rounded(16, .regular))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .frame(minHeight: 160)
                            .focused($isTextEditorFocused)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(PromptTheme.glassFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(
                                        isTextEditorFocused
                                            ? PromptTheme.softLilac.opacity(0.35)
                                            : Color.white.opacity(0.1),
                                        lineWidth: isTextEditorFocused ? 1 : 0.5
                                    )
                            )
                    )
                    .animation(.easeInOut(duration: 0.18), value: isTextEditorFocused)

                    // Generate button
                    Button {
                        isTextEditorFocused = false
                        Task {
                            await viewModel.generate()
                            dismiss()
                        }
                    } label: {
                        ZStack {
                            if viewModel.isGenerating {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(PromptTheme.paleLilacWhite)
                                    Text("Generating…")
                                        .font(PromptTheme.Typography.rounded(17, .semibold))
                                        .foregroundStyle(PromptTheme.paleLilacWhite)
                                }
                            } else {
                                Text("Generate")
                                    .font(PromptTheme.Typography.rounded(17, .semibold))
                                    .foregroundStyle(PromptTheme.paleLilacWhite)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#7F7FD5"),
                                            Color(hex: "#6E55D8")
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(PromptTheme.softLilac.opacity(0.28), lineWidth: 0.5)
                                )
                        )
                        .opacity(viewModel.canGenerate ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canGenerate)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .navigationTitle("Type a Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PromptTheme.softLilac)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { isTextEditorFocused = false }
                }
            }
            .promptClearNavigationSurfaces()
        }
        .onAppear { isTextEditorFocused = true }
        .presentationCornerRadius(32)
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
