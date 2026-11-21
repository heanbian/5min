package chat.fivemin.app.timer

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.MainActivity
import chat.fivemin.app.R
import kotlin.math.max

class TimerForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val remainText = intent?.getStringExtra(EXTRA_REMAIN_TEXT) ?: "--:--"
        val endAt = intent?.getLongExtra(EXTRA_END_AT, 0L) ?: 0L
        val totalMs = intent?.getLongExtra(EXTRA_TOTAL_MS, 0L) ?: 0L
        if (endAt > 0L) lastEndAt = endAt
        if (totalMs > 0L) lastTotalMs = totalMs
        val notification = buildNotification(this, remainText, lastEndAt, lastTotalMs)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIF_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            // Last resort: still try without typed FGS so process doesn't die mid-start
            try {
                startForeground(NOTIF_ID, notification)
            } catch (e2: Exception) {
                Log.e(TAG, "startForeground fallback failed", e2)
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_STICKY
    }

    companion object {
        private const val TAG = "TimerFgs"
        const val NOTIF_ID = 1001
        const val EXTRA_END_AT = "end_at"
        const val EXTRA_TOTAL_MS = "total_ms"
        const val EXTRA_REMAIN_TEXT = "remain_text"

        @Volatile private var lastEndAt: Long = 0L
        @Volatile private var lastTotalMs: Long = 0L

        fun start(context: Context, endAt: Long, remainText: String, totalMs: Long = 0L) {
            lastEndAt = endAt
            if (totalMs > 0L) lastTotalMs = totalMs
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                putExtra(EXTRA_END_AT, endAt)
                putExtra(EXTRA_TOTAL_MS, lastTotalMs)
                putExtra(EXTRA_REMAIN_TEXT, remainText)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "startForegroundService failed", e)
            }
        }

        /** Update running notification without re-starting the FGS. */
        fun update(context: Context, remainText: String, endAt: Long = lastEndAt, totalMs: Long = lastTotalMs) {
            try {
                if (endAt > 0L) lastEndAt = endAt
                if (totalMs > 0L) lastTotalMs = totalMs
                val nm = context.getSystemService(NotificationManager::class.java) ?: return
                nm.notify(NOTIF_ID, buildNotification(context, remainText, lastEndAt, lastTotalMs))
            } catch (e: Exception) {
                Log.e(TAG, "update notification failed", e)
            }
        }

        fun stop(context: Context) {
            try {
                lastEndAt = 0L
                lastTotalMs = 0L
                context.stopService(Intent(context, TimerForegroundService::class.java))
            } catch (e: Exception) {
                Log.e(TAG, "stopService failed", e)
            }
        }

        private fun buildNotification(
            context: Context,
            remainText: String,
            endAt: Long,
            totalMs: Long,
        ): Notification {
            val launch = PendingIntent.getActivity(
                context,
                2002,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = NotificationCompat.Builder(context, FiveMinApp.CHANNEL_TIMER)
                .setSmallIcon(R.drawable.ic_stat_timer)
                .setContentTitle(context.getString(R.string.app_name))
                .setContentText("${context.getString(R.string.notif_running)} · $remainText")
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(launch)
                .setSilent(true)
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            if (totalMs > 0L && endAt > 0L) {
                val remain = max(0L, endAt - System.currentTimeMillis())
                val max = totalMs.toInt().coerceAtLeast(1)
                val progress = (totalMs - remain).coerceIn(0L, totalMs).toInt()
                builder.setProgress(max, progress, false)
            }
            return builder.build()
        }
    }
}
