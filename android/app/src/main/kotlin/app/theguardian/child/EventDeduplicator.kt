package app.theguardian.child

/**
 * Responsable de la déduplication des événements de navigation et de recherche.
 */
class EventDeduplicator {

    private var lastUrl: String? = null
    private var lastSearchQuery: String? = null

    fun isDuplicateUrl(url: String): Boolean {
        if (url == lastUrl) return true
        lastUrl = url
        return false
    }

    fun isDuplicateSearch(query: String): Boolean {
        if (query == lastSearchQuery) return true
        lastSearchQuery = query
        return false
    }

    fun clear() {
        lastUrl = null
        lastSearchQuery = null
    }
}
