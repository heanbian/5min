import ActivityKit
import SwiftUI
import WidgetKit

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.sceneTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.running {
                        Text(timerInterval: Date.now...context.state.endAt, countsDown: true)
                            .monospacedDigit()
                            .frame(width: 64)
                    } else {
                        Text(formatMs(context.state.remainMs))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.running ? "Running" : "Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                if context.state.running {
                    Text(timerInterval: Date.now...max(Date.now, context.state.endAt), countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 52)
                } else {
                    Text(formatMs(context.state.remainMs))
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.sceneTitle)
                    .font(.headline)
                Text(context.state.running ? "Countdown" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if context.state.running {
                Text(timerInterval: Date.now...max(Date.now, context.state.endAt), countsDown: true)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .multilineTextAlignment(.trailing)
            } else {
                Text(formatMs(context.state.remainMs))
                    .font(.title2.monospacedDigit().weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color(red: 0.93, green: 0.96, blue: 0.94))
        .activitySystemActionForegroundColor(Color(red: 0.22, green: 0.35, blue: 0.28))
    }

    private func formatMs(_ ms: Int64) -> String {
        let totalSec = max(0, ms / 1000)
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d", m, s)
    }
}
