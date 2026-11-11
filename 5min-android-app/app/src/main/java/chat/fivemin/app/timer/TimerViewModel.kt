package chat.fivemin.app.timer

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.alert.FinishAlerter
import chat.fivemin.app.data.AppLocales
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
    private var pendingCustomMin: Int? = null

    private val _state: MutableStateFlow<TimerUiState>
    val state: StateFlow<TimerUiState>

    init {
        val locale = i18n.resolveInitial()
        if (prefs.locale != locale) prefs.locale = locale
        val custom = prefs.customMin(catalog.defaultMin)
        val toilet = catalog.scenes.find { it.id == "toilet" }
        val activeSceneId: String?
        val total: Long
        if (toilet != null && custom == toilet.min) {
            activeSceneId = toilet.id
            total = toilet.min * 60_000L
        } else {
            activeSceneId = null
            total = custom * 60_000L
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

    fun acceptPrivacy() {
        prefs.privacyAccepted = true
        _state.update { it.copy(privacyAccepted = true) }
    }

    fun setSelectedTab(index: Int) {
        _state.update { it.copy(selectedTab = index) }
        if (index == 0) {
            _state.update { it.copy(recordsEpoch = it.recordsEpoch + 1) }
        } else if (index == 1) {
            consumePendingCustomMin()
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

    fun applyCustomMinutes(minutes: Int) {
        val n = minutes.coerceIn(1, 120)
        prefs.setCustomMin(n)
        pendingCustomMin = n
        _state.update { it.copy(customMin = n) }
    }

    fun consumePendingCustomMin() {
        val pending = pendingCustomMin ?: return
        if (_state.value.running) return
        pendingCustomMin = null
        setPresetMinutes(pending, null)
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
        val scene = catalog.scenes.find { it.id == sceneId } ?: return
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
        val id = _state.value.activeSceneId
        if (!id.isNullOrBlank()) {
            val scene = catalog.scenes.find { it.id == id }
            if (scene != null) return t(scene.titleKey)
        }
        return t("sceneToiletTitle")
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
