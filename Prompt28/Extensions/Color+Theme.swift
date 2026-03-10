import SwiftUI

extension Color {
    static let midnightBlack = Color(red: 0.02, green: 0.03, blue: 0.10)
    static let deepIndigo = Color(red: 0.05, green: 0.07, blue: 0.22)
    static let orbGlowBlue = Color(red: 0.79, green: 0.87, blue: 1.00)
    static let orbCoreMid = Color(red: 0.09, green: 0.11, blue: 0.27)
    static let orbCoreDark = Color(red: 0.03, green: 0.05, blue: 0.16)
}

extension LinearGradient {
    static let neonBorder = LinearGradient(
        colors: [Color.white.opacity(0.30), Color.white.opacity(0.16)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

enum PromptMode: String, CaseIterable, Identifiable {
    case ai = "AI Mode"
    case human = "Human Mode"

    var id: String { rawValue }
}
