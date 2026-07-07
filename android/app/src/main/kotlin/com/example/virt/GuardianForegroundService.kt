package com.example.virt

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class GuardianForegroundService : Service() {

    private val CHANNEL_ID = "GuardianForegroundServiceChannel"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("The Guardian")
            .setContentText("Protection active en arrière-plan")
            // Make sure you have an icon in your drawables/mipmaps for this!
            .setSmallIcon(android.R.drawable.ic_secure) 
            .build()

        try {
            startForeground(1, notification)
        } catch (e: SecurityException) {
            e.printStackTrace()
            stopSelf()
            return START_NOT_STICKY
        }
        // L'application des règles (apps/sites/mots-clés) est gérée côté Dart
        // par ChildEnforcementService → NativeBridgeService → GuardianPrefs.
        // Ce service maintient uniquement le processus en vie.
        return START_STICKY
    }

    override fun onBind(intent: Intent): IBinder? {
        return null // We don't provide binding, so return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "The Guardian Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager: NotificationManager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
