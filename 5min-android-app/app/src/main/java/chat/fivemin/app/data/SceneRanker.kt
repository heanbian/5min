package chat.fivemin.app.data

/**
 * On-device scene ranking from local session history (shared rules across clients).
 */
object SceneRanker {
    const val GROUP_ID = "suggested"
    const val LABEL_KEY = "sceneGroupSuggested"
    const val TOP_N = 6
    const val CHIP_N = 5
    const val MIN_COUNT = 2
    const val RECENT_DAYS = 3
    const val HISTORY_WINDOW_DAYS = 14
    const val DAY_MS = 24L * 60L * 60L * 1000L

    data class SessionRef(val sceneId: String, val at: Long)

    /** Rank known scenes by frequency + recency. Empty when nothing qualifies (cold start). */
    fun rank(
        sessions: List<SessionRef>,
        knownIds: Set<String>,
        nowMs: Long = System.currentTimeMillis(),
    ): List<String> {
        val countById = linkedMapOf<String, Int>()
        val lastAtById = linkedMapOf<String, Long>()
        for (session in sessions) {
            val id = session.sceneId.trim()
            if (id.isEmpty() || id !in knownIds) continue
            countById[id] = (countById[id] ?: 0) + 1
            val prev = lastAtById[id]
            if (prev == null || session.at > prev) lastAtById[id] = session.at
        }
        data class Ranked(val id: String, val score: Int, val lastAt: Long)
        val ranked = mutableListOf<Ranked>()
        for ((id, count) in countById) {
            val lastAt = lastAtById[id] ?: 0L
            val daysSince = ((nowMs - lastAt) / DAY_MS).toInt().coerceAtLeast(0)
            val qualifies = count >= MIN_COUNT || daysSince <= RECENT_DAYS
            if (!qualifies) continue
            val score = count * 100 + (HISTORY_WINDOW_DAYS - daysSince).coerceAtLeast(0)
            ranked += Ranked(id, score, lastAt)
        }
        ranked.sortWith(compareByDescending<Ranked> { it.score }.thenByDescending { it.lastAt })
        return ranked.take(TOP_N).map { it.id }
    }
}
