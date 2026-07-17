package app.theguardian.child

import android.content.Context
import android.util.Log
import java.util.UUID

enum class NotificationDecision {
    ALLOW,
    WARNING,
    DISMISS,
    BLOCK_AND_ALERT,
}

object NotificationRiskEngine {

    private const val TAG = "NotificationRiskEngine"

    fun evaluate(result: GeminiAnalysisResult): NotificationDecision {
        return when (result.risk) {
            "SAFE", "LOW" -> NotificationDecision.ALLOW
            "MEDIUM" -> NotificationDecision.WARNING
            "HIGH" -> NotificationDecision.DISMISS
            "CRITICAL" -> NotificationDecision.BLOCK_AND_ALERT
            else -> NotificationDecision.ALLOW
        }
    }

    /** Enregistre la décision et met en file une alerte si nécessaire. */
    fun processDecision(
        context: Context,
        extracted: ExtractedNotification,
        result: GeminiAnalysisResult,
        decision: NotificationDecision,
    ) {
        val entry = NotificationHistoryEntry(
            timestamp = System.currentTimeMillis(),
            application = extracted.applicationName,
            packageName = extracted.packageName,
            sender = extracted.sender,
            conversation = extracted.conversationTitle,
            message = extracted.messageText,
            geminiCategory = result.category,
            score = result.score,
            riskLevel = result.risk,
            decision = decision.name,
            reason = result.reason,
            synced = false,
        )
        NotificationHistoryRepository.record(context, entry)

        if (decision == NotificationDecision.DISMISS ||
            decision == NotificationDecision.BLOCK_AND_ALERT
        ) {
            createSecurityAlert(context, extracted, result, decision)
        }
    }

    private fun createSecurityAlert(
        context: Context,
        extracted: ExtractedNotification,
        result: GeminiAnalysisResult,
        decision: NotificationDecision,
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val severity = if (decision == NotificationDecision.BLOCK_AND_ALERT) "CRITICAL" else "HIGH"

            // Le contenu intégral n'est pas recopié dans l'alerte. Il reste dans
            // l'historique autorisé, séparé du flux de notifications parentales.
            val detail = "Une notification potentiellement risquée a été détectée " +
                "dans ${extracted.applicationName}. Catégorie : ${result.category}. " +
                "Décision : ${decision.name}."

            val alertObject = org.json.JSONObject().apply {
                put("type", "NOTIFICATION_RISK")
                put("title", "Notification à risque détectée")
                put("description", detail)
                put("detail", detail)
                put("severity", severity)
                put("status", "unread")
                put("genre", "security")
                put("read", false)
                put("timestamp", System.currentTimeMillis())
                put("createdAt", System.currentTimeMillis())
                put("ai_processed", true)
                put("appName", extracted.applicationName)
                put("appPackage", extracted.packageName)
                put("sender", extracted.sender)
                put("category", result.category)
                put("score", result.score)
                put("reason", result.reason)
            }

            val key = "flutter.guardian_alert_${UUID.randomUUID()}"
            prefs.edit().putString(key, alertObject.toString()).apply()
            Log.i(TAG, "Security alert queued for authenticated synchronization.")
        } catch (error: Exception) {
            Log.e(TAG, "Failed to queue a security alert.", error)
        }
    }
}
