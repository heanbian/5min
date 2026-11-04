package chat.fivemin.app.timer

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.MainActivity
import chat.fivemin.app.R

class TimerForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val endAt = intent?.getLongExtra(EXTRA_END_AT, 0L) ?: 0L
        val remainText = intent?.getStringExtra(EXTRA_REMAIN_TEXT) ?: "--:--"
        val notification = buildNotification(remainText)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notification)
        }
        if (endAt > 0L) {
            // keep service alive; exact alarm handles finish
        }
        return START_STICKY
    }

    private fun buildNotification(remainText: String): Notification {
        val launch = PendingIntent.getActivity(
            this,
            2002,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, FiveMinApp.CHANNEL_TIMER)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(getString(R.string.app_name))
            .setContentText("${getString(R.string.notif_running)} · $remainText")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(launch)
            .setSilent(true)
            .build()
    }

    companion object {
        private const val NOTIF_ID = 1001
        const val EXTRA_END_AT = "end_at"
        const val EXTRA_REMAIN_TEXT = "remain_text"

        fun start(context: Context, endAt: Long, remainText: String) {
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                putExtra(EXTRA_END_AT, endAt)
                putExtra(EXTRA_REMAIN_TEXT, remainText)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TimerForegroundService::class.java))
        }
    }
}
