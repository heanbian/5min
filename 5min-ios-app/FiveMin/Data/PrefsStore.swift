import Foundation

final class PrefsStore {
    private let defaults = UserDefaults.standard
    private let localeKey = "5min.locale"
    private let ambientKey = "5min.ambient"
    private let statsDayKey = "5min.stats.day"
    private let statsCountKey = "5min.stats.count"
    private let statsMsKey = "5min.stats.ms"

    var locale: String {
        get { defaults.string(forKey: localeKey) ?? "" }
        set { defaults.set(newValue, forKey: localeKey) }
    }

    var ambient: String {
        get { defaults.string(forKey: ambientKey) ?? "off" }
        set { defaults.set(newValue, forKey: ambientKey) }
    }

    private var todayKey: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func todayStats() -> (count: Int, ms: Int64) {
        if defaults.string(forKey: statsDayKey) != todayKey {
            return (0, 0)
        }
        return (defaults.integer(forKey: statsCountKey), Int64(defaults.integer(forKey: statsMsKey)))
    }

    func recordSession(elapsedMs: Int64) {
        let day = todayKey
        if defaults.string(forKey: statsDayKey) != day {
            defaults.set(day, forKey: statsDayKey)
            defaults.set(1, forKey: statsCountKey)
            defaults.set(Int(max(0, elapsedMs)), forKey: statsMsKey)
        } else {
            defaults.set(defaults.integer(forKey: statsCountKey) + 1, forKey: statsCountKey)
            defaults.set(defaults.integer(forKey: statsMsKey) + Int(max(0, elapsedMs)), forKey: statsMsKey)
        }
    }
}
