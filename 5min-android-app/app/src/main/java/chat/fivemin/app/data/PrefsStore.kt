package chat.fivemin.app.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

data class CustomScene(
    val id: String,
    val name: String,
    val min: Int,
) {
    companion object {
        const val GROUP_ID = "custom"
        const val ID_PREFIX = "custom_"
        const val MAX_COUNT = 30
        const val MAX_NAME_LENGTH = 24

        fun makeId(): String = "$ID_PREFIX${UUID.randomUUID().toString().lowercase()}"

        fun clampMinutes(value: Int): Int = value.coerceIn(1, 90)

        fun normalizedName(raw: String): String {
            val trimmed = raw.trim()
            return if (trimmed.length <= MAX_NAME_LENGTH) trimmed else trimmed.take(MAX_NAME_LENGTH)
        }
    }
}

/** App settings only; session history lives in [HistoryStore]. */
class PrefsStore(context: Context) {
    private val sp = context.getSharedPreferences("5min_prefs", Context.MODE_PRIVATE)

    init {
        migrateFinishAlertPrefs()
    }

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

    var finishTone: Boolean
        get() = sp.getBoolean(KEY_FINISH_TONE, true)
        set(value) {
            sp.edit().putBoolean(KEY_FINISH_TONE, value).apply()
        }

    var finishVibrate: Boolean
        get() = sp.getBoolean(KEY_FINISH_VIBRATE, true)
        set(value) {
            sp.edit().putBoolean(KEY_FINISH_VIBRATE, value).apply()
        }

    var finishNotify: Boolean
        get() = sp.getBoolean(KEY_FINISH_NOTIFY, true)
        set(value) {
            sp.edit().putBoolean(KEY_FINISH_NOTIFY, value).apply()
        }

    var storageMode: String
        get() = if (sp.getString(KEY_STORAGE_MODE, MODE_LOCAL) == MODE_CLOUD) MODE_CLOUD else MODE_LOCAL
        set(value) {
            sp.edit().putString(KEY_STORAGE_MODE, if (value == MODE_CLOUD) MODE_CLOUD else MODE_LOCAL).apply()
        }

    var deviceId: String
        get() = sp.getString(KEY_DEVICE_ID, null).orEmpty()
        set(value) {
            sp.edit().putString(KEY_DEVICE_ID, value).apply()
        }

    var deviceSecret: String
        get() = sp.getString(KEY_DEVICE_SECRET, null).orEmpty()
        set(value) {
            sp.edit().putString(KEY_DEVICE_SECRET, value).apply()
        }

    fun setDeviceCredentials(id: String, secret: String) {
        sp.edit()
            .putString(KEY_DEVICE_ID, id)
            .putString(KEY_DEVICE_SECRET, secret)
            .apply()
    }

    var privacyAccepted: Boolean
        get() = sp.getBoolean(KEY_PRIVACY, false)
        set(value) {
            sp.edit().putBoolean(KEY_PRIVACY, value).apply()
        }

    fun customMin(fallback: Int = 5): Int {
        val n = sp.getInt(KEY_CUSTOM_MIN, fallback)
        return if (n < 1) fallback else n.coerceAtMost(90)
    }

    fun setCustomMin(value: Int) {
        sp.edit().putInt(KEY_CUSTOM_MIN, CustomScene.clampMinutes(value)).apply()
    }

    fun customScenes(): List<CustomScene> {
        val raw = sp.getString(KEY_CUSTOM_SCENES, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.getJSONObject(i)
                val id = o.optString("id").ifEmpty { CustomScene.makeId() }
                val name = CustomScene.normalizedName(o.optString("name"))
                if (name.isEmpty()) return@mapNotNull null
                CustomScene(
                    id = id,
                    name = name,
                    min = CustomScene.clampMinutes(o.optInt("min", 5)),
                )
            }.take(CustomScene.MAX_COUNT)
        }.getOrDefault(emptyList())
    }

    fun setCustomScenes(scenes: List<CustomScene>) {
        val cleaned = scenes
            .map { scene ->
                CustomScene(
                    id = scene.id.ifEmpty { CustomScene.makeId() },
                    name = CustomScene.normalizedName(scene.name),
                    min = CustomScene.clampMinutes(scene.min),
                )
            }
            .filter { it.name.isNotEmpty() }
            .take(CustomScene.MAX_COUNT)
        val arr = JSONArray()
        cleaned.forEach { scene ->
            arr.put(
                JSONObject().apply {
                    put("id", scene.id)
                    put("name", scene.name)
                    put("min", scene.min)
                },
            )
        }
        sp.edit().putString(KEY_CUSTOM_SCENES, arr.toString()).apply()
        markCustomScenesMigrated()
    }

    val customScenesMigrated: Boolean
        get() = sp.getBoolean(KEY_CUSTOM_SCENES_MIGRATED, false)

    fun markCustomScenesMigrated() {
        sp.edit().putBoolean(KEY_CUSTOM_SCENES_MIGRATED, true).apply()
    }

    private fun migrateFinishAlertPrefs() {
        if (sp.contains(KEY_FINISH_TONE)) return
        val legacyTone = (sp.getString(KEY_AMBIENT, "off") ?: "off") != "off"
        sp.edit()
            .putBoolean(KEY_FINISH_TONE, legacyTone)
            .putBoolean(KEY_FINISH_VIBRATE, true)
            .putBoolean(KEY_FINISH_NOTIFY, true)
            .apply()
    }

    companion object {
        private const val KEY_LOCALE = "locale"
        private const val KEY_AMBIENT = "ambient"
        private const val KEY_FINISH_TONE = "finish_tone"
        private const val KEY_FINISH_VIBRATE = "finish_vibrate"
        private const val KEY_FINISH_NOTIFY = "finish_notify"
        private const val KEY_PRIVACY = "privacy_accepted"
        private const val KEY_CUSTOM_MIN = "custom_min"
        private const val KEY_CUSTOM_SCENES = "custom_scenes"
        private const val KEY_CUSTOM_SCENES_MIGRATED = "custom_scenes_migrated"
        private const val KEY_STORAGE_MODE = "storage_mode"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_DEVICE_SECRET = "device_secret"
        const val MODE_LOCAL = "local"
        const val MODE_CLOUD = "cloud"
    }
}
