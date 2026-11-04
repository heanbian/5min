import Foundation

struct SceneGroupDTO: Codable, Identifiable {
    let id: String
    let labelKey: String
}

struct SceneDTO: Codable, Identifiable {
    let id: String
    let min: Int
    let group: String
    let labelKey: String
    let titleKey: String
}

struct ScenesFile: Codable {
    let presetsMin: [Int]
    let defaultMin: Int
    let alertDurationMs: Int
    let vibratePatternMs: [Int]
    let groups: [SceneGroupDTO]
    let scenes: [SceneDTO]
    let localeCodes: [String]
    let defaultLocale: String
}

final class SharedCatalog {
    let presetsMin: [Int]
    let defaultMin: Int
    let alertDurationMs: Int
    let vibratePatternMs: [Int]
    let groups: [SceneGroupDTO]
    let scenes: [SceneDTO]
    let localeCodes: [String]
    let defaultLocale: String
    private let localeMaps: [String: [String: String]]

    init() {
        let scenesURL = Bundle.main.url(forResource: "scenes", withExtension: "json", subdirectory: "shared")
        guard let scenesURL,
              let scenesData = try? Data(contentsOf: scenesURL),
              let root = try? JSONDecoder().decode(ScenesFile.self, from: scenesData) else {
            self.presetsMin = [3, 5, 10]
            self.defaultMin = 5
            self.alertDurationMs = 5000
            self.vibratePatternMs = []
            self.groups = []
            self.scenes = []
            self.localeCodes = ["zh-CN", "en"]
            self.defaultLocale = "zh-CN"
            self.localeMaps = [:]
            return
        }

        var maps: [String: [String: String]] = [:]
        for code in root.localeCodes {
            let url = Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "shared/locales")
            if let url,
               let data = try? Data(contentsOf: url),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var flat: [String: String] = [:]
                for (k, v) in obj {
                    flat[k] = "\(v)"
                }
                maps[code] = flat
            }
        }

        self.presetsMin = root.presetsMin
        self.defaultMin = root.defaultMin
        self.alertDurationMs = root.alertDurationMs
        self.vibratePatternMs = root.vibratePatternMs
        self.groups = root.groups
        self.scenes = root.scenes
        self.localeCodes = root.localeCodes
        self.defaultLocale = root.defaultLocale
        self.localeMaps = maps
    }

    func t(_ locale: String, _ key: String, _ vars: [String: String] = [:]) -> String {
        let pack = localeMaps[locale] ?? localeMaps[defaultLocale] ?? [:]
        var text = pack[key] ?? localeMaps[defaultLocale]?[key] ?? key
        for (k, v) in vars {
            text = text.replacingOccurrences(of: "{\(k)}", with: v)
        }
        return text
    }
}
