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

        // 1. Send local broadcast for MainActivity (if alive and listening)
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

        // 2. Enqueue event to SharedPreferences (for Dart background isolate)
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val obj = JSONObject().apply {
                put("action", "web_event")
                put("ts", System.currentTimeMillis())
                put("url", report.url)
                put("package", report.appPackage)
                if (report.searchQuery != null) {
                    put("searchQuery", report.searchQuery)
                }
                put("title", report.title ?: "")
                put("category", report.category ?: "Aucune")
                put("riskLevel", report.riskLevel)
                put("isSiteBlocked", report.isSiteBlocked)
                put("isWordBlocked", report.isWordBlocked)
                put("status", report.status)
                put("date", dateStr)
                put("time", timeStr)
            }
            val key = "flutter.guardian_event_${System.currentTimeMillis()}_${(Math.random() * 1000).toInt()}"
            prefs.edit().putString(key, obj.toString()).apply()
            Log.d(TAG, "Report enqueued: $key -> ${report.url}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enqueue report", e)
        }
    }
}
