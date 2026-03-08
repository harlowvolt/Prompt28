import SwiftUI
import UIKit

struct OrbView: View {
    @ObservedObject var engine: OrbEngine
    let onTranscript: (String) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: PromptTheme.Spacing.s) {
            Button {
                Task {
                    if engine.isRecording {
                        if let final = await engine.stopListeningAndFinalize() {
                            onTranscript(final)
                        }
                    } else {
                        engine.startListening()
                    }
                }
            } label: {
                GeometryReader { proxy in
                    let size = min(proxy.size.width, proxy.size.height)
                    let orbSize = size * 0.47
                    let ringSize = orbSize * 1.42

                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate

                        ZStack {
                            backgroundAtmosphere(size: size)
                            reactiveGlowRing(size: ringSize, time: t)
                            audioWaveHalo(size: ringSize * 1.22, time: t)
                            coreOrb(size: orbSize, time: t)
                            processingSpinner(size: orbSize * 1.12, time: t)
                        }
                        .frame(width: size, height: size)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 420)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)

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
                        Color.white.opacity(0.08),
                        PromptTheme.mutedViolet.opacity(0.12),
                        Color.black.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: size * 0.04,
                    endRadius: size * 0.62
                )
            )
            .frame(width: size, height: size)
            .blendMode(.screen)
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
                        startRadius: size * 0.06,
                        endRadius: size * 0.82
                    )
                )

            Circle()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: size * 0.015)
                .blur(radius: 0.5)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.34), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(0.82)
                .blur(radius: 2)

            Image(systemName: orbSymbol)
                .font(.system(size: size * 0.24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .frame(width: size, height: size)
        .shadow(color: glowColor.opacity(glowStrength), radius: size * 0.28)
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
                        glowColor.opacity(0.15),
                        glowColor.opacity(0.58),
                        Color.white.opacity(0.42),
                        glowColor.opacity(0.15)
                    ],
                    center: .center
                ),
                lineWidth: max(2.0, size * 0.038)
            )
            .hueRotation(hue)
            .blur(radius: size * 0.024)
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
                let height = max(size * 0.022, size * CGFloat(0.026 + activity * 0.088))
                let width = size * 0.012

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
                    .opacity(active ? 0.94 : 0.0)
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
                style: StrokeStyle(lineWidth: max(2, size * 0.04), lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(rotation)
            .opacity(visualState == .processing ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.25), value: visualState)
    }

    private var orbGradientColors: [Color] {
        switch visualState {
        case .idle:
            return [PromptTheme.paleLilacWhite.opacity(0.30), PromptTheme.softLilac.opacity(0.34), PromptTheme.mutedViolet.opacity(0.58), PromptTheme.backgroundBase.opacity(0.94)]
        case .listening:
            return [PromptTheme.paleLilacWhite.opacity(0.36), PromptTheme.softLilac.opacity(0.46), PromptTheme.mutedViolet.opacity(0.75), PromptTheme.deepShadow.opacity(0.95)]
        case .processing:
            return [PromptTheme.paleLilacWhite.opacity(0.34), PromptTheme.softLilac.opacity(0.42), PromptTheme.mutedViolet.opacity(0.66), PromptTheme.plum.opacity(0.95)]
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
            return 0.32
        case .listening:
            return 0.64 + engine.audioLevel * 0.38
        case .processing:
            return 0.5
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
