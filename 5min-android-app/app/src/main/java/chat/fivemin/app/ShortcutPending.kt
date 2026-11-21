package chat.fivemin.app

/**
 * In-process handoff from non-exported [ShortcutActivity] to [MainActivity].
 * External apps cannot set this — only same-process shortcut entry can.
 */
object ShortcutPending {
    @Volatile
    private var sceneId: String? = null

    fun offer(id: String) {
        val trimmed = id.trim()
        sceneId = trimmed.takeIf { it.isNotEmpty() }
    }

    fun take(): String? {
        val id = sceneId
        sceneId = null
        return id
    }
}
