import UIKit

/// Centralised haptic feedback. Call from @MainActor contexts only.
enum HapticService {

    /// Physical impact feel — use for taps and toggles.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Success / warning / error notification pulse.
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }

    /// Subtle tick — use for selection changes (mode pills, pickers).
    static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }
}
