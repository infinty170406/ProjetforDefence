package app.theguardian.child

import android.content.Context
import android.util.Log

/**
 * Surveille le temps passé et l'activité au sein des applications configurées.
 */
class AppUsageMonitor(private val context: Context) {

    private var activeAppPackage: String? = null
    private var startTimeMs: Long = 0L

    fun onAppForeground(pkg: String) {
        val now = System.currentTimeMillis()
        if (activeAppPackage != null && activeAppPackage != pkg) {
            val timeSpentSeconds = (now - startTimeMs) / 1000
            if (timeSpentSeconds > 0) {
                recordAppUsage(activeAppPackage!!, timeSpentSeconds)
            }
        }
        activeAppPackage = pkg
        startTimeMs = now
    }

    fun onAppBackground() {
        val now = System.currentTimeMillis()
        if (activeAppPackage != null) {
            val timeSpentSeconds = (now - startTimeMs) / 1000
            if (timeSpentSeconds > 0) {
                recordAppUsage(activeAppPackage!!, timeSpentSeconds)
            }
            activeAppPackage = null
        }
    }

    private fun recordAppUsage(pkg: String, seconds: Long) {
        Log.i("AppUsageMonitor", "App $pkg was used for $seconds seconds")
        val syncManager = SyncManager(context)
        syncManager.queueEvent("app_usage_stats", mapOf(
            "package" to pkg,
            "seconds" to seconds
        ))
    }
}
