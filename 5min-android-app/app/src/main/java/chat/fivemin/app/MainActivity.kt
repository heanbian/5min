package chat.fivemin.app

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import chat.fivemin.app.ui.TimerApp
import chat.fivemin.app.ui.theme.FiveMinTheme

class MainActivity : ComponentActivity() {
    private var pendingAfterNotif: (() -> Unit)? = null

    private val requestNotif = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        val next = pendingAfterNotif
        pendingAfterNotif = null
        if (granted) {
            next?.invoke()
        } else {
            // Still allow timer; FGS may use system fallback. Guide user if they want banners.
            next?.invoke()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            FiveMinTheme {
                TimerApp(
                    ensureStartPermissions = ::ensureStartPermissions,
                )
            }
        }
    }

    /**
     * Ensure notification (Android 13+) and exact-alarm (Android 12+) before starting.
     * Invokes [onReady] when the timer can start (even if exact alarm falls back).
     */
    private fun ensureStartPermissions(onReady: () -> Unit) {
        if (!PermissionHelper.hasNotifications(this) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pendingAfterNotif = {
                maybePromptExactAlarm()
                onReady()
            }
            requestNotif.launch(Manifest.permission.POST_NOTIFICATIONS)
            return
        }
        maybePromptExactAlarm()
        onReady()
    }

    private fun maybePromptExactAlarm() {
        if (!PermissionHelper.hasExactAlarm(this)) {
            PermissionHelper.openExactAlarmSettings(this)
        }
    }
}
