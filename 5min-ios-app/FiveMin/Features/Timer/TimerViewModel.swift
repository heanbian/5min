import Foundation
import SwiftUI
import Observation
import WidgetKit

enum TimerPhase {
    case idle, running, paused, warn, done
}

@MainActor
@Observable
final class TimerViewModel {
    let catalog = SharedCatalog()
    private let prefs = PrefsStore()
    private let history = HistoryStore.shared
    @ObservationIgnored
    private let cloud: CloudSync

    init() {
        cloud = CloudSync(prefs: prefs, history: history)
    }

    var locale: String = "zh-CN"
    var totalMs: Int64 = 5 * 60 * 1000
    var remainMs: Int64 = 5 * 60 * 1000
    var running = false
    var finished = false
    var activeSceneId: String?
    var ambient: String = "off"
    var statsCount = 0
    var statsMs: Int64 = 0
    var phase: TimerPhase = .idle
    var privacyAccepted = false
    var customMin = 5
    var customScenes: [CustomScene] = []
    var suggestedSceneIds: [String] = []
    var recordsEpoch = 0
    var pendingSceneId: String?
    /// 0 records · 1 home · 2 mine
    var selectedTab = 1
    var finishTone = true
    var finishVibrate = true
    var finishNotify = true
    var inOvertime = false
    var overtimeMs: Int64 = 0
    var storageMode = PrefsStore.modeLocal
    var storageSyncStatus = ""
    var standRitual = P0Features.ritualBasic
    var alertProfile = P0Features.profileNormal
    var showRitual = false
    var ritualUp = false
    var ritualStretch = false
    var ritualLeave = false

    private var endAt: Date?
    private var overtimeStart: Date?
    private var tickTask: Task<Void, Never>?
    private var finishedHandled = false
    private var lastRecordedSessionId: Int64?

    var suggestedGroup: SceneGroupDTO {
        SceneGroupDTO(id: SceneRanker.groupId, labelKey: SceneRanker.labelKey, doneKey: nil)
    }

    var customGroup: SceneGroupDTO {
        SceneGroupDTO(id: CustomScene.groupId, labelKey: "sceneGroupCustom", doneKey: nil)
    }

    private var pickerCacheKey: String = ""
    private var cachedPickerGroups: [SceneGroupDTO] = []
    private var cachedScenesByGroup: [String: [SceneDTO]] = [:]

    private func invalidatePickerCache() {
        pickerCacheKey = ""
    }

    private func ensurePickerCache() {
        let key =
            "\(locale)|\(suggestedSceneIds.joined(separator: ","))|" +
            customScenes.map { "\($0.id):\($0.min)" }.joined(separator: ";")
        if key == pickerCacheKey { return }
        let profile = LocaleSceneProfiles.resolve(locale: locale)
        var byGroup: [String: [SceneDTO]] = [:]
        let suggested = suggestedSceneIds.compactMap { sceneDTO(for: $0) }
        if !suggested.isEmpty { byGroup[SceneRanker.groupId] = suggested }
        let custom = customScenes.map { custom in
            SceneDTO(
                id: custom.id,
                min: custom.min,
                group: CustomScene.groupId,
                labelKey: custom.id,
                titleKey: custom.id,
                doneKey: nil
            )
        }
        if !custom.isEmpty { byGroup[CustomScene.groupId] = custom }
        for group in LocaleSceneProfiles.orderGroups(catalog.groups, profile: profile) {
            let items = catalog.scenes.filter {
                $0.group == group.id && !LocaleSceneProfiles.isSceneHidden($0.id, profile: profile)
            }
            if !items.isEmpty { byGroup[group.id] = items }
        }
        var groups: [SceneGroupDTO] = []
        if byGroup[SceneRanker.groupId] != nil { groups.append(suggestedGroup) }
        if byGroup[CustomScene.groupId] != nil { groups.append(customGroup) }
        for group in LocaleSceneProfiles.orderGroups(catalog.groups, profile: profile)
        where byGroup[group.id] != nil {
            groups.append(group)
        }
        cachedScenesByGroup = byGroup
        cachedPickerGroups = groups
        pickerCacheKey = key
    }

    var pickerGroups: [SceneGroupDTO] {
        ensurePickerCache()
        return cachedPickerGroups
    }

    var chipSceneIds: [String] {
        Array(suggestedSceneIds.prefix(SceneRanker.chipN))
    }

    var progress: CGFloat {
        guard totalMs > 0 else { return 0 }
        return CGFloat(remainMs) / CGFloat(totalMs)
    }

    var alertSoundOn: Bool { resolvedFinishAlerts().withTone }

    private func resolvedFinishAlerts() -> P0Features.FinishAlerts {
        P0Features.resolveFinishAlerts(
            finishTone: finishTone,
            finishVibrate: finishVibrate,
            finishNotify: finishNotify
        )
    }

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
        standRitual = P0Features.getStandRitual()
        alertProfile = P0Features.getAlertProfile()
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
        consumeShortcutPending()
        // Store-screenshot launches must stay free of the system notification prompt.
        if privacyAccepted, !Self.isStoreScreenshotLaunch {
            Task { await NotificationService.requestPermission() }
        }
        applyStoreScreenshotSceneIfNeeded()
        scheduleCloudSyncIfNeeded()
        if ambient != "off" {
            AmbientPlayer.shared.setMode(ambient)
        }
    }

    /// Deep link / App Intent / widget pending scene (Android ShortcutPending).
    func consumeShortcutPending() {
        guard let scene = ShortcutPending.take() else { return }
        pendingSceneId = scene
        selectedTab = 1
        consumePendingScene()
    }

    func handleDeepLink(_ url: URL) {
        ShortcutPending.offer(url: url)
        consumeShortcutPending()
    }

    func scheduleCloudSyncIfNeeded() {
        Task {
            let ok = await cloud.scheduleSync()
            guard ok else { return }
            reloadPrefsFromStore()
            recordsEpoch += 1
            refreshTodayStats()
            refreshSuggested()
        }
    }

    func refreshSuggested() {
        let known = Set(catalog.scenes.map(\.id) + customScenes.map(\.id))
        let sessions = history.getHistory().map {
            SceneRanker.SessionRef(sceneId: $0.sceneId, at: $0.at)
        }
        let profile = LocaleSceneProfiles.resolve(locale: locale)
        let ranked = SceneRanker.rank(sessions: sessions, knownIds: known)
        suggestedSceneIds = LocaleSceneProfiles.mergePinnedSuggested(
            ranked: ranked,
            pin: profile.pin,
            knownIds: known,
            hideScenes: Set(profile.hideScenes)
        )
        .filter { sceneDTO(for: $0) != nil }
        invalidatePickerCache()
    }

    private static var isStoreScreenshotLaunch: Bool {
        ProcessInfo.processInfo.environment["FIVEMIN_SCREENSHOT"] != nil
    }

    /// DEBUG-only: drive UI for `scripts/capture_store_screenshots.sh` via `FIVEMIN_SCREENSHOT`.
    /// In-memory only — no privacy persist / no durable history write for done.
    private func applyStoreScreenshotSceneIfNeeded() {
#if DEBUG
        guard let scene = ProcessInfo.processInfo.environment["FIVEMIN_SCREENSHOT"] else { return }
        // In-memory only — do not persist privacyAccepted from launch env.
        privacyAccepted = true
        switch scene {
        case "home", "idle":
            selectedTab = 1
            setPreset(minutes: 5, sceneId: "toilet")
        case "running":
            selectedTab = 1
            setPreset(minutes: 5, sceneId: "toilet")
            // Defer so the first frame paints before the countdown starts.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard let self else { return }
                self.remainMs = 3 * 60_000 + 42_000
                self.start()
            }
        case "warn":
            selectedTab = 1
            setPreset(minutes: 5, sceneId: "toilet")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard let self else { return }
                self.remainMs = 42_000
                self.start()
            }
        case "done":
            selectedTab = 1
            setPreset(minutes: 5, sceneId: "toilet")
            // Finished UI without sound / notification / history write (store marketing shot).
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                guard let self else { return }
                self.finishedHandled = true
                self.stopTicker()
                NotificationService.cancelFinish()
                self.running = false
                self.finished = true
                self.remainMs = 0
                self.inOvertime = true
                self.overtimeStart = Date().addingTimeInterval(-12)
                self.overtimeMs = 12_000
                // Fake id only — never write marketing scenes into durable history.
                self.lastRecordedSessionId = -1
                self.statsCount = max(1, self.statsCount)
                self.statsMs = max(self.totalMs, self.statsMs)
                self.refreshPhase()
                self.startTicker()
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
        Task { await NotificationService.requestPermission() }
    }

    func setLocale(_ code: String) {
        let value = AppLocales.normalize(
            I18n.resolve(catalog: catalog, saved: code, preferredLanguages: [code])
        )
        locale = value
        prefs.locale = value
        invalidatePickerCache()
        refreshSuggested()
        cloud.schedulePushPrefs()
    }

    func setAmbient(_ mode: String) {
        let next = AmbientPlayer.modes.contains(mode) ? mode : "off"
        ambient = next
        prefs.ambient = next
        AmbientPlayer.shared.setMode(next)
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

    func setShowOvertimeInsight(_ on: Bool) {
        P0Features.setShowOvertimeInsight(on)
        recordsEpoch += 1
        cloud.schedulePushPrefs()
    }

    func setStandRitual(_ mode: String) {
        P0Features.setStandRitual(mode)
        standRitual = P0Features.getStandRitual()
    }

    func setAlertProfile(_ mode: String) {
        P0Features.setAlertProfile(mode)
        alertProfile = P0Features.getAlertProfile()
    }

    func dismissRitual() {
        showRitual = false
        ritualUp = false
        ritualStretch = false
        ritualLeave = false
    }

    func setStorageMode(_ mode: String) {
        if mode == PrefsStore.modeCloud {
            storageSyncStatus = t("storageSyncing")
            Task {
                let ok = await cloud.enableCloud()
                if ok {
                    reloadPrefsFromStore()
                    recordsEpoch += 1
                    refreshTodayStats()
                    refreshSuggested()
                    storageMode = prefs.storageMode
                    storageSyncStatus = t("storageSyncOk")
                } else {
                    storageMode = prefs.storageMode
                    storageSyncStatus = t("storageSyncFail")
                }
            }
            return
        }
        cloud.disableCloud()
        storageMode = PrefsStore.modeLocal
        storageSyncStatus = ""
    }

    func recoveryCode() -> String { prefs.formatRecoveryCode() }

    /// Returns `(ok, invalidFormat)`.
    func restoreWithCode(_ code: String) async -> (Bool, Bool) {
        storageSyncStatus = t("storageSyncing")
        let err = await cloud.restoreWithCode(code)
        if err == nil {
            reloadPrefsFromStore()
            recordsEpoch += 1
            refreshTodayStats()
            refreshSuggested()
            storageMode = prefs.storageMode
            storageSyncStatus = t("storageRestoreOk")
            return (true, false)
        }
        if err == "invalid" {
            storageSyncStatus = t("storageRestoreInvalid")
            return (false, true)
        }
        storageMode = prefs.storageMode
        storageSyncStatus = t("storageRestoreFail")
        return (false, false)
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
        AmbientPlayer.shared.setMode(ambient)
        finishTone = prefs.finishTone
        finishVibrate = prefs.finishVibrate
        finishNotify = prefs.finishNotify
        standRitual = P0Features.getStandRitual()
        alertProfile = P0Features.getAlertProfile()
        customMin = prefs.customMin(fallback: catalog.defaultMin)
        customScenes = prefs.customScenes()
        storageMode = prefs.storageMode
        invalidatePickerCache()
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
        LiveActivityController.shared.end()
        finishedHandled = false
        inOvertime = false
        overtimeMs = 0
        overtimeStart = nil
        remainMs = totalMs
        running = false
        finished = false
        dismissRitual()
        UIApplication.shared.isIdleTimerDisabled = false
        refreshPhase()
        resumeAmbientAfterAlertIfNeeded()
    }

    private func commitOvertimeToHistoryIfNeeded() {
        guard inOvertime, overtimeMs > 0, let id = lastRecordedSessionId else { return }
        let ot = overtimeMs
        let elapsed = totalMs + overtimeMs
        history.updateSessionElapsed(id: id, elapsedMs: elapsed)
        P0Features.recordOvertime(ot)
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
        ensurePickerCache()
        return cachedScenesByGroup[groupId] ?? []
    }

    private func sceneDTO(for id: String) -> SceneDTO? {
        if let custom = customScenes.first(where: { $0.id == id }) {
            return SceneDTO(
                id: custom.id,
                min: custom.min,
                group: SceneRanker.groupId,
                labelKey: custom.id,
                titleKey: custom.id,
                doneKey: nil
            )
        }
        guard let scene = catalog.scenes.first(where: { $0.id == id }) else { return nil }
        return SceneDTO(
            id: scene.id,
            min: scene.min,
            group: SceneRanker.groupId,
            labelKey: scene.labelKey,
            titleKey: scene.titleKey,
            doneKey: scene.doneKey
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
        WidgetShared.setTodayCount(statsCount)
        WidgetCenter.shared.reloadTimelines(ofKind: "TimerHomeWidget")
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
            Task {
                await NotificationService.ensureAuthorized()
                start()
            }
            return
        }
        if running {
            pause()
        } else {
            Task {
                await NotificationService.ensureAuthorized()
                start()
            }
        }
    }

    func reset() {
        commitOvertimeToHistoryIfNeeded()
        stopTicker()
        NotificationService.cancelFinish()
        AlertService.shared.stop()
        LiveActivityController.shared.end()
        finishedHandled = false
        clearOvertimeState()
        lastRecordedSessionId = nil
        remainMs = totalMs
        running = false
        finished = false
        UIApplication.shared.isIdleTimerDisabled = false
        refreshPhase()
        resumeAmbientAfterAlertIfNeeded()
    }

    func realert() {
        let alerts = resolvedFinishAlerts()
        playFinishAlert(alerts: alerts)
    }

    private func playFinishAlert(alerts: P0Features.FinishAlerts) {
        AmbientPlayer.shared.suspend()
        AlertService.shared.play(
            durationMs: catalog.alertDurationMs,
            withSound: alerts.withTone,
            withVibrate: alerts.withVibrate
        )
        let delayMs = catalog.alertDurationMs
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delayMs))
            self?.resumeAmbientAfterAlertIfNeeded()
        }
    }

    private func resumeAmbientAfterAlertIfNeeded() {
        guard ambient != "off" else { return }
        AmbientPlayer.shared.resumeIfNeeded()
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
        let alerts = resolvedFinishAlerts()
        if alerts.withNotify {
            NotificationService.scheduleFinish(
                at: end,
                title: t("notifyTitle", vars),
                body: notifyBodyText(vars),
                withSound: alerts.withTone
            )
        }
        startTicker()
        refreshPhase()
        let title = notifySceneName()
        LiveActivityController.shared.start(
            sceneId: activeSceneId ?? "toilet",
            sceneTitle: title,
            endAt: end,
            remainMs: remainMs
        )
    }

    private func pause() {
        guard running, let endAt else { return }
        remainMs = max(0, Int64(endAt.timeIntervalSinceNow * 1000))
        running = false
        stopTicker()
        NotificationService.cancelFinish()
        UIApplication.shared.isIdleTimerDisabled = false
        refreshPhase()
        LiveActivityController.shared.update(
            endAt: Date().addingTimeInterval(Double(remainMs) / 1000.0),
            remainMs: remainMs,
            running: false,
            sceneTitle: notifySceneName()
        )
    }

    private var lastPublishedDial: String = ""

    private func startTicker() {
        stopTicker()
        lastPublishedDial = ""
        tickTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.onTick()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func stopTicker() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func onTick() {
        if inOvertime, let overtimeStart {
            let next = max(0, Int64(-overtimeStart.timeIntervalSinceNow * 1000))
            let dial = "+" + formatOvertime(next)
            // Publish only when the displayed clock string changes (~1Hz).
            guard dial != lastPublishedDial else { return }
            lastPublishedDial = dial
            overtimeMs = next
            refreshPhase()
            return
        }
        guard running, let endAt else { return }
        let remain = max(0, Int64(endAt.timeIntervalSinceNow * 1000))
        if remain <= 0 {
            remainMs = 0
            handleFinish(fromTicker: true)
            return
        }
        let dial = format(remain)
        guard dial != lastPublishedDial else { return }
        lastPublishedDial = dial
        remainMs = remain
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
            let alerts = resolvedFinishAlerts()
            if alerts.withNotify {
                NotificationService.presentNow(
                    title: t("notifyTitle", vars),
                    body: notifyBodyText(vars),
                    withSound: alerts.withTone
                )
            }
            playFinishAlert(alerts: alerts)
        }
        LiveActivityController.shared.end()
        inOvertime = true
        overtimeStart = Date()
        overtimeMs = 0
        UIApplication.shared.isIdleTimerDisabled = true
        startTicker()
        refreshPhase()
        maybeShowRitual()
    }

    private func maybeShowRitual() {
        guard P0Features.getStandRitual() == P0Features.ritualBasic else { return }
        ritualUp = false
        ritualStretch = false
        ritualLeave = false
        showRitual = true
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

    private func notifyBodyText(_ vars: [String: String]) -> String {
        catalog.notifyBodyText(locale: locale, sceneId: activeSceneId, vars: vars)
    }

    private func statusDoneText() -> String {
        catalog.statusDoneText(locale: locale, sceneId: activeSceneId)
    }

    func ritualPackForActiveScene() -> P0Features.RitualPack {
        let group = catalog.scenes.first(where: { $0.id == activeSceneId })?.group
        return P0Features.resolveRitualPack(sceneId: activeSceneId, sceneGroup: group)
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
            return statusDoneText()
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
