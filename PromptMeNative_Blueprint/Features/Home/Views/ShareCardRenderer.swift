import SwiftUI
import UIKit

@MainActor
final class ShareCardRenderer {
    static func render(
        rawInput: String,
        generatedPrompt: String,
        modeName: String
    ) -> UIImage? {
        let cleanedPrompt = generatedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedPrompt.isEmpty else { return nil }

        let view = ShareCardView(
            rawInput: rawInput,
            generatedPrompt: cleanedPrompt,
            modeName: modeName
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = .init(CGSize(width: 400, height: 650))

        return renderer.uiImage
    }
}
