package app.theguardian.child

import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreSettings
import com.google.firebase.firestore.SetOptions

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NativeFirebaseSync {

    private const val TAG = "NativeFirebaseSync"
    private const val BATCH_SIZE = 50
    private val identifierPattern = Regex("^[A-Za-z0-9_-]{1,128}$")

    private data class PairingContext(
        val parentId: String,
        val childId: String,
        val deviceUid: String,
    ) {
        val childPath: String
            get() = "parents/$parentId/children/$childId"
    }

    /** Point d'entrée principal pour la synchronisation native. */
    suspend fun syncPendingEntries(context: Context): Boolean = withContext(Dispatchers.IO) {
        try {
            val pairing = resolvePairingContext(context)
            if (pairing == null) {
                Log.w(TAG, "Pairing metadata is unavailable. Sync skipped.")
                return@withContext false
            }

            ensureFirebaseInitialized(context)

            // Flutter owns the anonymous session used during pairing. Creating a
            // second anonymous user here would no longer match childDeviceUid.
            val authenticatedUid = FirebaseAuth.getInstance().currentUser?.uid
            if (authenticatedUid == null || authenticatedUid != pairing.deviceUid) {
                Log.w(TAG, "The paired Firebase session is unavailable. Sync skipped.")
                return@withContext false
            }

            val firestore = FirebaseFirestore.getInstance()
            try {
                firestore.firestoreSettings = FirebaseFirestoreSettings.Builder()
                    .setPersistenceEnabled(true)
                    .build()
            } catch (_: Exception) {
                // Settings can only be assigned before the first Firestore use.
            }

            val webSuccess = syncWebHistory(context, firestore, pairing.childPath)
            val notificationSuccess = syncNotificationHistory(context, firestore, pairing.childPath)
            val alertsSuccess = syncPendingAlerts(context, pairing)

            webSuccess && notificationSuccess && alertsSuccess
        } catch (error: Exception) {
            Log.e(TAG, "Native sync failed.", error)
            false
        }
    }

    private suspend fun syncWebHistory(
        context: Context,
        firestore: FirebaseFirestore,
        childPath: String,
    ): Boolean {
        val unsynced = NativeHistoryRepository.getUnsynced(context)
        if (unsynced.isEmpty()) return true

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

                batch.set(
                    historyRef,
                    mapOf(
                        "url" to entry.url,
                        "domain" to domain,
                        "package" to entry.packageName,
                        "searchQuery" to (entry.searchQuery ?: ""),
                        "title" to entry.title.ifBlank { buildTitle(entry) },
                        "category" to entry.category,
                        "riskLevel" to entry.riskLevel,
                        "isSiteBlocked" to entry.isSiteBlocked,
                        "isWordBlocked" to entry.isWordBlocked,
                        "status" to if (entry.isBlocked) "Bloqué" else "Autorisé",
                        "date" to dateStr,
                        "time" to timeStr,
                        "timestamp" to FieldValue.serverTimestamp(),
                    ),
                )

                if (domain.isNotBlank()) {
                    val statsRef = firestore.document("$childPath/alerts/usage/websites/$dateStr")
                    val safeKey = domain.replace('.', '_')
                    batch.set(
                        statsRef,
                        mapOf(
                            "websites" to mapOf(
                                safeKey to mapOf(
                                    "domain" to domain,
                                    "lastVisit" to FieldValue.serverTimestamp(),
                                    "visits" to FieldValue.increment(1),
                                ),
                            ),
                            "lastSync" to FieldValue.serverTimestamp(),
                        ),
                        SetOptions.merge(),
                    )
                }

                processedIds.add(entry.id)
            }

            try {
                batch.commit().await()
                NativeHistoryRepository.markSynced(context, processedIds)
                successCount += processedIds.size
            } catch (error: Exception) {
                Log.e(TAG, "A web-history batch could not be synchronized.", error)
            }
        }
        return successCount == unsynced.size
    }

    private suspend fun syncNotificationHistory(
        context: Context,
        firestore: FirebaseFirestore,
        childPath: String,
    ): Boolean {
        val unsynced = NotificationHistoryRepository.getUnsynced(context)
        if (unsynced.isEmpty()) return true

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        var successCount = 0

        for (chunk in unsynced.chunked(BATCH_SIZE)) {
            val batch = firestore.batch()
            val processedIds = mutableListOf<Long>()

            for (entry in chunk) {
                val entryDate = Date(entry.timestamp)
                val historyRef = firestore
                    .collection("$childPath/inventory/notifications/history")
                    .document()

                batch.set(
                    historyRef,
                    mapOf(
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
                        "date" to dateFormat.format(entryDate),
                        "time" to timeFormat.format(entryDate),
                        "timestamp" to FieldValue.serverTimestamp(),
                    ),
                )
                processedIds.add(entry.id)
            }

            try {
                batch.commit().await()
                NotificationHistoryRepository.markSynced(context, processedIds)
                successCount += processedIds.size
            } catch (error: Exception) {
                Log.e(TAG, "A notification-history batch could not be synchronized.", error)
            }
        }
        return successCount == unsynced.size
    }

    private suspend fun syncPendingAlerts(
        context: Context,
        pairing: PairingContext,
    ): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val alertKeys = prefs.all.keys.filter { it.startsWith("flutter.guardian_alert_") }
        if (alertKeys.isEmpty()) return true

        val idToken = readFlutterPreference(prefs, "firebase_id_token")
        if (idToken == null) {
            Log.w(TAG, "Firebase ID token unavailable, skipping queued alerts.")
            return false
        }

        var success = true

        for (key in alertKeys) {
            val rawValue = prefs.getString(key, null) ?: continue
            try {
                val json = JSONObject(rawValue)
                val extra = JSONObject()
                listOf("appName", "appPackage", "sender", "category", "reason").forEach { field ->
                    val v = json.optString(field).trim()
                    if (v.isNotEmpty()) extra.put(field, v)
                }
                if (json.has("score")) extra.put("score", json.optInt("score", 0).coerceIn(0, 100))

                val payload = JSONObject().apply {
                    put("parentId", pairing.parentId)
                    put("childId", pairing.childId)
                    put("eventId", deterministicEventId(key))
                    put("type", json.optString("type", "NOTIFICATION_RISK"))
                    put("detail", json.optString("detail", json.optString("description", "Alerte enfant")))
                    put("severity", json.optString("severity", "HIGH"))
                    put("genre", json.optString("genre", "security"))
                    put("extra", extra)
                }

                val statusCode = postJson(
                    url = "https://guardian-secure-api.onrender.com/api/v1/device/alerts",
                    idToken = idToken,
                    body = payload,
                )

                if (statusCode in 200..299) {
                    prefs.edit().remove(key).apply()
                } else {
                    Log.w(TAG, "Alert endpoint returned HTTP $statusCode for key=$key")
                    success = false
                }
            } catch (error: Exception) {
                Log.e(TAG, "A queued child alert could not be synchronized.", error)
                success = false
            }
        }
        return success
    }

    private fun copyString(source: JSONObject, target: MutableMap<String, Any>, key: String) {
        val value = source.optString(key).trim()
        if (value.isNotEmpty()) target[key] = value
    }

    private fun postJson(url: String, idToken: String, body: JSONObject): Int {
        val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.connectTimeout = 30_000
            connection.readTimeout = 30_000
            connection.doOutput = true
            connection.outputStream.bufferedWriter().use { it.write(body.toString()) }
            connection.responseCode
        } finally {
            connection.disconnect()
        }
    }

    private fun deterministicEventId(rawKey: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(rawKey.toByteArray(Charsets.UTF_8))
            .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
        return "native_${digest.take(40)}"
    }

    private fun ensureFirebaseInitialized(context: Context) {
        if (FirebaseApp.getApps(context).isEmpty()) {
            checkNotNull(FirebaseApp.initializeApp(context)) { "Firebase initialization failed." }
        }
    }

    private fun resolvePairingContext(context: Context): PairingContext? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val parentId = readFlutterPreference(prefs, "parent_id") ?: return null
        val childId = readFlutterPreference(prefs, "child_id") ?: return null
        val deviceUid = readFlutterPreference(prefs, "device_uid") ?: return null

        if (!identifierPattern.matches(parentId) ||
            !identifierPattern.matches(childId) ||
            !identifierPattern.matches(deviceUid)
        ) {
            return null
        }
        return PairingContext(parentId, childId, deviceUid)
    }

    private fun readFlutterPreference(
        prefs: android.content.SharedPreferences,
        key: String,
    ): String? {
        return (prefs.getString("flutter.$key", null) ?: prefs.getString(key, null))
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    private fun extractDomain(url: String): String {
        return try {
            val host = android.net.Uri.parse(url).host ?: return ""
            if (host.startsWith("www.")) host.substring(4) else host
        } catch (_: Exception) {
            ""
        }
    }

    private fun buildTitle(entry: NavigationHistoryEntry): String {
        if (!entry.searchQuery.isNullOrBlank()) {
            return "Recherche : \"${entry.searchQuery}\""
        }
        return extractDomain(entry.url).ifBlank { entry.url }
    }
}
