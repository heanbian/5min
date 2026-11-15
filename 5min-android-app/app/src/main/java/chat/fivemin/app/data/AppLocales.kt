package chat.fivemin.app.data

object AppLocales {
    val supported: List<String> = listOf("zh-CN", "zh-TW", "en", "de", "ru", "fr", "bo", "ja", "es", "ar")

    fun isSupported(code: String): Boolean = code in supported

    fun normalize(code: String, fallback: String = "zh-CN"): String {
        val trimmed = code.trim().replace('_', '-')
        if (isSupported(trimmed)) return trimmed
        if (trimmed.isEmpty()) return fallback
        val parts = trimmed.split('-')
        val base = parts.firstOrNull()?.lowercase().orEmpty()
        val region = parts.getOrNull(1)?.uppercase().orEmpty()
        return when {
            base == "zh" && (region == "TW" || region == "HK" || region == "MO" ||
                trimmed.lowercase().contains("hant")) -> "zh-TW"
            base == "zh" -> "zh-CN"
            base in listOf("en", "de", "ru", "fr", "bo", "ja", "es", "ar") && isSupported(base) -> base
            else -> fallback
        }
    }

    fun filter(codes: List<String>): List<String> {
        val hit = supported.filter { it in codes }
        return hit.ifEmpty { supported }
    }
}
