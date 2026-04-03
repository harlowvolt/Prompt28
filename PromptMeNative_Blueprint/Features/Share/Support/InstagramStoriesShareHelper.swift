import UIKit

enum ShareCardError: LocalizedError {
    case renderFailed
    case instagramUnavailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Couldn't create the share card."
        case .instagramUnavailable:
            return "Instagram Stories isn't available on this device."
        case .saveFailed:
            return "Couldn't save the share card to Photos."
        }
    }
}

enum InstagramStoriesShareHelper {
    private static let scheme = "instagram-stories://share"
    private static let backgroundImageKey = "com.instagram.sharedSticker.backgroundImage"

    static var canShareToStories: Bool {
        guard let url = URL(string: scheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    @MainActor
    static func share(backgroundImage: UIImage) throws {
        guard let url = URL(string: scheme), canShareToStories else {
            throw ShareCardError.instagramUnavailable
        }

        guard let pngData = backgroundImage.pngData() else {
            throw ShareCardError.renderFailed
        }

        UIPasteboard.general.setItems(
            [[backgroundImageKey: pngData]],
            options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
        )

        UIApplication.shared.open(url)
    }
}
