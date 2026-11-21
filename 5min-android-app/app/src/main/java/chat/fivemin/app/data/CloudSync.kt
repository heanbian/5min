package chat.fivemin.app.data

import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Device-bound cloud sync against https://5min.chat/api/v1/storage
 */
class CloudSync(
    private val prefs: PrefsStore,
    private val history: HistoryStore,
) {
    private val executor = Executors.newSingleThreadExecutor()

    fun ensureCredentials(): Pair<String, String> {
        var id = prefs.deviceId
        var secret = prefs.deviceSecret
        if (id.isBlank() || secret.isBlank()) {
            id = UUID.randomUUID().toString().lowercase()
            secret = UUID.randomUUID().toString().replace("-", "") +
                UUID.randomUUID().toString().replace("-", "")
            prefs.setDeviceCredentials(id, secret)
        }
        return id to secret
    }

    fun isCloud(): Boolean = prefs.storageMode == MODE_CLOUD

    fun scheduleSync() {
        if (!isCloud()) return
        executor.execute {
            runCatching { syncNow() }
        }
    }

    fun schedulePushPrefs() {
        if (!isCloud()) return
        executor.execute {
            runCatching {
                register()
                request("PUT", "/prefs", JSONObject().put("prefs", prefsJson()))
            }
        }
    }

    fun schedulePushSessions() {
        if (!isCloud()) return
        executor.execute {
            runCatching {
                register()
                request("PUT", "/sessions", JSONObject().put("sessions", sessionsJson()))
            }
        }
    }

    fun scheduleDeleteSession(clientId: String) {
        if (!isCloud() || clientId.isBlank()) return
        executor.execute {
            runCatching {
                register()
                request("DELETE", "/sessions/${java.net.URLEncoder.encode(clientId, "UTF-8")}", null)
            }
        }
    }

    fun scheduleClearSessions() {
        if (!isCloud()) return
        executor.execute {
            runCatching {
                register()
                request("POST", "/sessions/clear", JSONObject())
            }
        }
    }

    fun enableCloud(onResult: (Boolean) -> Unit) {
        prefs.storageMode = MODE_CLOUD
        executor.execute {
            val ok = runCatching { syncNow() }.isSuccess
            if (!ok) prefs.storageMode = MODE_LOCAL
            onResult(ok)
        }
    }

    fun disableCloud() {
        prefs.storageMode = MODE_LOCAL
    }

    fun syncNow() {
        register()
        request(
            "PUT",
            "/snapshot",
            JSONObject()
                .put("prefs", prefsJson())
                .put("sessions", sessionsJson()),
        )
        val snap = request("GET", "/snapshot", null)
        applyRemotePrefs(snap.optJSONObject("prefs"))
        applyRemoteSessions(snap.optJSONArray("sessions"))
    }

    private fun register() {
        val (id, secret) = ensureCredentials()
        request(
            "POST",
            "/register",
            JSONObject().put("deviceId", id).put("deviceSecret", secret),
        )
    }

    private fun prefsJson(): JSONObject {
        val scenes = JSONArray()
        prefs.customScenes().forEach { s ->
            scenes.put(
                JSONObject()
                    .put("id", s.id)
                    .put("name", s.name)
                    .put("min", s.min),
            )
        }
        return JSONObject()
            .put("locale", prefs.locale)
            .put("ambient", prefs.ambient)
            .put("storageMode", prefs.storageMode)
            .put("finishTone", prefs.finishTone)
            .put("finishVibrate", prefs.finishVibrate)
            .put("finishNotify", prefs.finishNotify)
            .put("standRitual", prefs.p0.standRitual)
            .put("alertProfile", prefs.p0.alertProfile)
            .put("overtimeInsight", prefs.p0.showOvertimeInsight)
            .put("customMin", prefs.customMin())
            .put("customScenes", scenes)
    }

    private fun sessionsJson(): JSONArray {
        val arr = JSONArray()
        history.exportForSync().forEach { row ->
            arr.put(
                JSONObject()
                    .put("clientId", row.clientId)
                    .put("at", row.at)
                    .put("minutes", row.minutes)
                    .put("sceneId", row.sceneId)
                    .put("elapsedMs", row.elapsedMs),
            )
        }
        return arr
    }

    private fun applyRemotePrefs(remote: JSONObject?) {
        if (remote == null) return
        remote.optString("locale").takeIf { it.isNotBlank() }?.let { prefs.locale = it }
        remote.optString("ambient").takeIf { it.isNotBlank() }?.let { prefs.ambient = it }
        if (remote.has("finishTone")) prefs.finishTone = remote.optBoolean("finishTone", true)
        if (remote.has("finishVibrate")) prefs.finishVibrate = remote.optBoolean("finishVibrate", true)
        if (remote.has("finishNotify")) prefs.finishNotify = remote.optBoolean("finishNotify", true)
        remote.optString("standRitual").takeIf { it == "off" || it == "basic" }?.let {
            prefs.p0.standRitual = it
        }
        remote.optString("alertProfile").takeIf {
            it == "normal" || it == "quiet" || it == "silent"
        }?.let { prefs.p0.alertProfile = it }
        if (remote.has("overtimeInsight")) {
            prefs.p0.showOvertimeInsight = remote.optBoolean("overtimeInsight", true)
        }
        if (remote.has("customMin")) prefs.setCustomMin(remote.optInt("customMin", 5))
        val scenesArr = remote.optJSONArray("customScenes") ?: return
        val scenes = mutableListOf<CustomScene>()
        for (i in 0 until scenesArr.length()) {
            val o = scenesArr.optJSONObject(i) ?: continue
            val name = CustomScene.normalizedName(o.optString("name"))
            if (name.isEmpty()) continue
            scenes += CustomScene(
                id = o.optString("id").ifEmpty { CustomScene.makeId() },
                name = name,
                min = CustomScene.clampMinutes(o.optInt("min", 5)),
            )
        }
        prefs.setCustomScenes(scenes)
    }

    private fun applyRemoteSessions(arr: JSONArray?) {
        if (arr == null) return
        val rows = mutableListOf<HistoryStore.SyncSession>()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val clientId = o.optString("clientId").ifEmpty { o.optString("id") }
            val at = o.optLong("at", 0L)
            val minutes = o.optInt("minutes", 0)
            if (clientId.isBlank() || at <= 0L || minutes <= 0) continue
            rows += HistoryStore.SyncSession(
                clientId = clientId,
                at = at,
                minutes = minutes,
                sceneId = o.optString("sceneId"),
                elapsedMs = o.optLong("elapsedMs", 0L),
            )
        }
        history.mergeFromCloud(rows)
    }

    private fun request(method: String, path: String, body: JSONObject?): JSONObject {
        val (deviceId, deviceSecret) = ensureCredentials()
        val url = URL(API_BASE + path)
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = if (method == "DELETE") "DELETE" else method
            connectTimeout = 12_000
            readTimeout = 15_000
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("X-Device-Id", deviceId)
            setRequestProperty("X-Device-Secret", deviceSecret)
            doInput = true
            if (body != null && method != "GET" && method != "DELETE") {
                doOutput = true
            }
        }
        try {
            if (body != null && method != "GET" && method != "DELETE") {
                OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body.toString()) }
            }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.use { BufferedReader(InputStreamReader(it, Charsets.UTF_8)).readText() }.orEmpty()
            val json = if (text.isBlank()) JSONObject() else JSONObject(text)
            if (code !in 200..299 || !json.optBoolean("success", false)) {
                throw IllegalStateException(json.optString("message", "HTTP $code"))
            }
            return json.optJSONObject("data") ?: JSONObject()
        } finally {
            conn.disconnect()
        }
    }

    companion object {
        const val MODE_LOCAL = "local"
        const val MODE_CLOUD = "cloud"
        const val API_BASE = "https://5min.chat/api/v1/storage"
    }
}
