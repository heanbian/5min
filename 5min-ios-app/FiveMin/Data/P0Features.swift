import Foundation

/// P0: overtime insight · stand-up ritual · alert profile
enum P0Features {
    static let ritualOff = "off"
    static let ritualBasic = "basic"
    static let profileNormal = "normal"
    static let profileQuiet = "quiet"
    static let profileSilent = "silent"

    private static let overtimeStatsKey = "5min.overtime_stats"
    private static let overtimeInsightKey = "5min.overtime_insight"
    private static let standRitualKey = "5min.stand_ritual"
    private static let alertProfileKey = "5min.alert_profile"

    private static var defaults: UserDefaults { .standard }

    struct OvertimeStats: Equatable {
        var weekKey: String
        var count: Int
        var ms: Int64
    }

    struct FinishAlerts {
        var withTone: Bool
        var withVibrate: Bool
        var withNotify: Bool
    }

    static func weekKey(now: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        let startOfDay = cal.startOfDay(for: now)
        let weekday = cal.component(.weekday, from: startOfDay) // 1=Sun … 7=Sat
        let diff = weekday == 1 ? -6 : 2 - weekday
        guard let monday = cal.date(byAdding: .day, value: diff, to: startOfDay) else {
            return "1970-01-01"
        }
        let y = cal.component(.year, from: monday)
        let m = cal.component(.month, from: monday)
        let d = cal.component(.day, from: monday)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func readOvertimeStats() -> OvertimeStats {
        let key = weekKey()
        guard let raw = defaults.dictionary(forKey: overtimeStatsKey) else {
            return OvertimeStats(weekKey: key, count: 0, ms: 0)
        }
        let storedKey = raw["weekKey"] as? String ?? ""
        if storedKey != key {
            return OvertimeStats(weekKey: key, count: 0, ms: 0)
        }
        let count = max(0, (raw["count"] as? Int) ?? Int(raw["count"] as? Int64 ?? 0))
        let ms: Int64
        if let v = raw["ms"] as? Int64 {
            ms = max(0, v)
        } else if let v = raw["ms"] as? Int {
            ms = max(0, Int64(v))
        } else if let v = raw["ms"] as? Double {
            ms = max(0, Int64(v))
        } else {
            ms = 0
        }
        return OvertimeStats(weekKey: storedKey, count: count, ms: ms)
    }

    @discardableResult
    static func recordOvertime(_ overtimeMs: Int64) -> OvertimeStats {
        let ms = max(0, overtimeMs)
        if ms <= 0 { return readOvertimeStats() }
        let cur = readOvertimeStats()
        let next = OvertimeStats(
            weekKey: weekKey(),
            count: cur.count + 1,
            ms: cur.ms + ms
        )
        writeOvertimeStats(next)
        return next
    }

    private static func writeOvertimeStats(_ stats: OvertimeStats) {
        defaults.set(
            [
                "weekKey": stats.weekKey,
                "count": stats.count,
                "ms": stats.ms,
            ] as [String: Any],
            forKey: overtimeStatsKey
        )
    }

    static func getShowOvertimeInsight() -> Bool {
        if defaults.object(forKey: overtimeInsightKey) == nil { return true }
        return defaults.bool(forKey: overtimeInsightKey)
    }

    static func setShowOvertimeInsight(_ on: Bool) {
        defaults.set(on, forKey: overtimeInsightKey)
    }

    static func getStandRitual() -> String {
        let v = defaults.string(forKey: standRitualKey) ?? ritualBasic
        return v == ritualBasic ? ritualBasic : ritualOff
    }

    static func setStandRitual(_ mode: String) {
        defaults.set(mode == ritualBasic ? ritualBasic : ritualOff, forKey: standRitualKey)
    }

    static func getAlertProfile() -> String {
        let v = defaults.string(forKey: alertProfileKey) ?? profileNormal
        if v == profileQuiet || v == profileSilent { return v }
        return profileNormal
    }

    static func setAlertProfile(_ mode: String) {
        let next: String
        if mode == profileQuiet || mode == profileSilent {
            next = mode
        } else {
            next = profileNormal
        }
        defaults.set(next, forKey: alertProfileKey)
    }

    static func resolveFinishAlerts(
        finishTone: Bool,
        finishVibrate: Bool,
        finishNotify: Bool
    ) -> FinishAlerts {
        var withTone = finishTone
        var withVibrate = finishVibrate
        let withNotify = finishNotify
        let profile = getAlertProfile()
        if profile == profileQuiet {
            withTone = false
        } else if profile == profileSilent {
            withTone = false
            withVibrate = false
        }
        return FinishAlerts(withTone: withTone, withVibrate: withVibrate, withNotify: withNotify)
    }

    static func insightMinutes(_ ms: Int64) -> Int {
        max(1, Int(ceil(Double(max(0, ms)) / 60_000.0)))
    }
}
