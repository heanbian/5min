package chat.fivemin.app.timer

enum class TimerPhase { Idle, Running, Paused, Warn, Done }

data class TimerUiState(
    val locale: String,
    val totalMs: Long,
    val remainMs: Long,
    val running: Boolean,
    val finished: Boolean,
    val activeSceneId: String?,
    val ambient: String,
    val statsCount: Int,
    val statsMs: Long,
    val phase: TimerPhase,
) {
    val progress: Float
        get() = if (totalMs <= 0L) 0f else (remainMs.toFloat() / totalMs.toFloat()).coerceIn(0f, 1f)
}
