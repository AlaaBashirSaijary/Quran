package io.github.alaabashirsaijary.tareeqaljannah

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.text.format.DateFormat
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar
import java.util.Date

/**
 * Home-screen widget with the next prayer and today's prayer times.
 *
 * The app saves the coming week's times (lib/widget/prayer_widget.dart); the
 * widget picks what to show from the current time and is redrawn at each
 * prayer time.
 */
class PrayerWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val times = readTimes(widgetData.getString("prayer_times", null))
    val place = placeOf(widgetData.getString("prayer_times", null))
    val now = System.currentTimeMillis()
    val next = times.firstOrNull { it.second > now }
    val today = Calendar.getInstance()
    val todays =
        times.filter {
          val c = Calendar.getInstance().apply { timeInMillis = it.second }
          c.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
              c.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
        }
    val format = DateFormat.getTimeFormat(context)

    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.prayer_widget)
      views.setOnClickPendingIntent(
          R.id.widget_root,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
      )
      if (next == null) {
        views.setTextViewText(R.id.widget_next_name, "مواقيت الصلاة")
        views.setTextViewText(R.id.widget_next_time, "")
        views.setTextViewText(R.id.widget_place, "افتح التطبيق لتحديد موقعك")
        views.setTextViewText(R.id.widget_today, "")
      } else {
        views.setTextViewText(R.id.widget_next_name, "الصلاة القادمة: ${next.first}")
        views.setTextViewText(R.id.widget_next_time, format.format(Date(next.second)))
        views.setTextViewText(R.id.widget_place, place ?: "")
        views.setTextViewText(
            R.id.widget_today,
            todays.joinToString("  ·  ") { "${it.first} ${format.format(Date(it.second))}" },
        )
      }
      appWidgetManager.updateAppWidget(id, views)
    }
  }

  private fun readTimes(json: String?): List<Pair<String, Long>> {
    if (json == null) return emptyList()
    return try {
      val list = JSONObject(json).getJSONArray("times")
      (0 until list.length()).map {
        val t = list.getJSONArray(it)
        Pair(t.getString(0), t.getLong(1))
      }
    } catch (e: Exception) {
      emptyList()
    }
  }

  private fun placeOf(json: String?): String? {
    if (json == null) return null
    return try {
      JSONObject(json).optString("place").ifEmpty { null }
    } catch (e: Exception) {
      null
    }
  }
}
