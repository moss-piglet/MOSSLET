package com.mosslet.app

import android.app.Application
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner

class MossletApplication : Application() {
    companion object {
        private const val TAG = "MossletApp"
        lateinit var instance: MossletApplication
            private set
    }
    
    private var isInForeground = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "Application created")
        
        PushNotificationService.createNotificationChannel(this)
        
        ProcessLifecycleOwner.get().lifecycle.addObserver(
            LifecycleEventObserver { _, event ->
                when (event) {
                    Lifecycle.Event.ON_START -> {
                        isInForeground = true
                        Log.d(TAG, "App entered foreground")
                    }
                    Lifecycle.Event.ON_STOP -> {
                        isInForeground = false
                        Log.d(TAG, "App entered background")
                    }
                    else -> {}
                }
            }
        )
    }
    
    fun isAppInForeground(): Boolean = isInForeground

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
