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

struct TimerHomeWidget: Widget {
    let kind = "TimerHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerHomeProvider()) { entry in
            TimerHomeWidgetView(entry: entry)
                .widgetURL(WidgetShared.startURL(scene: "toilet"))
        }
        .configurationDisplayName("5min")
        .description("Today's sessions · tap to start toilet timer")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimerHomeWidgetView: View {
    var entry: TimerHomeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("5min")
                .font(.headline.weight(.semibold))
            Text("Today · \(entry.todayCount)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Spacer(minLength: 0)
            Text("Start toilet")
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
