package app.theguardian.child

/**
 * Responsable de la détection et de l'extraction des recherches utilisateur.
 * Extrait les mots-clés depuis les URLs de moteurs de recherche et conserve
 * la dernière recherche effectuée.
 * Utilise UrlAnalyzer pour l'analyse sans contains().
 */
class SearchDetector {
    
    companion object {
        private const val TAG = "SearchDetector"

        @Volatile
        private var lastDetectedSearch: String? = null

        /**
         * Extrait la requête de recherche à partir d'une URL en déléguant à UrlAnalyzer.
         */
        fun extractSearchQuery(url: String): String? {
            val query = UrlAnalyzer.extractSearchQuery(url)
            if (!query.isNullOrBlank()) {
                lastDetectedSearch = query
                return query
            }
            return null
        }

        /**
         * Conserve et retourne la dernière recherche détectée.
         */
        fun getLastSearch(): String? = lastDetectedSearch

        /**
         * Force la mise à jour de la dernière recherche.
         */
        fun setLastSearch(query: String) {
            lastDetectedSearch = query
        }
    }
}
