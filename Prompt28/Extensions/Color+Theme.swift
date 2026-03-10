import SwiftUI

extension Color {
    static let cyberBlack = Color(red: 0.04, green: 0.02, blue: 0.09)
    static let deepPurple = Color(red: 0.12, green: 0.05, blue: 0.25)
    static let neonPurple = Color(red: 0.78, green: 0.22, blue: 0.98)
    static let neonCyan = Color(red: 0.05, green: 0.92, blue: 0.95)
}

extension LinearGradient {
    static let neonBorder = LinearGradient(
        colors: [.neonPurple, .neonCyan],
        startPoint: .leading,
        endPoint: .trailing
    )
}

enum PromptMode: String, CaseIterable, Identifiable {
    case ai = "AI Mode"
    case human = "Human Mode"

    var id: String { rawValue }
}
