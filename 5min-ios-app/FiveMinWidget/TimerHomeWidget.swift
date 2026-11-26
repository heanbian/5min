import SwiftUI
import WidgetKit

struct TimerHomeEntry: TimelineEntry {
    let date: Date
    let todayCount: Int
}

struct TimerHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerHomeEntry {
        TimerHomeEntry(date: Date(), todayCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerHomeEntry) -> Void) {
        completion(TimerHomeEntry(date: Date(), todayCount: WidgetShared.todayCount))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerHomeEntry>) -> Void) {
        let entry = TimerHomeEntry(date: Date(), todayCount: WidgetShared.todayCount)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// Widget strings from Bundle.main `shared/locales/*.json` (same packs as SharedCatalog).
enum WidgetCopy {
    private static let localeCodes = [
        "zh-CN", "zh-TW", "en", "fr", "ru", "es", "ar", "de", "bo", "ja", "ko", "pt", "id",
    ]
    private static let defaultLocale = "zh-CN"

    private static let pack: [String: String] = {
        loadPack(for: resolveLocale(preferred: Locale.preferredLanguages))
    }()

    static var brand: String { t("brandTitle", fallback: "Toilet Timer") }
    static func todayCount(_ n: Int) -> String {
        t("widgetTodayCount", fallback: "Today · {n}").replacingOccurrences(of: "{n}", with: "\(n)")
    }
    static var startToilet: String { t("widgetStartToilet", fallback: "Start toilet") }
    static var description: String {
        t("widgetDescription", fallback: "Today's sessions · tap to start Toilet Timer")
    }
    static var running: String { t("widgetRunning", fallback: "Countdown") }
    static var paused: String { t("widgetPaused", fallback: "Paused") }

    private static func t(_ key: String, fallback: String) -> String {
        pack[key] ?? fallback
    }

    private static func resolveLocale(preferred: [String]) -> String {
        for tag in preferred {
            if let hit = match(tag) { return hit }
        }
        return defaultLocale
    }

    private static func match(_ tag: String) -> String? {
        let lower = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        if lower.isEmpty { return nil }
        if localeCodes.contains(lower) { return lower }
        let parts = lower.split(separator: "-").map(String.init)
        let base = parts.first?.lowercased() ?? ""
        let region = parts.count > 1 ? parts[1].uppercased() : ""
        if base == "zh" {
            if ["TW", "HK", "MO"].contains(region) || lower.lowercased().contains("hant") {
                return "zh-TW"
            }
            return "zh-CN"
        }
        if base == "en" { return "en" }
        if localeCodes.contains(base) { return base }
        return nil
    }

    private static func loadPack(for code: String) -> [String: String] {
        if let pack = readLocaleJSON(code) { return pack }
        if code != defaultLocale, let pack = readLocaleJSON(defaultLocale) { return pack }
        if let pack = readLocaleJSON("en") { return pack }
        return [:]
    }

    private static func readLocaleJSON(_ code: String) -> [String: String]? {
        let url = Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "shared/locales")
            ?? Bundle.main.url(forResource: code, withExtension: "json")
        guard let url,
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var flat: [String: String] = [:]
        for (k, v) in obj {
            flat[k] = "\(v)"
        }
        return flat
    }
}

struct TimerHomeWidget: Widget {
    let kind = "TimerHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerHomeProvider()) { entry in
            TimerHomeWidgetView(entry: entry)
                .widgetURL(WidgetShared.startURL(scene: "toilet"))
        }
        .configurationDisplayName(WidgetCopy.brand)
        .description(WidgetCopy.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimerHomeWidgetView: View {
    var entry: TimerHomeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WidgetCopy.brand)
                .font(.headline.weight(.semibold))
            Text(WidgetCopy.todayCount(entry.todayCount))
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Spacer(minLength: 0)
            Text(WidgetCopy.startToilet)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 0.93, green: 0.96, blue: 0.94)
        }
    }
}
