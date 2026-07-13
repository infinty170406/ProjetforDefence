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
 *
 * Responsabilités dans l'ordre :
 *   1. Vérifier la santé du moteur natif (heartbeat AccessibilityService)
 *   2. Synchroniser Room → Firebase via NativeFirebaseSync (100% natif, sans Flutter)
 *   3. Si la sync native échoue (Firebase inaccessible), tenter de redémarrer
 *      le BackgroundService Flutter comme plan B
 *   4. Maintenir la chaîne d'alarmes AlarmManager (WatchdogReceiver)
 *
 * AUTONOMIE COMPLÈTE :
 *   - Le moteur de blocage (GuardianAccessibilityService) est vérifié via son heartbeat natif
 *   - La sync Firebase est tentée directement (Firebase Android SDK)
 *   - Flutter n'est relancé que si la sync native échoue ET si des entrées Room sont en attente
 */
class GuardianWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result {
        Log.d(TAG, "Periodic watchdog check running.")

        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )

        // ── 1. Vérifier la santé du service d'accessibilité ─────────────────
        val isA11yEnabled = GuardianAccessibilityService.isEnabled(applicationContext)
        val lastHeartbeat = prefs.getLong("flutter.guardian_service_heartbeat", 0L)
        val now = System.currentTimeMillis()
        val heartbeatAgeMs = now - lastHeartbeat
        val heartbeatStale = lastHeartbeat == 0L || heartbeatAgeMs > HEARTBEAT_TIMEOUT_MS

        Log.d(TAG, "a11y=$isA11yEnabled, heartbeat_age=${heartbeatAgeMs / 1000}s, stale=$heartbeatStale")

        if (heartbeatStale && !isA11yEnabled) {
            Log.w(TAG, "AccessibilityService NOT enabled. Cannot auto-restart native protection.")
        }

        // ── 2. Sync Firebase native (sans Flutter) ───────────────────────────
        val unsyncedCount = try {
            NativeHistoryRepository.getUnsynced(applicationContext).size
        } catch (e: Exception) { 0 }

        if (unsyncedCount > 0) {
            Log.i(TAG, "$unsyncedCount unsynced Room entries — attempting native Firebase sync...")
            val syncSuccess = try {
                NativeFirebaseSync.syncPendingEntries(applicationContext)
            } catch (e: Exception) {
                Log.e(TAG, "Native Firebase sync threw: ${e.message}")
                false
            }

            if (syncSuccess) {
                Log.i(TAG, "✅ Native Firebase sync completed successfully.")
            } else {
                // ── 3. Plan B : relancer Flutter pour la sync ────────────────
                Log.w(TAG, "⚠️ Native sync failed. Falling back to Flutter BackgroundService restart.")
                restartFlutterService()
            }
        } else {
            Log.d(TAG, "No unsynced entries. Firebase sync skipped.")
        }

        // ── 4. Maintenir la chaîne d'alarmes AlarmManager ───────────────────
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
            Log.i(TAG, "Flutter BackgroundService restart requested (sync fallback).")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart Flutter BackgroundService: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "GuardianWorker"

        /** 10 minutes : si le heartbeat natif est plus vieux, on le signale. */
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
