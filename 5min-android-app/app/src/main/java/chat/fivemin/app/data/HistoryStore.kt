package chat.fivemin.app.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import kotlin.math.max
import kotlin.math.roundToInt

data class HistoryItem(
    val id: Long,
    val at: Long,
    val minutes: Int,
    val sceneId: String,
    val clientId: String = "",
)

/**
 * Local SQLite under filesDir/5min-chat/5min_chat_history.db (survives app upgrades).
 */
class HistoryStore(context: Context) {
    data class SyncSession(
        val clientId: String,
        val at: Long,
        val minutes: Int,
        val sceneId: String,
        val elapsedMs: Long,
    )

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
        ensureClientIdColumn()
        pruneOld()
    }

    private fun ensureClientIdColumn() {
        val cols = mutableSetOf<String>()
        db.rawQuery("PRAGMA table_info($TABLE)", null).use { c ->
            val iName = c.getColumnIndex("name")
            while (c.moveToNext()) {
                cols += c.getString(iName)
            }
        }
        if (!cols.contains("client_id")) {
            db.execSQL("ALTER TABLE $TABLE ADD COLUMN client_id TEXT NOT NULL DEFAULT ''")
        }
        db.execSQL(
            "UPDATE $TABLE SET client_id = 'n_' || id WHERE client_id IS NULL OR client_id = ''",
        )
        db.execSQL(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_client_id ON $TABLE(client_id)",
        )
    }

    private fun newClientId(): String = "n_" + UUID.randomUUID().toString().lowercase()

    fun recordSession(elapsedMs: Long, sceneId: String = ""): Long {
        val ms = elapsedMs.coerceAtLeast(0L)
        val minutes = max(1, (ms / 60_000.0).roundToInt())
        val values = ContentValues().apply {
            put("at", System.currentTimeMillis())
            put("minutes", minutes)
            put("scene_id", sceneId)
            put("elapsed_ms", ms)
            put("client_id", newClientId())
        }
        val id = db.insert(TABLE, null, values)
        pruneOld()
        return id
    }

    fun updateSessionElapsed(id: Long, elapsedMs: Long) {
        if (id <= 0L) return
        val ms = elapsedMs.coerceAtLeast(0L)
        val minutes = max(1, (ms / 60_000.0).roundToInt())
        val values = ContentValues().apply {
            put("minutes", minutes)
            put("elapsed_ms", ms)
        }
        db.update(TABLE, values, "id = ?", arrayOf(id.toString()))
    }

    fun clientIdOf(id: Long): String {
        if (id <= 0L) return ""
        db.query(
            TABLE,
            arrayOf("client_id"),
            "id = ?",
            arrayOf(id.toString()),
            null,
            null,
            null,
        ).use { c ->
            if (c.moveToFirst()) return c.getString(0).orEmpty()
        }
        return ""
    }

    fun deleteSession(id: Long): String {
        if (id <= 0L) return ""
        val clientId = clientIdOf(id)
        db.delete(TABLE, "id = ?", arrayOf(id.toString()))
        return clientId
    }

    fun clearHistory() {
        db.delete(TABLE, null, null)
    }

    fun getHistory(sceneId: String? = null): List<HistoryItem> {
        val cutoff = cutoffMs()
        val selection: String
        val args: Array<String>
        if (!sceneId.isNullOrEmpty()) {
            selection = "at >= ? AND scene_id = ?"
            args = arrayOf(cutoff.toString(), sceneId)
        } else {
            selection = "at >= ?"
            args = arrayOf(cutoff.toString())
        }
        val out = ArrayList<HistoryItem>()
        db.query(
            TABLE,
            arrayOf("id", "at", "minutes", "scene_id", "client_id"),
            selection,
            args,
            null,
            null,
            "at DESC",
        ).use { c ->
            val iId = c.getColumnIndexOrThrow("id")
            val iAt = c.getColumnIndexOrThrow("at")
            val iMin = c.getColumnIndexOrThrow("minutes")
            val iScene = c.getColumnIndexOrThrow("scene_id")
            val iClient = c.getColumnIndexOrThrow("client_id")
            while (c.moveToNext()) {
                val at = c.getLong(iAt)
                val minutes = c.getInt(iMin)
                if (at > 0L && minutes > 0) {
                    out += HistoryItem(
                        id = c.getLong(iId),
                        at = at,
                        minutes = minutes,
                        sceneId = c.getString(iScene).orEmpty(),
                        clientId = c.getString(iClient).orEmpty(),
                    )
                }
            }
        }
        return out
    }

    fun exportForSync(): List<SyncSession> {
        val cutoff = cutoffMs()
        val out = ArrayList<SyncSession>()
        db.query(
            TABLE,
            arrayOf("client_id", "at", "minutes", "scene_id", "elapsed_ms"),
            "at >= ?",
            arrayOf(cutoff.toString()),
            null,
            null,
            "at DESC",
        ).use { c ->
            val iClient = c.getColumnIndexOrThrow("client_id")
            val iAt = c.getColumnIndexOrThrow("at")
            val iMin = c.getColumnIndexOrThrow("minutes")
            val iScene = c.getColumnIndexOrThrow("scene_id")
            val iEl = c.getColumnIndexOrThrow("elapsed_ms")
            while (c.moveToNext()) {
                val clientId = c.getString(iClient).orEmpty()
                val at = c.getLong(iAt)
                val minutes = c.getInt(iMin)
                if (clientId.isEmpty() || at <= 0L || minutes <= 0) continue
                out += SyncSession(
                    clientId = clientId,
                    at = at,
                    minutes = minutes,
                    sceneId = c.getString(iScene).orEmpty(),
                    elapsedMs = c.getLong(iEl),
                )
            }
        }
        return out
    }

    fun mergeFromCloud(rows: List<SyncSession>) {
        if (rows.isEmpty()) return
        db.beginTransaction()
        try {
            for (row in rows) {
                if (row.clientId.isBlank() || row.at <= 0L || row.minutes <= 0) continue
                val existing = db.query(
                    TABLE,
                    arrayOf("id"),
                    "client_id = ?",
                    arrayOf(row.clientId),
                    null,
                    null,
                    null,
                ).use { c -> if (c.moveToFirst()) c.getLong(0) else -1L }
                val values = ContentValues().apply {
                    put("at", row.at)
                    put("minutes", row.minutes)
                    put("scene_id", row.sceneId)
                    put("elapsed_ms", row.elapsedMs.coerceAtLeast(0L))
                    put("client_id", row.clientId)
                }
                if (existing > 0L) {
                    db.update(TABLE, values, "id = ?", arrayOf(existing.toString()))
                } else {
                    db.insert(TABLE, null, values)
                }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        pruneOld()
    }

    fun periodStats(): Pair<Int, Int> {
        val list = getHistory()
        return list.size to list.sumOf { it.minutes }
    }

    /**
     * Consecutive calendar days (ending today or yesterday) with ≥1 completed session.
     * Returns 0 when today and yesterday are both empty.
     */
    fun streakDays(): Int {
        val daySet = sortedDayStarts()
        if (daySet.isEmpty()) return 0
        val today = startOfDayMs(System.currentTimeMillis())
        val dayMs = 24L * 60L * 60L * 1000L
        var cursor = today
        if (!daySet.contains(cursor)) {
            cursor -= dayMs
            if (!daySet.contains(cursor)) return 0
        }
        var streak = 0
        while (daySet.contains(cursor)) {
            streak += 1
            cursor -= dayMs
        }
        return streak
    }

    fun shareSummaryValues(): Triple<Int, Int, Int> {
        val period = periodStats()
        return Triple(period.first, period.second, streakDays())
    }

    private fun sortedDayStarts(): Set<Long> {
        val out = LinkedHashSet<Long>()
        db.query(TABLE, arrayOf("at"), null, null, null, null, null).use { c ->
            val iAt = c.getColumnIndexOrThrow("at")
            while (c.moveToNext()) {
                out.add(startOfDayMs(c.getLong(iAt)))
            }
        }
        return out
    }

    private fun startOfDayMs(at: Long): Long {
        val zone = ZoneId.systemDefault()
        return Instant.ofEpochMilli(at)
            .atZone(zone)
            .toLocalDate()
            .atStartOfDay(zone)
            .toInstant()
            .toEpochMilli()
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
        val zone = ZoneId.systemDefault()
        return LocalDate.now(zone)
            .atStartOfDay(zone)
            .toInstant()
            .toEpochMilli()
    }

    companion object {
        const val HISTORY_DAYS = 14
        private const val DB_DIR = "5min-chat"
        private const val DB_NAME = "5min_chat_history.db"
        private const val TABLE = "sessions"
    }
}
