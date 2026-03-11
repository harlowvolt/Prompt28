import UIKit

enum ShareCardFileStore {
    static func writePNG(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prompt28-share-card-\(UUID().uuidString).png")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func removeFileIfNeeded(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
