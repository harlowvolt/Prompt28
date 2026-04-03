import SwiftUI

/// Animated orbital-rings logo for Orbit Orb.
/// Two elliptical rings crossing at ±45° with a soft centre glow — no bright burst.
struct OrbitLogoView: View {

    @State private var pulse = false

    // Ring 1: lilac → accent purple (tilted -45°)
    private let ring1Start  = PromptTheme.logoRingHighlight.opacity(0.85)
    private let ring1Mid    = PromptTheme.logoRingSoft
    private let ring1End    = PromptTheme.orbAccent

    // Ring 2: accent2 → violet (tilted +45°)
    private let ring2Start  = PromptTheme.orbAccentLight
    private let ring2Mid    = PromptTheme.orbAccent
    private let ring2End    = PromptTheme.orbAccentMuted

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let cx     = geo.size.width  / 2
            let cy     = geo.size.height / 2
            let rx: CGFloat = size * 0.435   // ring half-width
            let ry: CGFloat = size * 0.148   // ring half-height (flattening)

            ZStack {
                // ── ambient outer glow ──────────────────────────────────────
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                PromptTheme.orbAccent.opacity(pulse ? 0.11 : 0.07),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.52
                        )
                    )
                    .frame(width: size, height: size)
                    .position(x: cx, y: cy)
                    .blur(radius: size * 0.06)

                // ── ring 1 — glow pass (blurred, low opacity) ──────────────
                EllipseRing(rx: rx, ry: ry)
                    .stroke(PromptTheme.logoRingSoft.opacity(0.20), lineWidth: size * 0.058)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .rotationEffect(.degrees(-45))
                    .blur(radius: size * 0.025)

                // ── ring 1 — sharp pass ─────────────────────────────────────
                EllipseRing(rx: rx, ry: ry)
                    .stroke(
                        AngularGradient(
                            colors: [ring1Start, ring1Mid, ring1End, ring1Mid, ring1Start],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: size * 0.026, lineCap: .round)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .rotationEffect(.degrees(-45))

                // ── ring 1 — shimmer dash ───────────────────────────────────
                EllipseRing(rx: rx, ry: ry)
                    .stroke(
                        PromptTheme.logoRingHighlight.opacity(0.45),
                        style: StrokeStyle(lineWidth: size * 0.007, lineCap: .round,
                                           dash: [size * 0.12, size * 0.88])
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .rotationEffect(.degrees(-45))

                // ── ring 2 — glow pass ──────────────────────────────────────
                EllipseRing(rx: rx, ry: ry)
                    .stroke(PromptTheme.orbAccentLight.opacity(0.18), lineWidth: size * 0.058)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .rotationEffect(.degrees(45))
                    .blur(radius: size * 0.025)

                // ── ring 2 — sharp pass ─────────────────────────────────────
                EllipseRing(rx: rx, ry: ry)
                    .stroke(
                        AngularGradient(
                            colors: [ring2Start, ring2Mid, ring2End, ring2Mid, ring2Start],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: size * 0.026, lineCap: .round)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .rotationEffect(.degrees(45))

                // ── ring 2 — shimmer dash ───────────────────────────────────
                EllipseRing(rx: rx, ry: ry)
                    .stroke(
                        PromptTheme.logoRingSoft.opacity(0.35),
                        style: StrokeStyle(lineWidth: size * 0.007, lineCap: .round,
                                           dash: [size * 0.10, size * 0.90],
                                           dashPhase: size * 0.30)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .rotationEffect(.degrees(45))

                // ── centre — soft purple glow only (no orange burst) ────────
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                PromptTheme.logoRingSoft.opacity(0.75),
                                PromptTheme.orbAccentLight.opacity(0.40),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.10
                        )
                    )
                    .frame(width: size * 0.18, height: size * 0.18)
                    .position(x: cx, y: cy)
                    .blur(radius: size * 0.04)
                    .scaleEffect(pulse ? 1.08 : 0.95)

                // tiny bright core dot
                Circle()
                    .fill(PromptTheme.logoRingHighlight.opacity(0.80))
                    .frame(width: size * 0.030, height: size * 0.030)
                    .position(x: cx, y: cy)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 3.2)
                .repeatForever(autoreverses: true)
            ) { pulse = true }
        }
    }
}

/// A centred ellipse ring Shape — draws an ellipse centred in its frame.
private struct EllipseRing: Shape {
    let rx: CGFloat
    let ry: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        p.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        return p
    }
}

#Preview {
    ZStack {
        PromptTheme.previewBackground.ignoresSafeArea()
        OrbitLogoView()
            .frame(width: 200, height: 200)
    }
}
