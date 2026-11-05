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

    static func requestPermission(completion: ((Bool) -> Void)? = nil) {
        configure()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    /// Request authorization if needed, then invoke `onReady` on the main queue.
    static func ensureAuthorized(then onReady: @escaping () -> Void) {
        configure()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    onReady()
                case .notDetermined:
                    requestPermission { _ in onReady() }
                case .denied:
                    onReady() // still start timer; scheduled notify may be silent
                @unknown default:
                    onReady()
                }
            }
        }
    }

    static func scheduleFinish(at endAt: Date, title: String, body: String) {
        cancelFinish()
        configure()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        if #available(iOS 15.0, *) {
            content.relevanceScore = 1.0
        }

        // Prefer absolute calendar trigger (more reliable across background / lock screen).
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: finishId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { error in
            if error != nil {
                // Fallback: relative interval
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

    /// Immediate local banner (e.g. when finish is handled in-foreground).
    static func presentNow(title: String, body: String) {
        configure()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.15, repeats: false)
        let req = UNNotificationRequest(
            identifier: "\(finishId).now.\(UUID().uuidString)",
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

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
