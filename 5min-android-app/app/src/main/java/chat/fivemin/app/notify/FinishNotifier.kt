package chat.fivemin.app.notify

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.provider.Settings
import androidx.core.app.NotificationCompat
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.MainActivity
import chat.fivemin.app.R

object FinishNotifier {
    const val NOTIF_ID = 3001

    fun show(context: Context) {
        val appCtx = context.applicationContext
        val launch = PendingIntent.getActivity(
            appCtx,
            2001,
            Intent(appCtx, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val locale = FiveMinApp.instance.i18n.resolveInitial().let { code ->
            val saved = FiveMinApp.instance.prefs.locale
            FiveMinApp.instance.i18n.resolve(saved) ?: code
        }
        val cat = FiveMinApp.instance.catalog
        val title = cat.t(locale, "notifyTitle")
        val body = cat.t(locale, "notifyBody")
        val pattern = cat.vibratePatternMs.map { it.toLong() }.toLongArray()
        val notification = NotificationCompat.Builder(appCtx, FiveMinApp.CHANNEL_FINISH)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setColor(Color.parseColor("#2F9A68"))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setSound(Settings.System.DEFAULT_NOTIFICATION_URI)
            .setVibrate(pattern)
            .setContentIntent(launch)
            .build()
        appCtx.getSystemService(NotificationManager::class.java)
            ?.notify(NOTIF_ID, notification)
    }
}
