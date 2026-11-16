package chat.fivemin.app.timer

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import android.content.pm.ApplicationInfo
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.alert.FinishAlerter
import chat.fivemin.app.data.AppLocales
import chat.fivemin.app.data.CustomScene
import chat.fivemin.app.data.P0Features
import chat.fivemin.app.data.Scene
import chat.fivemin.app.data.SceneGroup
import chat.fivemin.app.data.SceneRanker
import chat.fivemin.app.notify.FinishNotifier
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.math.max

class TimerViewModel(app: Application) : AndroidViewModel(app) {
    private val catalog = FiveMinApp.instance.catalog
    private val prefs = FiveMinApp.instance.prefs
    private val history = FiveMinApp.instance.history
    private val i18n = FiveMinApp.instance.i18n

    private var endAt = 0L
    private var overtimeAt = 0L
    private var tickJob: Job? = null
    private var overtimeJob: Job? = null
    private var finishedHandled = false
    private var pendingSceneId: String? = null
    private var lastRecordedId = -1L

    private val suggestedGroup = SceneGroup(SceneRanker.GROUP_ID, SceneRanker.LABEL_KEY)
    private val customGroup = SceneGroup(CustomScene.GROUP_ID, "sceneGroupCustom")

    private val _state: MutableStateFlow<TimerUiState>
    val state: StateFlow<TimerUiState>

    init {
        val locale = i18n.resolveInitial()
        if (prefs.locale != locale) prefs.locale = locale
        val custom = prefs.customMin(catalog.defaultMin)
        var scenes = prefs.customScenes()
        scenes = migrateLegacyCustomMinIfNeeded(locale, scenes)
        val toilet = catalog.scenes.find { it.id == "toilet" }
        val activeSceneId: String?
        val total: Long
        when {
            toilet != null && custom == toilet.min -> {
                activeSceneId = toilet.id
                total = toilet.min * 60_000L
            }
            else -> {
                val match = scenes.firstOrNull { it.min == custom }
                if (match != null) {
                    activeSceneId = match.id
                    total = match.min * 60_000L
                } else {
                    activeSceneId = null
                    total = custom * 60_000L
                }
            }
        }
        val (count, ms) = history.todayStats()
        val suggested = computeSuggested(scenes)
        _state = MutableStateFlow(
            TimerUiState(
                locale = locale,
                totalMs = total,
                remainMs = total,
                running = false,
                finished = false,
                activeSceneId = activeSceneId,
                ambient = prefs.ambient,
                finishTone = prefs.finishTone,
                finishVibrate = prefs.finishVibrate,
                finishNotify = prefs.finishNotify,
                storageMode = prefs.storageMode,
                storageSyncStatus = "",
                statsCount = count,
                statsMs = ms,
                phase = TimerPhase.Idle,
                privacyAccepted = prefs.privacyAccepted,
                customMin = custom,
                customScenes = scenes,
                suggestedSceneIds = suggested,
                recordsEpoch = 0,
                selectedTab = 1,
                standRitual = prefs.p0.standRitual,
                alertProfile = prefs.p0.alertProfile,
            ),
        )
        state = _state.asStateFlow()
        viewModelScope.launch {
            TimerBus.finished.collect { onExternalFinish(it.sessionId) }
        }
    }

    /**
     * DEBUG / store marketing: launch with
     * `adb shell am start -n chat.fivemin.app/.MainActivity --es FIVEMIN_SCREENSHOT home|running|done`
     * (also accepts idle / warn). Skips privacy sheet and finish alerts.
     */
    fun applyStoreScreenshot(scene: String) {
        val debuggable =
            (getApplication<Application>().applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) return
        acceptPrivacy()
        // CN store listings: force Simplified Chinese copy on marketing shots.
        setLocale("zh-CN")
        when (scene) {
            "home", "idle" -> {
                setSelectedTab(1)
                setPresetMinutes(5, "toilet")
            }
            "running" -> {
                setSelectedTab(1)
                setPresetMinutes(5, "toilet")
                viewModelScope.launch {
                    delay(400)
                    startForScreenshot(3 * 60_000L + 42_000L)
                }
            }
            "warn" -> {
                setSelectedTab(1)
                setPresetMinutes(5, "toilet")
                viewModelScope.launch {
                    delay(400)
                    startForScreenshot(42_000L)
                }
            }
            "done" -> {
                setSelectedTab(1)
                setPresetMinutes(5, "toilet")
                viewModelScope.launch {
                    delay(350)
                    applyDoneScreenshot()
                }
            }
        }
    }

    private fun startForScreenshot(remain: Long) {
        finishedHandled = false
        endAt = System.currentTimeMillis() + remain
        _state.update {
            it.copy(
                remainMs = remain,
                running = true,
                finished = false,
                phase = phaseFor(remain, true, false),
            )
        }
        startTicker()
    }

    private fun applyDoneScreenshot() {
        finishedHandled = true
        stopTicker()
        TimerScheduler.cancel(getApplication())
        TimerForegroundService.stop(getApplication())
        FinishAlerter.stop()
        lastRecordedId = history.recordSession(_state.value.totalMs, "toilet")
        val (count, ms) = history.todayStats()
        overtimeAt = System.currentTimeMillis() - 12_000L
        _state.update {
            it.copy(
                remainMs = 0L,
                running = false,
                finished = true,
                phase = TimerPhase.Done,
                overtimeMs = 12_000L,
                statsCount = count,
                statsMs = ms,
                suggestedSceneIds = computeSuggested(),
                recordsEpoch = it.recordsEpoch + 1,
                sessionLogged = lastRecordedId > 0L,
                showStandRitual = false,
            )
        }
        startOvertimeTicker()
    }

    private fun computeSuggested(customScenes: List<CustomScene> = _state.value.customScenes): List<String> {
        val known = catalog.scenes.map { it.id }.toMutableSet()
        customScenes.forEach { known.add(it.id) }
        val sessions = history.getHistory().map { SceneRanker.SessionRef(it.sceneId, it.at) }
        return SceneRanker.rank(sessions, known)
    }

    fun refreshSuggested() {
        _state.update { it.copy(suggestedSceneIds = computeSuggested(it.customScenes)) }
    }

    fun chipSceneIds(): List<String> =
        _state.value.suggestedSceneIds.take(SceneRanker.CHIP_N)

    fun t(key: String, vars: Map<String, String> = emptyMap()) =
        catalog.t(_state.value.locale, key, vars)

    fun appLocaleCodes(): List<String> = i18n.appLocaleCodes()

    fun pickerGroups(): List<SceneGroup> {
        val groups = mutableListOf<SceneGroup>()
        if (_state.value.suggestedSceneIds.isNotEmpty()) groups += suggestedGroup
        if (_state.value.customScenes.isNotEmpty()) groups += customGroup
        groups += catalog.groups
        return groups
    }

    fun scenesInGroup(groupId: String): List<Scene> {
        if (groupId == SceneRanker.GROUP_ID) {
            return _state.value.suggestedSceneIds.mapNotNull { sceneForId(it, SceneRanker.GROUP_ID) }
        }
        if (groupId == CustomScene.GROUP_ID) {
            return _state.value.customScenes.map { custom ->
                Scene(
                    id = custom.id,
                    min = custom.min,
                    group = CustomScene.GROUP_ID,
                    labelKey = custom.id,
                    titleKey = custom.id,
                )
            }
        }
        return catalog.scenes.filter { it.group == groupId }
    }

    private fun sceneForId(id: String, group: String): Scene? {
        _state.value.customScenes.firstOrNull { it.id == id }?.let { custom ->
            return Scene(
                id = custom.id,
                min = custom.min,
                group = group,
                labelKey = custom.id,
                titleKey = custom.id,
            )
        }
        return catalog.scenes.firstOrNull { it.id == id }?.copy(group = group)
    }

    fun sceneTitle(id: String?): String? {
        if (id.isNullOrEmpty()) return null
        _state.value.customScenes.firstOrNull { it.id == id }?.let { return it.name }
        catalog.scenes.firstOrNull { it.id == id }?.let { return t(it.titleKey) }
        return null
    }

    fun sceneLabel(id: String?): String? {
        if (id.isNullOrEmpty()) return null
        _state.value.customScenes.firstOrNull { it.id == id }?.let { custom ->
            return "${custom.name} · ${custom.min} ${t("customUnit")}"
        }
        catalog.scenes.firstOrNull { it.id == id }?.let { return t(it.labelKey) }
        return null
    }

    fun acceptPrivacy() {
        prefs.privacyAccepted = true
        _state.update { it.copy(privacyAccepted = true) }
    }

    fun setSelectedTab(index: Int) {
        _state.update { it.copy(selectedTab = index) }
        if (index == 0) {
            _state.update { it.copy(recordsEpoch = it.recordsEpoch + 1) }
        } else if (index == 1) {
            consumePendingScene()
            refreshTodayStats()
            refreshSuggested()
        }
    }

    private val cloud get() = FiveMinApp.instance.cloudSync

    fun setLocale(code: String) {
        val resolved = AppLocales.normalize(i18n.resolve(code) ?: code)
        prefs.locale = resolved
        _state.update { it.copy(locale = resolved) }
        cloud.schedulePushPrefs()
    }

    fun setAmbient(mode: String) {
        prefs.ambient = mode
        _state.update { it.copy(ambient = mode) }
        if (mode == "off") FinishAlerter.stop()
        cloud.schedulePushPrefs()
    }

    fun setFinishTone(on: Boolean) {
        prefs.finishTone = on
        _state.update { it.copy(finishTone = on) }
        if (!on) FinishAlerter.stop()
        cloud.schedulePushPrefs()
    }

    fun setFinishVibrate(on: Boolean) {
        prefs.finishVibrate = on
        _state.update { it.copy(finishVibrate = on) }
        cloud.schedulePushPrefs()
    }

    fun setFinishNotify(on: Boolean) {
        prefs.finishNotify = on
        _state.update { it.copy(finishNotify = on) }
        cloud.schedulePushPrefs()
    }

    fun setStandRitual(mode: String) {
        prefs.p0.standRitual = mode
        _state.update { it.copy(standRitual = prefs.p0.standRitual) }
        cloud.schedulePushPrefs()
    }

    fun setAlertProfile(mode: String) {
        prefs.p0.alertProfile = mode
        _state.update { it.copy(alertProfile = prefs.p0.alertProfile) }
        cloud.schedulePushPrefs()
    }

    fun dismissStandRitual() {
        _state.update { it.copy(showStandRitual = false) }
    }

    private fun resolvedFinishAlerts(): P0Features.FinishAlerts =
        prefs.p0.resolveFinishAlerts(
            finishTone = _state.value.finishTone,
            finishVibrate = _state.value.finishVibrate,
            finishNotify = _state.value.finishNotify,
        )

    fun setStorageMode(mode: String) {
        if (mode == "cloud") {
            _state.update { it.copy(storageSyncStatus = t("storageSyncing")) }
            cloud.enableCloud { ok ->
                viewModelScope.launch {
                    withContext(Dispatchers.Main) {
                        if (ok) {
                            reloadPrefsFromStore()
                            bumpRecordsEpoch()
                            refreshTodayStats()
                            refreshSuggested()
                            _state.update {
                                it.copy(
                                    storageMode = prefs.storageMode,
                                    storageSyncStatus = t("storageSyncOk"),
                                )
                            }
                        } else {
                            _state.update {
                                it.copy(
                                    storageMode = prefs.storageMode,
                                    storageSyncStatus = t("storageSyncFail"),
                                )
                            }
                        }
                    }
                }
            }
            return
        }
        cloud.disableCloud()
        _state.update { it.copy(storageMode = "local", storageSyncStatus = "") }
    }

    private fun reloadPrefsFromStore() {
        _state.update {
            it.copy(
                locale = prefs.locale.ifBlank { it.locale },
                ambient = prefs.ambient,
                finishTone = prefs.finishTone,
                finishVibrate = prefs.finishVibrate,
                finishNotify = prefs.finishNotify,
                customMin = prefs.customMin(catalog.defaultMin),
                customScenes = prefs.customScenes(),
                storageMode = prefs.storageMode,
                standRitual = prefs.p0.standRitual,
                alertProfile = prefs.p0.alertProfile,
            )
        }
    }

    fun consumePendingScene() {
        val pending = pendingSceneId ?: return
        if (_state.value.running) return
        pendingSceneId = null
        selectScene(pending)
    }

    fun upsertCustomScene(id: String?, name: String, minutes: Int): CustomScene? {
        val trimmed = CustomScene.normalizedName(name)
        if (trimmed.isEmpty()) return null
        val n = CustomScene.clampMinutes(minutes)
        val current = _state.value.customScenes.toMutableList()
        val idx = id?.let { findId -> current.indexOfFirst { it.id == findId } } ?: -1
        val saved: CustomScene
        if (idx >= 0) {
            saved = current[idx].copy(name = trimmed, min = n)
            current[idx] = saved
            if (_state.value.activeSceneId == saved.id && !_state.value.running) {
                setPresetMinutes(n, saved.id)
            }
        } else {
            if (current.size >= CustomScene.MAX_COUNT) return null
            saved = CustomScene(id = CustomScene.makeId(), name = trimmed, min = n)
            current.add(0, saved)
            if (!_state.value.running) {
                pendingSceneId = saved.id
            }
        }
        persistCustomScenes(current)
        prefs.setCustomMin(n)
        _state.update { it.copy(customMin = n, suggestedSceneIds = computeSuggested(it.customScenes)) }
        return saved
    }

    fun deleteCustomScene(id: String) {
        val next = _state.value.customScenes.filterNot { it.id == id }
        persistCustomScenes(next)
        refreshSuggested()
        if (pendingSceneId == id) pendingSceneId = null
        if (_state.value.activeSceneId == id) {
            _state.update { it.copy(activeSceneId = null) }
        }
    }

    fun queueCustomScene(id: String) {
        if (_state.value.customScenes.none { it.id == id }) return
        pendingSceneId = id
    }

    private fun persistCustomScenes(scenes: List<CustomScene>) {
        prefs.setCustomScenes(scenes)
        _state.update { it.copy(customScenes = prefs.customScenes()) }
        cloud.schedulePushPrefs()
    }

    /** One-shot: turn the old single custom duration into a named scene. */
    private fun migrateLegacyCustomMinIfNeeded(
        locale: String,
        scenes: List<CustomScene>,
    ): List<CustomScene> {
        if (prefs.customScenesMigrated) return scenes
        prefs.markCustomScenesMigrated()
        if (scenes.isNotEmpty()) return scenes
        val legacy = prefs.customMin(fallback = catalog.defaultMin)
        if (legacy == catalog.defaultMin) return scenes
        val name = catalog.t(locale, "customSceneMigratedName")
        val scene = CustomScene(id = CustomScene.makeId(), name = name, min = legacy)
        prefs.setCustomScenes(listOf(scene))
        return prefs.customScenes()
    }

    fun refreshTodayStats() {
        val (count, ms) = history.todayStats()
        _state.update { it.copy(statsCount = count, statsMs = ms) }
    }

    fun bumpRecordsEpoch() {
        _state.update { it.copy(recordsEpoch = it.recordsEpoch + 1) }
    }

    fun deleteHistorySession(id: Long) {
        val clientId = history.deleteSession(id)
        cloud.scheduleDeleteSession(clientId)
        bumpRecordsEpoch()
        refreshTodayStats()
        refreshSuggested()
    }

    fun clearHistory() {
        history.clearHistory()
        cloud.scheduleClearSessions()
        bumpRecordsEpoch()
        refreshTodayStats()
        refreshSuggested()
    }

    fun setPresetMinutes(min: Int, sceneId: String? = null) {
        if (_state.value.running) return
        commitOvertimeToHistoryIfNeeded()
        val total = min.coerceAtLeast(1) * 60_000L
        stopOvertimeTicker()
        finishedHandled = false
        lastRecordedId = -1L
        _state.update {
            it.copy(
                totalMs = total,
                remainMs = total,
                finished = false,
                activeSceneId = sceneId,
                phase = TimerPhase.Idle,
                overtimeMs = 0L,
                sessionLogged = false,
                showStandRitual = false,
            )
        }
    }

    fun selectScene(sceneId: String) {
        val custom = _state.value.customScenes.firstOrNull { it.id == sceneId }
        if (custom != null) {
            prefs.setCustomMin(custom.min)
            _state.update { it.copy(customMin = custom.min) }
            setPresetMinutes(custom.min, custom.id)
            return
        }
        val scene = catalog.scenes.find { it.id == sceneId } ?: return
        prefs.setCustomMin(scene.min)
        _state.update { it.copy(customMin = scene.min) }
        setPresetMinutes(scene.min, scene.id)
    }

    fun toggleStart() {
        val s = _state.value
        when {
            s.finished && !s.running -> restart()
            s.running -> pause()
            else -> start()
        }
    }

    fun reset() {
        commitOvertimeToHistoryIfNeeded()
        stopTicker()
        stopOvertimeTicker()
        FinishAlerter.stop()
        TimerScheduler.cancel(getApplication())
        TimerForegroundService.stop(getApplication())
        finishedHandled = false
        lastRecordedId = -1L
        _state.update {
            it.copy(
                remainMs = it.totalMs,
                running = false,
                finished = false,
                phase = TimerPhase.Idle,
                overtimeMs = 0L,
                sessionLogged = false,
                showStandRitual = false,
            )
        }
    }

    fun ignoreFinish() {
        val id = lastRecordedId
        if (id > 0L) {
            history.deleteSession(id)
            lastRecordedId = -1L // clear before reset so overtime is not re-committed
            refreshTodayStats()
            refreshSuggested()
            _state.update { it.copy(recordsEpoch = it.recordsEpoch + 1) }
        }
        // Zero overtime before reset so commitOvertimeToHistoryIfNeeded is a no-op.
        _state.update { it.copy(overtimeMs = 0L, showStandRitual = false) }
        reset()
    }

    fun realert() {
        if (!_state.value.finished) return
        val alerts = resolvedFinishAlerts()
        FinishAlerter.play(getApplication(), alerts.withTone, alerts.withVibrate)
    }

    /** Persist overtime into the last session and weekly insight stats. */
    private fun commitOvertimeToHistoryIfNeeded() {
        val s = _state.value
        if (!s.finished || s.overtimeMs <= 0L || lastRecordedId <= 0L) return
        val ot = s.overtimeMs
        history.updateSessionElapsed(lastRecordedId, s.totalMs + ot)
        prefs.p0.recordOvertime(ot)
        cloud.schedulePushSessions()
        refreshTodayStats()
        refreshSuggested()
        _state.update { it.copy(recordsEpoch = it.recordsEpoch + 1) }
    }

    private fun start() {
        val s = _state.value
        if (s.remainMs <= 0L) return
        finishedHandled = false
        endAt = System.currentTimeMillis() + s.remainMs
        _state.update { it.copy(running = true, finished = false, phase = phaseFor(it.remainMs, true, false)) }
        runCatching {
            TimerScheduler.scheduleExact(
                getApplication(),
                endAt,
                s.totalMs,
                notifySceneName(),
                s.activeSceneId.orEmpty(),
            )
        }
        runCatching { TimerForegroundService.start(getApplication(), endAt, format(s.remainMs)) }
        startTicker()
    }

    private fun pause() {
        val s = _state.value
        if (!s.running) return
        val remain = max(0L, endAt - System.currentTimeMillis())
        stopTicker()
        TimerScheduler.cancel(getApplication())
        TimerForegroundService.stop(getApplication())
        _state.update {
            it.copy(
                remainMs = remain,
                running = false,
                phase = if (remain <= 0L) TimerPhase.Done else TimerPhase.Paused,
            )
        }
    }

    private fun restart() {
        commitOvertimeToHistoryIfNeeded()
        stopOvertimeTicker()
        lastRecordedId = -1L
        _state.update {
            it.copy(
                remainMs = it.totalMs,
                finished = false,
                phase = TimerPhase.Idle,
                overtimeMs = 0L,
                sessionLogged = false,
                showStandRitual = false,
            )
        }
        start()
    }

    private fun startTicker() {
        tickJob?.cancel()
        tickJob = viewModelScope.launch {
            while (isActive) {
                val remain = max(0L, endAt - System.currentTimeMillis())
                val running = _state.value.running
                if (!running) break
                if (remain <= 0L) {
                    handleFinish(fromTicker = true)
                    break
                }
                _state.update {
                    it.copy(
                        remainMs = remain,
                        phase = phaseFor(remain, true, false),
                    )
                }
                TimerForegroundService.update(getApplication(), format(remain))
                delay(250)
            }
        }
    }

    private fun stopTicker() {
        tickJob?.cancel()
        tickJob = null
    }

    private fun startOvertimeTicker() {
        overtimeAt = System.currentTimeMillis()
        overtimeJob?.cancel()
        overtimeJob = viewModelScope.launch {
            while (isActive) {
                val s = _state.value
                if (!s.finished || s.running) break
                val overtime = max(0L, System.currentTimeMillis() - overtimeAt)
                _state.update { it.copy(overtimeMs = overtime, phase = TimerPhase.Done) }
                delay(250)
            }
        }
    }

    private fun stopOvertimeTicker() {
        overtimeJob?.cancel()
        overtimeJob = null
    }

    private fun onExternalFinish(alarmSessionId: Long) {
        viewModelScope.launch { handleFinish(fromTicker = false, alarmSessionId = alarmSessionId) }
    }

    private fun handleFinish(fromTicker: Boolean, alarmSessionId: Long = -1L) {
        if (finishedHandled) return
        finishedHandled = true
        stopTicker()
        TimerScheduler.cancel(getApplication())
        TimerForegroundService.stop(getApplication())
        val s = _state.value
        val total = s.totalMs
        val sceneId = s.activeSceneId.orEmpty()
        val alerts = resolvedFinishAlerts()
        if (fromTicker) {
            lastRecordedId = history.recordSession(total, sceneId)
            cloud.schedulePushSessions()
            if (alerts.withNotify) {
                FinishNotifier.show(
                    getApplication(),
                    total,
                    notifySceneName(),
                    alerts.withTone,
                    alerts.withVibrate,
                )
            }
            FinishAlerter.play(getApplication(), alerts.withTone, alerts.withVibrate)
        } else if (alarmSessionId > 0L) {
            lastRecordedId = alarmSessionId
        }
        val (count, ms) = history.todayStats()
        val suggested = computeSuggested()
        val showRitual = prefs.p0.standRitual == P0Features.RITUAL_BASIC
        _state.update {
            it.copy(
                remainMs = 0L,
                running = false,
                finished = true,
                phase = TimerPhase.Done,
                statsCount = count,
                statsMs = ms,
                suggestedSceneIds = suggested,
                recordsEpoch = it.recordsEpoch + 1,
                overtimeMs = 0L,
                sessionLogged = lastRecordedId > 0L,
                showStandRitual = showRitual,
            )
        }
        startOvertimeTicker()
    }

    private fun phaseFor(remain: Long, running: Boolean, finished: Boolean): TimerPhase = when {
        finished || remain <= 0L && !running -> TimerPhase.Done
        running && remain in 1..60_000L -> TimerPhase.Warn
        running -> TimerPhase.Running
        remain < _state.value.totalMs -> TimerPhase.Paused
        else -> TimerPhase.Idle
    }

    fun notifySceneName(): String {
        return sceneTitle(_state.value.activeSceneId) ?: t("sceneToiletTitle")
    }

    fun format(ms: Long): String {
        val totalSec = ((ms + 999L) / 1000L).coerceAtLeast(0L)
        val m = totalSec / 60L
        val s = totalSec % 60L
        return String.format(Locale.US, "%02d:%02d", m, s)
    }

    fun statsMinutes(): Int {
        val ms = _state.value.statsMs
        if (ms <= 0L) return 0
        return max(1, ((ms + 59_999L) / 60_000L).toInt())
    }
}
