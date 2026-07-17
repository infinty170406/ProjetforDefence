package app.theguardian.child

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class GeminiAnalysisResult(
    val risk: String,
    val score: Int,
    val category: String,
    val blocked: Boolean,
    val confidence: Double,
    val reason: String,
)

object GeminiNotificationAnalyzer {

    private const val TAG = "GeminiAnalyzer"
    private const val BASE_URL = "https://guardian-secure-api.onrender.com"
    private val allowedRisks = setOf("SAFE", "LOW", "MEDIUM", "HIGH", "CRITICAL")

    /**
     * Analyses a notification via the authenticated Render backend.
     * Firebase Functions are no longer used; all analysis calls go to
     * POST /api/v1/device/notifications/analyze.
     */
    suspend fun analyze(
        context: Context,
        extracted: ExtractedNotification,
    ): GeminiAnalysisResult = withContext(Dispatchers.IO) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val parentId = readFlutterPreference(prefs, "parent_id")
        val childId = readFlutterPreference(prefs, "child_id")
        val idToken = readFlutterPreference(prefs, "firebase_id_token")

        if (parentId == null || childId == null) {
            return@withContext safeFallback("Appareil non associé.")
        }
        if (idToken == null) {
            return@withContext safeFallback("Token d'authentification indisponible.")
        }

        try {
            val payload = JSONObject().apply {
                put("parentId", parentId)
                put("childId", childId)
                put("application", extracted.applicationName)
                put("sender", extracted.sender)
                put("conversation", extracted.conversationTitle)
                put("message", extracted.messageText)
            }

            val raw = postJson(
                url = "$BASE_URL/api/v1/device/notifications/analyze",
                idToken = idToken,
                body = payload,
            ) ?: return@withContext safeFallback("Analyse indisponible.")

            val riskCandidate = raw.optString("risk", "SAFE").uppercase()
            val risk = if (riskCandidate in allowedRisks) riskCandidate else "SAFE"
            val score = raw.optInt("score", 0).coerceIn(0, 100)
            val confidence = raw.optDouble("confidence", 0.0).coerceIn(0.0, 1.0)

            GeminiAnalysisResult(
                risk = risk,
                score = score,
                category = raw.optString("category", "NONE").uppercase().take(80),
                blocked = raw.optBoolean("blocked", false),
                confidence = confidence,
                reason = raw.optString("reason", "Analyse terminée.").take(300),
            )
        } catch (error: Exception) {
            Log.e(TAG, "Server-side notification analysis failed.", error)
            safeFallback("Analyse temporairement indisponible.")
        }
    }

    private fun postJson(url: String, idToken: String, body: JSONObject): JSONObject? {
        val connection = URL(url).openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.connectTimeout = 30_000
            connection.readTimeout = 30_000
            connection.doOutput = true

            connection.outputStream.bufferedWriter().use { it.write(body.toString()) }

            if (connection.responseCode !in 200..299) {
                Log.w(TAG, "Analyze endpoint returned HTTP ${connection.responseCode}")
                return null
            }

            val responseText = connection.inputStream.bufferedReader().readText()
            JSONObject(responseText)
        } finally {
            connection.disconnect()
        }
    }

    private fun readFlutterPreference(prefs: SharedPreferences, key: String): String? {
        return (prefs.getString("flutter.$key", null) ?: prefs.getString(key, null))
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    private fun safeFallback(reason: String) = GeminiAnalysisResult(
        risk = "SAFE",
        score = 0,
        category = "NONE",
        blocked = false,
        confidence = 0.0,
        reason = reason,
    )
}
