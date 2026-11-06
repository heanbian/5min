package chat.fivemin.app.alert

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import chat.fivemin.app.FiveMinApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

object FinishAlerter {
    private var job: Job? = null

    fun play(context: Context, withSound: Boolean = true) {
        val app = FiveMinApp.instance
        val pattern = app.catalog.vibratePatternMs
        val duration = app.catalog.alertDurationMs
        vibrate(context, pattern)
        job?.cancel()
        if (!withSound) return
        job = CoroutineScope(Dispatchers.Default).launch {
            val tg = try {
                ToneGenerator(AudioManager.STREAM_ALARM, 90)
            } catch (_: Exception) {
                null
            }
            val end = System.currentTimeMillis() + duration
            var toggle = true
            while (isActive && System.currentTimeMillis() < end) {
                try {
                    if (toggle) tg?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 220)
                    else tg?.startTone(ToneGenerator.TONE_CDMA_PIP, 180)
                } catch (_: Exception) {
                }
                toggle = !toggle
                delay(620)
            }
            try {
                tg?.release()
            } catch (_: Exception) {
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }

    private fun vibrate(context: Context, patternMs: IntArray) {
        val timings = LongArray(patternMs.size) { patternMs[it].toLong() }
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = context.getSystemService(VibratorManager::class.java)
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
        if (vibrator == null || !vibrator.hasVibrator()) return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(timings, -1), attrs)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(timings, -1)
        }
    }
}
