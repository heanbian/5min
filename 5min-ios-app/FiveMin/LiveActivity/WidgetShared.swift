import Foundation

/// App Group bridge for Home Widget today-count + optional pending scene.
enum WidgetShared {
    static let appGroupId = "group.chat.5min.app"
    static let todayCountKey = "widget.todayCount"
    static let pendingSceneKey = "widget.pendingSceneId"
    static let urlScheme = "fiveMin"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }

    static func setTodayCount(_ count: Int) {
        defaults.set(count, forKey: todayCountKey)
    }

    static var todayCount: Int {
        defaults.integer(forKey: todayCountKey)
    }

    static func setPendingScene(_ id: String?) {
        if let id, !id.isEmpty {
            defaults.set(id, forKey: pendingSceneKey)
        } else {
            defaults.removeObject(forKey: pendingSceneKey)
        }
    }

    static func takePendingScene() -> String? {
        let id = defaults.string(forKey: pendingSceneKey)
        defaults.removeObject(forKey: pendingSceneKey)
        guard let id, !id.isEmpty else { return nil }
        return id
    }

    static func startURL(scene: String = "toilet") -> URL {
        var comps = URLComponents()
        comps.scheme = urlScheme
        comps.host = "start"
        comps.queryItems = [URLQueryItem(name: "scene", value: scene)]
        return comps.url ?? URL(string: "\(urlScheme)://start?scene=\(scene)")!
    }

    static func sceneId(from url: URL) -> String? {
        guard let scheme = url.scheme, scheme.caseInsensitiveCompare(urlScheme) == .orderedSame else {
            return nil
        }
        let host = (url.host ?? "").lowercased()
        if host == "start" || url.path.contains("start") {
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let scene = comps.queryItems?.first(where: { $0.name == "scene" })?.value,
               isPlausibleSceneId(scene) {
                return scene
            }
            return "toilet"
        }
        return nil
    }

    /// Catalog ids (`toilet`) or custom ids (`custom_<uuid>`); reject arbitrary query junk.
    static func isPlausibleSceneId(_ raw: String) -> Bool {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.count <= 64 else { return false }
        if id.hasPrefix("custom_") {
            let rest = String(id.dropFirst("custom_".count))
            return rest.range(of: #"^[0-9a-fA-F-]{36}$"#, options: .regularExpression) != nil
        }
        return id.range(of: #"^[a-z][a-z0-9_]{0,47}$"#, options: .regularExpression) != nil
    }
}
