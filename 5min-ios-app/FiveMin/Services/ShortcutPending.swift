import Foundation

/// In-process / deep-link handoff for widget / App Intent scene start (mirrors Android ShortcutPending).
enum ShortcutPending {
    private static let key = "5min.pendingSceneId"
    private static var memory: String?

    static func offer(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        memory = trimmed
        UserDefaults.standard.set(trimmed, forKey: key)
        WidgetShared.setPendingScene(trimmed)
    }

    static func offer(url: URL) {
        if let scene = WidgetShared.sceneId(from: url) {
            offer(scene)
        }
    }

    static func take() -> String? {
        if let mem = memory {
            memory = nil
            UserDefaults.standard.removeObject(forKey: key)
            _ = WidgetShared.takePendingScene()
            return mem
        }
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            _ = WidgetShared.takePendingScene()
            return stored
        }
        return WidgetShared.takePendingScene()
    }
}
