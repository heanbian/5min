package chat.fivemin.app.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class SceneProfile(
    val pin: List<String>,
    val groupOrder: List<String>,
    val demoteGroups: List<String>,
    val hideGroups: List<String>,
    val hideScenes: List<String>,
)

/**
 * Locale-specific scene picker profile (pin / order / demote / hide).
 * Source: assets/shared/locale-scene-profiles.json
 */
object LocaleSceneProfiles {
    @Volatile
    private var root: JSONObject? = null
    private val cache = mutableMapOf<String, SceneProfile>()

    fun load(context: Context) {
        if (root != null) return
        synchronized(this) {
            if (root != null) return
            val raw = context.assets.open("shared/locale-scene-profiles.json")
                .bufferedReader()
                .use { it.readText() }
            root = JSONObject(raw)
            cache.clear()
        }
    }

    fun resolve(locale: String): SceneProfile {
        cache[locale]?.let { return it }
        val doc = root ?: return defaultProfile()
        val base = doc.optJSONObject("default")
        val over = doc.optJSONObject(locale)
        val profile = SceneProfile(
            pin = stringList(over, "pin") ?: stringList(base, "pin") ?: emptyList(),
            groupOrder = stringList(over, "groupOrder")
                ?: stringList(base, "groupOrder")
                ?: emptyList(),
            demoteGroups = stringList(over, "demoteGroups")
                ?: stringList(base, "demoteGroups")
                ?: emptyList(),
            hideGroups = stringList(over, "hideGroups")
                ?: stringList(base, "hideGroups")
                ?: emptyList(),
            hideScenes = stringList(over, "hideScenes")
                ?: stringList(base, "hideScenes")
                ?: emptyList(),
        )
        cache[locale] = profile
        return profile
    }

    fun orderGroups(groups: List<SceneGroup>, profile: SceneProfile): List<SceneGroup> {
        val hide = profile.hideGroups.toSet()
        val demote = profile.demoteGroups.toSet()
        val byId = groups.associateBy { it.id }
        val primary = mutableListOf<SceneGroup>()
        val seen = mutableSetOf<String>()
        for (id in profile.groupOrder) {
            if (id in hide || id in demote || id in seen) continue
            val g = byId[id] ?: continue
            primary += g
            seen += id
        }
        for (g in groups) {
            if (g.id in hide || g.id in demote || g.id in seen) continue
            primary += g
            seen += g.id
        }
        val demoted = mutableListOf<SceneGroup>()
        for (id in profile.groupOrder) {
            if (id !in demote || id in hide || id in seen) continue
            val g = byId[id] ?: continue
            demoted += g
            seen += id
        }
        for (g in groups) {
            if (g.id !in demote || g.id in hide || g.id in seen) continue
            demoted += g
            seen += g.id
        }
        return primary + demoted
    }

    fun isSceneHidden(sceneId: String, profile: SceneProfile): Boolean =
        sceneId in profile.hideScenes

    /** Pin first, then ranked usage ids; unique; capped. Skips [hideScenes] so topN can still fill. */
    fun mergePinnedSuggested(
        ranked: List<String>,
        pin: List<String>,
        knownIds: Set<String>,
        topN: Int = SceneRanker.TOP_N,
        hideScenes: Collection<String> = emptyList(),
    ): List<String> {
        val hidden = hideScenes.toSet()
        val out = ArrayList<String>(topN)
        val seen = mutableSetOf<String>()
        fun take(id: String): Boolean {
            if (id !in knownIds || id in seen || id in hidden) return false
            out += id
            seen += id
            return out.size >= topN
        }
        for (id in pin) if (take(id)) return out
        for (id in ranked) if (take(id)) return out
        return out
    }

    private fun defaultProfile() = SceneProfile(
        pin = listOf("toilet", "brush", "noodles", "shower", "lazy5"),
        groupOrder = listOf(
            "daily", "kitchen", "care", "rest", "work", "study",
            "chores", "transit", "labor", "farm",
        ),
        demoteGroups = listOf("farm", "labor"),
        hideGroups = emptyList(),
        hideScenes = emptyList(),
    )

    private fun stringList(obj: JSONObject?, key: String): List<String>? {
        if (obj == null || !obj.has(key)) return null
        val arr: JSONArray = obj.optJSONArray(key) ?: return null
        return List(arr.length()) { arr.getString(it) }
    }
}
