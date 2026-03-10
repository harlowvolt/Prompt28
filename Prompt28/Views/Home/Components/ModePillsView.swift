import SwiftUI

struct ModePillsView: View {
    @Binding var selectedMode: PromptMode

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            ForEach(PromptMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 33, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppHeights.segmentedControl)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.08), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            if mode == selectedMode {
                                RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                            } else {
                                RoundedRectangle(cornerRadius: AppRadii.pill, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            }
                        }
                }
                .foregroundStyle(mode == selectedMode ? .white.opacity(0.96) : .white.opacity(0.64))
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
