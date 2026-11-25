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

enum WidgetCopy {
    static var isZh: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }

    static var brand: String { isZh ? "如厕计时器" : "Toilet Timer" }
    static func todayCount(_ n: Int) -> String {
        isZh ? "今日 \(n) 次" : "Today · \(n)"
    }
    static var startToilet: String { isZh ? "开始如厕" : "Start toilet" }
    static var description: String {
        isZh ? "今日次数与快速开始如厕" : "Today's sessions · tap to start toilet timer"
    }
    static var running: String { isZh ? "倒计时中" : "Countdown" }
    static var paused: String { isZh ? "已暂停" : "Paused" }
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
