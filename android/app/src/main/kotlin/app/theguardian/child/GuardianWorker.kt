package app.theguardian.child

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit
import id.flutter.flutter_background_service.BackgroundService

class GuardianWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        Log.d("GuardianWorker", "Performing periodic watchdog check")

        // FIX BUG #6 : vérifier si le service Flutter est vivant via son heartbeat
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        val lastHeartbeat = prefs.getLong("flutter.guardian_service_heartbeat", 0L)
        val now = System.currentTimeMillis()
        val elapsedMs = now - lastHeartbeat
        val fiveMinutes = 5 * 60 * 1000L

        if (lastHeartbeat == 0L || elapsedMs > fiveMinutes) {
            Log.w("GuardianWorker",
                "Service heartbeat stale (${elapsedMs / 1000}s ago). Attempting silent restart.")
            try {
                val serviceIntent = Intent(applicationContext, BackgroundService::class.java)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(serviceIntent)
                } else {
                    applicationContext.startService(serviceIntent)
                }
                Log.i("GuardianWorker", "Directly and silently started background service.")
            } catch (e: Exception) {
                Log.w("GuardianWorker", "Failed to start service directly: ${e.message}. Falling back to MainActivity.")
                try {
                    // Relancer MainActivity qui redémarre le BackgroundService Flutter
                    val intent = Intent(applicationContext, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        putExtra("RESTART_SERVICE", true)
                    }
                    applicationContext.startActivity(intent)
                } catch (ex: Exception) {
                    Log.e("GuardianWorker", "Failed to restart service via MainActivity: ${ex.message}")
                }
            }
        } else {
            Log.d("GuardianWorker", "Service is alive (heartbeat ${elapsedMs / 1000}s ago).")
        }

        // Maintenir la chaîne d'alarmes AlarmManager
        WatchdogReceiver.schedule(applicationContext)

        return Result.success()
    }

    companion object {
        fun scheduleIfNeeded(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .setRequiresBatteryNotLow(false)
                .build()

            val request = PeriodicWorkRequestBuilder<GuardianWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "guardian_watchdog",
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
            Log.d("GuardianWorker", "WorkManager watchdog scheduled")
        }
    }
}
