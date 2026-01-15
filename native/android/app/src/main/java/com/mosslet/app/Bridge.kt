package com.mosslet.app

import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.SecureRandom
import android.util.Base64
import kotlin.concurrent.thread

object Bridge {
    private const val TAG = "MossletBridge"
    private var erlangPort: Int = 0
    private var authToken: String? = null
    private var secretKeyBase: String? = null
    private var isStarted = false
    private var erlangThread: Thread? = null

    interface StartCallback {
        fun onStarted(port: Int)
        fun onError(error: String)
    }

    fun startErlang(context: Context, callback: StartCallback) {
        if (isStarted) {
            callback.onStarted(erlangPort)
            return
        }

        erlangThread = thread(name = "ErlangRuntime") {
            try {
                val port = doStartErlang(context)
                android.os.Handler(context.mainLooper).post {
                    callback.onStarted(port)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start Erlang", e)
                android.os.Handler(context.mainLooper).post {
                    callback.onError(e.message ?: "Unknown error")
                }
            }
        }
    }

    private fun doStartErlang(context: Context): Int {
        setEnvironmentVariables(context)
        
        authToken = getOrCreateAuthToken(context)
        secretKeyBase = getOrCreateSecretKeyBase(context)

        val nativeLibDir = context.applicationInfo.nativeLibraryDir
        val dataDir = File(context.filesDir, "mosslet_data").apply { mkdirs() }
        val assetsRelDir = extractRelease(context)

        setEnv("RELEASE_ROOT", assetsRelDir.absolutePath)
        setEnv("RELEASE_NAME", "mobile")
        setEnv("RELEASE_VSN", releaseVersion(context))
        setEnv("HOME", dataDir.absolutePath)
        setEnv("MOSSLET_DESKTOP", "true")
        setEnv("MOSSLET_MOBILE", "true")
        setEnv("MOSSLET_DATA_DIR", dataDir.absolutePath)
        setEnv("DESKTOP_AUTH_TOKEN", authToken!!)
        setEnv("SECRET_KEY_BASE", secretKeyBase!!)
        setEnv("PHX_SERVER", "true")
        setEnv("PORT", "4000")
        setEnv("LD_LIBRARY_PATH", nativeLibDir)

        Log.d(TAG, "Starting Erlang VM...")
        Log.d(TAG, "Native lib dir: $nativeLibDir")
        Log.d(TAG, "Release dir: ${assetsRelDir.absolutePath}")

        erlangPort = startErlangProcess(context, assetsRelDir.absolutePath, nativeLibDir)
        isStarted = true

        waitForPhoenix(erlangPort, 30)

        Log.d(TAG, "Erlang started on port $erlangPort")
        return erlangPort
    }

    private fun extractRelease(context: Context): File {
        val relDir = File(context.filesDir, "rel")
        val versionFile = File(relDir, ".version")
        val currentVersion = releaseVersion(context)

        if (relDir.exists() && versionFile.exists()) {
            val extractedVersion = versionFile.readText().trim()
            if (extractedVersion == currentVersion) {
                Log.d(TAG, "Release already extracted (v$currentVersion)")
                return relDir
            }
        }

        Log.d(TAG, "Extracting release v$currentVersion...")
        relDir.deleteRecursively()
        relDir.mkdirs()

        extractAssetDir(context, "rel", relDir)

        versionFile.writeText(currentVersion)
        Log.d(TAG, "Release extracted successfully")
        return relDir
    }

    private fun extractAssetDir(context: Context, assetPath: String, targetDir: File) {
        val assetManager = context.assets
        val files = assetManager.list(assetPath) ?: return

        for (file in files) {
            val assetFilePath = "$assetPath/$file"
            val targetFile = File(targetDir, file)

            val subFiles = assetManager.list(assetFilePath)
            if (subFiles != null && subFiles.isNotEmpty()) {
                targetFile.mkdirs()
                extractAssetDir(context, assetFilePath, targetFile)
            } else {
                assetManager.open(assetFilePath).use { input ->
                    FileOutputStream(targetFile).use { output ->
                        input.copyTo(output)
                    }
                }
                if (file.endsWith(".sh") || file == "beam.smp" || file == "erl") {
                    targetFile.setExecutable(true)
                }
            }
        }
    }

    private fun waitForPhoenix(port: Int, timeoutSeconds: Int) {
        val startTime = System.currentTimeMillis()
        val timeoutMs = timeoutSeconds * 1000L

        while (System.currentTimeMillis() - startTime < timeoutMs) {
            try {
                val url = URL("http://127.0.0.1:$port/health")
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 1000
                conn.readTimeout = 1000
                conn.requestMethod = "GET"

                if (conn.responseCode == 200) {
                    Log.d(TAG, "Phoenix is ready on port $port")
                    return
                }
            } catch (e: Exception) {
            }
            Thread.sleep(500)
        }

        Log.w(TAG, "Phoenix did not respond within $timeoutSeconds seconds")
    }

    fun stopErlang() {
        if (!isStarted) return

        sendEvent("shutdown")
        isStarted = false
        Log.d(TAG, "Erlang stopped")
    }

    fun sendEvent(event: String, data: Map<String, Any>? = null) {
        if (!isStarted) return
        Log.d(TAG, "Event: $event")
    }

    fun authToken(): String {
        return authToken ?: ""
    }

    fun getPort(): Int {
        return erlangPort
    }

    fun isRunning(): Boolean {
        return isStarted
    }

    private fun setEnvironmentVariables(context: Context) {
        val locale = context.resources.configuration.locales[0]
        setEnv("LANG", "${locale.language}.UTF-8")

        val tz = java.util.TimeZone.getDefault().id
        setEnv("TZ", tz)

        setEnv("MOSSLET_PACKAGE_NAME", context.packageName)
        setEnv("MOSSLET_DEVICE_MODEL", Build.MODEL)
        setEnv("MOSSLET_OS_VERSION", Build.VERSION.RELEASE)
    }

    private fun setEnv(key: String, value: String) {
        System.setProperty(key, value)
    }

    private fun releaseVersion(context: Context): String {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            packageInfo.versionName ?: "0.15.0"
        } catch (e: Exception) {
            "0.15.0"
        }
    }

    private fun getOrCreateAuthToken(context: Context): String {
        val key = "mosslet_desktop_auth_token"
        
        SecureStorage.getString(context, key)?.let { return it }
        
        val token = generateSecureToken()
        SecureStorage.saveString(context, key, token)
        return token
    }

    private fun getOrCreateSecretKeyBase(context: Context): String {
        val key = "mosslet_secret_key_base"
        
        SecureStorage.getString(context, key)?.let { return it }
        
        val secretKeyBase = generateSecureToken(64)
        SecureStorage.saveString(context, key, secretKeyBase)
        return secretKeyBase
    }

    private fun generateSecureToken(length: Int = 32): String {
        val bytes = ByteArray(length)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    private fun startErlangProcess(context: Context, relPath: String, nativeLibDir: String): Int {
        return 4000
    }
}
