package chat.fivemin.app.data

import android.content.SharedPreferences
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.max

/**
 * P0: overtime insight · stand-up ritual · alert profile.
 * Storage keys match the WeChat mini-program (`5min-mp/utils/p0Features.js`).
 */
class P0Features(private val sp: SharedPreferences) {

    data class OvertimeStats(val weekKey: String, val count: Int, val ms: Long)

    data class FinishAlerts(
        val withTone: Boolean,
        val withVibrate: Boolean,
        val withNotify: Boolean,
    )

    fun weekKey(nowMs: Long = System.currentTimeMillis()): String {
        val cal = Calendar.getInstance().apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val day = cal.get(Calendar.DAY_OF_WEEK) // Sun=1 … Sat=7
        val diff = if (day == Calendar.SUNDAY) -6 else Calendar.MONDAY - day
        cal.add(Calendar.DAY_OF_MONTH, diff)
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return String.format(Locale.US, "%04d-%02d-%02d", y, m, d)
    }

    fun readOvertimeStats(): OvertimeStats {
        val key = weekKey()
        val raw = sp.getString(KEY_OVERTIME_STATS, null) ?: return OvertimeStats(key, 0, 0)
        return runCatching {
            val o = JSONObject(raw)
            val storedKey = o.optString("weekKey", "")
            if (storedKey != key) return OvertimeStats(key, 0, 0)
            OvertimeStats(
                weekKey = storedKey,
                count = max(0, o.optInt("count", 0)),
                ms = max(0L, o.optLong("ms", 0L)),
            )
        }.getOrDefault(OvertimeStats(key, 0, 0))
    }

    fun writeOvertimeStats(stats: OvertimeStats) {
        val o = JSONObject()
            .put("weekKey", stats.weekKey)
            .put("count", stats.count)
            .put("ms", stats.ms)
        sp.edit().putString(KEY_OVERTIME_STATS, o.toString()).apply()
    }

    /** Record one overtime burst (ms beyond planned). */
    fun recordOvertime(overtimeMs: Long): OvertimeStats {
        val ms = max(0L, overtimeMs)
        if (ms <= 0L) return readOvertimeStats()
        val cur = readOvertimeStats()
        val next = OvertimeStats(
            weekKey = weekKey(),
            count = cur.count + 1,
            ms = cur.ms + ms,
        )
        writeOvertimeStats(next)
        return next
    }

    var showOvertimeInsight: Boolean
        get() = if (!sp.contains(KEY_OVERTIME_INSIGHT)) true else sp.getBoolean(KEY_OVERTIME_INSIGHT, true)
        set(value) {
            sp.edit().putBoolean(KEY_OVERTIME_INSIGHT, value).apply()
        }

    var standRitual: String
        get() {
            val v = sp.getString(KEY_STAND_RITUAL, RITUAL_BASIC) ?: RITUAL_BASIC
            return if (v == RITUAL_BASIC) RITUAL_BASIC else RITUAL_OFF
        }
        set(value) {
            sp.edit()
                .putString(KEY_STAND_RITUAL, if (value == RITUAL_BASIC) RITUAL_BASIC else RITUAL_OFF)
                .apply()
        }

    var alertProfile: String
        get() {
            val v = sp.getString(KEY_ALERT_PROFILE, PROFILE_NORMAL) ?: PROFILE_NORMAL
            return when (v) {
                PROFILE_QUIET, PROFILE_SILENT -> v
                else -> PROFILE_NORMAL
            }
        }
        set(value) {
            val next = when (value) {
                PROFILE_QUIET, PROFILE_SILENT -> value
                else -> PROFILE_NORMAL
            }
            sp.edit().putString(KEY_ALERT_PROFILE, next).apply()
        }

    fun resolveFinishAlerts(
        finishTone: Boolean,
        finishVibrate: Boolean,
        finishNotify: Boolean,
    ): FinishAlerts {
        var withTone = finishTone
        var withVibrate = finishVibrate
        val withNotify = finishNotify
        when (alertProfile) {
            PROFILE_QUIET -> withTone = false
            PROFILE_SILENT -> {
                withTone = false
                withVibrate = false
            }
        }
        return FinishAlerts(withTone, withVibrate, withNotify)
    }

    fun insightMinutes(ms: Long): Int =
        max(1, ceil(max(0.0, ms.toDouble()) / 60_000.0).toInt())

    companion object {
        const val RITUAL_OFF = "off"
        const val RITUAL_BASIC = "basic"
        const val PROFILE_NORMAL = "normal"
        const val PROFILE_QUIET = "quiet"
        const val PROFILE_SILENT = "silent"

        private const val KEY_OVERTIME_STATS = "5min.overtime_stats"
        private const val KEY_OVERTIME_INSIGHT = "5min.overtime_insight"
        private const val KEY_STAND_RITUAL = "5min.stand_ritual"
        private const val KEY_ALERT_PROFILE = "5min.alert_profile"
    }
}
