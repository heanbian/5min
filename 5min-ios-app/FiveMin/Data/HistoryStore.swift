import Foundation
import SQLite3

struct HistoryItem: Identifiable, Equatable {
    var id: Int64
    var at: Int64
    var minutes: Int
    var sceneId: String
    var clientId: String = ""
}

/// Local SQLite history under Application Support/5min-chat/5min_chat_history.db
final class HistoryStore {
    struct SyncSession {
        var clientId: String
        var at: Int64
        var minutes: Int
        var sceneId: String
        var elapsedMs: Int64
    }

    static let shared = HistoryStore()
    static let historyDays = 14

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "chat.5min.app.history", qos: .utility)

    private init() {
        open()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private var dbURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("5min-chat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("5min_chat_history.db")
    }

    private func open() {
        let path = dbURL.path
        if sqlite3_open(path, &db) != SQLITE_OK {
            db = nil
            return
        }
        exec("""
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          at INTEGER NOT NULL,
          minutes INTEGER NOT NULL,
          scene_id TEXT NOT NULL DEFAULT '',
          elapsed_ms INTEGER NOT NULL DEFAULT 0
        );
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_sessions_at ON sessions(at);")
        ensureClientIdColumn()
        pruneOld()
    }

    private func ensureClientIdColumn() {
        var hasClient = false
        queue.sync {
            guard let db else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            if sqlite3_prepare_v2(db, "PRAGMA table_info(sessions)", -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let name = sqlite3_column_text(stmt, 1) {
                        if String(cString: name) == "client_id" { hasClient = true }
                    }
                }
            }
        }
        if !hasClient {
            exec("ALTER TABLE sessions ADD COLUMN client_id TEXT NOT NULL DEFAULT ''")
        }
        exec("UPDATE sessions SET client_id = 'n_' || id WHERE client_id IS NULL OR client_id = ''")
        exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_client_id ON sessions(client_id)")
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        guard let db else { return false }
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if let err {
            sqlite3_free(err)
        }
        return rc == SQLITE_OK
    }

    private var cutoffMs: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000) - Int64(Self.historyDays) * 24 * 60 * 60 * 1000
    }

    private var todayStartMs: Int64 {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return Int64(start.timeIntervalSince1970 * 1000)
    }

    private func pruneOld() {
        guard let db else { return }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, "DELETE FROM sessions WHERE at < ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, cutoffMs)
            _ = sqlite3_step(stmt)
        }
    }

    private func newClientId() -> String {
        "n_" + UUID().uuidString.lowercased()
    }

    @discardableResult
    func recordSession(elapsedMs: Int64, sceneId: String = "") -> Int64 {
        let at = Int64(Date().timeIntervalSince1970 * 1000)
        let ms = max(0, elapsedMs)
        let minutes = max(1, Int((Double(ms) / 60_000.0).rounded()))
        return insertSession(at: at, minutes: minutes, sceneId: sceneId, elapsedMs: ms, clientId: newClientId())
    }

#if DEBUG
    /// Seed local history for store screenshot captures.
    func insertDemoSession(at: Int64, minutes: Int, sceneId: String) {
        let mins = max(1, minutes)
        insertSession(at: at, minutes: mins, sceneId: sceneId, elapsedMs: Int64(mins) * 60_000, clientId: newClientId())
    }
#endif

    @discardableResult
    private func insertSession(at: Int64, minutes: Int, sceneId: String, elapsedMs: Int64, clientId: String) -> Int64 {
        queue.sync {
            guard let db else { return 0 }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "INSERT INTO sessions(at, minutes, scene_id, elapsed_ms, client_id) VALUES(?,?,?,?,?)"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            sqlite3_bind_int64(stmt, 1, at)
            sqlite3_bind_int(stmt, 2, Int32(minutes))
            sqlite3_bind_text(stmt, 3, (sceneId as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 4, elapsedMs)
            sqlite3_bind_text(stmt, 5, (clientId as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_DONE else { return 0 }
            pruneOld()
            return sqlite3_last_insert_rowid(db)
        }
    }

    func updateSessionElapsed(id: Int64, elapsedMs: Int64) {
        let ms = max(0, elapsedMs)
        let minutes = max(1, Int((Double(ms) / 60_000.0).rounded()))
        queue.sync {
            guard let db else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "UPDATE sessions SET elapsed_ms = ?, minutes = ? WHERE id = ?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int64(stmt, 1, ms)
            sqlite3_bind_int(stmt, 2, Int32(minutes))
            sqlite3_bind_int64(stmt, 3, id)
            _ = sqlite3_step(stmt)
        }
    }

    func clientIdOf(id: Int64) -> String {
        queue.sync {
            guard let db, id > 0 else { return "" }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, "SELECT client_id FROM sessions WHERE id = ?", -1, &stmt, nil) == SQLITE_OK else {
                return ""
            }
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_ROW {
                return sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
            }
            return ""
        }
    }

    @discardableResult
    func deleteSession(id: Int64) -> String {
        let clientId = clientIdOf(id: id)
        queue.sync {
            guard let db else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "DELETE FROM sessions WHERE id = ?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int64(stmt, 1, id)
            _ = sqlite3_step(stmt)
        }
        return clientId
    }

    func clearHistory() {
        queue.sync {
            _ = exec("DELETE FROM sessions")
        }
    }

    func getHistory(sceneId: String? = nil) -> [HistoryItem] {
        queue.sync {
            guard let db else { return [] }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let filterByScene = sceneId != nil && !(sceneId?.isEmpty ?? true)
            let sql: String
            if filterByScene {
                sql = "SELECT id, at, minutes, scene_id, client_id FROM sessions WHERE at >= ? AND scene_id = ? ORDER BY at DESC"
            } else {
                sql = "SELECT id, at, minutes, scene_id, client_id FROM sessions WHERE at >= ? ORDER BY at DESC"
            }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_int64(stmt, 1, cutoffMs)
            if filterByScene, let sceneId {
                sqlite3_bind_text(stmt, 2, (sceneId as NSString).utf8String, -1, nil)
            }
            var out: [HistoryItem] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let at = sqlite3_column_int64(stmt, 1)
                let minutes = Int(sqlite3_column_int(stmt, 2))
                let scene = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                let client = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                if at > 0, minutes > 0 {
                    out.append(HistoryItem(id: id, at: at, minutes: minutes, sceneId: scene, clientId: client))
                }
            }
            return out
        }
    }

    func exportForSync() -> [SyncSession] {
        queue.sync {
            guard let db else { return [] }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "SELECT client_id, at, minutes, scene_id, elapsed_ms FROM sessions WHERE at >= ? ORDER BY at DESC"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_int64(stmt, 1, cutoffMs)
            var out: [SyncSession] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let client = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
                let at = sqlite3_column_int64(stmt, 1)
                let minutes = Int(sqlite3_column_int(stmt, 2))
                let scene = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                let elapsed = sqlite3_column_int64(stmt, 4)
                if client.isEmpty || at <= 0 || minutes <= 0 { continue }
                out.append(SyncSession(clientId: client, at: at, minutes: minutes, sceneId: scene, elapsedMs: elapsed))
            }
            return out
        }
    }

    func mergeFromCloud(_ rows: [SyncSession]) {
        guard !rows.isEmpty else { return }
        queue.sync {
            guard let db else { return }
            for row in rows {
                if row.clientId.isEmpty || row.at <= 0 || row.minutes <= 0 { continue }
                var find: OpaquePointer?
                defer { sqlite3_finalize(find) }
                var existing: Int64 = -1
                if sqlite3_prepare_v2(db, "SELECT id FROM sessions WHERE client_id = ?", -1, &find, nil) == SQLITE_OK {
                    sqlite3_bind_text(find, 1, (row.clientId as NSString).utf8String, -1, nil)
                    if sqlite3_step(find) == SQLITE_ROW {
                        existing = sqlite3_column_int64(find, 0)
                    }
                }
                if existing > 0 {
                    var upd: OpaquePointer?
                    defer { sqlite3_finalize(upd) }
                    let sql = "UPDATE sessions SET at=?, minutes=?, scene_id=?, elapsed_ms=? WHERE id=?"
                    if sqlite3_prepare_v2(db, sql, -1, &upd, nil) == SQLITE_OK {
                        sqlite3_bind_int64(upd, 1, row.at)
                        sqlite3_bind_int(upd, 2, Int32(row.minutes))
                        sqlite3_bind_text(upd, 3, (row.sceneId as NSString).utf8String, -1, nil)
                        sqlite3_bind_int64(upd, 4, row.elapsedMs)
                        sqlite3_bind_int64(upd, 5, existing)
                        _ = sqlite3_step(upd)
                    }
                } else {
                    _ = insertSessionUnlocked(
                        at: row.at,
                        minutes: row.minutes,
                        sceneId: row.sceneId,
                        elapsedMs: row.elapsedMs,
                        clientId: row.clientId
                    )
                }
            }
            pruneOld()
        }
    }

    /// Caller must already be on `queue`.
    private func insertSessionUnlocked(at: Int64, minutes: Int, sceneId: String, elapsedMs: Int64, clientId: String) -> Int64 {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "INSERT INTO sessions(at, minutes, scene_id, elapsed_ms, client_id) VALUES(?,?,?,?,?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        sqlite3_bind_int64(stmt, 1, at)
        sqlite3_bind_int(stmt, 2, Int32(minutes))
        sqlite3_bind_text(stmt, 3, (sceneId as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 4, elapsedMs)
        sqlite3_bind_text(stmt, 5, (clientId as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return 0 }
        return sqlite3_last_insert_rowid(db)
    }

    func todayStats() -> (count: Int, ms: Int64) {
        queue.sync {
            guard let db else { return (0, 0) }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "SELECT COUNT(*), COALESCE(SUM(CASE WHEN elapsed_ms > 0 THEN elapsed_ms ELSE minutes * 60000 END), 0) FROM sessions WHERE at >= ?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return (0, 0) }
            sqlite3_bind_int64(stmt, 1, todayStartMs)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = Int(sqlite3_column_int(stmt, 0))
                let ms = sqlite3_column_int64(stmt, 1)
                return (count, ms)
            }
            return (0, 0)
        }
    }

    /// Consecutive calendar days (ending today or yesterday) with ≥1 completed session.
    func streakDays() -> Int {
        streakDays(from: getHistory())
    }

    func streakDays(from list: [HistoryItem]) -> Int {
        let daySet = Set(list.map { Self.startOfDayMs($0.at) })
        if daySet.isEmpty { return 0 }
        let dayMs: Int64 = 24 * 60 * 60 * 1000
        var cursor = Self.startOfDayMs(Int64(Date().timeIntervalSince1970 * 1000))
        if !daySet.contains(cursor) {
            cursor -= dayMs
            if !daySet.contains(cursor) { return 0 }
        }
        var streak = 0
        while daySet.contains(cursor) {
            streak += 1
            cursor -= dayMs
        }
        return streak
    }

    /// Single history read for share copy (avoids double scan for streak).
    func shareSummaryValues() -> (count: Int, minutes: Int, streak: Int) {
        let list = getHistory()
        return (list.count, list.reduce(0) { $0 + $1.minutes }, streakDays(from: list))
    }

    private static func startOfDayMs(_ at: Int64) -> Int64 {
        let cal = Calendar.current
        let date = Date(timeIntervalSince1970: TimeInterval(at) / 1000)
        let start = cal.startOfDay(for: date)
        return Int64(start.timeIntervalSince1970 * 1000)
    }
}
