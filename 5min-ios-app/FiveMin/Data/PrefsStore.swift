import Foundation

/// App settings only; session history lives in HistoryStore (SQLite).
final class PrefsStore {
    private let defaults = UserDefaults.standard
    private let localeKey = "5min.locale"
    private let ambientKey = "5min.ambient"
    private let customMinKey = "5min.custom_min"
    private let privacyKey = "5min.privacy_accepted"

    var locale: String {
        get { defaults.string(forKey: localeKey) ?? "" }
        set { defaults.set(newValue, forKey: localeKey) }
    }

    var ambient: String {
        get { defaults.string(forKey: ambientKey) ?? "off" }
        set { defaults.set(newValue, forKey: ambientKey) }
    }

    var privacyAccepted: Bool {
        get { defaults.bool(forKey: privacyKey) }
        set { defaults.set(newValue, forKey: privacyKey) }
    }

    func customMin(fallback: Int = 5) -> Int {
        let n = defaults.object(forKey: customMinKey) as? Int ?? fallback
        if n < 1 { return fallback }
        return Swift.min(120, n)
    }

    func setCustomMin(_ value: Int) {
        defaults.set(Swift.max(1, Swift.min(120, value)), forKey: customMinKey)
    }
}
