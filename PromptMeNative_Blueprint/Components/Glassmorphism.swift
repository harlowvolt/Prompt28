import SwiftUI

// MARK: - Glassmorphism Components

/// A glassmorphic container view with blur, gradient overlay, and subtle border
struct GlassContainer<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 24
    var blurRadius: CGFloat = 20
    var opacity: Double = 0.15
    
    init(
        cornerRadius: CGFloat = 24,
        blurRadius: CGFloat = 20,
        opacity: Double = 0.15,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.blurRadius = blurRadius
        self.opacity = opacity
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
    }
}

/// A glassmorphic button with tap feedback
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    @State private var isPressed = false
    
    init(
        title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .pressEvents {
            withAnimation { isPressed = true }
        } onRelease: {
            withAnimation { isPressed = false }
        }
    }
}

/// A glassmorphic card for displaying content
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    
    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

/// A floating glass orb for decorative purposes
struct GlassOrb: View {
    var size: CGFloat = 120
    var color: Color = .purple
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.6),
                        color.opacity(0.2),
                        color.opacity(0.05)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: size
                )
            )
            .overlay(
                Circle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: 10)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Press Events Modifier

private struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Preview

#Preview("Glassmorphism") {
    ZStack {
        // Background gradient
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 24) {
                GlassOrb(size: 100, color: .purple)
                
                GlassContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Glass Container")
                            .font(.title2.bold())
                        Text("This is a glassmorphic container with blur and subtle border effects.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Quick Action", systemImage: "bolt.fill")
                            .font(.headline)
                        Text("Perform a quick action with this glass card.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                GlassButton(title: "Get Started", icon: "arrow.right") {}
            }
            .padding()
        }
    }
}
