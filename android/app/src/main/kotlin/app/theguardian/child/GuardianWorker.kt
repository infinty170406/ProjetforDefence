package app.theguardian.child

import android.content.Context
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

class GuardianWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): ListenableWorker.Result {
        Log.d("GuardianWorker", "Performing periodic watchdog check")
        // Ici on peut vérifier si le service Flutter tourne (via un flag SharedPreferences partagé par exemple)
        // S'il ne tourne pas, on peut tenter de le redémarrer via un Intent broadcast ou AlarmManager.
        
        // On s'assure aussi que l'AlarmManager est toujours programmé
        WatchdogReceiver.schedule(applicationContext)
        
        return ListenableWorker.Result.success()
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
