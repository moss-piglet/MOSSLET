package com.mosslet.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.webkit.JavascriptInterface
import android.webkit.WebView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging
import org.json.JSONObject

class JsonBridge(private val activity: MainActivity) {
    
    private var webView: WebView? = null
    
    fun setWebView(webView: WebView) {
        this.webView = webView
        setupPushCallbacks()
    }
    
    private fun setupPushCallbacks() {
        PushNotificationService.setTokenCallback { token ->
            notifyTokenReceived(token)
        }
        
        PushNotificationService.setNotificationReceivedCallback { data, foreground ->
            notifyNotificationReceived(data, foreground)
        }
        
        PushNotificationService.setNotificationTappedCallback { data ->
            notifyNotificationTapped(data)
        }
    }

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
                "push_request_permission" -> {
                    activity.runOnUiThread { requestPushPermission() }
                }
                "push_get_permission_status" -> {
                    activity.runOnUiThread { getPushPermissionStatus() }
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
    
    private fun requestPushPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            when {
                ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) 
                    == PackageManager.PERMISSION_GRANTED -> {
                    notifyPermissionResult(true)
                    registerForPush()
                }
                else -> {
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        MainActivity.NOTIFICATION_PERMISSION_CODE
                    )
                }
            }
        } else {
            notifyPermissionResult(true)
            registerForPush()
        }
    }
    
    private fun getPushPermissionStatus() {
        val status = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            when {
                ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) 
                    == PackageManager.PERMISSION_GRANTED -> "granted"
                ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.POST_NOTIFICATIONS) -> "denied"
                else -> "not_determined"
            }
        } else {
            "granted"
        }
        notifyPermissionStatus(status)
    }
    
    fun registerForPush() {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                val token = task.result
                notifyTokenReceived(token)
            } else {
                notifyTokenError(task.exception?.message ?: "Failed to get FCM token")
            }
        }
    }
    
    fun onPermissionResult(granted: Boolean) {
        notifyPermissionResult(granted)
        if (granted) {
            registerForPush()
        }
    }
    
    private fun notifyPermissionResult(granted: Boolean) {
        executeJavaScript("""
            if (window.MossletNative && window.MossletNative.push.onPermissionResult) {
                window.MossletNative.push.onPermissionResult($granted);
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-permission', { detail: { granted: $granted } }));
        """.trimIndent())
    }
    
    private fun notifyPermissionStatus(status: String) {
        executeJavaScript("""
            if (window.MossletNative && window.MossletNative.push.onPermissionStatus) {
                window.MossletNative.push.onPermissionStatus('$status');
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-permission-status', { detail: { status: '$status' } }));
        """.trimIndent())
    }
    
    private fun notifyTokenReceived(token: String) {
        executeJavaScript("""
            if (window.MossletNative && window.MossletNative.push.onTokenReceived) {
                window.MossletNative.push.onTokenReceived('$token');
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-token', { detail: { token: '$token' } }));
        """.trimIndent())
    }
    
    private fun notifyTokenError(error: String) {
        val escapedError = error.replace("'", "\\'")
        executeJavaScript("""
            if (window.MossletNative && window.MossletNative.push.onTokenError) {
                window.MossletNative.push.onTokenError('$escapedError');
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-token-error', { detail: { error: '$escapedError' } }));
        """.trimIndent())
    }
    
    private fun notifyNotificationReceived(data: Map<String, String>, foreground: Boolean) {
        val jsonData = JSONObject(data).toString()
        executeJavaScript("""
            var data = $jsonData;
            if (window.MossletNative && window.MossletNative.push.onNotificationReceived) {
                window.MossletNative.push.onNotificationReceived(data, $foreground);
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-received', { detail: { data: data, foreground: $foreground } }));
        """.trimIndent())
    }
    
    private fun notifyNotificationTapped(data: Map<String, String>) {
        val jsonData = JSONObject(data).toString()
        executeJavaScript("""
            var data = $jsonData;
            if (window.MossletNative && window.MossletNative.push.onNotificationTapped) {
                window.MossletNative.push.onNotificationTapped(data);
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-tapped', { detail: { data: data } }));
        """.trimIndent())
    }
    
    private fun executeJavaScript(script: String) {
        activity.runOnUiThread {
            webView?.evaluateJavascript(script, null)
        }
    }

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
