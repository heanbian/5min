package chat.fivemin.app.data

import android.content.Context
import org.json.JSONObject

data class SceneGroup(val id: String, val labelKey: String)
data class Scene(
    val id: String,
    val min: Int,
    val group: String,
    val labelKey: String,
    val titleKey: String,
)

class SharedCatalog(
    val presetsMin: List<Int>,
    val defaultMin: Int,
    val alertDurationMs: Long,
    val vibratePatternMs: IntArray,
    val groups: List<SceneGroup>,
    val scenes: List<Scene>,
    val localeCodes: List<String>,
    val defaultLocale: String,
    private val localeMaps: Map<String, Map<String, String>>,
) {
    fun t(locale: String, key: String, vars: Map<String, String> = emptyMap()): String {
        val pack = localeMaps[locale] ?: localeMaps[defaultLocale] ?: emptyMap()
        var text = pack[key] ?: localeMaps[defaultLocale]?.get(key) ?: key
        for ((k, v) in vars) text = text.replace("{$k}", v)
        return text
    }

    companion object {
        fun load(context: Context): SharedCatalog {
            val scenesJson = context.assets.open("shared/scenes.json").bufferedReader().use { it.readText() }
            val root = JSONObject(scenesJson)
            val presets = root.getJSONArray("presetsMin").let { arr ->
                List(arr.length()) { arr.getInt(it) }
            }
            val groups = root.getJSONArray("groups").let { arr ->
                List(arr.length()) {
                    val o = arr.getJSONObject(it)
                    SceneGroup(o.getString("id"), o.getString("labelKey"))
                }
            }
            val scenes = root.getJSONArray("scenes").let { arr ->
                List(arr.length()) {
                    val o = arr.getJSONObject(it)
                    Scene(
                        id = o.getString("id"),
                        min = o.getInt("min"),
                        group = o.getString("group"),
                        labelKey = o.getString("labelKey"),
                        titleKey = o.getString("titleKey"),
                    )
                }
            }
            val codes = root.getJSONArray("localeCodes").let { arr ->
                List(arr.length()) { arr.getString(it) }
            }
            val localeMaps = codes.associateWith { code ->
                val raw = context.assets.open("shared/locales/$code.json").bufferedReader().use { it.readText() }
                val obj = JSONObject(raw)
                obj.keys().asSequence().associateWith { key -> obj.get(key).toString() }
            }
            val vibrate = root.getJSONArray("vibratePatternMs").let { arr ->
                IntArray(arr.length()) { arr.getInt(it) }
            }
            return SharedCatalog(
                presetsMin = presets,
                defaultMin = root.getInt("defaultMin"),
                alertDurationMs = root.getLong("alertDurationMs"),
                vibratePatternMs = vibrate,
                groups = groups,
                scenes = scenes,
                localeCodes = codes,
                defaultLocale = root.getString("defaultLocale"),
                localeMaps = localeMaps,
            )
        }
    }
}
