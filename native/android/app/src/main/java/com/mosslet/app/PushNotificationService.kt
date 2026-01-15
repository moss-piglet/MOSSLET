package com.mosslet.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class PushNotificationService : FirebaseMessagingService() {
    
    companion object {
        const val CHANNEL_ID = "mosslet_notifications"
        const val CHANNEL_NAME = "Mosslet Notifications"
        private var tokenCallback: ((String) -> Unit)? = null
        private var notificationReceivedCallback: ((Map<String, String>, Boolean) -> Unit)? = null
        private var notificationTappedCallback: ((Map<String, String>) -> Unit)? = null
        private var pendingToken: String? = null
        
        fun setTokenCallback(callback: (String) -> Unit) {
            tokenCallback = callback
            pendingToken?.let {
                callback(it)
                pendingToken = null
            }
        }
        
        fun setNotificationReceivedCallback(callback: (Map<String, String>, Boolean) -> Unit) {
            notificationReceivedCallback = callback
        }
        
        fun setNotificationTappedCallback(callback: (Map<String, String>) -> Unit) {
            notificationTappedCallback = callback
        }
        
        fun handleNotificationTapped(data: Map<String, String>) {
            notificationTappedCallback?.invoke(data)
        }
        
        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val importance = NotificationManager.IMPORTANCE_HIGH
                val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                    description = "Notifications from Mosslet"
                    enableVibration(true)
                    enableLights(true)
                }
                
                val notificationManager = context.getSystemService(NotificationManager::class.java)
                notificationManager?.createNotificationChannel(channel)
            }
        }
    }
    
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        
        if (tokenCallback != null) {
            tokenCallback?.invoke(token)
        } else {
            pendingToken = token
        }
    }
    
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        val data = remoteMessage.data
        val isForeground = MossletApplication.instance.isAppInForeground()
        
        notificationReceivedCallback?.invoke(data, isForeground)
        
        if (!isForeground || remoteMessage.notification != null) {
            showNotification(remoteMessage)
        }
    }
    
    private fun showNotification(remoteMessage: RemoteMessage) {
        val title = remoteMessage.notification?.title ?: remoteMessage.data["title"] ?: "Mosslet"
        val body = remoteMessage.notification?.body ?: remoteMessage.data["body"] ?: "You have new activity"
        
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            remoteMessage.data.forEach { (key, value) ->
                putExtra("push_$key", value)
            }
            putExtra("from_notification", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
        
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) 
            == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            NotificationManagerCompat.from(this).notify(
                System.currentTimeMillis().toInt(),
                notificationBuilder.build()
            )
        }
    }
}
