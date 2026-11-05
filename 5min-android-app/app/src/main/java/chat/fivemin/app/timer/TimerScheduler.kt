package chat.fivemin.app.timer

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object TimerScheduler {
    const val ACTION_FINISH = "chat.fivemin.app.action.TIMER_FINISH"
    const val EXTRA_END_AT = "end_at"
    const val EXTRA_ELAPSED = "elapsed_ms"
    const val EXTRA_SCENE = "scene_name"
    private const val TAG = "TimerScheduler"

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(AlarmManager::class.java) ?: return false
        return am.canScheduleExactAlarms()
    }

    /** Schedule finish wake-up. Never throws — falls back when exact alarm is denied. */
    fun scheduleExact(
        context: Context,
        endAt: Long,
        elapsedMs: Long,
        sceneName: String = "",
    ) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val pi = pending(context, endAt, elapsedMs, sceneName)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endAt, pi)
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endAt, pi)
            } else {
                @Suppress("DEPRECATION")
                am.setExact(AlarmManager.RTC_WAKEUP, endAt, pi)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "exact alarm denied, fallback", e)
            try {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endAt, pi)
            } catch (e2: Exception) {
                Log.e(TAG, "alarm schedule failed", e2)
            }
        } catch (e: Exception) {
            Log.e(TAG, "alarm schedule failed", e)
        }
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        try {
            am.cancel(pending(context, 0L, 0L, ""))
        } catch (_: Exception) {
            // ignore
        }
    }

    private fun pending(
        context: Context,
        endAt: Long,
        elapsedMs: Long,
        sceneName: String,
    ): PendingIntent {
        val intent = Intent(context, TimerAlarmReceiver::class.java).apply {
            action = ACTION_FINISH
            putExtra(EXTRA_END_AT, endAt)
            putExtra(EXTRA_ELAPSED, elapsedMs)
            putExtra(EXTRA_SCENE, sceneName)
        }
        return PendingIntent.getBroadcast(
            context,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
