import SwiftUI

struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 58, height: 58)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.24), lineWidth: 1.2)
                        )
                }
                .shadow(color: Color.white.opacity(0.18), radius: 10)
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}
