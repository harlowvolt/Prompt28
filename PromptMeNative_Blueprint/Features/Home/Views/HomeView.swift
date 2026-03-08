import SwiftUI

struct HomeView: View {
    @State private var orbScale: CGFloat = 1.0
    @State private var orbGlow = false
    @State private var statusText = "Tap the orb"

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("Prompt28")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)

                Text(statusText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        orbScale = 0.92
                        statusText = "Listening..."
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            orbScale = 1.0
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.blue.opacity(0.9),
                                        Color.purple.opacity(0.5),
                                        Color.black.opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 200
                                )
                            )
                            .frame(width: 260, height: 260)
                            .scaleEffect(orbGlow ? 1.2 : 0.9)
                            .animation(
                                .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                                value: orbGlow
                            )

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Color.blue,
                                        Color.purple
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 170, height: 170)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .blue.opacity(0.45), radius: 24)
                    }
                    .scaleEffect(orbScale)
                }
                .buttonStyle(.plain)
                .onAppear {
                    orbGlow = true
                }

                Text("Native orb placeholder")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}
