import Foundation

enum I18n {
    static func resolve(catalog: SharedCatalog, saved: String, preferredLanguages: [String]) -> String {
        if let hit = match(catalog, saved) { return hit }
        for tag in preferredLanguages {
            if let hit = match(catalog, tag) { return hit }
        }
        return catalog.defaultLocale
    }

    private static func match(_ catalog: SharedCatalog, _ tag: String) -> String? {
        let lower = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        if lower.isEmpty { return nil }
        if catalog.localeCodes.contains(lower) { return lower }
        let parts = lower.split(separator: "-").map(String.init)
        let base = parts.first?.lowercased() ?? ""
        let region = parts.count > 1 ? parts[1].uppercased() : ""
        if base == "zh" {
            if ["TW", "HK", "MO"].contains(region) || lower.lowercased().contains("hant") {
                return "zh-TW"
            }
            return "zh-CN"
        }
        if catalog.localeCodes.contains(base) { return base }
        return nil
    }
}
