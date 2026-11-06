package chat.fivemin.app.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.util.Calendar
import kotlin.math.max
import kotlin.math.roundToInt

data class HistoryItem(
    val id: Long,
    val at: Long,
    val minutes: Int,
    val sceneId: String,
)

/**
 * Local SQLite under filesDir/5min-chat/5min_chat_history.db (survives app upgrades).
 */
class HistoryStore(context: Context) {
    private val db: SQLiteDatabase

    init {
        val dir = File(context.filesDir, DB_DIR).apply { mkdirs() }
        val file = File(dir, DB_NAME)
        db = SQLiteDatabase.openOrCreateDatabase(file, null)
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              at INTEGER NOT NULL,
              minutes INTEGER NOT NULL,
              scene_id TEXT NOT NULL DEFAULT '',
              elapsed_ms INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent(),
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_sessions_at ON $TABLE(at)")
        pruneOld()
    }

    fun recordSession(elapsedMs: Long, sceneId: String = "") {
        val ms = elapsedMs.coerceAtLeast(0L)
        val minutes = max(1, (ms / 60_000.0).roundToInt())
        val values = ContentValues().apply {
            put("at", System.currentTimeMillis())
            put("minutes", minutes)
            put("scene_id", sceneId)
            put("elapsed_ms", ms)
        }
        db.insert(TABLE, null, values)
        pruneOld()
    }

    fun getHistory(): List<HistoryItem> {
        val cutoff = cutoffMs()
        val out = ArrayList<HistoryItem>()
        db.query(
            TABLE,
            arrayOf("id", "at", "minutes", "scene_id"),
            "at >= ?",
            arrayOf(cutoff.toString()),
            null,
            null,
            "at DESC",
        ).use { c ->
            val iId = c.getColumnIndexOrThrow("id")
            val iAt = c.getColumnIndexOrThrow("at")
            val iMin = c.getColumnIndexOrThrow("minutes")
            val iScene = c.getColumnIndexOrThrow("scene_id")
            while (c.moveToNext()) {
                val at = c.getLong(iAt)
                val minutes = c.getInt(iMin)
                if (at > 0L && minutes > 0) {
                    out += HistoryItem(
                        id = c.getLong(iId),
                        at = at,
                        minutes = minutes,
                        sceneId = c.getString(iScene).orEmpty(),
                    )
                }
            }
        }
        return out
    }

    fun periodStats(): Pair<Int, Int> {
        val list = getHistory()
        return list.size to list.sumOf { it.minutes }
    }

    fun todayStats(): Pair<Int, Long> {
        val start = todayStartMs()
        var count = 0
        var ms = 0L
        db.query(
            TABLE,
            arrayOf("minutes", "elapsed_ms"),
            "at >= ?",
            arrayOf(start.toString()),
            null,
            null,
            null,
        ).use { c ->
            val iMin = c.getColumnIndexOrThrow("minutes")
            val iEl = c.getColumnIndexOrThrow("elapsed_ms")
            while (c.moveToNext()) {
                count += 1
                val elapsed = c.getLong(iEl)
                val minutes = c.getInt(iMin)
                ms += if (elapsed > 0L) elapsed else minutes * 60_000L
            }
        }
        return count to ms
    }

    private fun pruneOld() {
        db.delete(TABLE, "at < ?", arrayOf(cutoffMs().toString()))
    }

    private fun cutoffMs(): Long =
        System.currentTimeMillis() - HISTORY_DAYS * 24L * 60L * 60L * 1000L

    private fun todayStartMs(): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    companion object {
        const val HISTORY_DAYS = 14
        private const val DB_DIR = "5min-chat"
        private const val DB_NAME = "5min_chat_history.db"
        private const val TABLE = "sessions"
    }
}
