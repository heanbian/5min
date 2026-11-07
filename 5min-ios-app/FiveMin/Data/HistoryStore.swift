import Foundation
import SQLite3

struct HistoryItem: Identifiable, Equatable {
    var id: Int64
    var at: Int64
    var minutes: Int
    var sceneId: String
}

/// Local SQLite history under Application Support/5min-chat/5min_chat_history.db
final class HistoryStore {
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
        pruneOld()
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

    func recordSession(elapsedMs: Int64, sceneId: String = "") {
        let at = Int64(Date().timeIntervalSince1970 * 1000)
        let ms = max(0, elapsedMs)
        let minutes = max(1, Int((Double(ms) / 60_000.0).rounded()))
        insertSession(at: at, minutes: minutes, sceneId: sceneId, elapsedMs: ms)
    }

#if DEBUG
    /// Seed local history for store screenshot captures.
    func insertDemoSession(at: Int64, minutes: Int, sceneId: String) {
        let mins = max(1, minutes)
        insertSession(at: at, minutes: mins, sceneId: sceneId, elapsedMs: Int64(mins) * 60_000)
    }
#endif

    private func insertSession(at: Int64, minutes: Int, sceneId: String, elapsedMs: Int64) {
        queue.sync {
            guard let db else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "INSERT INTO sessions(at, minutes, scene_id, elapsed_ms) VALUES(?,?,?,?)"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int64(stmt, 1, at)
            sqlite3_bind_int(stmt, 2, Int32(minutes))
            sqlite3_bind_text(stmt, 3, (sceneId as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 4, elapsedMs)
            _ = sqlite3_step(stmt)
            pruneOld()
        }
    }

    func getHistory() -> [HistoryItem] {
        queue.sync {
            guard let db else { return [] }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "SELECT id, at, minutes, scene_id FROM sessions WHERE at >= ? ORDER BY at DESC"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_int64(stmt, 1, cutoffMs)
            var out: [HistoryItem] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let at = sqlite3_column_int64(stmt, 1)
                let minutes = Int(sqlite3_column_int(stmt, 2))
                let scene = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                if at > 0, minutes > 0 {
                    out.append(HistoryItem(id: id, at: at, minutes: minutes, sceneId: scene))
                }
            }
            return out
        }
    }

    func periodStats() -> (count: Int, minutes: Int) {
        let list = getHistory()
        return (list.count, list.reduce(0) { $0 + $1.minutes })
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
}
