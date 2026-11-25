package chat.fivemin.app.alert

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.concurrent.thread
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Procedural ambient loops (rain / waves / clock) via AudioTrack — no media assets.
 * Mirrors Harmony AmbientPlayer / web ambient.js behaviour.
 */
object AmbientPlayer {
    private const val SAMPLE_RATE = 44100
    private const val CHUNK_FRAMES = 1024

    @Volatile
    private var mode: String = "off"

    @Volatile
    private var track: AudioTrack? = null

    @Volatile
    private var writing: Boolean = false

    private var writeThread: Thread? = null

    private var phase = 0.0
    private var tickRemain = 0
    private var swellGain = 0.35
    private var swellTarget = 0.35
    private var swellFramesLeft = 0
    private var noiseState = 1

    private val lock = Any()

    fun setMode(mode: String) {
        val next = if (mode == "rain" || mode == "waves" || mode == "clock") mode else "off"
        synchronized(lock) {
            if (next == AmbientPlayer.mode && (next == "off" || track != null)) {
                return
            }
            stopInternal(resetMode = false)
            AmbientPlayer.mode = next
            if (next == "off") return
            start(next)
        }
    }

    /** Stop playback and reset mode to off. */
    fun stop() {
        synchronized(lock) {
            stopInternal(resetMode = true)
        }
    }

    private fun stopInternal(resetMode: Boolean) {
        writing = false
        if (resetMode) {
            mode = "off"
        }
        val t = track
        track = null
        val thr = writeThread
        writeThread = null
        if (t != null) {
            try {
                t.pause()
            } catch (_: Exception) {
            }
            try {
                t.flush()
            } catch (_: Exception) {
            }
            try {
                t.stop()
            } catch (_: Exception) {
            }
            try {
                t.release()
            } catch (_: Exception) {
            }
        }
        // Join briefly so a restarted write loop does not race the old one.
        if (thr != null && thr !== Thread.currentThread()) {
            try {
                thr.join(200)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
    }

    private fun start(playMode: String) {
        try {
            val minBuf = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            if (minBuf <= 0) {
                mode = "off"
                return
            }
            val bufferSize = max(minBuf, CHUNK_FRAMES * 2 * 4)
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val format = AudioFormat.Builder()
                .setSampleRate(SAMPLE_RATE)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build()
            val audioTrack = AudioTrack.Builder()
                .setAudioAttributes(attrs)
                .setAudioFormat(format)
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            if (audioTrack.state != AudioTrack.STATE_INITIALIZED) {
                audioTrack.release()
                mode = "off"
                return
            }
            track = audioTrack
            writing = true
            phase = 0.0
            tickRemain = 0
            swellGain = 0.35
            swellTarget = 0.35
            swellFramesLeft = 0
            noiseState = 1
            audioTrack.play()
            writeThread = thread(name = "5min-ambient", isDaemon = true) {
                writeLoop(playMode)
            }
        } catch (_: Exception) {
            mode = "off"
            writing = false
            track = null
        }
    }

    private fun writeLoop(playMode: String) {
        val pcm = ShortArray(CHUNK_FRAMES)
        while (writing && mode == playMode) {
            val t = track ?: break
            genChunk(playMode, pcm)
            try {
                var offset = 0
                while (offset < pcm.size && writing && mode == playMode) {
                    val written = t.write(pcm, offset, pcm.size - offset)
                    if (written < 0) break
                    offset += written
                }
            } catch (_: Exception) {
                break
            }
        }
    }

    private fun genChunk(playMode: String, out: ShortArray) {
        for (i in out.indices) {
            var sample = 0.0
            when (playMode) {
                "rain" -> {
                    sample = nextNoise() * 0.22
                    // Cheap high-shelf emphasis via one-pole difference
                    phase = phase * 0.92 + sample
                    sample = sample - phase * 0.35
                }
                "waves" -> {
                    if (swellFramesLeft <= 0) {
                        swellTarget = 0.12 + Random.nextDouble() * 0.28
                        swellFramesLeft = floor(SAMPLE_RATE * (1.8 + Random.nextDouble() * 1.4)).toInt()
                    }
                    val step = (swellTarget - swellGain) / max(1, swellFramesLeft).toDouble()
                    swellGain += step
                    swellFramesLeft -= 1
                    // Low-passed noise swell
                    phase = phase * 0.97 + nextNoise() * 0.03
                    sample = phase * swellGain
                }
                else -> {
                    // clock tick once per second
                    if (tickRemain <= 0) {
                        tickRemain = SAMPLE_RATE
                        phase = 0.0
                    }
                    val tickAge = SAMPLE_RATE - tickRemain
                    if (tickAge < floor(SAMPLE_RATE * 0.06).toInt()) {
                        val env = exp(-tickAge / (SAMPLE_RATE * 0.012))
                        sample = sin(2.0 * Math.PI * 1180.0 * tickAge / SAMPLE_RATE) * 0.18 * env
                    } else {
                        sample = 0.0
                    }
                    tickRemain -= 1
                }
            }
            val clamped = max(-1.0, min(1.0, sample))
            out[i] = floor(clamped * 32767.0).toInt().toShort()
        }
    }

    /** xorshift-ish white noise in [-1, 1] */
    private fun nextNoise(): Double {
        var x = noiseState
        x = x xor (x shl 13)
        x = x xor (x ushr 17)
        x = x xor (x shl 5)
        noiseState = if (x == 0) 1 else x
        return (x and 0xffff) / 0x8000.toDouble() - 1.0
    }
}
