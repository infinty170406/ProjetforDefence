package app.theguardian.child

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.*
import id.flutter.flutter_background_service.BackgroundService
import java.util.concurrent.TimeUnit

/**
 * GuardianWorker
 *
 * Tâche périodique WorkManager (15 minutes).
 * Rôle : surveiller la santé du moteur de sécurité et déclencher une re-synchro
 *         des entrées Room non encore synchronisées vers Firebase (via Flutter
 *         SharedPreferences queue).
 *
 * IMPORTANT : Le worker vérifie le heartbeat natif écrit par GuardianAccessibilityService,
 * pas le heartbeat Dart. Si l'AccessibilityService est vivant, on ne redémarre
 * PAS Flutter inutilement.
 */
class GuardianWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    override fun doWork(): Result {
        Log.d(TAG, "Periodic watchdog check running.")

        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )

        // ── 1. Vérifier l'état du service d'accessibilité ─────────────────────
        val isA11yEnabled = GuardianAccessibilityService.isEnabled(applicationContext)
        val lastHeartbeat = prefs.getLong("flutter.guardian_service_heartbeat", 0L)
        val now = System.currentTimeMillis()
        val heartbeatAgeMs = now - lastHeartbeat
        val heartbeatStale = lastHeartbeat == 0L || heartbeatAgeMs > HEARTBEAT_TIMEOUT_MS

        Log.d(TAG, "a11y=$isA11yEnabled, heartbeat_age=${heartbeatAgeMs / 1000}s, stale=$heartbeatStale")

        if (heartbeatStale) {
            // Le heartbeat est absent ou trop vieux.
            // Si l'AccessibilityService n'est pas activé, on ne peut rien faire de plus.
            // Si l'AS est activé mais le heartbeat manque, c'est un bug : on tente de
            // relancer le BackgroundService Flutter pour la synchro Firebase.
            if (isA11yEnabled) {
                Log.w(TAG, "HeartBeat stale but AccessibilityService is enabled. " +
                        "Restarting Flutter background service for Firebase sync.")
                restartFlutterService()
            } else {
                Log.w(TAG, "AccessibilityService NOT enabled. Cannot auto-restart protection. " +
                        "User action required.")
            }
        } else {
            Log.d(TAG, "Service alive (heartbeat ${heartbeatAgeMs / 1000}s ago). No restart needed.")
        }

        // ── 2. Drainer les entrées Room non-syncées vers la queue Flutter ─────
        // NativeHistoryRepository.writeToFlutterQueue() est appelé à chaque record()
        // donc les entrées sont déjà dans SharedPreferences.
        // GuardianWorker se contente de vérifier qu'elles sont bien présentes
        // et relance Flutter si nécessaire pour les drainer.
        val unsyncedCount = try {
            NativeHistoryRepository.getUnsynced(applicationContext).size
        } catch (e: Exception) {
            Log.e(TAG, "Failed to count unsynced entries: ${e.message}")
            0
        }

        if (unsyncedCount > 0) {
            Log.i(TAG, "$unsyncedCount unsynced Room entries — Flutter service needed for Firebase sync.")
            // Si Flutter ne tourne pas, on le redémarre pour la synchro.
            // L'idempotence est garantie car BackgroundService vérifie isRunning().
            restartFlutterService()
        }

        // ── 3. Maintenir la chaîne d'alarmes AlarmManager ────────────────────
        WatchdogReceiver.schedule(applicationContext)

        return Result.success()
    }

    private fun restartFlutterService() {
        try {
            val serviceIntent = Intent(applicationContext, BackgroundService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(serviceIntent)
            } else {
                applicationContext.startService(serviceIntent)
            }
            Log.i(TAG, "Flutter BackgroundService restart requested.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart Flutter BackgroundService: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "GuardianWorker"
        /** 10 minutes : si le heartbeat est plus vieux, on considère le service mort. */
        private const val HEARTBEAT_TIMEOUT_MS = 10 * 60 * 1000L

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
            Log.d(TAG, "WorkManager watchdog scheduled")
        }
    }
}
