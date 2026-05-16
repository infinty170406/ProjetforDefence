package app.theguardian.child

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class WatchdogReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION = "app.theguardian.child.GUARDIAN_WATCHDOG"
        private const val TAG = "WatchdogReceiver"

        fun schedule(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WatchdogReceiver::class.java).apply {
                action = ACTION
                setPackage(context.packageName)
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            // Répéter toutes les 15 minutes pour plus de fiabilité
            val interval = 15 * 60 * 1000L
            val triggerTime = System.currentTimeMillis() + interval
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // setAndAllowWhileIdle est crucial pour passer outre le mode Doze d'Android
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }
            Log.d(TAG, "Watchdog scheduled for $triggerTime (in 15m)")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Watchdog heartbeat: ${intent.action}")
        
        // On ne lance plus MainActivity ici pour éviter de déranger l'enfant.
        // Le Foreground Service est déjà configuré comme "sticky" et se relance
        // via le BootReceiver ou le WorkManager si nécessaire.
        
        // On replanifie immédiatement pour maintenir la chaîne d'alarmes
        schedule(context)
    }
}
