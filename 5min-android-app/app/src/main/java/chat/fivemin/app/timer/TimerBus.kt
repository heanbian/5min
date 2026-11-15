package chat.fivemin.app.timer

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

object TimerBus {
    data class FinishEvent(val sessionId: Long = -1L)

    private val _finished = MutableSharedFlow<FinishEvent>(extraBufferCapacity = 1)
    val finished: SharedFlow<FinishEvent> = _finished.asSharedFlow()

    fun publishFinished(sessionId: Long = -1L) {
        _finished.tryEmit(FinishEvent(sessionId))
    }
}
