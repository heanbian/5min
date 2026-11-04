package chat.fivemin.app.timer

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object TimerScheduler {
    const val ACTION_FINISH = "chat.fivemin.app.action.TIMER_FINISH"
    const val EXTRA_END_AT = "end_at"
    const val EXTRA_ELAPSED = "elapsed_ms"

    fun scheduleExact(context: Context, endAt: Long, elapsedMs: Long) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val pi = pending(context, endAt, elapsedMs)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endAt, pi)
        } else {
            @Suppress("DEPRECATION")
            am.setExact(AlarmManager.RTC_WAKEUP, endAt, pi)
        }
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        am.cancel(pending(context, 0L, 0L))
    }

    private fun pending(context: Context, endAt: Long, elapsedMs: Long): PendingIntent {
        val intent = Intent(context, TimerAlarmReceiver::class.java).apply {
            action = ACTION_FINISH
            putExtra(EXTRA_END_AT, endAt)
            putExtra(EXTRA_ELAPSED, elapsedMs)
        }
        return PendingIntent.getBroadcast(
            context,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
