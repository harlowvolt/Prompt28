import SwiftUI

struct OrbView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let orbSize = size * 0.72
            let ringSize = orbSize * 1.06

            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    backgroundAtmosphere(size: size * 0.92)
                    equatorialRays(size: size * 0.86, time: t)
                    reactiveGlowRing(size: ringSize, time: t)
                    audioWaveHalo(size: ringSize * 1.02, time: t)
                    coreOrb(size: orbSize, time: t)
                    processingSpinner(size: orbSize * 1.04, time: t)
                }
                .frame(width: size, height: size)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 420)
        .padding(.horizontal, 8)
        .buttonStyle(.plain)
    }
}

// MARK: - Layers
private extension OrbView {
    func backgroundAtmosphere(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.purple.opacity(0.14),
                            Color.blue.opacity(0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: 18)

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: size * 0.92, height: size * 0.92)
                .blur(radius: 1)
        }
    }

    func equatorialRays(size: CGFloat, time: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<14, id: \.self) { i in
                let phase = Double(i) * 0.35
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.cyan.opacity(0.06),
                                Color.white.opacity(0.22),
                                Color.purple.opacity(0.10),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: size * (0.72 + 0.04 * sin(time * 1.4 + phase)),
                        height: 2.0 + CGFloat((i % 3))
                    )
                    .blur(radius: 0.8)
                    .opacity(0.45 + 0.15 * sin(time * 1.8 + phase))
            }
        }
        .rotationEffect(.degrees(sin(time * 0.6) * 4))
    }

    func reactiveGlowRing(size: CGFloat, time: TimeInterval) -> some View {
        Circle()
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.95),
                        Color.cyan.opacity(0.85),
                        Color.blue.opacity(0.75),
                        Color.purple.opacity(0.85),
                        Color.white.opacity(0.95)
                    ]),
                    center: .center,
                    angle: .degrees(time * 28)
                ),
                lineWidth: 3.0
            )
            .frame(width: size, height: size)
            .blur(radius: 0.6)
            .shadow(color: Color.cyan.opacity(0.35), radius: 12)
            .shadow(color: Color.purple.opacity(0.30), radius: 20)
    }

    func audioWaveHalo(size: CGFloat, time: TimeInterval) -> some View {
        Circle()
            .stroke(Color.white.opacity(0.14), lineWidth: 1.4)
            .frame(
                width: size + CGFloat(sin(time * 2.2) * 10),
                height: size + CGFloat(sin(time * 2.2) * 10)
            )
            .blur(radius: 2.0)
            .opacity(0.65)
    }

    func coreOrb(size: CGFloat, time: TimeInterval) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color(red: 0.50, green: 0.76, blue: 1.00).opacity(0.68),
                            Color(red: 0.18, green: 0.32, blue: 0.80).opacity(0.82),
                            Color(red: 0.04, green: 0.06, blue: 0.28).opacity(0.88)
                        ],
                        center: UnitPoint(x: 0.38, y: 0.28),
                        startRadius: 2,
                        endRadius: size * 0.62
                    )
                )
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.32),
                                    Color.clear,
                                    Color(red: 0.50, green: 0.30, blue: 0.90).opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.82, blue: 1.00).opacity(0.92),
                                    Color.white.opacity(0.96),
                                    Color(red: 0.72, green: 0.55, blue: 1.00).opacity(0.88),
                                    Color(red: 0.42, green: 0.68, blue: 1.00).opacity(0.80),
                                    Color.white.opacity(0.94),
                                    Color(red: 0.55, green: 0.82, blue: 1.00).opacity(0.92)
                                ],
                                center: .center
                            ),
                            lineWidth: max(1.6, size * 0.010)
                        )
                }
                .shadow(color: Color(red: 0.30, green: 0.55, blue: 1.00).opacity(0.55), radius: 28)
                .shadow(color: Color.purple.opacity(0.38), radius: 44)
                .shadow(color: Color.cyan.opacity(0.22), radius: 58)

            // Top-left glass highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.52),
                            Color.white.opacity(0.14),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.34, y: 0.25),
                        startRadius: 1,
                        endRadius: size * 0.22
                    )
                )
                .frame(width: size * 0.50, height: size * 0.50)
                .offset(x: -size * 0.12, y: -size * 0.16)

            sparklesLayer(size: size, time: time)
        }
        .frame(width: size, height: size)
        .scaleEffect(1.0 + CGFloat(sin(time * 1.7)) * 0.012)
    }

    func sparklesLayer(size: CGFloat, time: TimeInterval) -> some View {
        ZStack {
            sparkle(x: -0.18, y: -0.22, size: size * 0.030, opacity: 0.85 + 0.15 * sin(time * 2.1))
            sparkle(x: 0.22, y: -0.10, size: size * 0.018, opacity: 0.70 + 0.20 * sin(time * 2.7))
            sparkle(x: 0.12, y: 0.20, size: size * 0.022, opacity: 0.72 + 0.18 * sin(time * 1.9))
            sparkle(x: -0.24, y: 0.16, size: size * 0.016, opacity: 0.60 + 0.18 * sin(time * 3.2))
            sparkle(x: 0.00, y: -0.28, size: size * 0.014, opacity: 0.65 + 0.22 * sin(time * 2.4))
        }
    }

    func sparkle(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) -> some View {
        // orbDiameter ≈ size / 0.030 — back-calculate so offset scales with orb
        let orbDiameter = size / 0.030
        return Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 0.3)
            .shadow(color: Color.cyan.opacity(0.40), radius: 5)
            .offset(x: x * orbDiameter * 0.40, y: y * orbDiameter * 0.40)
    }

    func processingSpinner(size: CGFloat, time: TimeInterval) -> some View {
        Circle()
            .trim(from: 0.08, to: 0.32)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.90),
                        Color.cyan.opacity(0.75),
                        Color.purple.opacity(0.20),
                        Color.clear
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(time * 80))
            .blur(radius: 0.3)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color(red: 0.08, green: 0.03, blue: 0.16)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        OrbView()
            .padding(40)
    }
}
