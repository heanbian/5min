package chat.fivemin.app.i18n

import android.content.Context
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.data.AppLocales
import chat.fivemin.app.data.SharedCatalog
import java.util.Locale

class I18n(
    private val context: Context,
    private val catalog: SharedCatalog,
) {
    fun resolveInitial(): String {
        val saved = FiveMinApp.instance.prefs.locale
        resolve(saved)?.let { return AppLocales.normalize(it) }
        val candidates = mutableListOf<String>()
        val locales = context.resources.configuration.locales
        for (i in 0 until locales.size()) candidates += locales[i].toLanguageTag()
        candidates += Locale.getDefault().toLanguageTag()
        for (tag in candidates) {
            resolve(tag)?.let { return AppLocales.normalize(it) }
        }
        return AppLocales.normalize(catalog.defaultLocale)
    }

    fun resolve(tag: String?): String? {
        if (tag.isNullOrBlank()) return null
        val lower = tag.trim().replace('_', '-')
        val codes = AppLocales.filter(catalog.localeCodes)
        if (codes.contains(lower)) return lower
        val parts = lower.split('-')
        val base = parts.firstOrNull()?.lowercase() ?: return null
        val region = parts.getOrNull(1)?.uppercase()
        if (base == "zh") {
            return if (region == "TW" || region == "HK" || region == "MO" || lower.contains("hant")) {
                "zh-TW"
            } else {
                "zh-CN"
            }
        }
        if (base == "en") return "en"
        if (codes.contains(base)) return base
        return null
    }

    fun appLocaleCodes(): List<String> = AppLocales.filter(catalog.localeCodes)
}
