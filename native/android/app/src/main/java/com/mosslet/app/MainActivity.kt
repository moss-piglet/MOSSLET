package com.mosslet.app

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.webkit.*
import android.widget.ProgressBar
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private lateinit var loadingView: View
    private lateinit var progressBar: ProgressBar
    private lateinit var jsonBridge: JsonBridge
    private var serverPort: Int = 0

    companion object {
        const val NOTIFICATION_PERMISSION_CODE = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        WindowCompat.setDecorFitsSystemWindows(window, false)

        webView = findViewById(R.id.webView)
        loadingView = findViewById(R.id.loadingView)
        progressBar = findViewById(R.id.progressBar)

        setupWebView()
        startErlangAndLoadApp()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            mediaPlaybackRequiresUserGesture = false
            allowFileAccess = false
            allowContentAccess = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            cacheMode = WebSettings.LOAD_DEFAULT

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                safeBrowsingEnabled = true
            }
        }

        jsonBridge = JsonBridge(this)
        webView.addJavascriptInterface(jsonBridge, "AndroidBridge")
        jsonBridge.setWebView(webView)

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString() ?: return false

                return when {
                    url.startsWith("http://localhost") -> false
                    url.startsWith("mailto:") || url.startsWith("tel:") -> {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        true
                    }
                    else -> {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        true
                    }
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                loadingView.visibility = View.GONE
                webView.visibility = View.VISIBLE
                injectSafeAreaInsets()
                injectAndroidBridgeScript()
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                super.onReceivedError(view, request, error)
                if (request?.isForMainFrame == true) {
                    showErrorAndRetry("Connection error. Please try again.")
                }
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                progressBar.progress = newProgress
            }

            override fun onJsAlert(view: WebView?, url: String?, message: String?, result: JsResult?): Boolean {
                AlertDialog.Builder(this@MainActivity)
                    .setMessage(message)
                    .setPositiveButton(android.R.string.ok) { _, _ -> result?.confirm() }
                    .setOnCancelListener { result?.cancel() }
                    .show()
                return true
            }

            override fun onJsConfirm(view: WebView?, url: String?, message: String?, result: JsResult?): Boolean {
                AlertDialog.Builder(this@MainActivity)
                    .setMessage(message)
                    .setPositiveButton(android.R.string.ok) { _, _ -> result?.confirm() }
                    .setNegativeButton(android.R.string.cancel) { _, _ -> result?.cancel() }
                    .setOnCancelListener { result?.cancel() }
                    .show()
                return true
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT && BuildConfig.DEBUG) {
            WebView.setWebContentsDebuggingEnabled(true)
        }
    }
    
    private fun injectAndroidBridgeScript() {
        val script = """
            if (!window.MossletNative) {
                window.MossletNative = {
                    postMessage: function(message) {
                        AndroidBridge.postMessage(JSON.stringify(message));
                    },
                    
                    openURL: function(url) {
                        this.postMessage({ action: 'open_url', url: url });
                    },
                    
                    share: function(text, url) {
                        this.postMessage({ action: 'share', text: text, url: url });
                    },
                    
                    haptic: function(style) {
                        this.postMessage({ action: 'haptic', style: style || 'medium' });
                    },
                    
                    isNative: function() {
                        return true;
                    },
                    
                    getPlatform: function() {
                        return 'android';
                    },
                    
                    push: {
                        requestPermission: function() {
                            AndroidBridge.postMessage(JSON.stringify({ action: 'push_request_permission' }));
                        },
                        
                        getPermissionStatus: function() {
                            AndroidBridge.postMessage(JSON.stringify({ action: 'push_get_permission_status' }));
                        },
                        
                        onPermissionResult: null,
                        onPermissionStatus: null,
                        onTokenReceived: null,
                        onTokenError: null,
                        onNotificationReceived: null,
                        onNotificationTapped: null
                    }
                };
                
                window.dispatchEvent(new CustomEvent('mosslet-native-ready'));
            }
        """.trimIndent()
        webView.evaluateJavascript(script, null)
    }

    private fun startErlangAndLoadApp() {
        lifecycleScope.launch {
            serverPort = withContext(Dispatchers.IO) {
                Bridge.startErlang(this@MainActivity)
            }
            loadApp()
        }
    }

    private fun loadApp() {
        val url = "http://localhost:$serverPort"
        val headers = mapOf("X-Desktop-Auth" to Bridge.authToken())
        webView.loadUrl(url, headers)
    }

    private fun injectSafeAreaInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(webView) { _, insets ->
            val systemBars = insets.getInsets(WindowInsets.Type.systemBars())
            val js = """
                document.documentElement.style.setProperty('--safe-area-top', '${systemBars.top}px');
                document.documentElement.style.setProperty('--safe-area-bottom', '${systemBars.bottom}px');
                document.documentElement.style.setProperty('--safe-area-left', '${systemBars.left}px');
                document.documentElement.style.setProperty('--safe-area-right', '${systemBars.right}px');
            """.trimIndent()
            webView.evaluateJavascript(js, null)
            insets
        }
    }

    private fun showErrorAndRetry(message: String) {
        AlertDialog.Builder(this)
            .setTitle("Error")
            .setMessage(message)
            .setPositiveButton("Retry") { _, _ -> loadApp() }
            .setNegativeButton("Exit") { _, _ -> finish() }
            .show()
    }
    
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        handlePushNotificationIntent(intent)
    }
    
    private fun handlePushNotificationIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("from_notification", false) == true) {
            val data = mutableMapOf<String, String>()
            intent.extras?.keySet()?.forEach { key ->
                if (key.startsWith("push_")) {
                    val value = intent.getStringExtra(key)
                    if (value != null) {
                        data[key.removePrefix("push_")] = value
                    }
                }
            }
            if (data.isNotEmpty()) {
                PushNotificationService.handleNotificationTapped(data)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Bridge.sendEvent("app_resumed")
        webView.onResume()
        handlePushNotificationIntent(intent)
    }

    override fun onPause() {
        super.onPause()
        Bridge.sendEvent("app_paused")
        webView.onPause()
    }

    override fun onDestroy() {
        super.onDestroy()
        Bridge.sendEvent("app_destroyed")
        webView.destroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == NOTIFICATION_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && 
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            jsonBridge.onPermissionResult(granted)
        }
    }

    fun openExternalUrl(url: String) {
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }

    fun shareContent(text: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(intent, "Share"))
    }
}
