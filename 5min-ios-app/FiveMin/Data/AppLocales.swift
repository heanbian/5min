import Foundation

enum AppLocales {
    static let supported: [String] = ["zh-CN", "zh-TW", "en", "fr", "ru", "es", "ar", "de", "bo", "ja", "ko", "pt", "id"]

    static func isSupported(_ code: String) -> Bool {
        supported.contains(code)
    }

    static func normalize(_ code: String, fallback: String = "zh-CN") -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        if isSupported(trimmed) { return trimmed }
        if trimmed.isEmpty { return fallback }
        let parts = trimmed.split(separator: "-").map(String.init)
        let base = parts.first?.lowercased() ?? ""
        let region = parts.count > 1 ? parts[1].uppercased() : ""
        if base == "zh" {
            if ["TW", "HK", "MO"].contains(region) || trimmed.lowercased().contains("hant") {
                return "zh-TW"
            }
            return "zh-CN"
        }
        if ["en", "fr", "ru", "es", "ar", "de", "bo", "ja", "ko", "pt", "id"].contains(base), isSupported(base) {
            return base
        }
        return fallback
    }

    static func filter(_ codes: [String]) -> [String] {
        let hit = supported.filter { codes.contains($0) }
        return hit.isEmpty ? supported : hit
    }
}
