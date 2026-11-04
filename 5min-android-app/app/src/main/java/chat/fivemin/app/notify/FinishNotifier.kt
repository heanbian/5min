package chat.fivemin.app.notify

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.MainActivity
import chat.fivemin.app.R

object FinishNotifier {
    fun show(context: Context) {
        val launch = PendingIntent.getActivity(
            context,
            2001,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val locale = FiveMinApp.instance.i18n.resolveInitial().let { code ->
            val saved = FiveMinApp.instance.prefs.locale
            FiveMinApp.instance.i18n.resolve(saved) ?: code
        }
        val cat = FiveMinApp.instance.catalog
        val title = cat.t(locale, "notifyTitle")
        val body = cat.t(locale, "notifyBody")
        val notification = NotificationCompat.Builder(context, FiveMinApp.CHANNEL_FINISH)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(launch)
            .build()
        context.getSystemService(NotificationManager::class.java)
            ?.notify(3001, notification)
    }
}
