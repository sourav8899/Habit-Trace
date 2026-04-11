package com.yourname.habit_flow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import android.graphics.Color
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class HabitWidgetSmall : AppWidgetProvider() {

    companion object {
        const val ACTION_TICK_TODAY_SMALL = "com.yourname.habit_flow.ACTION_TICK_TODAY_SMALL"
        private val SDF = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, HabitWidgetSmall::class.java))
            for (id in ids) updateWidget(context, manager, id)
        }

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val widgetPrefs = context.getSharedPreferences(
                "com.yourname.habit_flow.WIDGETS", Context.MODE_PRIVATE
            )
            val habitId = widgetPrefs.getString("widget_$appWidgetId", null)
            val views = RemoteViews(context.packageName, R.layout.habit_widget_small)

            val prefs = HomeWidgetPlugin.getData(context)
            val habitsJson = prefs.getString("habits_list", "[]") ?: "[]"
            val hasHabits = try { JSONArray(habitsJson).length() > 0 } catch (e: Exception) { false }

            if (habitId == null) {
                views.setViewVisibility(R.id.widget_tick_icon, android.view.View.INVISIBLE)
                views.setInt(R.id.widget_tick_box, "setBackgroundColor", Color.TRANSPARENT)
                views.setViewVisibility(R.id.widget_heatmap, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_add_button, android.view.View.VISIBLE)

                if (hasHabits) {
                    views.setTextViewText(R.id.widget_title, "Select a habit")
                    val intent = Intent(context, HabitWidgetConfigureActivity::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    }
                    val configPi = PendingIntent.getActivity(
                        context, appWidgetId, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_add_button, configPi)
                    views.setOnClickPendingIntent(R.id.widget_root, configPi)
                } else {
                    views.setTextViewText(R.id.widget_title, "No habits yet")
                    val addUri = android.net.Uri.parse("habitflow://add_habit")
                    val addPi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, addUri)
                    views.setOnClickPendingIntent(R.id.widget_add_button, addPi)
                    views.setOnClickPendingIntent(R.id.widget_root, addPi)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            val habit = try {
                val arr = JSONArray(habitsJson)
                (0 until arr.length()).map { arr.getJSONObject(it) }.firstOrNull { it.optString("id") == habitId }
            } catch (e: Exception) { null }

            if (habit == null) {
                views.setViewVisibility(R.id.widget_tick_icon, android.view.View.INVISIBLE)
                views.setInt(R.id.widget_tick_box, "setBackgroundColor", Color.TRANSPARENT)
                views.setViewVisibility(R.id.widget_heatmap, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_add_button, android.view.View.VISIBLE)

                if (hasHabits) {
                    views.setTextViewText(R.id.widget_title, "Select a habit")
                    val intent = Intent(context, HabitWidgetConfigureActivity::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    }
                    val configPi = PendingIntent.getActivity(
                        context, appWidgetId, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_add_button, configPi)
                    views.setOnClickPendingIntent(R.id.widget_root, configPi)
                } else {
                    views.setTextViewText(R.id.widget_title, "No habits yet")
                    val addUri = android.net.Uri.parse("habitflow://add_habit")
                    val addPi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, addUri)
                    views.setOnClickPendingIntent(R.id.widget_add_button, addPi)
                    views.setOnClickPendingIntent(R.id.widget_root, addPi)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            val title = habit.optString("name", "Habit")
            val colorValue = habit.optInt("colorValue", 0xFF7193B5.toInt())
            val iconEmoji = habit.optString("iconEmoji", "⭐")
            val createdAt = habit.optString("createdAt", "")
            val completions = habit.optJSONObject("completions") ?: JSONObject()

            // Icon (emoji renders natively in TextView)
            views.setTextViewText(R.id.widget_icon_text, iconEmoji)

            // Title
            views.setTextViewText(R.id.widget_title, title)

            // Heatmap: dynamically sized for 2x2 widget shape
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val density = context.resources.displayMetrics.density
            val padding = 16 * density
            val headerH = 34 * density
            val marginTop = 6 * density

            val maxWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 200)
            val maxHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 200)

            val widthPx = (maxWidthDp * density - padding).toInt().coerceAtLeast(60)
            val heightPx = (maxHeightDp * density - padding - headerH - marginTop).toInt().coerceAtLeast(40)

            val rows = 7
            val gapPx = (2 * density).toInt().coerceAtLeast(2)
            val cellSize = (heightPx - (rows - 1) * gapPx) / rows
            val cols = (widthPx + gapPx) / (cellSize + gapPx)

            val bitmapW = cols * (cellSize + gapPx) - gapPx
            val bitmapH = rows * (cellSize + gapPx) - gapPx

            // Hide '+' button, show heatmap for valid habit
            views.setViewVisibility(R.id.widget_add_button, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_heatmap, android.view.View.VISIBLE)
            views.setImageViewBitmap(
                R.id.widget_heatmap,
                HabitWidget.buildHeatmap(completions, colorValue, createdAt, cols, rows, cellSize, gapPx, bitmapW, bitmapH)
            )

            // Today done?
            val todayKey = SDF.format(Date())
            val isTodayDone = completions.optBoolean(todayKey, false)

            if (isTodayDone) {
                val r = Color.red(colorValue)
                val g = Color.green(colorValue)
                val b = Color.blue(colorValue)
                views.setInt(R.id.widget_tick_box, "setBackgroundColor", Color.argb(220, r, g, b))
                views.setViewVisibility(R.id.widget_tick_icon, android.view.View.VISIBLE)
            } else {
                views.setInt(R.id.widget_tick_box, "setBackgroundResource", R.drawable.widget_tick_bg_unchecked)
                views.setViewVisibility(R.id.widget_tick_icon, android.view.View.INVISIBLE)
            }

            // Tick tap intent
            val tickIntent = Intent(context, HabitWidgetSmall::class.java).apply {
                action = ACTION_TICK_TODAY_SMALL
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra("habit_id", habitId)
            }
            views.setOnClickPendingIntent(
                R.id.widget_tick_box,
                PendingIntent.getBroadcast(
                    context, appWidgetId * 200, tickIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )

            // Root tap → open habit stats deep link
            val uri = Uri.parse("habitflow://habit/${habitId}")
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    uri
                )
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(
        context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray
    ) = appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }

    override fun onAppWidgetOptionsChanged(
        context: Context, appWidgetManager: AppWidgetManager,
        appWidgetId: Int, newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_TICK_TODAY_SMALL) return

        val habitId = intent.getStringExtra("habit_id") ?: return
        val prefs = HomeWidgetPlugin.getData(context)
        val habitsJson = prefs.getString("habits_list", "[]") ?: "[]"

        try {
            val arr = JSONArray(habitsJson)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("id") != habitId) continue
                val compl = obj.optJSONObject("completions") ?: JSONObject()
                val today = SDF.format(Date())
                compl.put(today, !compl.optBoolean(today, false))
                obj.put("completions", compl)
                prefs.edit().putString("habits_list", arr.toString()).apply()
                break
            }
        } catch (e: Exception) { e.printStackTrace() }

        updateAllWidgets(context)
        HabitWidget.updateAllWidgets(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val wp = context.getSharedPreferences(
            "com.yourname.habit_flow.WIDGETS", Context.MODE_PRIVATE
        ).edit()
        appWidgetIds.forEach { wp.remove("widget_$it") }
        wp.apply()
    }
}
