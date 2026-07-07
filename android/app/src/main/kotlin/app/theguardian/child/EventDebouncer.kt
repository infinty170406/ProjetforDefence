package app.theguardian.child

import android.util.LruCache

/**
 * Limite la fréquence des scans d'arbre et l'émission des événements (debouncing/throttling).
 */
class EventDebouncer {

    private val scanCache = LruCache<String, Long>(100)
    private val debounceDurationMs = 2000L // 2 secondes

    fun shouldProcess(eventKey: String): Boolean {
        val now = System.currentTimeMillis()
        val lastProcessed = scanCache.get(eventKey) ?: 0L
        if (now - lastProcessed < debounceDurationMs) {
            return false
        }
        scanCache.put(eventKey, now)
        return true
    }

    fun clear() {
        scanCache.evictAll()
    }
}
