package io.github.alaabashirsaijary.tareeqaljannah

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** What the user sees instead of a social app during the prayer lock. */
class PrayerLockActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: ""
    val en = intent.getBooleanExtra(EXTRA_ENGLISH, false)
    fun t(ar: String, english: String) = if (en) english else ar

    val pad = (24 * resources.displayMetrics.density).toInt()
    val root =
        LinearLayout(this).apply {
          orientation = LinearLayout.VERTICAL
          gravity = Gravity.CENTER
          setPadding(pad, pad, pad, pad)
          setBackgroundColor(Color.parseColor("#1F1B2E"))
          layoutDirection = if (en) View.LAYOUT_DIRECTION_LTR else View.LAYOUT_DIRECTION_RTL
        }
    fun text(value: String, size: Float, bold: Boolean = false, alpha: Float = 1f) =
        TextView(this).apply {
          this.text = value
          textSize = size
          setTextColor(Color.WHITE)
          this.alpha = alpha
          gravity = Gravity.CENTER
          if (bold) setTypeface(typeface, Typeface.BOLD)
          setPadding(0, pad / 3, 0, pad / 3)
        }
    fun button(label: String, filled: Boolean, onClick: () -> Unit) =
        Button(this).apply {
          this.text = label
          isAllCaps = false
          textSize = 17f
          setTextColor(if (filled) Color.parseColor("#1F1B2E") else Color.WHITE)
          setBackgroundColor(if (filled) Color.parseColor("#E8C26A") else Color.parseColor("#3A3552"))
          setOnClickListener { onClick() }
          layoutParams =
              LinearLayout.LayoutParams(
                      LinearLayout.LayoutParams.MATCH_PARENT,
                      LinearLayout.LayoutParams.WRAP_CONTENT)
                  .apply { topMargin = pad / 2 }
        }

    root.addView(text("🕌", 56f))
    root.addView(
        text(
            if (prayer.isEmpty()) t("حان وقت الصلاة", "It is time to pray")
            else t("حان وقت صلاة $prayer", "It is time for $prayer"),
            26f,
            bold = true))
    root.addView(
        text(
            t(
                "أغلقتُ تطبيقات التواصل لتصلّي وتقرأ أذكار ما بعد الصلاة.\nارجع إليها بعد أن تنتهي.",
                "Social apps are closed so you can pray and read the azkar.\nCome back to them when you are done."),
            17f,
            alpha = 0.85f))
    root.addView(
        button(t("افتح منهج حياة (الأذكار)", "Open the app (azkar)"), true) {
          startActivity(
              Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
          finish()
        })
    root.addView(
        button(t("أتممتُ الصلاة والأذكار", "I have prayed and read the azkar"), false) {
          PrayerLock.markDone(this)
          finish()
        })
    root.addView(button(t("إغلاق", "Close"), false) { goHome() })
    setContentView(root)
  }

  @Deprecated("Deprecated in Java")
  override fun onBackPressed() = goHome()

  private fun goHome() {
    startActivity(
        Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    finish()
  }

  companion object {
    const val EXTRA_PRAYER = "prayer"
    const val EXTRA_ENGLISH = "english"
  }
}
