import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set from FiveMinApp so deep links reach TimerViewModel.
    static var onOpenURL: ((URL) -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationService.configure()
        if let url = launchOptions?[.url] as? URL {
            ShortcutPending.offer(url: url)
        }
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        ShortcutPending.offer(url: url)
        Self.onOpenURL?(url)
        return true
    }
}
