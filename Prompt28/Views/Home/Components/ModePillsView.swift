import SwiftUI

struct ModePillsView: View {
    @Binding var selectedMode: PromptMode

    var body: some View {
        HStack(spacing: 14) {
            ForEach(PromptMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                        )
                        .overlay {
                            if mode == selectedMode {
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .strokeBorder(LinearGradient.neonBorder, lineWidth: 2.5)
                            } else {
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            }
                        }
                }
                .foregroundStyle(mode == selectedMode ? .white : .white.opacity(0.75))
            }
        }
        .padding(.horizontal, 28)
    }
}
