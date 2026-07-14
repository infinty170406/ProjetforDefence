package app.theguardian.child

import android.content.Context
import android.util.Log
import androidx.room.*
import kotlinx.coroutines.*
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// ─── Entity ──────────────────────────────────────────────────────────────────

/**
 * Enregistrement d'une visite web ou d'une tentative de recherche.
 * Stocké localement dans Room, ensuite synchronisé vers Firebase par le
 * service Flutter (ou directement si Firebase Android SDK est disponible).
 */
@Entity(tableName = "navigation_history")
data class NavigationHistoryEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val timestamp: Long = System.currentTimeMillis(),
    val packageName: String = "",
    val browser: String = "",
    val url: String = "",
    val title: String = "",
    val searchQuery: String? = null,
    val category: String = "Aucune",
    val riskLevel: String = "Faible",
    val isBlocked: Boolean = false,
    val blockReason: String? = null,
    val isSiteBlocked: Boolean = false,
    val isWordBlocked: Boolean = false,
    val synced: Boolean = false          // true après sync Firebase réussie
)

// ─── DAO ─────────────────────────────────────────────────────────────────────

@Dao
interface NavigationHistoryDao {

    @Insert
    fun insert(entry: NavigationHistoryEntry): Long

    @Query("SELECT * FROM navigation_history WHERE synced = 0 ORDER BY timestamp ASC LIMIT 100")
    fun getUnsynced(): List<NavigationHistoryEntry>

    @Query("UPDATE navigation_history SET synced = 1 WHERE id IN (:ids)")
    fun markSynced(ids: List<Long>)

    @Query("SELECT * FROM navigation_history ORDER BY timestamp DESC LIMIT :limit")
    fun getRecent(limit: Int = 200): List<NavigationHistoryEntry>

    /** Purge les entrées synchronisées de plus de 7 jours pour éviter la croissance infinie. */
    @Query("DELETE FROM navigation_history WHERE synced = 1 AND timestamp < :cutoff")
    fun purgeOld(cutoff: Long)

    @Query("SELECT COUNT(*) FROM navigation_history WHERE synced = 0")
    fun countUnsynced(): Int
}

// ─── Sync Event Entity & DAO ──────────────────────────────────────────────────

@Entity(tableName = "sync_events")
data class SyncEventEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val action: String,
    val payload: String, // Stocké sous forme de JSON String
    val timestamp: Long = System.currentTimeMillis()
)

@Dao
interface SyncEventDao {
    @Insert
    fun insert(event: SyncEventEntry): Long

    @Query("SELECT * FROM sync_events ORDER BY id ASC")
    fun getAll(): List<SyncEventEntry>

    @Query("DELETE FROM sync_events WHERE id IN (:ids)")
    fun deleteByIds(ids: List<Long>)
    
    @Query("DELETE FROM sync_events")
    fun clearAll()
}

// ─── Database ─────────────────────────────────────────────────────────────────

@Database(
    entities = [NavigationHistoryEntry::class, NotificationHistoryEntry::class, SyncEventEntry::class],
    version = 3,
    exportSchema = false
)
abstract class GuardianDatabase : RoomDatabase() {
    abstract fun historyDao(): NavigationHistoryDao
    abstract fun notificationHistoryDao(): NotificationHistoryDao
    abstract fun syncEventDao(): SyncEventDao

    companion object {
        @Volatile
        private var INSTANCE: GuardianDatabase? = null

        fun getInstance(context: Context): GuardianDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext,
                    GuardianDatabase::class.java,
                    "guardian_history.db"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { INSTANCE = it }
            }
        }
    }
}

// ─── Repository ───────────────────────────────────────────────────────────────

/**
 * NativeHistoryRepository
 *
 * Couche d'accès aux données pour l'historique de navigation.
 * Fonctionne ENTIÈREMENT en natif Android sans dépendance Flutter.
 *
 * Flux :
 *   GuardianAccessibilityService détecte un événement
 *   → NativeHistoryRepository.record() écrit dans Room (thread background)
 *   → EventReporter envoie aussi dans FlutterSharedPreferences pour la sync Flutter
 *   → GuardianWorker lit les entrées non-syncées et écrit dans FlutterSharedPreferences
 *     pour que le service Flutter les synchronise vers Firebase
 */
object NativeHistoryRepository {

    private const val TAG = "NativeHistory"
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /** Enregistre une navigation (autorisée ou bloquée) de façon asynchrone. */
    fun record(context: Context, entry: NavigationHistoryEntry) {
        if (entry.url.isBlank()) return
        scope.launch {
            try {
                val db = GuardianDatabase.getInstance(context)
                val id = db.historyDao().insert(entry)
                Log.d(TAG, "Recorded entry #$id: ${entry.url} [blocked=${entry.isBlocked}]")

                // Écrire aussi dans FlutterSharedPreferences pour que le service
                // Flutter puisse drainer et sync vers Firebase
                writeToFlutterQueue(context, entry)

                // Purge périodique (une chance sur 20 d'être exécuté)
                if ((id % 20L) == 0L) {
                    val cutoff = System.currentTimeMillis() - 7 * 24 * 60 * 60 * 1000L
                    db.historyDao().purgeOld(cutoff)
                    Log.d(TAG, "Purged old synced entries.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to record history: ${e.message}")
            }
        }
    }

    /** Récupère les entrées non encore synchronisées (appelé par GuardianWorker). */
    fun getUnsynced(context: Context): List<NavigationHistoryEntry> {
        return try {
            GuardianDatabase.getInstance(context).historyDao().getUnsynced()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get unsynced entries: ${e.message}")
            emptyList()
        }
    }

    /** Marque des entrées comme synchronisées. */
    fun markSynced(context: Context, ids: List<Long>) {
        if (ids.isEmpty()) return
        scope.launch {
            try {
                GuardianDatabase.getInstance(context).historyDao().markSynced(ids)
                Log.d(TAG, "Marked ${ids.size} entries as synced.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to mark entries as synced: ${e.message}")
            }
        }
    }

    fun recordSyncEvent(context: Context, action: String, payloadJson: String) {
        scope.launch {
            try {
                val db = GuardianDatabase.getInstance(context)
                db.syncEventDao().insert(SyncEventEntry(action = action, payload = payloadJson))
                Log.d(TAG, "Sync event queued in Room: $action")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to record sync event in Room: ${e.message}")
            }
        }
    }

    /**
     * Écrit l'entrée dans Room sous forme d'événement synchronisé
     * pour que le service Flutter la drainer vers Firebase.
     */
    private fun writeToFlutterQueue(context: Context, entry: NavigationHistoryEntry) {
        try {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
            val date = Date(entry.timestamp)

            val obj = org.json.JSONObject().apply {
                put("ts", entry.timestamp)
                put("url", entry.url)
                put("package", entry.packageName)
                if (!entry.searchQuery.isNullOrBlank()) put("searchQuery", entry.searchQuery)
                put("title", entry.title)
                put("category", entry.category)
                put("riskLevel", entry.riskLevel)
                put("isSiteBlocked", entry.isSiteBlocked)
                put("isWordBlocked", entry.isWordBlocked)
                put("status", if (entry.isBlocked) "Bloqué" else "Autorisé")
                put("date", dateFormat.format(date))
                put("time", timeFormat.format(date))
            }
            recordSyncEvent(context, "web_event", obj.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write web event to Room queue: ${e.message}")
        }
    }
}
