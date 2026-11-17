package chat.fivemin.app.data

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
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

    fun localVersionName(context: Context): String {
        return runCatching {
            val info = if (Build.VERSION.SDK_INT >= 33) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(context.packageName, 0)
            }
            info.versionName.orEmpty()
        }.getOrNull().orEmpty().ifBlank { "—" }
    }

    fun localVersionCode(context: Context): Long {
        return runCatching {
            val info = if (Build.VERSION.SDK_INT >= 33) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(context.packageName, 0)
            }
            if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        }.getOrNull() ?: 0L
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
            val apkUrl = json.optString("apkUrl").trim()
            val pageUrl = json.optString("pageUrl").trim().ifBlank { FALLBACK_PAGE }
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
        val target = url.trim()
        if (!target.startsWith("https://", ignoreCase = true)) return
        runCatching {
            context.startActivity(
                android.content.Intent(
                    android.content.Intent.ACTION_VIEW,
                    android.net.Uri.parse(target),
                ),
            )
        }
    }
}
