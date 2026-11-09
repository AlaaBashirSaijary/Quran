package io.github.alaabashirsaijary.tareeqaljannah

import android.content.Context
import org.json.JSONObject

/**
 * The prayer lock: while it is active, the social apps the user chose are
 * not opened. The app writes the settings and the next prayer times (see
 * lib/prayerlock/prayer_lock.dart); this object only reads them, so the lock
 * works while the app itself is closed.
 *
 * Active means: the last prayer time passed less than `maxMinutes` ago and
 * the user has not said they finished since then.
 */
object PrayerLock {
  /** The prayer behind the lock and the apps it covers. */
  data class Active(val prayer: String, val apps: Set<String>, val english: Boolean)

  private const val NATIVE = "prayerlock"
  private const val DONE_AT = "doneAt"
  private const val TEST_UNTIL = "testUntil"

  // The Flutter shared_preferences plugin's file and key prefix.
  private const val FLUTTER = "FlutterSharedPreferences"
  private const val CONFIG = "flutter.prayerlock.config"

  fun current(context: Context, now: Long = System.currentTimeMillis()): Active? {
    val raw = context.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE).getString(CONFIG, null)
        ?: return null
    val native = context.getSharedPreferences(NATIVE, Context.MODE_PRIVATE)
    return try {
      val config = JSONObject(raw)
      val apps = HashSet<String>()
      val list = config.optJSONArray("apps")
      if (list != null) for (i in 0 until list.length()) apps.add(list.getString(i))
      val english = config.optBoolean("en", false)
      // A test the user started from the settings screen.
      if (now < native.getLong(TEST_UNTIL, 0L)) {
        return Active(if (english) "test" else "تجربة", apps, english)
      }
      if (!config.optBoolean("enabled", false)) return null
      val window = config.optInt("maxMinutes", 30) * 60_000L
      var latest = 0L
      var name = ""
      val times = config.optJSONArray("times") ?: return null
      for (i in 0 until times.length()) {
        val t = times.getJSONArray(i)
        val at = t.getLong(1)
        if (at <= now && at > latest) {
          latest = at
          name = t.getString(0)
        }
      }
      if (latest == 0L || now - latest >= window) return null
      if (native.getLong(DONE_AT, 0L) >= latest) return null
      Active(name, apps, english)
    } catch (e: Exception) {
      null
    }
  }

  /** The user says they prayed and read the azkar: the lock ends until the next prayer. */
  fun markDone(context: Context, now: Long = System.currentTimeMillis()) {
    context.getSharedPreferences(NATIVE, Context.MODE_PRIVATE)
        .edit()
        .putLong(DONE_AT, now)
        .putLong(TEST_UNTIL, 0L)
        .apply()
  }

  /** Locks for a minute, so the user can see how it looks. */
  fun startTest(context: Context, now: Long = System.currentTimeMillis()) {
    context.getSharedPreferences(NATIVE, Context.MODE_PRIVATE)
        .edit()
        .putLong(TEST_UNTIL, now + 60_000L)
        .apply()
  }
}
