package io.github.alaabashirsaijary.tareeqaljannah

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Starts the prayer lock's watcher again after a restart or an update, if it was on. */
class PrayerLockBoot : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    PrayerLockWatcher.apply(context)
  }
}
