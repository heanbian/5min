import Foundation

/// On-device scene ranking from local session history (shared rules across clients).
enum SceneRanker {
    static let groupId = "suggested"
    static let labelKey = "sceneGroupSuggested"
    static let topN = 6
    static let chipN = 5
    static let minCount = 2
    static let recentDays = 3
    static let historyWindowDays = 14
    static let dayMs: Int64 = 24 * 60 * 60 * 1000

    struct SessionRef {
        let sceneId: String
        let at: Int64
    }

    /// Rank known scenes by frequency + recency. Empty when nothing qualifies (cold start).
    static func rank(sessions: [SessionRef], knownIds: Set<String>, nowMs: Int64? = nil) -> [String] {
        let now = nowMs ?? Int64(Date().timeIntervalSince1970 * 1000)
        var countById: [String: Int] = [:]
        var lastAtById: [String: Int64] = [:]
        for session in sessions {
            let id = session.sceneId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, knownIds.contains(id) else { continue }
            countById[id, default: 0] += 1
            if let prev = lastAtById[id] {
                if session.at > prev { lastAtById[id] = session.at }
            } else {
                lastAtById[id] = session.at
            }
        }
        struct Ranked {
            let id: String
            let score: Int
            let lastAt: Int64
        }
        var ranked: [Ranked] = []
        for (id, count) in countById {
            let lastAt = lastAtById[id] ?? 0
            let daysSince = max(0, Int((now - lastAt) / dayMs))
            let qualifies = count >= minCount || daysSince <= recentDays
            guard qualifies else { continue }
            let score = count * 100 + max(0, historyWindowDays - daysSince)
            ranked.append(Ranked(id: id, score: score, lastAt: lastAt))
        }
        ranked.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.lastAt > $1.lastAt
        }
        return Array(ranked.prefix(topN).map(\.id))
    }
}
