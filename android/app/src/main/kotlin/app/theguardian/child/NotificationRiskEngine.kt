package app.theguardian.child

import android.content.Context
import android.util.Log

enum class NotificationDecision {
    ALLOW,
    WARNING,
    DISMISS,
    BLOCK_AND_ALERT
}

object NotificationRiskEngine {

    private const val TAG = "NotificationRiskEngine"

    fun evaluate(result: GeminiAnalysisResult): NotificationDecision {
        return when (result.risk) {
            "SAFE" -> NotificationDecision.ALLOW
            "LOW" -> NotificationDecision.ALLOW
            "MEDIUM" -> NotificationDecision.WARNING
            "HIGH" -> NotificationDecision.DISMISS
            "CRITICAL" -> NotificationDecision.BLOCK_AND_ALERT
            else -> NotificationDecision.ALLOW
        }
    }

    /**
     * Traite la décision de risque et génère une alerte de sécurité si nécessaire.
     */
    fun processDecision(
        context: Context,
        extracted: ExtractedNotification,
        result: GeminiAnalysisResult,
        decision: NotificationDecision
    ) {
        val timestamp = System.currentTimeMillis()

        // 1. Enregistrer dans la base de données Room (Étape 6)
        val entry = NotificationHistoryEntry(
            timestamp = timestamp,
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
            synced = false
        )
        NotificationHistoryRepository.record(context, entry)

        // 2. Si HIGH ou CRITICAL (Étape 5), créer une alerte Firestore
        if (decision == NotificationDecision.DISMISS || decision == NotificationDecision.BLOCK_AND_ALERT) {
            createSecurityAlert(context, extracted, result, decision)
        }
    }

    private fun createSecurityAlert(
        context: Context,
        extracted: ExtractedNotification,
        result: GeminiAnalysisResult,
        decision: NotificationDecision
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val childId = prefs.getString("child_id", "unknown_child") ?: "unknown_child"

            val severity = if (decision == NotificationDecision.BLOCK_AND_ALERT) "CRITICAL" else "HIGH"
            val detail = "Alerte Sécurité Notification [${result.category}] : " +
                    "Un message suspect de ${extracted.sender} dans l'application ${extracted.applicationName} a été détecté et filtré.\n" +
                    "Message : \"${extracted.messageText}\"\n" +
                    "Raison de l'IA : ${result.reason}"

            val alertObj = org.json.JSONObject().apply {
                put("childId", childId)
                put("type", "NOTIFICATION_ALERT")
                put("title", "Message suspect détecté")
                put("description", detail)
                put("detail", detail)
                put("severity", severity)
                put("status", "unread")
                put("genre", "security")
                put("read", false)
                put("timestamp", System.currentTimeMillis())
                put("createdAt", System.currentTimeMillis())
                put("ai_processed", false)
                put("appName", extracted.applicationName)
                put("appPackage", extracted.packageName)
                put("sender", extracted.sender)
                put("category", result.category)
                put("score", result.score)
                put("reason", result.reason)
            }

            // File d'attente SharedPreferences pour compatibilité ou sync en arrière-plan
            val key = "flutter.guardian_alert_${System.currentTimeMillis()}_${(Math.random() * 1000).toInt()}"
            prefs.edit().putString(key, alertObj.toString()).apply()
            Log.i(TAG, "Security alert enqueued in SharedPreferences: $key")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create security alert: ${e.message}")
        }
    }
}
