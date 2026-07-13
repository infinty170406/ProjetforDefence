package app.theguardian.child

import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class EventReporter(private val context: Context) {
    companion object {
        private const val TAG = "EventReporter"
        private const val ACTION_URL_DETECTED = "app.theguardian.child.URL_DETECTED"
    }

    class Report(
        val url: String,
        val appPackage: String,
        val searchQuery: String?,
        val title: String?,
        val category: String?,
        val riskLevel: String,
        val isSiteBlocked: Boolean,
        val isWordBlocked: Boolean,
        val status: String // "Autorisé" or "Bloqué"
    )

    fun sendReport(report: Report) {
        val now = Date()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        
        val dateStr = dateFormat.format(now)
        val timeStr = timeFormat.format(now)
        val isBlocked = report.status == "Bloqué"

        // 1. Persistance locale Room (indépendant de Flutter — JAMAIS perdu)
        NativeHistoryRepository.record(
            context,
            NavigationHistoryEntry(
                timestamp     = now.time,
                packageName   = report.appPackage,
                browser       = report.appPackage.substringAfterLast('.'),
                url           = report.url,
                title         = report.title ?: "",
                searchQuery   = report.searchQuery,
                category      = report.category ?: "Aucune",
                riskLevel     = report.riskLevel,
                isBlocked     = isBlocked,
                blockReason   = if (isBlocked) report.category else null,
                isSiteBlocked = report.isSiteBlocked,
                isWordBlocked = report.isWordBlocked,
                synced        = false
            )
        )
        // NativeHistoryRepository.record() appelle déjà writeToFlutterQueue()
        // → on ne double pas l'écriture SharedPreferences ici.
        // On envoie seulement le broadcast local pour MainActivity (si ouverte).

        // 2. Send local broadcast for MainActivity (if alive and listening)
        val broadcastIntent = Intent(ACTION_URL_DETECTED).apply {
            setPackage(context.packageName)
            putExtra("detected_url", report.url)
            putExtra("url_package", report.appPackage)
            if (report.searchQuery != null) {
                putExtra("search_query", report.searchQuery)
            }
            putExtra("title", report.title ?: "")
            putExtra("category", report.category ?: "Aucune")
            putExtra("risk_level", report.riskLevel)
            putExtra("is_site_blocked", report.isSiteBlocked)
            putExtra("is_word_blocked", report.isWordBlocked)
            putExtra("status", report.status)
            putExtra("date", dateStr)
            putExtra("time", timeStr)
        }
        context.sendBroadcast(broadcastIntent)
        Log.d(TAG, "Report sent: ${report.url} [${report.status}]")
    }
}

