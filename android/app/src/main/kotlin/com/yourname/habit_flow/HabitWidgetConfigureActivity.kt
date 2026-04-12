package com.yourname.habit_flow

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class HabitWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        setContentView(R.layout.activity_habit_widget_configure)

        val intent = intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val prefs = HomeWidgetPlugin.getData(this)
        val habitsJsonString = prefs.getString("habits_list", "[]")
        
        val habitsList = mutableListOf<JSONObject>()
        try {
            val jsonArray = JSONArray(habitsJsonString)
            for (i in 0 until jsonArray.length()) {
                habitsList.add(jsonArray.getJSONObject(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (habitsList.isEmpty()) {
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val info = appWidgetManager.getAppWidgetInfo(appWidgetId)
            if (info?.provider?.className == HabitWidgetSmall::class.java.name) {
                HabitWidgetSmall.updateWidget(this, appWidgetManager, appWidgetId)
            } else {
                HabitWidget.updateWidget(this, appWidgetManager, appWidgetId)
            }
            val resultValue = Intent()
            resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            finish()
            return
        }

        val listView = findViewById<ListView>(R.id.habits_list)
        
        val adapter = object : ArrayAdapter<JSONObject>(this, R.layout.item_habit_configure, habitsList) {
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val view = convertView ?: layoutInflater.inflate(R.layout.item_habit_configure, parent, false)
                val item = getItem(position)
                
                val title = view.findViewById<TextView>(R.id.habit_title)
                val subtitle = view.findViewById<TextView>(R.id.habit_subtitle)
                val icon = view.findViewById<TextView>(R.id.habit_icon)
                
                title.text = item?.optString("name", "Unknown")
                subtitle.text = item?.optString("description", "")
                
                val emoji = item?.optString("iconEmoji", "") ?: ""
                icon.text = if (emoji.isNotEmpty()) emoji else title.text.toString().take(1)

                return view
            }
        }
        
        listView.adapter = adapter
        
        listView.setOnItemClickListener { _, _, position, _ ->
            val selectedHabit = habitsList[position]
            val habitId = selectedHabit.optString("id", "")
            
            // Save the mapping: appWidgetId -> habitId
            val widgetPrefs = getSharedPreferences("com.yourname.habit_flow.WIDGETS", Context.MODE_PRIVATE)
            widgetPrefs.edit().putString("widget_$appWidgetId", habitId).apply()
            
            // Update widget now
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val info = appWidgetManager.getAppWidgetInfo(appWidgetId)
            if (info?.provider?.className == HabitWidgetSmall::class.java.name) {
                HabitWidgetSmall.updateWidget(this, appWidgetManager, appWidgetId)
            } else {
                HabitWidget.updateWidget(this, appWidgetManager, appWidgetId)
            }
            
            val resultValue = Intent()
            resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            finish()
        }
    }
}
