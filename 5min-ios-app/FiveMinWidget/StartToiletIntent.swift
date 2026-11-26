import AppIntents
import Foundation

/// iOS 18+: open via `OpenURLIntent` and queue the toilet scene in the App Group.
struct StartToiletIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Toilet Timer"
    static var description = IntentDescription("Opens Toilet Timer and queues the toilet scene.")

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        WidgetShared.setPendingScene("toilet")
        return .result(opensIntent: OpenURLIntent(WidgetShared.startURL(scene: "toilet")))
    }
}

struct FiveMinAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartToiletIntent(),
            phrases: [
                "Start Toilet Timer in \(.applicationName)",
                "Start \(.applicationName) toilet",
                "用\(.applicationName)开始如厕",
                "打开\(.applicationName)如厕计时"
            ],
            shortTitle: "Start toilet",
            systemImageName: "timer"
        )
    }
}
