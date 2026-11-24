import AppIntents
import Foundation

/// iOS 18+: open via `OpenURLIntent` and queue the toilet scene in the App Group.
struct StartToiletIntent: AppIntent {
    static var title: LocalizedStringResource = "Start toilet timer"
    static var description = IntentDescription("Opens 5min and queues the toilet scene.")

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
                "Start toilet timer in \(.applicationName)",
                "Start \(.applicationName) toilet"
            ],
            shortTitle: "Start toilet",
            systemImageName: "timer"
        )
    }
}
