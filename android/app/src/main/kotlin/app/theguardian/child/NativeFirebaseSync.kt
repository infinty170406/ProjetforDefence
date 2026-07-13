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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * NativeFirebaseSync
 *
 * Synchroniseur Firebase 100% natif Android (Kotlin).
 * Fonctionne sans aucune dépendance envers le runtime Flutter / Dart.
 *
 * Flux :
 *   GuardianWorker.doWork() (WorkManager, 15 min)
 *     ↓
 *   NativeFirebaseSync.syncPendingEntries(context)
 *     ↓ Lit les entrées non-syncées depuis Room (NativeHistoryRepository)
 *     ↓ Résout le childPath depuis FlutterSharedPreferences
 *     ↓ S'assure que Firebase est initialisé et authentifié
 *     ↓ Écrit en batch Firestore :
 *        - {childPath}/inventory/websites/history  (historique linéaire)
 *        - {childPath}/alerts/usage/websites/{today} (stats quotidiennes)
 *     ↓ Marque les entrées comme syncées dans Room
 *
 * Chemins Firestore identiques à ceux utilisés par EnforcementService.dart
 * pour garantir la compatibilité avec le dashboard parent.
 *
 * Robustesse :
 *   - Firestore offline persistence activée → les opérations sont mises en
 *     cache localement et envoyées dès le retour de la connectivité.
 *   - Batch limité à 50 entrées par exécution pour éviter les timeouts.
 *   - Retry géré par WorkManager (backoff exponentiel si Result.retry()).
 */
object NativeFirebaseSync {

    private const val TAG = "NativeFirebaseSync"

    /** Nombre maximal d'entrées traitées par appel (limite batch Firestore = 500). */
    private const val BATCH_SIZE = 50

    /**
     * Point d'entrée principal.
     * Appelé depuis GuardianWorker (thread background via WorkManager).
     *
     * @return true si toutes les entrées ont été traitées avec succès, false sinon.
     */
    suspend fun syncPendingEntries(context: Context): Boolean = withContext(Dispatchers.IO) {
        try {
            // ── 1. Résoudre le childPath ─────────────────────────────────────
            val childPath = resolveChildPath(context)
            if (childPath == null) {
                Log.w(TAG, "childPath not set — device not paired yet. Sync skipped.")
                return@withContext false
            }

            // ── 2. Lire les entrées non-syncées depuis Room ──────────────────
            val unsynced = NativeHistoryRepository.getUnsynced(context)
            if (unsynced.isEmpty()) {
                Log.d(TAG, "No unsynced entries. Nothing to do.")
                return@withContext true
            }
            Log.i(TAG, "${unsynced.size} unsynced entries to push to Firebase.")

            // ── 3. Initialiser Firebase (idempotent si déjà initialisé) ──────
            ensureFirebaseInitialized(context)

            // ── 4. Vérifier l'authentification Firebase ──────────────────────
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
            } else {
                Log.d(TAG, "Firebase user: ${auth.currentUser?.uid}")
            }

            // ── 5. Activer la persistance offline Firestore ──────────────────
            val firestore = FirebaseFirestore.getInstance()
            try {
                firestore.firestoreSettings = FirebaseFirestoreSettings.Builder()
                    .setPersistenceEnabled(true)
                    .build()
            } catch (e: Exception) {
                // Settings can only be set before any other Firestore usage — safe to ignore
                Log.d(TAG, "Firestore settings already set: ${e.message}")
            }

            // ── 6. Traiter par batches de BATCH_SIZE ─────────────────────────
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())

            var successCount = 0
            val batches = unsynced.chunked(BATCH_SIZE)

            for (chunk in batches) {
                val batch: WriteBatch = firestore.batch()
                val processedIds = mutableListOf<Long>()

                for (entry in chunk) {
                    val entryDate = Date(entry.timestamp)
                    val dateStr  = dateFormat.format(entryDate)
                    val timeStr  = timeFormat.format(entryDate)
                    val domain   = extractDomain(entry.url)

                    // ─ a. Historique linéaire ─────────────────────────────────
                    // Chemin : {childPath}/inventory/websites/history/{auto-id}
                    val historyRef = firestore
                        .collection("$childPath/inventory/websites/history")
                        .document()

                    batch.set(historyRef, mapOf(
                        "url"           to entry.url,
                        "domain"        to domain,
                        "package"       to entry.packageName,
                        "searchQuery"   to (entry.searchQuery ?: ""),
                        "title"         to entry.title.ifBlank { buildTitle(entry) },
                        "category"      to entry.category,
                        "riskLevel"     to entry.riskLevel,
                        "isSiteBlocked" to entry.isSiteBlocked,
                        "isWordBlocked" to entry.isWordBlocked,
                        "status"        to (if (entry.isBlocked) "Bloqué" else "Autorisé"),
                        "date"          to dateStr,
                        "time"          to timeStr,
                        "timestamp"     to FieldValue.serverTimestamp(),
                    ))

                    // ─ b. Stats quotidiennes (merge) ──────────────────────────
                    // Chemin : {childPath}/alerts/usage/websites/{today}
                    if (domain.isNotBlank()) {
                        val statsRef = firestore.document(
                            "$childPath/alerts/usage/websites/$dateStr"
                        )
                        val safeKey = domain.replace('.', '_')
                        batch.set(statsRef, mapOf(
                            "websites" to mapOf(
                                safeKey to mapOf(
                                    "domain"    to domain,
                                    "lastVisit" to FieldValue.serverTimestamp(),
                                    "visits"    to FieldValue.increment(1),
                                )
                            ),
                            "lastSync" to FieldValue.serverTimestamp(),
                        ), com.google.firebase.firestore.SetOptions.merge())
                    }

                    processedIds.add(entry.id)
                }

                // ── 7. Commit du batch Firestore ─────────────────────────────
                try {
                    batch.commit().await()
                    NativeHistoryRepository.markSynced(context, processedIds)
                    successCount += processedIds.size
                    Log.i(TAG, "Batch committed: ${processedIds.size} entries. Total: $successCount")
                } catch (e: Exception) {
                    Log.e(TAG, "Batch commit failed: ${e.message}")
                    // Continuer avec le batch suivant, celui-ci sera réessayé
                    // au prochain passage (entrées restent synced=false dans Room)
                }
            }

            Log.i(TAG, "Sync complete: $successCount/${unsynced.size} entries pushed.")
            return@withContext successCount == unsynced.size

        } catch (e: Exception) {
            Log.e(TAG, "syncPendingEntries fatal error: ${e.message}", e)
            return@withContext false
        }
    }

    /**
     * Initialise Firebase si ce n'est pas déjà fait.
     * Le SDK Firebase Android s'initialise automatiquement via google-services.json
     * au démarrage de l'application, mais dans le contexte WorkManager (process distinct
     * possible) on doit s'assurer qu'il est bien initialisé.
     */
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

    /**
     * Lit le childPath depuis FlutterSharedPreferences.
     *
     * Flutter l'écrit sous la clé 'child_path' (sans préfixe 'flutter.'
     * pour cette clé spécifique — voir ChildPathHelper.dart).
     * Si absent, on tente la clé avec préfixe 'flutter.child_path'.
     */
    private fun resolveChildPath(context: Context): String? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Essayer les deux variantes de clé
        val raw = prefs.getString("child_path", null)
            ?: prefs.getString("flutter.child_path", null)
            ?: return null
        val trimmed = raw.trim().trimEnd('/')
        return if (trimmed.isBlank()) null else trimmed
    }

    /** Extrait le domaine d'une URL (ex: "google.com" depuis "https://www.google.com/..."). */
    private fun extractDomain(url: String): String {
        return try {
            val uri = android.net.Uri.parse(url)
            val host = uri.host ?: return ""
            // Supprimer le sous-domaine "www."
            if (host.startsWith("www.")) host.substring(4) else host
        } catch (e: Exception) {
            ""
        }
    }

    /** Construit un titre lisible si aucun titre n'est fourni. */
    private fun buildTitle(entry: NavigationHistoryEntry): String {
        if (!entry.searchQuery.isNullOrBlank()) {
            return "Recherche : \"${entry.searchQuery}\""
        }
        val domain = extractDomain(entry.url)
        return domain.ifBlank { entry.url }
    }
}
