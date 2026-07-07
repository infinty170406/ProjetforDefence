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
        private const val PREFS_NAME = "FlutterSharedPreferences"
    }

    fun queueEvent(action: String, payload: Map<String, Any>) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val obj = JSONObject().apply {
                put("action", action)
                put("ts", System.currentTimeMillis())
                payload.forEach { (k, v) -> put(k, v) }
            }
            val key = "flutter.guardian_event_${System.currentTimeMillis()}_${(Math.random() * 1000).toInt()}"
            prefs.edit().putString(key, obj.toString()).apply()
            Log.d(TAG, "Event queued locally: $key")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to queue event", e)
        }
    }
}
