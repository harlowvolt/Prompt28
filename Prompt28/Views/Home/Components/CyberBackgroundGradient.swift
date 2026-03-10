import SwiftUI

struct CyberBackgroundGradient: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack {
                LinearGradient(
                    colors: [Color.midnightBlack, Color.deepIndigo, Color.midnightBlack],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(spacing: width * 0.12) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 80, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.01)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: width * 0.12)
                            .blur(radius: 16)
                    }
                }
                .padding(.horizontal, width * 0.04)
                .opacity(0.22)

                RadialGradient(
                    colors: [Color.orbGlowBlue.opacity(0.26), .clear],
                    center: UnitPoint(x: 0.5, y: 0.38),
                    startRadius: 20,
                    endRadius: 380
                )
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }
}
