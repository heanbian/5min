package chat.fivemin.app.data

import android.content.Context

/** App settings only; session history lives in [HistoryStore]. */
class PrefsStore(context: Context) {
    private val sp = context.getSharedPreferences("5min_prefs", Context.MODE_PRIVATE)

    var locale: String
        get() = sp.getString(KEY_LOCALE, null).orEmpty()
        set(value) {
            sp.edit().putString(KEY_LOCALE, value).apply()
        }

    var ambient: String
        get() = sp.getString(KEY_AMBIENT, "off") ?: "off"
        set(value) {
            sp.edit().putString(KEY_AMBIENT, value).apply()
        }

    var privacyAccepted: Boolean
        get() = sp.getBoolean(KEY_PRIVACY, false)
        set(value) {
            sp.edit().putBoolean(KEY_PRIVACY, value).apply()
        }

    fun customMin(fallback: Int = 5): Int {
        val n = sp.getInt(KEY_CUSTOM_MIN, fallback)
        return if (n < 1) fallback else n.coerceAtMost(120)
    }

    fun setCustomMin(value: Int) {
        sp.edit().putInt(KEY_CUSTOM_MIN, value.coerceIn(1, 120)).apply()
    }

    companion object {
        private const val KEY_LOCALE = "locale"
        private const val KEY_AMBIENT = "ambient"
        private const val KEY_PRIVACY = "privacy_accepted"
        private const val KEY_CUSTOM_MIN = "custom_min"
    }
}
