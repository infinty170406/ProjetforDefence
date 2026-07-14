package app.theguardian.child

import android.content.Context
import android.util.Log
import org.json.JSONObject

/**
 * Gère la persistance locale des événements hors-connexion et la synchronisation fiable.
 */
class SyncManager(private val context: Context) {

    companion object {
        private const val TAG = "SyncManager"
    }

    fun queueEvent(action: String, payload: Map<String, Any>) {
        try {
            val obj = JSONObject().apply {
                put("ts", System.currentTimeMillis())
                payload.forEach { (k, v) -> put(k, v) }
            }
            // Enregistrer directement dans Room via le repository natif
            NativeHistoryRepository.recordSyncEvent(context, action, obj.toString())
            Log.d(TAG, "Event queued locally in Room: $action")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to queue event in Room", e)
        }
    }
}
