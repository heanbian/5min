import UserNotifications

enum NotificationService {
    static let finishId = "chat.5min.app.timer.finish"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleFinish(at endAt: Date, title: String, body: String) {
        cancelFinish()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let interval = max(1, endAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let req = UNNotificationRequest(identifier: finishId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    static func cancelFinish() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [finishId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [finishId])
    }
}
