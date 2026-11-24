import Foundation

/// Device-bound cloud sync against https://5min.chat/api/v1/storage
final class CloudSync {
    static let modeLocal = PrefsStore.modeLocal
    static let modeCloud = PrefsStore.modeCloud
    static let apiBase = "https://5min.chat/api/v1/storage"

    private let prefs: PrefsStore
    private let history: HistoryStore
    private let queue = DispatchQueue(label: "chat.5min.app.cloud", qos: .utility)

    init(prefs: PrefsStore, history: HistoryStore) {
        self.prefs = prefs
        self.history = history
    }

    @discardableResult
    func ensureCredentials() -> (deviceId: String, deviceSecret: String) {
        var id = prefs.deviceId
        var secret = prefs.deviceSecret
        if id.isEmpty || secret.isEmpty {
            id = UUID().uuidString.lowercased()
            secret = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                + UUID().uuidString.replacingOccurrences(of: "-", with: "")
            prefs.setDeviceCredentials(id: id, secret: secret)
        }
        return (id, secret)
    }

    func isCloud() -> Bool {
        prefs.storageMode == Self.modeCloud
    }

    @discardableResult
    func scheduleSync() async -> Bool {
        guard isCloud() else { return false }
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                let ok: Bool
                do {
                    try self.syncNow()
                    ok = true
                } catch {
                    ok = false
                }
                continuation.resume(returning: ok)
            }
        }
    }

    func schedulePushPrefs() {
        guard isCloud() else { return }
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.register()
                _ = try self.request(
                    method: "PUT",
                    path: "/prefs",
                    body: ["prefs": self.prefsPayload()]
                )
            } catch {}
        }
    }

    func schedulePushSessions() {
        guard isCloud() else { return }
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.register()
                _ = try self.request(
                    method: "PUT",
                    path: "/sessions",
                    body: ["sessions": self.sessionsPayload()]
                )
            } catch {}
        }
    }

    func scheduleDeleteSession(clientId: String) {
        guard isCloud(), !clientId.isEmpty else { return }
        let encoded = clientId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clientId
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.register()
                _ = try self.request(method: "DELETE", path: "/sessions/\(encoded)", body: nil)
            } catch {}
        }
    }

    func scheduleClearSessions() {
        guard isCloud() else { return }
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.register()
                _ = try self.request(method: "POST", path: "/sessions/clear", body: [:])
            } catch {}
        }
    }

    func enableCloud() async -> Bool {
        prefs.storageMode = Self.modeCloud
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                let ok: Bool
                do {
                    try self.syncNow()
                    ok = true
                } catch {
                    self.prefs.storageMode = Self.modeLocal
                    ok = false
                }
                continuation.resume(returning: ok)
            }
        }
    }

    func disableCloud() {
        prefs.storageMode = Self.modeLocal
    }

    func syncNow() throws {
        try register()
        _ = try request(
            method: "PUT",
            path: "/snapshot",
            body: [
                "prefs": prefsPayload(),
                "sessions": sessionsPayload(),
            ]
        )
        let snap = try request(method: "GET", path: "/snapshot", body: nil)
        if let remotePrefs = snap["prefs"] as? [String: Any] {
            applyRemotePrefs(remotePrefs)
        }
        if let remoteSessions = snap["sessions"] as? [[String: Any]] {
            applyRemoteSessions(remoteSessions)
        } else if let arr = snap["sessions"] as? [Any] {
            let rows = arr.compactMap { $0 as? [String: Any] }
            applyRemoteSessions(rows)
        }
    }

    private func register() throws {
        _ = ensureCredentials()
        // Auth via X-Device-Id / X-Device-Secret headers only (no secret in JSON body).
        _ = try request(method: "POST", path: "/register", body: [:])
    }

    private func prefsPayload() -> [String: Any] {
        let scenes: [[String: Any]] = prefs.customScenes().map { scene in
            ["id": scene.id, "name": scene.name, "min": scene.min]
        }
        return [
            "locale": prefs.locale,
            "ambient": prefs.ambient,
            "storageMode": prefs.storageMode,
            "finishTone": prefs.finishTone,
            "finishVibrate": prefs.finishVibrate,
            "finishNotify": prefs.finishNotify,
            "standRitual": P0Features.getStandRitual(),
            "alertProfile": P0Features.getAlertProfile(),
            "overtimeInsight": P0Features.getShowOvertimeInsight(),
            "customMin": prefs.customMin(),
            "customScenes": scenes,
        ]
    }

    private func sessionsPayload() -> [[String: Any]] {
        history.exportForSync().map { row in
            [
                "clientId": row.clientId,
                "at": row.at,
                "minutes": row.minutes,
                "sceneId": row.sceneId,
                "elapsedMs": row.elapsedMs,
            ]
        }
    }

    private func applyRemotePrefs(_ remote: [String: Any]) {
        if let locale = remote["locale"] as? String, !locale.isEmpty {
            prefs.locale = locale
        }
        if let ambient = remote["ambient"] as? String, !ambient.isEmpty {
            prefs.ambient = ambient
        }
        if let tone = remote["finishTone"] as? Bool {
            prefs.finishTone = tone
        } else if let tone = remote["finishTone"] as? NSNumber {
            prefs.finishTone = tone.boolValue
        }
        if let vibrate = remote["finishVibrate"] as? Bool {
            prefs.finishVibrate = vibrate
        } else if let vibrate = remote["finishVibrate"] as? NSNumber {
            prefs.finishVibrate = vibrate.boolValue
        }
        if let notify = remote["finishNotify"] as? Bool {
            prefs.finishNotify = notify
        } else if let notify = remote["finishNotify"] as? NSNumber {
            prefs.finishNotify = notify.boolValue
        }
        if let ritual = remote["standRitual"] as? String, ritual == "off" || ritual == "basic" {
            P0Features.setStandRitual(ritual)
        }
        if let profile = remote["alertProfile"] as? String,
           profile == "normal" || profile == "quiet" || profile == "silent" {
            P0Features.setAlertProfile(profile)
        }
        if let insight = remote["overtimeInsight"] as? Bool {
            P0Features.setShowOvertimeInsight(insight)
        } else if let insight = remote["overtimeInsight"] as? NSNumber {
            P0Features.setShowOvertimeInsight(insight.boolValue)
        }
        if let customMin = remote["customMin"] as? Int {
            prefs.setCustomMin(customMin)
        } else if let customMin = remote["customMin"] as? NSNumber {
            prefs.setCustomMin(customMin.intValue)
        }
        guard let scenesArr = remote["customScenes"] as? [[String: Any]] else { return }
        var scenes: [CustomScene] = []
        for o in scenesArr {
            let name = CustomScene.normalizedName((o["name"] as? String) ?? "")
            if name.isEmpty { continue }
            let idRaw = (o["id"] as? String) ?? ""
            let minRaw: Int
            if let m = o["min"] as? Int {
                minRaw = m
            } else if let m = o["min"] as? NSNumber {
                minRaw = m.intValue
            } else {
                minRaw = 5
            }
            scenes.append(CustomScene(
                id: idRaw.isEmpty ? CustomScene.makeId() : idRaw,
                name: name,
                min: CustomScene.clampMinutes(minRaw)
            ))
        }
        prefs.setCustomScenes(scenes)
    }

    private func applyRemoteSessions(_ arr: [[String: Any]]) {
        var rows: [HistoryStore.SyncSession] = []
        for o in arr {
            let clientId: String
            if let c = o["clientId"] as? String, !c.isEmpty {
                clientId = c
            } else if let c = o["id"] as? String, !c.isEmpty {
                clientId = c
            } else {
                continue
            }
            let at: Int64
            if let v = o["at"] as? Int64 {
                at = v
            } else if let v = o["at"] as? Int {
                at = Int64(v)
            } else if let v = o["at"] as? NSNumber {
                at = v.int64Value
            } else {
                continue
            }
            let minutes: Int
            if let v = o["minutes"] as? Int {
                minutes = v
            } else if let v = o["minutes"] as? NSNumber {
                minutes = v.intValue
            } else {
                continue
            }
            if at <= 0 || minutes <= 0 { continue }
            let elapsed: Int64
            if let v = o["elapsedMs"] as? Int64 {
                elapsed = v
            } else if let v = o["elapsedMs"] as? Int {
                elapsed = Int64(v)
            } else if let v = o["elapsedMs"] as? NSNumber {
                elapsed = v.int64Value
            } else {
                elapsed = 0
            }
            rows.append(HistoryStore.SyncSession(
                clientId: clientId,
                at: at,
                minutes: minutes,
                sceneId: (o["sceneId"] as? String) ?? "",
                elapsedMs: elapsed
            ))
        }
        history.mergeFromCloud(rows)
    }

    @discardableResult
    private func request(method: String, path: String, body: [String: Any]?) throws -> [String: Any] {
        let creds = ensureCredentials()
        guard let url = URL(string: Self.apiBase + path) else {
            throw CloudSyncError.invalidURL
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(creds.deviceId, forHTTPHeaderField: "X-Device-Id")
        req.setValue(creds.deviceSecret, forHTTPHeaderField: "X-Device-Secret")
        if let body, method != "GET", method != "DELETE" {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let sem = DispatchSemaphore(value: 0)
        var dataOut: Data?
        var responseOut: URLResponse?
        var errorOut: Error?
        URLSession.shared.dataTask(with: req) { data, response, error in
            dataOut = data
            responseOut = response
            errorOut = error
            sem.signal()
        }.resume()
        sem.wait()

        if let errorOut { throw errorOut }
        let code = (responseOut as? HTTPURLResponse)?.statusCode ?? 0
        let text = dataOut.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let json: [String: Any]
        if text.isEmpty {
            json = [:]
        } else if let obj = try JSONSerialization.jsonObject(with: dataOut ?? Data(), options: []) as? [String: Any] {
            json = obj
        } else {
            json = [:]
        }
        let success = (json["success"] as? Bool) ?? false
        if !(200...299).contains(code) || !success {
            let message = (json["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "HTTP \(code)"
            throw CloudSyncError.server(message)
        }
        return (json["data"] as? [String: Any]) ?? [:]
    }
}

private enum CloudSyncError: Error {
    case invalidURL
    case server(String)
}
