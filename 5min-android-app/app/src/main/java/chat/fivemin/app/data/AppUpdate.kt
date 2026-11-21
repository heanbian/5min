package chat.fivemin.app.data

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.pm.PackageInfoCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

data class AndroidLatest(
    val versionCode: Int,
    val versionName: String,
    val apkUrl: String,
    val pageUrl: String,
)

sealed class UpdateCheckResult {
    data class Latest(val currentName: String) : UpdateCheckResult()
    data class Available(val latest: AndroidLatest, val currentName: String) : UpdateCheckResult()
    data class Failed(val message: String? = null) : UpdateCheckResult()
}

/**
 * Checks https://5min.chat/app/android-latest.json against the installed version.
 */
object AppUpdate {
    private const val LATEST_URL = "https://5min.chat/app/android-latest.json"
    private const val FALLBACK_PAGE = "https://5min.chat/download.html"
    private val TRUSTED_HOSTS = setOf("5min.chat", "www.5min.chat")

    fun localVersionName(context: Context): String {
        return runCatching { packageInfo(context).versionName.orEmpty() }
            .getOrNull()
            .orEmpty()
            .ifBlank { "—" }
    }

    fun localVersionCode(context: Context): Long {
        return runCatching { PackageInfoCompat.getLongVersionCode(packageInfo(context)) }
            .getOrNull()
            ?: 0L
    }

    /** Blocking network call — run on a background dispatcher. */
    fun check(context: Context): UpdateCheckResult {
        val currentCode = localVersionCode(context)
        val currentName = localVersionName(context)
        return runCatching {
            val latest = fetchLatest()
            if (latest.versionCode > currentCode) {
                UpdateCheckResult.Available(latest, currentName)
            } else {
                UpdateCheckResult.Latest(currentName)
            }
        }.getOrElse {
            UpdateCheckResult.Failed(it.message)
        }
    }

    fun fetchLatest(): AndroidLatest {
        val conn = (URL(LATEST_URL).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 12_000
            readTimeout = 12_000
            setRequestProperty("Accept", "application/json")
            instanceFollowRedirects = true
        }
        try {
            val code = conn.responseCode
            if (code !in 200..299) {
                error("HTTP $code")
            }
            val body = BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8)).use { it.readText() }
            val json = JSONObject(body)
            val versionCode = json.optInt("versionCode", 0)
            val versionName = json.optString("versionName").trim()
            val apkUrl = trustedHttpsUrl(json.optString("apkUrl").trim()).orEmpty()
            val pageUrl = trustedHttpsUrl(json.optString("pageUrl").trim()) ?: FALLBACK_PAGE
            if (versionCode <= 0 || versionName.isEmpty()) {
                error("invalid update manifest")
            }
            return AndroidLatest(
                versionCode = versionCode,
                versionName = versionName,
                apkUrl = apkUrl,
                pageUrl = pageUrl,
            )
        } finally {
            conn.disconnect()
        }
    }

    fun openUrl(context: Context, url: String) {
        val target = trustedHttpsUrl(url) ?: return
        runCatching {
            context.startActivity(
                android.content.Intent(
                    android.content.Intent.ACTION_VIEW,
                    Uri.parse(target),
                ),
            )
        }
    }

    /** Only https URLs on 5min.chat (or www) are accepted for update / download links. */
    fun trustedHttpsUrl(url: String): String? {
        val target = url.trim()
        if (!target.startsWith("https://", ignoreCase = true)) return null
        val host = runCatching { Uri.parse(target).host?.lowercase() }.getOrNull() ?: return null
        if (host !in TRUSTED_HOSTS) return null
        return target
    }

    private fun packageInfo(context: Context) =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, 0)
        }
}
