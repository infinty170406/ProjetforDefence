package app.theguardian.child

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Construit et ordonne chronologiquement la liste des événements de navigation.
 */
class TimelineManager {

    data class TimelineEvent(
        val date: String,
        val heure: String,
        val appPackage: String,
        val browser: String,
        val searchQuery: String,
        val title: String,
        val url: String,
        val category: String,
        val riskScore: Int,
        val timeSpentSeconds: Long,
        val status: String // "Autorisé" ou "Bloqué"
    )

    private val events = mutableListOf<TimelineEvent>()

    fun buildEvent(
        appPackage: String,
        searchQuery: String?,
        title: String?,
        url: String,
        category: String?,
        riskScore: Int,
        status: String
    ): TimelineEvent {
        val now = Date()
        val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(now)
        val timeStr = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(now)

        val browserName = when (appPackage) {
            "com.android.chrome" -> "Chrome"
            "org.mozilla.firefox" -> "Firefox"
            "com.sec.android.app.sbrowser" -> "Samsung Internet"
            "com.brave.browser" -> "Brave"
            else -> "Navigateur"
        }

        val event = TimelineEvent(
            date = dateStr,
            heure = timeStr,
            appPackage = appPackage,
            browser = browserName,
            searchQuery = searchQuery ?: "",
            title = title ?: "",
            url = url,
            category = category ?: "Aucune",
            riskScore = riskScore,
            timeSpentSeconds = 0L,
            status = status
        )

        synchronized(events) {
            events.add(event)
            if (events.size > 100) {
                events.removeAt(0)
            }
        }
        return event
    }

    fun getTimeline(): List<TimelineEvent> {
        synchronized(events) {
            return ArrayList(events)
        }
    }
}
