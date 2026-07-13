package app.theguardian.child

import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreSettings
import com.google.firebase.firestore.SetOptions
import com.google.firebase.firestore.WriteBatch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NativeFirebaseSync {

    private const val TAG = "NativeFirebaseSync"
    private const val BATCH_SIZE = 50

    /**
     * Point d'entrée principal pour la synchronisation.
     */
    suspend fun syncPendingEntries(context: Context): Boolean = withContext(Dispatchers.IO) {
        try {
            val childPath = resolveChildPath(context)
            if (childPath == null) {
                Log.w(TAG, "childPath not set — device not paired yet. Sync skipped.")
                return@withContext false
            }

            ensureFirebaseInitialized(context)

            // S'assurer que l'utilisateur est authentifié
            val auth = FirebaseAuth.getInstance()
            if (auth.currentUser == null) {
                Log.w(TAG, "Firebase user not signed in. Attempting anonymous sign-in...")
                try {
                    auth.signInAnonymously().await()
                    Log.i(TAG, "Signed in anonymously: ${auth.currentUser?.uid}")
                } catch (e: Exception) {
                    Log.e(TAG, "Anonymous sign-in failed: ${e.message}. Sync skipped.")
                    return@withContext false
                }
            }

            val firestore = FirebaseFirestore.getInstance()
            try {
                firestore.firestoreSettings = FirebaseFirestoreSettings.Builder()
                    .setPersistenceEnabled(true)
                    .build()
            } catch (e: Exception) {
                Log.d(TAG, "Firestore settings already set: ${e.message}")
            }

            // 1. Synchronisation de l'historique web
            val webSuccess = syncWebHistory(context, firestore, childPath)

            // 2. Synchronisation de l'historique des notifications
            val notifSuccess = syncNotificationHistory(context, firestore, childPath)

            // 3. Synchronisation des alertes de sécurité stockées en SharedPreferences (Étape 7)
            val alertsSuccess = syncPendingAlerts(context, firestore, childPath)

            return@withContext webSuccess && notifSuccess && alertsSuccess
        } catch (e: Exception) {
            Log.e(TAG, "syncPendingEntries fatal error: ${e.message}", e)
            return@withContext false
        }
    }

    private suspend fun syncWebHistory(context: Context, firestore: FirebaseFirestore, childPath: String): Boolean {
        val unsynced = NativeHistoryRepository.getUnsynced(context)
        if (unsynced.isEmpty()) return true

        Log.i(TAG, "Syncing ${unsynced.size} web history entries...")
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        var successCount = 0

        for (chunk in unsynced.chunked(BATCH_SIZE)) {
            val batch = firestore.batch()
            val processedIds = mutableListOf<Long>()

            for (entry in chunk) {
                val entryDate = Date(entry.timestamp)
                val dateStr = dateFormat.format(entryDate)
                val timeStr = timeFormat.format(entryDate)
                val domain = extractDomain(entry.url)

                val historyRef = firestore
                    .collection("$childPath/inventory/websites/history")
                    .document()

                batch.set(historyRef, mapOf(
                    "url" to entry.url,
                    "domain" to domain,
                    "package" to entry.packageName,
                    "searchQuery" to (entry.searchQuery ?: ""),
                    "title" to entry.title.ifBlank { buildTitle(entry) },
                    "category" to entry.category,
                    "riskLevel" to entry.riskLevel,
                    "isSiteBlocked" to entry.isSiteBlocked,
                    "isWordBlocked" to entry.isWordBlocked,
                    "status" to (if (entry.isBlocked) "Bloqué" else "Autorisé"),
                    "date" to dateStr,
                    "time" to timeStr,
                    "timestamp" to FieldValue.serverTimestamp()
                ))

                if (domain.isNotBlank()) {
                    val statsRef = firestore.document("$childPath/alerts/usage/websites/$dateStr")
                    val safeKey = domain.replace('.', '_')
                    batch.set(statsRef, mapOf(
                        "websites" to mapOf(
                            safeKey to mapOf(
                                "domain" to domain,
                                "lastVisit" to FieldValue.serverTimestamp(),
                                "visits" to FieldValue.increment(1)
                            )
                        ),
                        "lastSync" to FieldValue.serverTimestamp()
                    ), SetOptions.merge())
                }

                processedIds.add(entry.id)
            }

            try {
                batch.commit().await()
                NativeHistoryRepository.markSynced(context, processedIds)
                successCount += processedIds.size
            } catch (e: Exception) {
                Log.e(TAG, "Web batch commit failed: ${e.message}")
            }
        }
        return successCount == unsynced.size
    }

    private suspend fun syncNotificationHistory(context: Context, firestore: FirebaseFirestore, childPath: String): Boolean {
        val unsynced = NotificationHistoryRepository.getUnsynced(context)
        if (unsynced.isEmpty()) return true

        Log.i(TAG, "Syncing ${unsynced.size} notification history entries...")
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        var successCount = 0

        for (chunk in unsynced.chunked(BATCH_SIZE)) {
            val batch = firestore.batch()
            val processedIds = mutableListOf<Long>()

            for (entry in chunk) {
                val entryDate = Date(entry.timestamp)
                val dateStr = dateFormat.format(entryDate)
                val timeStr = timeFormat.format(entryDate)

                val historyRef = firestore
                    .collection("$childPath/inventory/notifications/history")
                    .document()

                batch.set(historyRef, mapOf(
                    "application" to entry.application,
                    "packageName" to entry.packageName,
                    "sender" to entry.sender,
                    "conversation" to entry.conversation,
                    "message" to entry.message,
                    "geminiCategory" to entry.geminiCategory,
                    "score" to entry.score,
                    "riskLevel" to entry.riskLevel,
                    "decision" to entry.decision,
                    "reason" to entry.reason,
                    "date" to dateStr,
                    "time" to timeStr,
                    "timestamp" to FieldValue.serverTimestamp()
                ))

                processedIds.add(entry.id)
            }

            try {
                batch.commit().await()
                NotificationHistoryRepository.markSynced(context, processedIds)
                successCount += processedIds.size
            } catch (e: Exception) {
                Log.e(TAG, "Notification batch commit failed: ${e.message}")
            }
        }
        return successCount == unsynced.size
    }

    private suspend fun syncPendingAlerts(context: Context, firestore: FirebaseFirestore, childPath: String): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val allKeys = prefs.all
        val alertKeys = allKeys.keys.filter { it.startsWith("flutter.guardian_alert_") }
        if (alertKeys.isEmpty()) return true

        Log.i(TAG, "Syncing ${alertKeys.size} security alerts from SharedPreferences...")
        var success = true

        for (key in alertKeys) {
            val rawValue = prefs.getString(key, null) ?: continue
            try {
                val json = JSONObject(rawValue)
                val collectionRef = firestore.collection("$childPath/alerts/notifications/items")
                val docRef = collectionRef.document()

                val data = mapOf(
                    "childId" to json.optString("childId"),
                    "type" to json.optString("type"),
                    "title" to json.optString("title"),
                    "description" to json.optString("description"),
                    "detail" to json.optString("detail"),
                    "severity" to json.optString("severity"),
                    "status" to json.optString("status"),
                    "genre" to json.optString("genre"),
                    "read" to json.optBoolean("read"),
                    "timestamp" to FieldValue.serverTimestamp(),
                    "createdAt" to FieldValue.serverTimestamp(),
                    "ai_processed" to json.optBoolean("ai_processed"),
                    "appName" to json.optString("appName"),
                    "appPackage" to json.optString("appPackage"),
                    "sender" to json.optString("sender"),
                    "category" to json.optString("category"),
                    "score" to json.optInt("score"),
                    "reason" to json.optString("reason"),
                    "message" to json.optString("description")
                )

                docRef.set(data).await()
                prefs.edit().remove(key).apply()
                Log.d(TAG, "Alert successfully synced and removed from prefs: $key")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to sync alert $key: ${e.message}")
                success = false
            }
        }
        return success
    }

    private fun ensureFirebaseInitialized(context: Context) {
        try {
            if (FirebaseApp.getApps(context).isEmpty()) {
                FirebaseApp.initializeApp(context)
                Log.i(TAG, "Firebase initialized from NativeFirebaseSync.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Firebase init error: ${e.message}")
        }
    }

    private fun resolveChildPath(context: Context): String? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("child_path", null)
            ?: prefs.getString("flutter.child_path", null)
            ?: return null
        val trimmed = raw.trim().trimEnd('/')
        return if (trimmed.isBlank()) null else trimmed
    }

    private fun extractDomain(url: String): String {
        return try {
            val uri = android.net.Uri.parse(url)
            val host = uri.host ?: return ""
            if (host.startsWith("www.")) host.substring(4) else host
        } catch (e: Exception) {
            ""
        }
    }

    private fun buildTitle(entry: NavigationHistoryEntry): String {
        if (!entry.searchQuery.isNullOrBlank()) {
            return "Recherche : \"${entry.searchQuery}\""
        }
        val domain = extractDomain(entry.url)
        return domain.ifBlank { entry.url }
    }
}
