package com.mosslet.app

import android.app.Application
import android.util.Log

class MossletApplication : Application() {
    companion object {
        private const val TAG = "MossletApp"
        lateinit var instance: MossletApplication
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "Application created")
    }

    override fun onTerminate() {
        super.onTerminate()
        Bridge.stopErlang()
        Log.d(TAG, "Application terminated")
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        when (level) {
            TRIM_MEMORY_RUNNING_LOW,
            TRIM_MEMORY_RUNNING_CRITICAL -> {
                Log.w(TAG, "Memory low, level: $level")
                Bridge.sendEvent("memory_warning")
            }
        }
    }
}
