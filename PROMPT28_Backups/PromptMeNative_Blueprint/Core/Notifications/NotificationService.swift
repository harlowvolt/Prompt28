import UserNotifications
import UIKit

@MainActor
final class NotificationService {

    // MARK: - Permission

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    // MARK: - Local alerts

    /// Fires a local notification when the user is running low on prompts (≤ 3 remaining).
    static func scheduleLowUsageAlert(remaining: Int) {
        guard remaining <= 3, remaining > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Running low on prompts"
        content.body = "You have \(remaining) prompt\(remaining == 1 ? "" : "s") left this period."
        content.sound = .default

        // Replace any existing low-usage alert so we don't stack duplicates
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["com.prompt28.lowUsage"]
        )

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "com.prompt28.lowUsage",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Badge

    static func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
