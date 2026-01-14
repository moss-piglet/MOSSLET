package com.mosslet.app

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.webkit.JavascriptInterface
import org.json.JSONObject

class JsonBridge(private val activity: MainActivity) {

    @JavascriptInterface
    fun postMessage(jsonString: String) {
        try {
            val json = JSONObject(jsonString)
            val action = json.optString("action")

            when (action) {
                "open_url" -> {
                    val url = json.optString("url")
                    if (url.isNotEmpty()) {
                        activity.runOnUiThread { activity.openExternalUrl(url) }
                    }
                }
                "share" -> {
                    val text = json.optString("text")
                    if (text.isNotEmpty()) {
                        activity.runOnUiThread { activity.shareContent(text) }
                    }
                }
                "haptic" -> {
                    val style = json.optString("style", "medium")
                    performHaptic(style)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @JavascriptInterface
    fun isNative(): Boolean = true

    @JavascriptInterface
    fun getPlatform(): String = "android"

    private fun performHaptic(style: String) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = activity.getSystemService(VibratorManager::class.java)
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            activity.getSystemService(Vibrator::class.java)
        }

        vibrator?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = when (style) {
                    "light" -> VibrationEffect.createOneShot(10, VibrationEffect.DEFAULT_AMPLITUDE)
                    "heavy" -> VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE)
                    else -> VibrationEffect.createOneShot(25, VibrationEffect.DEFAULT_AMPLITUDE)
                }
                it.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(25)
            }
        }
    }
}
