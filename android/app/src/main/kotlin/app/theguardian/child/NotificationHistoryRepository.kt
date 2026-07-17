package app.theguardian.child

import android.content.Context
import android.util.Log
import androidx.room.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

// ─── Entity ──────────────────────────────────────────────────────────────────

@Entity(tableName = "notification_history")
data class NotificationHistoryEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val timestamp: Long = System.currentTimeMillis(),
    val application: String = "",
    val packageName: String = "",
    val sender: String = "",
    val conversation: String = "",
    val message: String = "",
    val geminiCategory: String = "NONE",
    val score: Int = 0,
    val riskLevel: String = "SAFE", // "SAFE", "LOW", "MEDIUM", "HIGH", "CRITICAL"
    val decision: String = "ALLOWED", // "ALLOWED", "DISMISSED", "BLOCKED"
    val reason: String = "",
    val synced: Boolean = false
)

// ─── DAO ─────────────────────────────────────────────────────────────────────

@Dao
interface NotificationHistoryDao {

    @Insert
    fun insert(entry: NotificationHistoryEntry): Long

    @Query("SELECT * FROM notification_history WHERE synced = 0 ORDER BY timestamp ASC LIMIT 100")
    fun getUnsynced(): List<NotificationHistoryEntry>

    @Query("UPDATE notification_history SET synced = 1 WHERE id IN (:ids)")
    fun markSynced(ids: List<Long>)

    @Query("SELECT * FROM notification_history ORDER BY timestamp DESC LIMIT :limit")
    fun getRecent(limit: Int = 200): List<NotificationHistoryEntry>

    @Query("DELETE FROM notification_history WHERE synced = 1 AND timestamp < :cutoff")
    fun purgeOld(cutoff: Long)

    @Query("SELECT COUNT(*) FROM notification_history WHERE synced = 0")
    fun countUnsynced(): Int

    /** Recherche de doublons dans les X dernières minutes pour le cache persistant */
    @Query("""
        SELECT * FROM notification_history 
        WHERE packageName = :pkg 
          AND sender = :snd 
          AND message = :msg 
          AND timestamp >= :minTimestamp 
        LIMIT 1
    """)
    fun findDuplicate(pkg: String, snd: String, msg: String, minTimestamp: Long): NotificationHistoryEntry?
}

// ─── Repository ───────────────────────────────────────────────────────────────

object NotificationHistoryRepository {

    private const val TAG = "NotificationRepo"
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /** Enregistre un événement de notification de façon asynchrone */
    fun record(context: Context, entry: NotificationHistoryEntry) {
        scope.launch {
            try {
                val db = GuardianDatabase.getInstance(context)
                val id = db.notificationHistoryDao().insert(entry)
                Log.d(TAG, "Recorded notification entry #$id: risk=${entry.riskLevel}")

                // Purge des anciennes entrées synchronisées (> 7 jours)
                if ((id % 20L) == 0L) {
                    val cutoff = System.currentTimeMillis() - 7 * 24 * 60 * 60 * 1000L
                    db.notificationHistoryDao().purgeOld(cutoff)
                    Log.d(TAG, "Purged old synced notifications.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to record notification: ${e.message}")
            }
        }
    }

    /** Récupère les entrées non encore synchronisées */
    fun getUnsynced(context: Context): List<NotificationHistoryEntry> {
        return try {
            GuardianDatabase.getInstance(context).notificationHistoryDao().getUnsynced()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get unsynced notifications: ${e.message}")
            emptyList()
        }
    }

    /** Marque des entrées comme synchronisées */
    fun markSynced(context: Context, ids: List<Long>) {
        if (ids.isEmpty()) return
        scope.launch {
            try {
                GuardianDatabase.getInstance(context).notificationHistoryDao().markSynced(ids)
                Log.d(TAG, "Marked ${ids.size} notifications as synced.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to mark notifications as synced: ${e.message}")
            }
        }
    }

    /** Vérifie s'il existe une notification similaire récente (cache persistant) */
    fun findRecentDuplicate(
        context: Context,
        pkg: String,
        sender: String,
        message: String,
        maxAgeMs: Long
    ): NotificationHistoryEntry? {
        return try {
            val db = GuardianDatabase.getInstance(context)
            val minTimestamp = System.currentTimeMillis() - maxAgeMs
            db.notificationHistoryDao().findDuplicate(pkg, sender, message, minTimestamp)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to search duplicate: ${e.message}")
            null
        }
    }
}
