package io.github.alaabashirsaijary.tareeqaljannah

import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  private var pendingPick: MethodChannel.Result? = null
  private var volumeChannel: MethodChannel? = null

  /** While the tasbeeh counter is open (and the user chose it), the volume keys count. */
  private var captureVolume = false

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tareeq/sounds")
        .setMethodCallHandler { call, result ->
          when (call.method) {
            "pick" -> pick(call.argument<String>("current"), result)
            "import" ->
                importSound(call.argument<String>("path")!!, call.argument<String>("name")!!, result)
            "title" -> result.success(title(call.argument<String>("uri")!!))
            else -> result.notImplemented()
          }
        }
    volumeChannel =
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tareeq/volume").apply {
          setMethodCallHandler { call, result ->
            if (call.method == "capture") {
              captureVolume = call.arguments as? Boolean ?: false
              result.success(null)
            } else {
              result.notImplemented()
            }
          }
        }
  }

  override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
    if (captureVolume &&
        (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)) {
      // One count per press, not per auto-repeat while held.
      if ((event?.repeatCount ?: 0) == 0) volumeChannel?.invokeMethod("press", null)
      return true
    }
    return super.onKeyDown(keyCode, event)
  }

  override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
    if (captureVolume &&
        (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)) {
      return true
    }
    return super.onKeyUp(keyCode, event)
  }

  /** Opens the system picker of notification and alarm sounds. */
  private fun pick(current: String?, result: MethodChannel.Result) {
    pendingPick?.success(null)
    pendingPick = result
    val intent =
        Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
          putExtra(
              RingtoneManager.EXTRA_RINGTONE_TYPE,
              RingtoneManager.TYPE_NOTIFICATION or RingtoneManager.TYPE_ALARM,
          )
          putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
          putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
          if (current != null) {
            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
          }
        }
    startActivityForResult(intent, PICK_SOUND)
  }

  @Deprecated("Deprecated in Java")
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode != PICK_SOUND) return
    val uri: Uri? =
        if (resultCode != RESULT_OK || data == null) null
        else if (Build.VERSION.SDK_INT >= 33)
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
        else @Suppress("DEPRECATION") data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
    pendingPick?.success(uri?.toString())
    pendingPick = null
  }

  /**
   * Adds an audio file to the phone's notification sounds, so the system can
   * play it for a notification. Needs Android 10 (no storage permission).
   */
  private fun importSound(path: String, name: String, result: MethodChannel.Result) {
    if (Build.VERSION.SDK_INT < 29) {
      result.error("unsupported", "Needs Android 10", null)
      return
    }
    try {
      val file = File(path)
      val mime =
          when (file.extension.lowercase()) {
            "mp3" -> "audio/mpeg"
            "ogg", "oga" -> "audio/ogg"
            "wav" -> "audio/wav"
            "m4a", "aac" -> "audio/mp4"
            else -> "audio/*"
          }
      val values =
          ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, name)
            put(MediaStore.Audio.Media.TITLE, name.substringBeforeLast('.'))
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications/")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_ALARM, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
          }
      val resolver = contentResolver
      val uri =
          resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
              ?: throw IllegalStateException("insert failed")
      resolver.openOutputStream(uri).use { out ->
        file.inputStream().use { input -> input.copyTo(out!!) }
      }
      values.clear()
      values.put(MediaStore.Audio.Media.IS_PENDING, 0)
      resolver.update(uri, values, null, null)
      result.success(uri.toString())
    } catch (e: Exception) {
      result.error("failed", e.message, null)
    }
  }

  private fun title(uri: String): String? =
      try {
        RingtoneManager.getRingtone(this, Uri.parse(uri))?.getTitle(this)
      } catch (e: Exception) {
        null
      }

  companion object {
    private const val PICK_SOUND = 7101
  }
}
