package chat.fivemin.app.timer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.MainActivity
import chat.fivemin.app.R
import chat.fivemin.app.ShortcutActivity
import chat.fivemin.app.data.HistoryStore

/**
 * Home-screen widget: today's session count + quick-start toilet scene
 * via non-exported [ShortcutActivity] (same pattern as launcher shortcuts).
 */
class TimerAppWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onEnabled(context: Context) {
        // Refresh once when the first widget instance is placed.
        requestUpdate(context)
    }

    companion object {
        fun requestUpdate(context: Context) {
            val appContext = context.applicationContext
            val mgr = AppWidgetManager.getInstance(appContext)
            val ids = mgr.getAppWidgetIds(
                ComponentName(appContext, TimerAppWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(appContext, TimerAppWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            appContext.sendBroadcast(intent)
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val count = todaySessionCount(context)
            val views = RemoteViews(context.packageName, R.layout.timer_widget).apply {
                setTextViewText(
                    R.id.widget_today_count,
                    context.getString(R.string.widget_today_count, count),
                )
                setOnClickPendingIntent(R.id.widget_root, openAppPending(context))
                setOnClickPendingIntent(R.id.widget_start_btn, startToiletPending(context))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun todaySessionCount(context: Context): Int {
            return try {
                FiveMinApp.instance.history.todayStats().first
            } catch (_: Exception) {
                try {
                    HistoryStore(context.applicationContext).todayStats().first
                } catch (_: Exception) {
                    0
                }
            }
        }

        private fun openAppPending(context: Context): PendingIntent {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            return PendingIntent.getActivity(
                context,
                REQUEST_OPEN,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun startToiletPending(context: Context): PendingIntent {
            val intent = Intent(context, ShortcutActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                putExtra(ShortcutActivity.EXTRA_SCENE_ID, "toilet")
            }
            return PendingIntent.getActivity(
                context,
                REQUEST_TOILET,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private const val REQUEST_OPEN = 4101
        private const val REQUEST_TOILET = 4102
    }
}
