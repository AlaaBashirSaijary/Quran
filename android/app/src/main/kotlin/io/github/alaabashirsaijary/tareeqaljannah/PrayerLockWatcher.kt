package io.github.alaabashirsaijary.tareeqaljannah

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Runs while the user has the prayer lock turned on. It looks at which app
 * came to the front (usage access, no screen content) and, while a lock is
 * active, puts the lock screen over the apps the user chose. Outside a
 * lock it only wakes up every half minute to look at the clock.
 */
@Suppress("DEPRECATION")
class PrayerLockWatcher : Service() {
  private val handler = Handler(Looper.getMainLooper())
  private var lastPackage: String? = null
  private var lastQuery = 0L
  private var lastShown = 0L

  private val tick =
      object : Runnable {
        override fun run() {
          if (!PrayerLock.wanted(this@PrayerLockWatcher) || !PrayerLock.ready(this@PrayerLockWatcher)) {
            stopSelf()
            return
          }
          val active = check()
          handler.postDelayed(this, if (active) 800L else 30_000L)
        }
      }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val notification = notification()
    if (Build.VERSION.SDK_INT >= 34) {
      startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
    } else {
      startForeground(NOTIFICATION_ID, notification)
    }
    handler.removeCallbacks(tick)
    handler.post(tick)
    return START_STICKY
  }

  override fun onDestroy() {
    handler.removeCallbacks(tick)
    super.onDestroy()
  }

  /** Looks at the app in front; returns whether a lock is active. */
  private fun check(): Boolean {
    val lock = PrayerLock.current(this)
    if (lock == null) {
      lastQuery = 0L
      lastPackage = null
      return false
    }
    val now = System.currentTimeMillis()
    val pkg = foreground(now) ?: return true
    if (pkg == packageName || pkg !in lock.apps) return true
    if (now - lastShown < 2000L) return true
    lastShown = now
    try {
      startActivity(
          Intent(this, PrayerLockActivity::class.java)
              .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
              .putExtra(PrayerLockActivity.EXTRA_PRAYER, lock.prayer)
              .putExtra(PrayerLockActivity.EXTRA_ENGLISH, lock.english))
    } catch (e: Exception) {
      // Not allowed to show it on this phone; the user can still close the lock.
    }
    return true
  }

  /** The package that last came to the front. */
  private fun foreground(now: Long): String? {
    val usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val from = if (lastQuery == 0L) now - 10_000L else lastQuery - 1_000L
    val events = usage.queryEvents(from, now)
    val event = UsageEvents.Event()
    while (events.hasNextEvent()) {
      events.getNextEvent(event)
      if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) lastPackage = event.packageName
    }
    lastQuery = now
    return lastPackage
  }

  private fun notification(): Notification {
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val builder =
        if (Build.VERSION.SDK_INT >= 26) {
          manager.createNotificationChannel(
              NotificationChannel(
                  CHANNEL, getString(R.string.prayer_lock_channel), NotificationManager.IMPORTANCE_MIN))
          Notification.Builder(this, CHANNEL)
        } else {
          Notification.Builder(this)
        }
    return builder
        .setSmallIcon(R.mipmap.ic_launcher)
        .setContentTitle(getString(R.string.prayer_lock_notification))
        .setOngoing(true)
        .build()
  }

  companion object {
    private const val CHANNEL = "prayerlock"
    private const val NOTIFICATION_ID = 7102

    /** Starts it when the lock is wanted and the permissions are given; stops it otherwise. */
    fun apply(context: Context) {
      val intent = Intent(context, PrayerLockWatcher::class.java)
      if (PrayerLock.wanted(context) && PrayerLock.ready(context)) {
        try {
          if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
          else context.startService(intent)
        } catch (e: Exception) {
          // Not allowed to start from here (the app is not in front); the next time it opens will.
        }
      } else {
        context.stopService(intent)
      }
    }
  }
}
