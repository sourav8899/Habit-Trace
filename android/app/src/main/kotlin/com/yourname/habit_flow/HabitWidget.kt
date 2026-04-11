package com.yourname.habit_flow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class HabitWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_TICK_TODAY = "com.yourname.habit_flow.ACTION_TICK_TODAY"
        private val SDF = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, HabitWidget::class.java))
            for (id in ids) updateWidget(context, manager, id)
        }

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val widgetPrefs = context.getSharedPreferences(
                "com.yourname.habit_flow.WIDGETS", Context.MODE_PRIVATE
            )
            val habitId = widgetPrefs.getString("widget_$appWidgetId", null)
            val views = RemoteViews(context.packageName, R.layout.habit_widget)

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
                    val addUri = Uri.parse("habitflow://add_habit")
                    val addPi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, addUri)
                    views.setOnClickPendingIntent(R.id.widget_add_button, addPi)
                    views.setOnClickPendingIntent(R.id.widget_root, addPi)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            val selectedHabit = findHabitById(habitsJson, habitId)

            if (selectedHabit == null) {
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
                    val addUri = Uri.parse("habitflow://add_habit")
                    val addPi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, addUri)
                    views.setOnClickPendingIntent(R.id.widget_add_button, addPi)
                    views.setOnClickPendingIntent(R.id.widget_root, addPi)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            val title = selectedHabit.optString("name", "Habit")
            val colorValue = selectedHabit.optInt("colorValue", 0xFF7193B5.toInt())
            val iconEmoji = selectedHabit.optString("iconEmoji", "⭐")
            val createdAt = selectedHabit.optString("createdAt", "")
            val completions = selectedHabit.optJSONObject("completions") ?: JSONObject()

            // ── Title ─────────────────────────────────────────────────────
            views.setTextViewText(R.id.widget_title, title)

            // ── Icon (emoji renders natively in TextView) ──────────────────
            views.setTextViewText(R.id.widget_icon_text, iconEmoji)

            // ── Tick button ───────────────────────────────────────────────
            val todayKey = SDF.format(Date())
            val isTodayDone = completions.optBoolean(todayKey, false)

            if (isTodayDone) {
                val r = Color.red(colorValue)
                val g = Color.green(colorValue)
                val b = Color.blue(colorValue)
                views.setInt(R.id.widget_tick_box, "setBackgroundColor", Color.argb(220, r, g, b))
                views.setViewVisibility(R.id.widget_tick_icon, android.view.View.VISIBLE)
            } else {
                views.setInt(R.id.widget_tick_box, "setBackgroundResource",
                    R.drawable.widget_tick_bg_unchecked)
                views.setViewVisibility(R.id.widget_tick_icon, android.view.View.INVISIBLE)
            }

            // Tick tap intent
            val tickIntent = Intent(context, HabitWidget::class.java).apply {
                action = ACTION_TICK_TODAY
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra("habit_id", habitId)
            }
            views.setOnClickPendingIntent(
                R.id.widget_tick_box,
                PendingIntent.getBroadcast(
                    context, appWidgetId * 100, tickIntent,
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

            // ── Heatmap: dynamically sized to fill widget ──────────────────
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val density = context.resources.displayMetrics.density
            val padding = 16 * density  // 8dp each side
            val headerH = 34 * density  // approx header row height
            val marginTop = 6 * density

            val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
            val maxWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 500)
            val maxHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 200)

            val widthPx = (maxWidthDp * density - padding).toInt().coerceAtLeast(100)
            val heightPx = (maxHeightDp * density - padding - headerH - marginTop).toInt().coerceAtLeast(50)

            val rows = 7
            val gapPx = (2 * density).toInt().coerceAtLeast(2)
            val cellSize = (heightPx - (rows - 1) * gapPx) / rows
            val cols = (widthPx + gapPx) / (cellSize + gapPx)

            val bitmapW = cols * (cellSize + gapPx) - gapPx
            val bitmapH = rows * (cellSize + gapPx) - gapPx

            // Hide the '+' button and show heatmap for valid habit
            views.setViewVisibility(R.id.widget_add_button, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_heatmap, android.view.View.VISIBLE)
            views.setImageViewBitmap(
                R.id.widget_heatmap,
                buildHeatmap(completions, colorValue, createdAt, cols, rows, cellSize, gapPx, bitmapW, bitmapH)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun findHabitById(json: String, id: String): JSONObject? {
            return try {
                val arr = JSONArray(json)
                (0 until arr.length()).map { arr.getJSONObject(it) }
                    .firstOrNull { it.optString("id") == id }
            } catch (e: Exception) { null }
        }

        private fun makePillColor(base: Int): Int {
            val r = Color.red(base)
            val g = Color.green(base)
            val b = Color.blue(base)
            return Color.argb(220, r, g, b)
        }

        /**
         * Draws a heatmap bitmap with exact pixel dimensions.
         * cellPx and gapPx are computed by the caller based on actual widget size.
         */
        fun buildHeatmap(
            completions: JSONObject,
            primaryColor: Int,
            createdAtIso: String,
            cols: Int,
            rows: Int,
            cellPx: Int = 56,
            gapPx: Int = 8,
            bitmapW: Int = cols * (cellPx + gapPx) - gapPx,
            bitmapH: Int = rows * (cellPx + gapPx) - gapPx
        ): Bitmap {
            val cornerPx = (cellPx * 0.28f).coerceAtLeast(4f)

            val bitmap = Bitmap.createBitmap(bitmapW, bitmapH, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.TRANSPARENT)

            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val emptyColor = Color.parseColor("#252D34")

            // Build a lighter "today highlight" ring color
            val r = Color.red(primaryColor)
            val g = Color.green(primaryColor)
            val b = Color.blue(primaryColor)
            val todayRingColor = Color.argb(255, r, g, b)

            // Pagination logic: window based on createdAt
            val totalCells = cols * rows

            val createdCal = Calendar.getInstance()
            if (createdAtIso.length >= 10) {
                try {
                    val date = SDF.parse(createdAtIso.substring(0, 10))
                    if (date != null) createdCal.time = date
                } catch (e: Exception) {}
            }
            createdCal.set(Calendar.HOUR_OF_DAY, 0)
            createdCal.set(Calendar.MINUTE, 0)
            createdCal.set(Calendar.SECOND, 0)
            createdCal.set(Calendar.MILLISECOND, 0)

            val todayCal = Calendar.getInstance()
            todayCal.set(Calendar.HOUR_OF_DAY, 0)
            todayCal.set(Calendar.MINUTE, 0)
            todayCal.set(Calendar.SECOND, 0)
            todayCal.set(Calendar.MILLISECOND, 0)
            val todayStr = SDF.format(todayCal.time)

            val diffMillis = todayCal.timeInMillis - createdCal.timeInMillis
            val daysSinceCreation = (diffMillis / 86_400_000L).coerceAtLeast(0).toInt()
            val currentWindow = daysSinceCreation / totalCells
            val baseDateCal = createdCal.clone() as Calendar
            baseDateCal.add(Calendar.DAY_OF_YEAR, currentWindow * totalCells)

            // Ring paint for "today" cell
            val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = (cellPx * 0.08f).coerceAtLeast(2f)
                color = todayRingColor
            }

            for (col in 0 until cols) {
                for (row in 0 until rows) {
                    val cellIndex = col * rows + row
                    val cellCal = baseDateCal.clone() as Calendar
                    cellCal.add(Calendar.DAY_OF_YEAR, cellIndex)
                    val key = SDF.format(cellCal.time)
                    val done = completions.optBoolean(key, false)
                    val isToday = key == todayStr

                    val left = (col * (cellPx + gapPx)).toFloat()
                    val top = (row * (cellPx + gapPx)).toFloat()
                    val rect = RectF(left, top, left + cellPx, top + cellPx)

                    // Fill
                    paint.color = when {
                        done -> primaryColor
                        isToday -> Color.parseColor("#3A4550") // slightly lighter for today
                        else -> emptyColor
                    }
                    canvas.drawRoundRect(rect, cornerPx, cornerPx, paint)

                    // Ring around today's cell
                    if (isToday) {
                        val inset = ringPaint.strokeWidth / 2f
                        val ringRect = RectF(rect.left + inset, rect.top + inset, rect.right - inset, rect.bottom - inset)
                        canvas.drawRoundRect(ringRect, cornerPx, cornerPx, ringPaint)
                    }
                }
            }
            return bitmap
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
        if (intent.action != ACTION_TICK_TODAY) return

        val habitId = intent.getStringExtra("habit_id") ?: return
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID
        )

        val prefs = HomeWidgetPlugin.getData(context)
        val habitsJson = prefs.getString("habits_list", "[]") ?: "[]"

        try {
            val arr = JSONArray(habitsJson)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("id") != habitId) continue

                val compl = obj.optJSONObject("completions") ?: JSONObject()
                val today  = SDF.format(Date())
                compl.put(today, !compl.optBoolean(today, false))
                obj.put("completions", compl)
                prefs.edit().putString("habits_list", arr.toString()).apply()
                break
            }
        } catch (e: Exception) { e.printStackTrace() }

        updateAllWidgets(context)
        HabitWidgetSmall.updateAllWidgets(context)
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
