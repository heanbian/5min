import Foundation

struct SceneProfile {
    let pin: [String]
    let groupOrder: [String]
    let demoteGroups: [String]
    let hideGroups: [String]
    let hideScenes: [String]
}

/// Locale-specific scene picker profile (pin / order / demote / hide).
/// Source: Resources/shared/locale-scene-profiles.json
enum LocaleSceneProfiles {
    private static let root: [String: Any] = {
        guard let url = Bundle.main.url(
            forResource: "locale-scene-profiles",
            withExtension: "json",
            subdirectory: "shared"
        ),
        let data = try? Data(contentsOf: url),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }()

    private static var cache: [String: SceneProfile] = [:]

    static func resolve(locale: String) -> SceneProfile {
        if let hit = cache[locale] { return hit }
        let base = root["default"] as? [String: Any]
        let over = root[locale] as? [String: Any]
        let profile = SceneProfile(
            pin: stringList(over, "pin") ?? stringList(base, "pin") ?? [],
            groupOrder: stringList(over, "groupOrder") ?? stringList(base, "groupOrder") ?? [],
            demoteGroups: stringList(over, "demoteGroups") ?? stringList(base, "demoteGroups") ?? [],
            hideGroups: stringList(over, "hideGroups") ?? stringList(base, "hideGroups") ?? [],
            hideScenes: stringList(over, "hideScenes") ?? stringList(base, "hideScenes") ?? []
        )
        cache[locale] = profile
        return profile
    }

    static func orderGroups(_ groups: [SceneGroupDTO], profile: SceneProfile) -> [SceneGroupDTO] {
        let hide = Set(profile.hideGroups)
        let demote = Set(profile.demoteGroups)
        let byId = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        var primary: [SceneGroupDTO] = []
        var seen = Set<String>()
        for id in profile.groupOrder {
            if hide.contains(id) || demote.contains(id) || seen.contains(id) { continue }
            guard let g = byId[id] else { continue }
            primary.append(g)
            seen.insert(id)
        }
        for g in groups {
            if hide.contains(g.id) || demote.contains(g.id) || seen.contains(g.id) { continue }
            primary.append(g)
            seen.insert(g.id)
        }
        var demoted: [SceneGroupDTO] = []
        for id in profile.groupOrder {
            if !demote.contains(id) || hide.contains(id) || seen.contains(id) { continue }
            guard let g = byId[id] else { continue }
            demoted.append(g)
            seen.insert(id)
        }
        for g in groups {
            if !demote.contains(g.id) || hide.contains(g.id) || seen.contains(g.id) { continue }
            demoted.append(g)
            seen.insert(g.id)
        }
        return primary + demoted
    }

    static func isSceneHidden(_ sceneId: String, profile: SceneProfile) -> Bool {
        profile.hideScenes.contains(sceneId)
    }

    /// Pin first, then ranked usage ids; unique; capped. Skips hideScenes so topN can still fill.
    static func mergePinnedSuggested(
        ranked: [String],
        pin: [String],
        knownIds: Set<String>,
        topN: Int = SceneRanker.topN,
        hideScenes: Set<String> = []
    ) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        func take(_ id: String) -> Bool {
            guard knownIds.contains(id), !seen.contains(id), !hideScenes.contains(id) else { return false }
            out.append(id)
            seen.insert(id)
            return out.count >= topN
        }
        for id in pin where take(id) { return out }
        for id in ranked where take(id) { return out }
        return out
    }

    private static func stringList(_ obj: [String: Any]?, _ key: String) -> [String]? {
        guard let arr = obj?[key] as? [String] else { return nil }
        return arr
    }
}
