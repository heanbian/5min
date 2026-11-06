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
import kotlin.math.max
import kotlin.math.roundToInt

object FinishNotifier {
    const val NOTIF_ID = 3001

    fun show(
        context: Context,
        totalMs: Long = 5 * 60_000L,
        sceneName: String? = null,
        withSound: Boolean = true,
    ) {
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
        val minutes = max(1, (totalMs / 60_000.0).roundToInt())
        val scene = sceneName?.takeIf { it.isNotBlank() }
            ?: cat.t(locale, "sceneToiletTitle")
        val vars = mapOf("n" to minutes.toString(), "scene" to scene)
        val title = cat.t(locale, "notifyTitle", vars)
        val body = cat.t(locale, "notifyBody", vars)
        val pattern = cat.vibratePatternMs.map { it.toLong() }.toLongArray()
        val channel = if (withSound) FiveMinApp.CHANNEL_FINISH else FiveMinApp.CHANNEL_FINISH_SILENT
        val builder = NotificationCompat.Builder(appCtx, channel)
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
            .setVibrate(pattern)
            .setContentIntent(launch)
        if (withSound) {
            builder.setDefaults(NotificationCompat.DEFAULT_ALL)
            builder.setSound(Settings.System.DEFAULT_NOTIFICATION_URI)
        } else {
            builder.setDefaults(0)
            builder.setSilent(true)
        }
        appCtx.getSystemService(NotificationManager::class.java)
            ?.notify(NOTIF_ID, builder.build())
    }
}
