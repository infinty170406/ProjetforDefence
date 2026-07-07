package app.theguardian.child

import java.util.LinkedList

/**
 * Gère l'association contextuelle des navigations.
 * Relie chronologiquement une recherche initiale avec les clics et pages subséquentes.
 */
class NavigationContextManager {

    companion object {
        private const val CONTEXT_VALIDITY_MS = 5 * 60 * 1000L // 5 minutes
    }

    data class ContextNode(
        val type: String, // "RECHERCHE", "NAVIGATION"
        val value: String,
        val timestamp: Long,
        val pageTitle: String? = null
    )

    private val navigationPath = LinkedList<ContextNode>()
    private var lastSearchQuery: String? = null
    private var lastSearchTimestamp: Long = 0L

    fun recordSearch(query: String) {
        val now = System.currentTimeMillis()
        lastSearchQuery = query
        lastSearchTimestamp = now
        
        navigationPath.add(ContextNode("RECHERCHE", query, now))
        trimPathIfNeeded()
    }

    fun recordNavigation(url: String, title: String?) {
        val now = System.currentTimeMillis()
        navigationPath.add(ContextNode("NAVIGATION", url, now, title))
        trimPathIfNeeded()
    }

    fun getAssociatedSearch(pkg: String): String? {
        val now = System.currentTimeMillis()
        if (now - lastSearchTimestamp < CONTEXT_VALIDITY_MS) {
            return lastSearchQuery
        }
        return null
    }

    fun getFullPathway(): List<Map<String, Any>> {
        return navigationPath.map { node ->
            mapOf(
                "type" to node.type,
                "value" to node.value,
                "timestamp" to node.timestamp,
                "title" to (node.pageTitle ?: "")
            )
        }
    }

    private fun trimPathIfNeeded() {
        if (navigationPath.size > 20) {
            navigationPath.removeFirst()
        }
    }

    fun clear() {
        navigationPath.clear()
        lastSearchQuery = null
        lastSearchTimestamp = 0L
    }
}
