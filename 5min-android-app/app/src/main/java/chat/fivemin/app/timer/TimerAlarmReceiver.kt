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
        if (elapsed > 0L) {
            FiveMinApp.instance.prefs.recordSession(elapsed)
        }
        FinishNotifier.show(context)
        FinishAlerter.play(context)
        TimerForegroundService.stop(context)
        TimerBus.publishFinished()
    }
}
