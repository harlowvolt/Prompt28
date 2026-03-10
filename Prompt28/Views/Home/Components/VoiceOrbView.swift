import SwiftUI

struct VoiceOrbView: View {
    @Binding var isRecording: Bool
    @State private var pulse: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let base = min(geo.size.width, geo.size.height)

            ZStack {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(
                            Color.orbGlowBlue.opacity(i == 0 ? 0.38 : 0.18)
                        )
                        .frame(width: base * (1.08 + CGFloat(i) * 0.12))
                        .blur(radius: i == 0 ? 28 : 42)
                        .scaleEffect(isRecording ? (1.0 + pulse * (0.05 + CGFloat(i) * 0.03)) : 1.0)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.26), Color.orbCoreMid, Color.orbCoreDark],
                            center: UnitPoint(x: 0.30, y: 0.22),
                            startRadius: 0,
                            endRadius: base * 0.54
                        )
                    )
                    .frame(width: base * 0.96)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.74), lineWidth: 1.2)
                    )

                Image(systemName: "mic.fill")
                    .font(.system(size: base * 0.17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .shadow(color: .white.opacity(0.35), radius: 10)
            }
            .frame(width: base, height: base)
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: Color.orbGlowBlue.opacity(0.74), radius: 35)
        .shadow(color: Color.orbGlowBlue.opacity(0.38), radius: 64)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.65).repeatForever(autoreverses: true)) {
                    pulse = 1
                }
            } else {
                pulse = 0
            }
        }
    }
}
