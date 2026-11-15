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
    private lazy var cloud = CloudSync(prefs: prefs, history: history)

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
    @Published var customScenes: [CustomScene] = []
    @Published var suggestedSceneIds: [String] = []
    @Published var recordsEpoch = 0
    @Published var pendingSceneId: String?
    /// 0 records · 1 home · 2 mine
    @Published var selectedTab = 1
    @Published var finishTone = true
    @Published var finishVibrate = true
    @Published var finishNotify = true
    @Published var inOvertime = false
    @Published var overtimeMs: Int64 = 0
    @Published var storageMode = PrefsStore.modeLocal
    @Published var storageSyncStatus = ""

    private var endAt: Date?
    private var overtimeStart: Date?
    private var tick: AnyCancellable?
    private var finishedHandled = false
    private var lastRecordedSessionId: Int64?

    var suggestedGroup: SceneGroupDTO {
        SceneGroupDTO(id: SceneRanker.groupId, labelKey: SceneRanker.labelKey)
    }

    var customGroup: SceneGroupDTO {
        SceneGroupDTO(id: CustomScene.groupId, labelKey: "sceneGroupCustom")
    }

    var pickerGroups: [SceneGroupDTO] {
        var groups: [SceneGroupDTO] = []
        if !suggestedSceneIds.isEmpty { groups.append(suggestedGroup) }
        if !customScenes.isEmpty { groups.append(customGroup) }
        groups.append(contentsOf: catalog.groups)
        return groups
    }

    var chipSceneIds: [String] {
        Array(suggestedSceneIds.prefix(SceneRanker.chipN))
    }

    var progress: CGFloat {
        guard totalMs > 0 else { return 0 }
        return CGFloat(remainMs) / CGFloat(totalMs)
    }

    var alertSoundOn: Bool { finishTone }

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
        finishTone = prefs.finishTone
        finishVibrate = prefs.finishVibrate
        finishNotify = prefs.finishNotify
        storageMode = prefs.storageMode
        customMin = prefs.customMin(fallback: catalog.defaultMin)
        customScenes = prefs.customScenes()
        migrateLegacyCustomMinIfNeeded()
        if let toilet = catalog.scenes.first(where: { $0.id == "toilet" }),
           customMin == toilet.min {
            setPreset(minutes: toilet.min, sceneId: toilet.id)
        } else if let match = customScenes.first(where: { $0.min == customMin }) {
            setPreset(minutes: match.min, sceneId: match.id)
        } else {
            setPreset(minutes: customMin, sceneId: nil)
        }
        refreshTodayStats()
        refreshSuggested()
        refreshPhase()
        // Store-screenshot launches must stay free of the system notification prompt.
        if privacyAccepted, !Self.isStoreScreenshotLaunch {
            NotificationService.requestPermission()
        }
        applyStoreScreenshotSceneIfNeeded()
        scheduleCloudSyncIfNeeded()
    }

    func scheduleCloudSyncIfNeeded() {
        cloud.scheduleSync()
    }

    func refreshSuggested() {
        let known = Set(catalog.scenes.map(\.id) + customScenes.map(\.id))
        let sessions = history.getHistory().map {
            SceneRanker.SessionRef(sceneId: $0.sceneId, at: $0.at)
        }
        suggestedSceneIds = SceneRanker.rank(sessions: sessions, knownIds: known)
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
        refreshSuggested()
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
        cloud.schedulePushPrefs()
    }

    func setAmbient(_ mode: String) {
        ambient = mode
        prefs.ambient = mode
        if mode == "off" {
            AlertService.shared.stop()
        }
        cloud.schedulePushPrefs()
    }

    func setFinishTone(_ on: Bool) {
        finishTone = on
        prefs.finishTone = on
        cloud.schedulePushPrefs()
    }

    func setFinishVibrate(_ on: Bool) {
        finishVibrate = on
        prefs.finishVibrate = on
        cloud.schedulePushPrefs()
    }

    func setFinishNotify(_ on: Bool) {
        finishNotify = on
        prefs.finishNotify = on
        cloud.schedulePushPrefs()
    }

    func setStorageMode(_ mode: String) {
        if mode == PrefsStore.modeCloud {
            storageSyncStatus = t("storageSyncing")
            cloud.enableCloud { [weak self] ok in
                Task { @MainActor in
                    guard let self else { return }
                    if ok {
                        self.reloadPrefsFromStore()
                        self.recordsEpoch += 1
                        self.refreshTodayStats()
                        self.refreshSuggested()
                        self.storageMode = self.prefs.storageMode
                        self.storageSyncStatus = self.t("storageSyncOk")
                    } else {
                        self.storageMode = self.prefs.storageMode
                        self.storageSyncStatus = self.t("storageSyncFail")
                    }
                }
            }
            return
        }
        cloud.disableCloud()
        storageMode = PrefsStore.modeLocal
        storageSyncStatus = ""
    }

    private func reloadPrefsFromStore() {
        let saved = prefs.locale
        if !saved.isEmpty {
            locale = I18n.resolve(
                catalog: catalog,
                saved: saved,
                preferredLanguages: Locale.preferredLanguages
            )
        }
        ambient = prefs.ambient
        finishTone = prefs.finishTone
        finishVibrate = prefs.finishVibrate
        finishNotify = prefs.finishNotify
        customMin = prefs.customMin(fallback: catalog.defaultMin)
        customScenes = prefs.customScenes()
        storageMode = prefs.storageMode
    }

    var dialTimeText: String {
        if inOvertime {
            return "+\(formatOvertime(overtimeMs))"
        }
        return format(remainMs)
    }

    func formatOvertime(_ ms: Int64) -> String {
        let totalSec = max(0, ms / 1000)
        let m = totalSec / 60
        let s = totalSec % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        }
        return String(format: "0:%02d", s)
    }

    var canIgnoreFinish: Bool {
        phase == .done && lastRecordedSessionId != nil
    }

    func ignoreLastSession() {
        guard let id = lastRecordedSessionId else { return }
        let clientId = history.deleteSession(id: id)
        cloud.scheduleDeleteSession(clientId: clientId)
        lastRecordedSessionId = nil
        recordsEpoch += 1
        refreshTodayStats()
        refreshSuggested()
        resetToIdleAfterFinish()
    }

    private func resetToIdleAfterFinish() {
        stopTicker()
        NotificationService.cancelFinish()
        AlertService.shared.stop()
        finishedHandled = false
        inOvertime = false
        overtimeMs = 0
        overtimeStart = nil
        remainMs = totalMs
        running = false
        finished = false
        UIApplication.shared.isIdleTimerDisabled = false
        refreshPhase()
    }

    private func commitOvertimeToHistoryIfNeeded() {
        guard inOvertime, overtimeMs > 0, let id = lastRecordedSessionId else { return }
        let elapsed = totalMs + overtimeMs
        history.updateSessionElapsed(id: id, elapsedMs: elapsed)
        cloud.schedulePushSessions()
        recordsEpoch += 1
        refreshTodayStats()
    }

    func consumePendingScene() {
        guard let pending = pendingSceneId, !running else { return }
        pendingSceneId = nil
        selectScene(pending)
    }

    @discardableResult
    func upsertCustomScene(id: String?, name: String, minutes: Int) -> CustomScene? {
        let trimmed = CustomScene.normalizedName(name)
        guard !trimmed.isEmpty else { return nil }
        let n = CustomScene.clampMinutes(minutes)
        let saved: CustomScene
        if let id, let idx = customScenes.firstIndex(where: { $0.id == id }) {
            customScenes[idx].name = trimmed
            customScenes[idx].min = n
            saved = customScenes[idx]
            if activeSceneId == id, !running {
                setPreset(minutes: n, sceneId: id)
            }
        } else {
            guard customScenes.count < CustomScene.maxCount else { return nil }
            saved = CustomScene(id: CustomScene.makeId(), name: trimmed, min: n)
            customScenes.insert(saved, at: 0)
            if !running {
                pendingSceneId = saved.id
            }
        }
        persistCustomScenes()
        refreshSuggested()
        customMin = n
        prefs.setCustomMin(n)
        return saved
    }

    func deleteCustomScene(id: String) {
        customScenes.removeAll { $0.id == id }
        persistCustomScenes()
        refreshSuggested()
        if pendingSceneId == id { pendingSceneId = nil }
        if activeSceneId == id {
            activeSceneId = nil
        }
    }

    func queueCustomScene(_ id: String) {
        guard customScenes.contains(where: { $0.id == id }) else { return }
        pendingSceneId = id
    }

    private func persistCustomScenes() {
        prefs.setCustomScenes(customScenes)
        customScenes = prefs.customScenes()
        cloud.schedulePushPrefs()
    }

    /// One-shot: turn the old single custom duration into a named scene.
    private func migrateLegacyCustomMinIfNeeded() {
        guard !prefs.customScenesMigrated else { return }
        defer { prefs.markCustomScenesMigrated() }
        guard customScenes.isEmpty else { return }
        let legacy = prefs.customMin(fallback: catalog.defaultMin)
        guard legacy != catalog.defaultMin else { return }
        let name = t("customSceneMigratedName")
        let scene = CustomScene(id: CustomScene.makeId(), name: name, min: legacy)
        customScenes = [scene]
        prefs.setCustomScenes(customScenes)
    }

    func scenes(inGroup groupId: String) -> [SceneDTO] {
        if groupId == SceneRanker.groupId {
            return suggestedSceneIds.compactMap { id in sceneDTO(for: id) }
        }
        if groupId == CustomScene.groupId {
            return customScenes.map { custom in
                SceneDTO(
                    id: custom.id,
                    min: custom.min,
                    group: CustomScene.groupId,
                    labelKey: custom.id,
                    titleKey: custom.id
                )
            }
        }
        return catalog.scenes.filter { $0.group == groupId }
    }

    private func sceneDTO(for id: String) -> SceneDTO? {
        if let custom = customScenes.first(where: { $0.id == id }) {
            return SceneDTO(
                id: custom.id,
                min: custom.min,
                group: SceneRanker.groupId,
                labelKey: custom.id,
                titleKey: custom.id
            )
        }
        guard let scene = catalog.scenes.first(where: { $0.id == id }) else { return nil }
        return SceneDTO(
            id: scene.id,
            min: scene.min,
            group: SceneRanker.groupId,
            labelKey: scene.labelKey,
            titleKey: scene.titleKey
        )
    }

    func sceneTitle(for id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        if let custom = customScenes.first(where: { $0.id == id }) {
            return custom.name
        }
        if let scene = catalog.scenes.first(where: { $0.id == id }) {
            return t(scene.titleKey)
        }
        return nil
    }

    func sceneLabel(for id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        if let custom = customScenes.first(where: { $0.id == id }) {
            return "\(custom.name) · \(custom.min) \(t("customUnit"))"
        }
        if let scene = catalog.scenes.first(where: { $0.id == id }) {
            return t(scene.labelKey)
        }
        return nil
    }

    func refreshTodayStats() {
        let stats = history.todayStats()
        statsCount = stats.count
        statsMs = stats.ms
    }

    func deleteHistorySession(id: Int64) {
        let clientId = history.deleteSession(id: id)
        cloud.scheduleDeleteSession(clientId: clientId)
        recordsEpoch += 1
        refreshTodayStats()
        refreshSuggested()
    }

    func clearAllHistory() {
        history.clearHistory()
        cloud.scheduleClearSessions()
        recordsEpoch += 1
        refreshTodayStats()
        refreshSuggested()
    }

    func setPreset(minutes: Int, sceneId: String?) {
        guard !running else { return }
        if inOvertime { commitOvertimeToHistoryIfNeeded() }
        clearOvertimeState()
        finishedHandled = false
        lastRecordedSessionId = nil
        let total = Int64(max(1, minutes)) * 60_000
        totalMs = total
        remainMs = total
        finished = false
        activeSceneId = sceneId
        refreshPhase()
    }

    func selectScene(_ id: String) {
        if let custom = customScenes.first(where: { $0.id == id }) {
            customMin = custom.min
            prefs.setCustomMin(custom.min)
            setPreset(minutes: custom.min, sceneId: custom.id)
            return
        }
        guard let scene = catalog.scenes.first(where: { $0.id == id }) else { return }
        customMin = scene.min
        prefs.setCustomMin(scene.min)
        setPreset(minutes: scene.min, sceneId: scene.id)
    }

    func toggleStart() {
        if finished && !running {
            commitOvertimeToHistoryIfNeeded()
            clearOvertimeState()
            lastRecordedSessionId = nil
            remainMs = totalMs
            finished = false
            finishedHandled = false
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
        commitOvertimeToHistoryIfNeeded()
        stopTicker()
        NotificationService.cancelFinish()
        AlertService.shared.stop()
        finishedHandled = false
        clearOvertimeState()
        lastRecordedSessionId = nil
        remainMs = totalMs
        running = false
        finished = false
        UIApplication.shared.isIdleTimerDisabled = false
        refreshPhase()
    }

    func realert() {
        AlertService.shared.play(
            durationMs: catalog.alertDurationMs,
            withSound: finishTone,
            withVibrate: finishVibrate
        )
    }

    private func clearOvertimeState() {
        inOvertime = false
        overtimeMs = 0
        overtimeStart = nil
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
        if finishNotify {
            NotificationService.scheduleFinish(
                at: end,
                title: t("notifyTitle", vars),
                body: t("notifyBody", vars),
                withSound: finishTone
            )
        }
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
        if inOvertime, let overtimeStart {
            overtimeMs = max(0, Int64(-overtimeStart.timeIntervalSinceNow * 1000))
            refreshPhase()
            return
        }
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
        lastRecordedSessionId = history.recordSession(elapsedMs: totalMs, sceneId: activeSceneId ?? "")
        cloud.schedulePushSessions()
        refreshTodayStats()
        refreshSuggested()
        recordsEpoch += 1
        if fromTicker {
            let vars = notifyVars()
            if finishNotify {
                NotificationService.presentNow(
                    title: t("notifyTitle", vars),
                    body: t("notifyBody", vars),
                    withSound: finishTone
                )
            }
            AlertService.shared.play(
                durationMs: catalog.alertDurationMs,
                withSound: finishTone,
                withVibrate: finishVibrate
            )
        }
        inOvertime = true
        overtimeStart = Date()
        overtimeMs = 0
        UIApplication.shared.isIdleTimerDisabled = true
        startTicker()
        refreshPhase()
    }

    func sessionMinutes() -> Int {
        max(1, Int((Double(totalMs) / 60_000.0).rounded()))
    }

    func notifySceneName() -> String {
        sceneTitle(for: activeSceneId) ?? t("sceneToiletTitle")
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
        sceneTitle(for: activeSceneId) ?? t("brandTitle")
    }

    var statusText: String {
        switch phase {
        case .done:
            if inOvertime {
                return t("statusOvertime", ["n": formatOvertime(overtimeMs)])
            }
            return t("statusDone")
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
        if finished || inOvertime || (remainMs <= 0 && !running) {
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
