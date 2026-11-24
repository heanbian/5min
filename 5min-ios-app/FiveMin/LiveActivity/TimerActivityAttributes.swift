import ActivityKit
import Foundation

public struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var endAt: Date
        public var remainMs: Int64
        public var running: Bool
        public var sceneTitle: String

        public init(endAt: Date, remainMs: Int64, running: Bool, sceneTitle: String) {
            self.endAt = endAt
            self.remainMs = remainMs
            self.running = running
            self.sceneTitle = sceneTitle
        }
    }

    public var sceneId: String
    public var sceneTitle: String

    public init(sceneId: String, sceneTitle: String) {
        self.sceneId = sceneId
        self.sceneTitle = sceneTitle
    }
}
