import SwiftUI
import UIKit

enum PromptShareCardRenderer {
    @MainActor
    static func renderImage(
        promptText: String,
        beforeText: String?,
        modeName: String,
        handle: String = "@harlowvolt",
        includeHashtag: Bool = true,
        colorScheme: ColorScheme = .dark,
        scale: CGFloat = 3.0
    ) -> UIImage? {
        let card = PromptShareCard(
            promptText: promptText,
            beforeText: beforeText,
            modeName: modeName,
            handle: handle,
            includeHashtag: includeHashtag
        )
        .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: card)
        renderer.scale = max(scale, 3.0)
        renderer.proposedSize = ProposedViewSize(PromptShareCard.exportSize)

        return renderer.uiImage
    }
}
