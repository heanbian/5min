package chat.fivemin.app.timer

import chat.fivemin.app.data.CustomScene

enum class TimerPhase { Idle, Running, Paused, Warn, Done }

data class TimerUiState(
    val locale: String,
    val totalMs: Long,
    val remainMs: Long,
    val running: Boolean,
    val finished: Boolean,
    val activeSceneId: String?,
    val ambient: String,
    val finishTone: Boolean = true,
    val finishVibrate: Boolean = true,
    val finishNotify: Boolean = true,
    val storageMode: String = "local",
    val storageSyncStatus: String = "",
    val statsCount: Int,
    val statsMs: Long,
    val phase: TimerPhase,
    val privacyAccepted: Boolean = false,
    val customMin: Int = 5,
    val customScenes: List<CustomScene> = emptyList(),
    val suggestedSceneIds: List<String> = emptyList(),
    val recordsEpoch: Int = 0,
    val selectedTab: Int = 1,
    val overtimeMs: Long = 0L,
    val sessionLogged: Boolean = false,
) {
    val progress: Float
        get() = if (totalMs <= 0L) 0f else (remainMs.toFloat() / totalMs.toFloat()).coerceIn(0f, 1f)
}
