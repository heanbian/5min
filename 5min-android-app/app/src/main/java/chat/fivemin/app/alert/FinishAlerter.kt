package chat.fivemin.app.alert

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationAttributes
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

    fun play(context: Context, withSound: Boolean = true, withVibrate: Boolean = true) {
        val app = FiveMinApp.instance
        val pattern = app.catalog.vibratePatternMs
        val duration = app.catalog.alertDurationMs
        // Avoid clash with procedural ambient (Harmony stops ambient during finish cue).
        val resumeAmbient = app.prefs.ambient
        AmbientPlayer.stop()
        if (withVibrate) vibrate(context, pattern)
        job?.cancel()
        if (!withSound) {
            resumeAmbientIfNeeded(resumeAmbient)
            return
        }
        job = CoroutineScope(Dispatchers.Default).launch {
            val tg = try {
                ToneGenerator(AudioManager.STREAM_ALARM, 90)
            } catch (_: Exception) {
                null
            }
            try {
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
            } finally {
                try {
                    tg?.release()
                } catch (_: Exception) {
                }
                resumeAmbientIfNeeded(resumeAmbient)
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }

    private fun resumeAmbientIfNeeded(mode: String) {
        if (mode == "off") return
        // Prefer current prefs in case the user changed ambient mid-alert.
        val next = runCatching { FiveMinApp.instance.prefs.ambient }.getOrDefault(mode)
        if (next != "off") AmbientPlayer.setMode(next)
    }

    private fun vibrate(context: Context, patternMs: IntArray) {
        val timings = LongArray(patternMs.size) { patternMs[it].toLong() }
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            context.getSystemService(Vibrator::class.java)
        }
        if (vibrator == null || !vibrator.hasVibrator()) return

        val effect = VibrationEffect.createWaveform(timings, -1)
        // minSdk 26: VibrationEffect path only. API 33+ prefers VibrationAttributes.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val attrs = VibrationAttributes.Builder()
                .setUsage(VibrationAttributes.USAGE_ALARM)
                .build()
            vibrator.vibrate(effect, attrs)
        } else {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            @Suppress("DEPRECATION")
            vibrator.vibrate(effect, attrs)
        }
    }
}
