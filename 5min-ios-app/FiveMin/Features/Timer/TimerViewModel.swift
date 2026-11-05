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

    private var endAt: Date?
    private var tick: AnyCancellable?
    private var finishedHandled = false

    var progress: CGFloat {
        guard totalMs > 0 else { return 0 }
        return CGFloat(remainMs) / CGFloat(totalMs)
    }

    func bootstrap() {
        NotificationService.configure()
        NotificationService.requestPermission()
        let saved = prefs.locale
        locale = I18n.resolve(
            catalog: catalog,
            saved: saved,
            preferredLanguages: Locale.preferredLanguages
        )
        if saved.isEmpty { prefs.locale = locale }
        ambient = prefs.ambient
        let total = Int64(catalog.defaultMin) * 60_000
        totalMs = total
        remainMs = total
        let stats = prefs.todayStats()
        statsCount = stats.count
        statsMs = stats.ms
        refreshPhase()
    }

    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        catalog.t(locale, key, vars)
    }

    func setLocale(_ code: String) {
        let value = I18n.resolve(catalog: catalog, saved: code, preferredLanguages: [code])
        locale = value
        prefs.locale = value
    }

    func setAmbient(_ mode: String) {
        ambient = mode
        prefs.ambient = mode
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
        finishedHandled = false
        remainMs = totalMs
        running = false
        finished = false
        UIApplication.shared.isIdleTimerDisabled = false
        refreshPhase()
    }

    func realert() {
        AlertService.shared.play(durationMs: catalog.alertDurationMs)
    }

    private func start() {
        guard remainMs > 0 else { return }
        finishedHandled = false
        let end = Date().addingTimeInterval(Double(remainMs) / 1000.0)
        endAt = end
        running = true
        finished = false
        UIApplication.shared.isIdleTimerDisabled = true
        NotificationService.scheduleFinish(
            at: end,
            title: t("notifyTitle"),
            body: t("notifyBody")
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
        prefs.recordSession(elapsedMs: totalMs)
        let stats = prefs.todayStats()
        statsCount = stats.count
        statsMs = stats.ms
        if fromTicker {
            NotificationService.presentNow(title: t("notifyTitle"), body: t("notifyBody"))
            AlertService.shared.play(durationMs: catalog.alertDurationMs)
        }
        refreshPhase()
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
