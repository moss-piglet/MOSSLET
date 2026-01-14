package com.mosslet.app

import android.content.Context
import android.util.Log
import java.io.File
import java.security.SecureRandom
import android.util.Base64

object Bridge {
    private const val TAG = "MossletBridge"
    private var erlangPort: Int = 0
    private var authToken: String? = null
    private var isStarted = false

    fun startErlang(context: Context): Int {
        if (isStarted) {
            return erlangPort
        }

        setEnvironmentVariables(context)
        authToken = generateAuthToken()

        val relPath = File(context.applicationInfo.nativeLibraryDir, "rel").absolutePath
        val homePath = context.filesDir.absolutePath

        System.setProperty("RELEASE_ROOT", relPath)
        System.setProperty("HOME", homePath)
        System.setProperty("MOSSLET_DESKTOP", "true")
        System.setProperty("MOSSLET_DATA_DIR", homePath)
        System.setProperty("DESKTOP_AUTH_TOKEN", authToken!!)

        erlangPort = startErlangProcess(relPath)
        isStarted = true

        Log.d(TAG, "Erlang started on port $erlangPort")
        return erlangPort
    }

    fun stopErlang() {
        if (!isStarted) return

        sendEvent("shutdown")
        isStarted = false
        Log.d(TAG, "Erlang stopped")
    }

    fun sendEvent(event: String) {
        if (!isStarted) return
        Log.d(TAG, "Sending event to Elixir: $event")
    }

    fun authToken(): String {
        return authToken ?: ""
    }

    private fun setEnvironmentVariables(context: Context) {
        val locale = context.resources.configuration.locales[0]
        System.setProperty("LANG", "${locale.language}.UTF-8")

        val tz = java.util.TimeZone.getDefault().id
        System.setProperty("TZ", tz)
    }

    private fun generateAuthToken(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    private fun startErlangProcess(relPath: String): Int {
        return 4000
    }
}
