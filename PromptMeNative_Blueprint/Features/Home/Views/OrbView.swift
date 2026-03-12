import SwiftUI
import UIKit

struct OrbView: View {
    var engine: OrbEngine
    let onTranscript: (String) -> Void
    @Environment(\.openURL) private var openURL
    @State private var orbState: OrbTapState = .idle

    var body: some View {
        VStack(spacing: PromptTheme.Spacing.s) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let orbSize = size * 0.78

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: visualState == .idle)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    ZStack {
                        backgroundAtmosphere(size: size * 0.76)
                        coreOrb(size: orbSize, time: t)
                        processingSpinner(size: orbSize * 1.04, time: t)
                    }
                    .frame(width: size, height: size)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 420)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                switch orbState {
                case .idle:
                    HapticService.impact(.heavy)
                    engine.startListening()
                    orbState = .listening

                case .listening:
                    HapticService.impact(.light)
                    engine.stopListening()
                    orbState = .processing

                case .processing:
                    break
                }
            }

            if !engine.permissionMessage.isEmpty {
                VStack(spacing: 8) {
                    Text(engine.permissionMessage)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if engine.needsPermissionSettingsAction {
                        Button("Open iOS Settings") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PromptTheme.mutedViolet.opacity(0.84))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            engine.onFinalTranscript = { text in
                onTranscript(text)
            }
        }
        .onDisappear {
            engine.onFinalTranscript = nil
        }
        .onChange(of: engine.state) { _, newState in
            switch newState {
            case .idle, .success, .failure:
                orbState = .idle
            case .listening:
                orbState = .listening
            case .transcribing, .ready, .generating:
                orbState = .processing
            }
        }
    }

    private var visualState: OrbVisualState {
        switch engine.state {
        case .idle, .success:
            return .idle
        case .listening, .ready:
            return .listening
        case .transcribing, .generating:
            return .processing
        case .failure:
            return .error
        }
    }

    @ViewBuilder
    private func backgroundAtmosphere(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        PromptTheme.softLilac.opacity(0.04),
                        PromptTheme.orbActiveGlow.opacity(0.025),
                        Color.black.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: size * 0.12,
                    endRadius: size * 0.40
                )
            )
            .frame(width: size, height: size)
            .blendMode(.plusLighter)
    }

    private func coreOrb(size: CGFloat, time: TimeInterval) -> some View {
        let level = engine.audioLevel
        let baseWave = sin(time * 1.35)
        let secondaryWave = sin(time * 2.45 + 0.9)
        let organicWave = CGFloat(baseWave * 0.65 + secondaryWave * 0.35)
        let motionAmplitude: CGFloat

        switch visualState {
        case .idle:
            motionAmplitude = 0.016
        case .listening:
            motionAmplitude = 0.028 + level * 0.02
        case .processing:
            motionAmplitude = 0.021
        case .error:
            motionAmplitude = 0.012
        }

        let levelInfluence = visualState == .listening ? level * 0.05 : 0
        let scale = 1 + organicWave * motionAmplitude + levelInfluence
        let yFloat = organicWave * size * 0.012

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: orbGradientColors,
                        center: .topLeading,
                        startRadius: size * 0.05,
                        endRadius: size * 0.88
                    )
                )

            Circle()
                .strokeBorder(PromptTheme.softLilac.opacity(0.62), lineWidth: max(1.2, size * 0.008))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.42), lineWidth: max(0.6, size * 0.0032))
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.06), .clear],
                        center: UnitPoint(x: 0.30, y: 0.26),
                        startRadius: size * 0.01,
                        endRadius: size * 0.42
                    )
                )
                .scaleEffect(0.95)
                .blur(radius: 6)

            Image(systemName: orbSymbol)
                .font(.system(size: size * 0.27, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.96))
                .shadow(color: Color.white.opacity(0.2), radius: 4)
        }
        .frame(width: size, height: size)
        .shadow(color: glowColor.opacity(glowStrength), radius: size * 0.14)
        .shadow(color: Color.white.opacity(0.12), radius: size * 0.06)
        .scaleEffect(scale)
        .offset(y: yFloat)
    }

    @ViewBuilder
    private func reactiveGlowRing(size: CGFloat, time: TimeInterval) -> some View {
        let level = engine.audioLevel
        let pulse = visualState == .listening ? (0.02 + level * 0.14) : 0.0
        let wave = CGFloat((sin(time * 4.4) + 1.0) * 0.5)
        let dynamicScale = 1.0 + pulse + wave * (visualState == .listening ? 0.04 : 0.0)
        let hue = visualState == .listening ? Angle(degrees: Double(6 + level * 20)) : .zero

        Circle()
            .stroke(
                AngularGradient(
                    colors: [
                        glowColor.opacity(0.05),
                        glowColor.opacity(0.26),
                        Color.white.opacity(0.24),
                        glowColor.opacity(0.05)
                    ],
                    center: .center
                ),
                lineWidth: max(1.0, size * 0.010)
            )
            .hueRotation(hue)
            .blur(radius: size * 0.008)
            .frame(width: size, height: size)
            .scaleEffect(dynamicScale)
            .opacity(visualState == .processing ? 0.7 : 1.0)
                .animation(.easeOut(duration: 0.16), value: engine.audioLevel)
            .animation(.easeInOut(duration: 0.4), value: visualState)
    }

    @ViewBuilder
    private func audioWaveHalo(size: CGFloat, time: TimeInterval) -> some View {
        let barCount = 64
        let radius = size * 0.46
        let level = engine.audioLevel
        let active = visualState == .listening

        ZStack {
            ForEach(0..<barCount, id: \.self) { index in
                let progress = Double(index) / Double(barCount)
                let angle = progress * Double.pi * 2.0
                let phase = sin(time * 10.0 + progress * Double.pi * 7.0)
                let activity = active ? max(0.0, phase * 0.6 + Double(level) * 1.1) : 0.0
                let height = max(size * 0.012, size * CGFloat(0.013 + activity * 0.048))
                let width = size * 0.006

                Capsule(style: .circular)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), glowColor.opacity(0.42)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: height)
                    .offset(y: -radius)
                    .rotationEffect(.radians(angle))
                    .opacity(active ? 0.72 : 0.0)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.12), value: engine.audioLevel)
    }

    @ViewBuilder
    private func processingSpinner(size: CGFloat, time: TimeInterval) -> some View {
        let rotation = visualState == .processing ? Angle.degrees(time * 140) : .zero

        Circle()
            .trim(from: 0.05, to: 0.34)
            .stroke(
                AngularGradient(
                    colors: [Color.clear, Color.white.opacity(0.8), glowColor.opacity(0.7), Color.clear],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: max(1.6, size * 0.016), lineCap: .round)
            )
            .shadow(color: glowColor.opacity(glowStrength), radius: size * 0.10)
            .shadow(color: Color.white.opacity(0.12), radius: size * 0.04)
            .rotationEffect(rotation)
            .opacity(visualState == .processing ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.25), value: visualState)
    }

    private var orbGradientColors: [Color] {
        switch visualState {
        case .idle:
            return [Color(hex: "#202A4A"), Color(hex: "#111A34"), Color(hex: "#070D22"), Color(hex: "#02050F")]
        case .listening:
            return [Color(hex: "#263359"), Color(hex: "#131D3D"), Color(hex: "#08102A"), Color(hex: "#020612")]
        case .processing:
            return [Color(hex: "#2B3960"), Color(hex: "#162246"), Color(hex: "#0A1330"), Color(hex: "#030712")]
        case .error:
            return [Color.white.opacity(0.22), Color.red.opacity(0.64), Color.red.opacity(0.9), Color.black.opacity(0.92)]
        }
    }

    private var glowColor: Color {
        switch visualState {
        case .idle:
            return PromptTheme.orbIdleGlow
        case .listening:
            return PromptTheme.orbActiveGlow
        case .processing:
            return PromptTheme.orbProcessingGlow
        case .error:
            return .red
        }
    }

    private var glowStrength: CGFloat {
        switch visualState {
        case .idle:
            return 0.2
        case .listening:
            return 0.4 + engine.audioLevel * 0.16
        case .processing:
            return 0.3
        case .error:
            return 0.85
        }
    }

    private var orbSymbol: String {
        "mic"
    }

}

private enum OrbVisualState {
    case idle
    case listening
    case processing
    case error
}

private enum OrbTapState {
    case idle
    case listening
    case processing
}
