import ActivityKit
import Foundation

/// Starts / updates / ends the timer Live Activity (Lock Screen + Dynamic Island).
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<TimerActivityAttributes>?

    private init() {}

    func start(sceneId: String, sceneTitle: String, endAt: Date, remainMs: Int64) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let attributes = TimerActivityAttributes(
            sceneId: sceneId.isEmpty ? "toilet" : sceneId,
            sceneTitle: sceneTitle
        )
        let state = TimerActivityAttributes.ContentState(
            endAt: endAt,
            remainMs: remainMs,
            running: true,
            sceneTitle: sceneTitle
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endAt),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func update(endAt: Date, remainMs: Int64, running: Bool, sceneTitle: String) {
        guard let activity else { return }
        let state = TimerActivityAttributes.ContentState(
            endAt: endAt,
            remainMs: remainMs,
            running: running,
            sceneTitle: sceneTitle
        )
        Task {
            await activity.update(.init(state: state, staleDate: running ? endAt : nil))
        }
    }

    func end() {
        activity = nil
        Task {
            for item in Activity<TimerActivityAttributes>.activities {
                await item.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
