package chat.fivemin.app.timer

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.alert.FinishAlerter
import chat.fivemin.app.data.AppLocales
import chat.fivemin.app.data.CustomScene
import chat.fivemin.app.data.Scene
import chat.fivemin.app.data.SceneGroup
import chat.fivemin.app.notify.FinishNotifier
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.Locale
import kotlin.math.max

class TimerViewModel(app: Application) : AndroidViewModel(app) {
    private val catalog = FiveMinApp.instance.catalog
    private val prefs = FiveMinApp.instance.prefs
    private val history = FiveMinApp.instance.history
    private val i18n = FiveMinApp.instance.i18n

    private var endAt = 0L
    private var tickJob: Job? = null
    private var finishedHandled = false
    private var pendingSceneId: String? = null

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
        _state = MutableStateFlow(
            TimerUiState(
                locale = locale,
                totalMs = total,
                remainMs = total,
                running = false,
                finished = false,
                activeSceneId = activeSceneId,
                ambient = prefs.ambient,
                statsCount = count,
                statsMs = ms,
                phase = TimerPhase.Idle,
                privacyAccepted = prefs.privacyAccepted,
                customMin = custom,
                customScenes = scenes,
                recordsEpoch = 0,
                selectedTab = 1,
            ),
        )
        state = _state.asStateFlow()
        viewModelScope.launch {
            TimerBus.finished.collect { onExternalFinish() }
        }
    }

    fun t(key: String, vars: Map<String, String> = emptyMap()) =
        catalog.t(_state.value.locale, key, vars)

    fun appLocaleCodes(): List<String> = i18n.appLocaleCodes()

    fun pickerGroups(): List<SceneGroup> {
        val scenes = _state.value.customScenes
        return if (scenes.isEmpty()) catalog.groups else listOf(customGroup) + catalog.groups
    }

    fun scenesInGroup(groupId: String): List<Scene> {
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
        }
    }

    fun setLocale(code: String) {
        val resolved = AppLocales.normalize(i18n.resolve(code) ?: code)
        prefs.locale = resolved
        _state.update { it.copy(locale = resolved) }
    }

    fun setAmbient(mode: String) {
        prefs.ambient = mode
        _state.update { it.copy(ambient = mode) }
        if (mode == "off") FinishAlerter.stop()
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
        _state.update { it.copy(customMin = n) }
        return saved
    }

    fun deleteCustomScene(id: String) {
        val next = _state.value.customScenes.filterNot { it.id == id }
        persistCustomScenes(next)
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

    fun setPresetMinutes(min: Int, sceneId: String? = null) {
        if (_state.value.running) return
        val total = min.coerceAtLeast(1) * 60_000L
        finishedHandled = false
        _state.update {
            it.copy(
                totalMs = total,
                remainMs = total,
                finished = false,
                activeSceneId = sceneId,
                phase = TimerPhase.Idle,
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
        stopTicker()
        FinishAlerter.stop()
        TimerScheduler.cancel(getApplication())
        TimerForegroundService.stop(getApplication())
        finishedHandled = false
        _state.update {
            it.copy(
                remainMs = it.totalMs,
                running = false,
                finished = false,
                phase = TimerPhase.Idle,
            )
        }
    }

    fun realert() {
        if (!_state.value.finished) return
        FinishAlerter.play(getApplication(), _state.value.alertSoundOn)
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
        _state.update { it.copy(remainMs = it.totalMs, finished = false, phase = TimerPhase.Idle) }
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

    private fun onExternalFinish() {
        viewModelScope.launch { handleFinish(fromTicker = false) }
    }

    private fun handleFinish(fromTicker: Boolean) {
        if (finishedHandled) return
        finishedHandled = true
        stopTicker()
        TimerScheduler.cancel(getApplication())
        TimerForegroundService.stop(getApplication())
        val s = _state.value
        val total = s.totalMs
        val sceneId = s.activeSceneId.orEmpty()
        if (fromTicker) {
            history.recordSession(total, sceneId)
            FinishNotifier.show(getApplication(), total, notifySceneName(), s.alertSoundOn)
            FinishAlerter.play(getApplication(), s.alertSoundOn)
        }
        val (count, ms) = history.todayStats()
        _state.update {
            it.copy(
                remainMs = 0L,
                running = false,
                finished = true,
                phase = TimerPhase.Done,
                statsCount = count,
                statsMs = ms,
                recordsEpoch = it.recordsEpoch + 1,
            )
        }
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
