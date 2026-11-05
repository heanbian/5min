package chat.fivemin.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import chat.fivemin.app.data.PrefsStore
import chat.fivemin.app.data.SharedCatalog
import chat.fivemin.app.i18n.I18n

class FiveMinApp : Application() {
    lateinit var prefs: PrefsStore
        private set
    lateinit var catalog: SharedCatalog
        private set
    lateinit var i18n: I18n
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = PrefsStore(this)
        catalog = SharedCatalog.load(this)
        i18n = I18n(this, catalog)
        ensureChannels()
    }

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_TIMER,
                getString(R.string.channel_timer),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_FINISH,
                getString(R.string.channel_finish),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = getString(R.string.channel_finish)
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                vibrationPattern = catalog.vibratePatternMs.map { it.toLong() }.toLongArray()
                setSound(
                    android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_EVENT)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            },
        )
    }

    companion object {
        const val CHANNEL_TIMER = "timer_running"
        const val CHANNEL_FINISH = "timer_finish"
        lateinit var instance: FiveMinApp
            private set
    }
}
