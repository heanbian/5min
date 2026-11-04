package chat.fivemin.app.data

import android.content.Context
import java.time.LocalDate
import java.time.ZoneId

class PrefsStore(context: Context) {
    private val sp = context.getSharedPreferences("5min_prefs", Context.MODE_PRIVATE)

    var locale: String
        get() = sp.getString(KEY_LOCALE, null).orEmpty()
        set(value) { sp.edit().putString(KEY_LOCALE, value).apply() }

    var ambient: String
        get() = sp.getString(KEY_AMBIENT, "off") ?: "off"
        set(value) { sp.edit().putString(KEY_AMBIENT, value).apply() }

    fun todayStats(): Pair<Int, Long> {
        val day = todayKey()
        if (sp.getString(KEY_STATS_DAY, "") != day) return 0 to 0L
        return sp.getInt(KEY_STATS_COUNT, 0) to sp.getLong(KEY_STATS_MS, 0L)
    }

    fun recordSession(elapsedMs: Long) {
        val day = todayKey()
        val editor = sp.edit()
        if (sp.getString(KEY_STATS_DAY, "") != day) {
            editor.putString(KEY_STATS_DAY, day)
            editor.putInt(KEY_STATS_COUNT, 1)
            editor.putLong(KEY_STATS_MS, elapsedMs.coerceAtLeast(0L))
        } else {
            editor.putInt(KEY_STATS_COUNT, sp.getInt(KEY_STATS_COUNT, 0) + 1)
            editor.putLong(KEY_STATS_MS, sp.getLong(KEY_STATS_MS, 0L) + elapsedMs.coerceAtLeast(0L))
        }
        editor.apply()
    }

    private fun todayKey(): String = LocalDate.now(ZoneId.systemDefault()).toString()

    companion object {
        private const val KEY_LOCALE = "locale"
        private const val KEY_AMBIENT = "ambient"
        private const val KEY_STATS_DAY = "stats_day"
        private const val KEY_STATS_COUNT = "stats_count"
        private const val KEY_STATS_MS = "stats_ms"
    }
}
