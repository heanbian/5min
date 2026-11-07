import Foundation
import SwiftUI
import Combine

enum TimerPhase {
    case idle, running, paused, warn, done
}

@MainActor
final class TimerViewModel: ObservableObject {
    let catalog = SharedCatalog()
    private let prefs = PrefsStore()
    private let history = HistoryStore.shared

    @Published var locale: String = "zh-CN"
    @Published var totalMs: Int64 = 5 * 60 * 1000
    @Published var remainMs: Int64 = 5 * 60 * 1000
    @Published var running = false
    @Published var finished = false
    @Published var activeSceneId: String?
    @Published var ambient: String = "off"
    @Published var statsCount = 0
    @Published var statsMs: Int64 = 0
    @Published var phase: TimerPhase = .idle
    @Published var privacyAccepted = false
    @Published var customMin = 5
    @Published var recordsEpoch = 0
    @Published var pendingCustomMin: Int?
    /// 0 records · 1 home · 2 mine
    @Published var selectedTab = 1

    private var endAt: Date?
    private var tick: AnyCancellable?
    private var finishedHandled = false

    var progress: CGFloat {
        guard totalMs > 0 else { return 0 }
        return CGFloat(remainMs) / CGFloat(totalMs)
    }

    var alertSoundOn: Bool { ambient != "off" }

    var appLocaleCodes: [String] {
        AppLocales.filter(catalog.localeCodes)
    }

    func bootstrap() {
        NotificationService.configure()
        privacyAccepted = prefs.privacyAccepted
        let saved = prefs.locale
        locale = I18n.resolve(
            catalog: catalog,
            saved: saved,
            preferredLanguages: Locale.preferredLanguages
        )
        if saved != locale { prefs.locale = locale }
        ambient = prefs.ambient
        customMin = prefs.customMin(fallback: catalog.defaultMin)
        let total = Int64(customMin) * 60_000
        totalMs = total
        remainMs = total
        refreshTodayStats()
        refreshPhase()
        // Store-screenshot launches must stay free of the system notification prompt.
        if privacyAccepted, !Self.isStoreScreenshotLaunch {
            NotificationService.requestPermission()
        }
        applyStoreScreenshotSceneIfNeeded()
    }

    private static var isStoreScreenshotLaunch: Bool {
        ProcessInfo.processInfo.environment["FIVEMIN_SCREENSHOT"] != nil
    }

    /// DEBUG-only: drive UI for `scripts/capture_store_screenshots.sh` via `FIVEMIN_SCREENSHOT`.
    private func applyStoreScreenshotSceneIfNeeded() {
#if DEBUG
        guard let scene = ProcessInfo.processInfo.environment["FIVEMIN_SCREENSHOT"] else { return }
        privacyAccepted = true
        prefs.privacyAccepted = true
        switch scene {
        case "home":
            selectedTab = 1
            setPreset(minutes: 5, sceneId: "toilet")
        case "running":
            selectedTab = 1
            setPreset(minutes: 5, sceneId: "toilet")
            // Defer so the first frame paints before the countdown starts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.remainMs = 3 * 60_000 + 42_000
                self.start()
            }
        case "warn":
            selectedTab = 1
            setPreset(minutes: 5, sceneId: "toilet")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.remainMs = 42_000
                self.start()
            }
        case "records":
            seedStoreScreenshotHistory()
            refreshTodayStats()
            selectedTab = 0
            recordsEpoch += 1
        case "mine":
            selectedTab = 2
        default:
            break
        }
#endif
    }

#if DEBUG
    private func seedStoreScreenshotHistory() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let samples: [(offsetMs: Int64, minutes: Int, scene: String)] = [
            (30 * 60_000, 5, "toilet"),
            (3 * 60 * 60_000, 3, "brush"),
            (26 * 60 * 60_000, 5, "tea"),
            (50 * 60 * 60_000, 10, "coffee"),
        ]
        for sample in samples {
            history.insertDemoSession(
                at: now - sample.offsetMs,
                minutes: sample.minutes,
                sceneId: sample.scene
            )
        }
    }
#endif

    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        catalog.t(locale, key, vars)
    }

    func acceptPrivacy() {
        privacyAccepted = true
        prefs.privacyAccepted = true
        NotificationService.requestPermission()
    }

    func setLocale(_ code: String) {
        let value = AppLocales.normalize(
            I18n.resolve(catalog: catalog, saved: code, preferredLanguages: [code])
        )
        locale = value
        prefs.locale = value
    }

    func setAmbient(_ mode: String) {
        ambient = mode
        prefs.ambient = mode
        if mode == "off" {
            AlertService.shared.stop()
        }
    }

    func applyCustomMinutes(_ minutes: Int) {
        let n = Swift.max(1, Swift.min(120, minutes))
        customMin = n
        prefs.setCustomMin(n)
        pendingCustomMin = n
    }

    func consumePendingCustomMin() {
        guard let pending = pendingCustomMin, !running else { return }
        pendingCustomMin = nil
        setPreset(minutes: pending, sceneId: nil)
    }

    func refreshTodayStats() {
        let stats = history.todayStats()
        statsCount = stats.count
        statsMs = stats.ms
    }

    func setPreset(minutes: Int, sceneId: String?) {
        guard !running else { return }
        finishedHandled = false
        let total = Int64(max(1, minutes)) * 60_000
        totalMs = total
        remainMs = total
        finished = false
        activeSceneId = sceneId
        refreshPhase()
    }

    func selectScene(_ id: String) {
        guard let scene = catalog.scenes.first(where: { $0.id == id }) else { return }
        setPreset(minutes: scene.min, sceneId: scene.id)
    }

    func toggleStart() {
        if finished && !running {
            remainMs = totalMs
            finished = false
            NotificationService.ensureAuthorized { [weak self] in self?.start() }
            return
        }
        if running {
            pause()
        } else {
            NotificationService.ensureAuthorized { [weak self] in self?.start() }
        }
    }

    func reset() {
        stopTicker()
        NotificationService.cancelFinish()
        AlertService.shared.stop()
        finishedHandled = false
        remainMs = totalMs
        running = false
        finished = false
        UIApplication.shared.isIdleTimerDisabled = false
        refreshPhase()
    }

    func realert() {
        AlertService.shared.play(durationMs: catalog.alertDurationMs, withSound: alertSoundOn)
    }

    private func start() {
        guard remainMs > 0 else { return }
        finishedHandled = false
        let end = Date().addingTimeInterval(Double(remainMs) / 1000.0)
        endAt = end
        running = true
        finished = false
        UIApplication.shared.isIdleTimerDisabled = true
        let vars = notifyVars()
        NotificationService.scheduleFinish(
            at: end,
            title: t("notifyTitle", vars),
            body: t("notifyBody", vars),
            withSound: alertSoundOn
        )
        startTicker()
        refreshPhase()
    }

    private func pause() {
        guard running, let endAt else { return }
        remainMs = max(0, Int64(endAt.timeIntervalSinceNow * 1000))
        running = false
        stopTicker()
        NotificationService.cancelFinish()
        UIApplication.shared.isIdleTimerDisabled = false
        refreshPhase()
    }

    private func startTicker() {
        stopTicker()
        tick = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.onTick()
            }
    }

    private func stopTicker() {
        tick?.cancel()
        tick = nil
    }

    private func onTick() {
        guard running, let endAt else { return }
        let remain = max(0, Int64(endAt.timeIntervalSinceNow * 1000))
        remainMs = remain
        if remain <= 0 {
            handleFinish(fromTicker: true)
            return
        }
        refreshPhase()
    }

    private func handleFinish(fromTicker: Bool) {
        guard !finishedHandled else { return }
        finishedHandled = true
        stopTicker()
        NotificationService.cancelFinish()
        running = false
        finished = true
        remainMs = 0
        UIApplication.shared.isIdleTimerDisabled = false
        history.recordSession(elapsedMs: totalMs, sceneId: activeSceneId ?? "")
        refreshTodayStats()
        recordsEpoch += 1
        if fromTicker {
            let vars = notifyVars()
            NotificationService.presentNow(
                title: t("notifyTitle", vars),
                body: t("notifyBody", vars),
                withSound: alertSoundOn
            )
            AlertService.shared.play(durationMs: catalog.alertDurationMs, withSound: alertSoundOn)
        }
        refreshPhase()
    }

    func sessionMinutes() -> Int {
        max(1, Int((Double(totalMs) / 60_000.0).rounded()))
    }

    func notifySceneName() -> String {
        if let id = activeSceneId,
           let scene = catalog.scenes.first(where: { $0.id == id }) {
            return t(scene.titleKey)
        }
        return t("sceneToiletTitle")
    }

    private func notifyVars() -> [String: String] {
        ["n": "\(sessionMinutes())", "scene": notifySceneName()]
    }

    func format(_ ms: Int64) -> String {
        let totalSec = max(0, ms / 1000)
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d", m, s)
    }

    func statsMinutes() -> Int {
        if statsMs <= 0 { return 0 }
        return max(1, Int((statsMs + 59_999) / 60_000))
    }

    var brandTitle: String {
        if let id = activeSceneId,
           let scene = catalog.scenes.first(where: { $0.id == id }) {
            return t(scene.titleKey)
        }
        return t("brandTitle")
    }

    var statusText: String {
        switch phase {
        case .done: return t("statusDone")
        case .warn: return t("statusWarn")
        case .running: return t("statusRunning")
        case .paused: return t("statusPaused")
        case .idle: return t("statusIdle")
        }
    }

    var startLabel: String {
        if finished && !running { return t("again") }
        if running { return t("pause") }
        if remainMs < totalMs && remainMs > 0 { return t("resume") }
        return t("start")
    }

    private func refreshPhase() {
        if finished || (remainMs <= 0 && !running) {
            phase = .done
        } else if running && remainMs > 0 && remainMs <= 60_000 {
            phase = .warn
        } else if running {
            phase = .running
        } else if remainMs < totalMs {
            phase = .paused
        } else {
            phase = .idle
        }
    }
}
