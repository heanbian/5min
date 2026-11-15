package chat.fivemin.app.timer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.alert.FinishAlerter
import chat.fivemin.app.notify.FinishNotifier

class TimerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != TimerScheduler.ACTION_FINISH) return
        val elapsed = intent.getLongExtra(TimerScheduler.EXTRA_ELAPSED, 0L)
        val sceneName = intent.getStringExtra(TimerScheduler.EXTRA_SCENE).orEmpty()
        val sceneId = intent.getStringExtra(TimerScheduler.EXTRA_SCENE_ID).orEmpty()
        val prefs = FiveMinApp.instance.prefs
        val alerts = prefs.p0.resolveFinishAlerts(
            finishTone = prefs.finishTone,
            finishVibrate = prefs.finishVibrate,
            finishNotify = prefs.finishNotify,
        )
        var sessionId = -1L
        if (elapsed > 0L) {
            sessionId = FiveMinApp.instance.history.recordSession(elapsed, sceneId)
            FiveMinApp.instance.cloudSync.schedulePushSessions()
        }
        if (alerts.withNotify) {
            FinishNotifier.show(
                context,
                elapsed,
                sceneName.takeIf { it.isNotBlank() },
                alerts.withTone,
                alerts.withVibrate,
            )
        }
        FinishAlerter.play(context, alerts.withTone, alerts.withVibrate)
        TimerForegroundService.stop(context)
        TimerBus.publishFinished(sessionId)
    }
}
