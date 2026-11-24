import Foundation
import UserNotifications

enum NotificationService {
    static let finishId = "chat.5min.app.timer.finish"

    /// Install delegate so banners also appear while the app is in the foreground.
    static func configure() {
        let center = UNUserNotificationCenter.current()
        if center.delegate == nil {
            center.delegate = NotificationCenterDelegate.shared
        }
    }

    @MainActor
    @discardableResult
    static func requestPermission() async -> Bool {
        configure()
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Request authorization if needed, then return on the main actor.
    @MainActor
    static func ensureAuthorized() async {
        configure()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .notDetermined:
            _ = await requestPermission()
        case .denied:
            return
        @unknown default:
            return
        }
    }

    static func scheduleFinish(at endAt: Date, title: String, body: String, withSound: Bool = true) {
        cancelFinish()
        configure()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = withSound ? .default : nil
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: finishId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { error in
            if error != nil {
                let interval = max(1, endAt.timeIntervalSinceNow)
                let fallback = UNNotificationRequest(
                    identifier: finishId,
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                )
                UNUserNotificationCenter.current().add(fallback)
            }
        }
    }

    static func presentNow(title: String, body: String, withSound: Bool = true) {
        configure()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = withSound ? .default : nil
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.15, repeats: false)
        let req = UNNotificationRequest(
            identifier: "\(finishId).now.\(Int(Date().timeIntervalSince1970 * 1000))",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(req)
    }

    static func cancelFinish() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [finishId])
        center.removeDeliveredNotifications(withIdentifiers: [finishId])
    }
}

private final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
