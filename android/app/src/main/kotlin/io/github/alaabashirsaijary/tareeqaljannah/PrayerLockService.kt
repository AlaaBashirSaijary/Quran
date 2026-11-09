package io.github.alaabashirsaijary.tareeqaljannah

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Watches which app comes to the front, nothing else: it does not read the
 * screen (canRetrieveWindowContent is off). When the prayer lock is active
 * and the app is one the user chose, it goes to the home screen and shows
 * the lock screen.
 */
class PrayerLockService : AccessibilityService() {
  private var lastShown = 0L

  override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
    val pkg = event.packageName?.toString() ?: return
    if (pkg == packageName) return
    val lock = PrayerLock.current(this) ?: return
    if (pkg !in lock.apps) return
    val now = System.currentTimeMillis()
    if (now - lastShown < 1500L) return
    lastShown = now
    performGlobalAction(GLOBAL_ACTION_HOME)
    try {
      startActivity(
          Intent(this, PrayerLockActivity::class.java)
              .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
              .putExtra(PrayerLockActivity.EXTRA_PRAYER, lock.prayer)
              .putExtra(PrayerLockActivity.EXTRA_ENGLISH, lock.english))
    } catch (e: Exception) {
      // Going to the home screen already kept the app closed.
    }
  }

  override fun onInterrupt() {}
}
