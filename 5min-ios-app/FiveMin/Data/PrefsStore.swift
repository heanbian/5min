import Foundation

struct CustomScene: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var min: Int

    static let groupId = "custom"
    static let idPrefix = "custom_"
    static let maxCount = 30
    static let maxNameLength = 24

    static func makeId() -> String {
        "\(idPrefix)\(UUID().uuidString.lowercased())"
    }

    static func clampMinutes(_ value: Int) -> Int {
        Swift.max(1, Swift.min(120, value))
    }

    static func normalizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxNameLength { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxNameLength)
        return String(trimmed[..<end])
    }
}

/// App settings only; session history lives in HistoryStore (SQLite).
final class PrefsStore {
    private let defaults = UserDefaults.standard
    private let localeKey = "5min.locale"
    private let ambientKey = "5min.ambient"
    private let customMinKey = "5min.custom_min"
    private let customScenesKey = "5min.custom_scenes"
    private let customScenesMigratedKey = "5min.custom_scenes_migrated"
    private let privacyKey = "5min.privacy_accepted"
    private let finishToneKey = "5min.finish_tone"
    private let finishVibrateKey = "5min.finish_vibrate"
    private let finishNotifyKey = "5min.finish_notify"

    var locale: String {
        get { defaults.string(forKey: localeKey) ?? "" }
        set { defaults.set(newValue, forKey: localeKey) }
    }

    var ambient: String {
        get { defaults.string(forKey: ambientKey) ?? "off" }
        set { defaults.set(newValue, forKey: ambientKey) }
    }

    var privacyAccepted: Bool {
        get { defaults.bool(forKey: privacyKey) }
        set { defaults.set(newValue, forKey: privacyKey) }
    }

    func customMin(fallback: Int = 5) -> Int {
        let n = defaults.object(forKey: customMinKey) as? Int ?? fallback
        if n < 1 { return fallback }
        return Swift.min(120, n)
    }

    func setCustomMin(_ value: Int) {
        defaults.set(CustomScene.clampMinutes(value), forKey: customMinKey)
    }

    func customScenes() -> [CustomScene] {
        guard let data = defaults.data(forKey: customScenesKey),
              let list = try? JSONDecoder().decode([CustomScene].self, from: data) else {
            return []
        }
        return list
            .map { scene in
                CustomScene(
                    id: scene.id.isEmpty ? CustomScene.makeId() : scene.id,
                    name: CustomScene.normalizedName(scene.name),
                    min: CustomScene.clampMinutes(scene.min)
                )
            }
            .filter { !$0.name.isEmpty }
            .prefix(CustomScene.maxCount)
            .map { $0 }
    }

    func setCustomScenes(_ scenes: [CustomScene]) {
        let cleaned = scenes
            .map { scene in
                CustomScene(
                    id: scene.id.isEmpty ? CustomScene.makeId() : scene.id,
                    name: CustomScene.normalizedName(scene.name),
                    min: CustomScene.clampMinutes(scene.min)
                )
            }
            .filter { !$0.name.isEmpty }
            .prefix(CustomScene.maxCount)
            .map { $0 }
        if let data = try? JSONEncoder().encode(Array(cleaned)) {
            defaults.set(data, forKey: customScenesKey)
        }
        markCustomScenesMigrated()
    }

    var customScenesMigrated: Bool {
        defaults.bool(forKey: customScenesMigratedKey)
    }

    func markCustomScenesMigrated() {
        defaults.set(true, forKey: customScenesMigratedKey)
    }

    var finishTone: Bool {
        get {
            if let value = defaults.object(forKey: finishToneKey) as? Bool {
                return value
            }
            return ambient != "off"
        }
        set { defaults.set(newValue, forKey: finishToneKey) }
    }

    var finishVibrate: Bool {
        get {
            if defaults.object(forKey: finishVibrateKey) == nil { return true }
            return defaults.bool(forKey: finishVibrateKey)
        }
        set { defaults.set(newValue, forKey: finishVibrateKey) }
    }

    var finishNotify: Bool {
        get {
            if defaults.object(forKey: finishNotifyKey) == nil { return true }
            return defaults.bool(forKey: finishNotifyKey)
        }
        set { defaults.set(newValue, forKey: finishNotifyKey) }
    }
}
