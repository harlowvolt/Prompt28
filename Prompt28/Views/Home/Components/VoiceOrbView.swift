import SwiftUI

struct VoiceOrbView: View {
    @Binding var isRecording: Bool
    @State private var pulse: Double = 0

    var body: some View {
        GeometryReader { geo in
            let base = min(geo.size.width, geo.size.height)

            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            Color.neonPurple.opacity(0.65 - Double(i) * 0.2),
                            lineWidth: base * 0.0085
                        )
                        .frame(width: base * (1.12 + CGFloat(i) * 0.26))
                        .blur(radius: CGFloat(i) * 4.5)
                        .scaleEffect(isRecording ? 1.0 + sin(pulse + Double(i)) * 0.055 : 1.0)
                        .opacity(isRecording ? 1.0 - Double(i) * 0.22 : 0.35)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.28), .neonPurple],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 0.42
                        )
                    )
                    .frame(width: base * 0.71)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.22), lineWidth: 3)
                    )
                    .shadow(color: .neonPurple.opacity(0.95), radius: 45)
                    .shadow(color: .neonCyan.opacity(0.55), radius: 70)
            }
            .frame(width: base, height: base)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.65).repeatForever(autoreverses: true)) {
                    pulse = .pi * 2
                }
            } else {
                pulse = 0
            }
        }
    }
}
