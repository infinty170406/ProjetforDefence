package app.theguardian.child

/**
 * Responsable de la classification automatique du contenu et de l'évaluation du score de risque (0-100%).
 */
class ContentClassifier {

    class ClassificationResult(
        val category: String?,
        val riskScore: Int, // 0 to 100
        val matchedKeyword: String?
    )

    companion object {
        
        fun classify(
            searchQuery: String?,
            title: String?,
            headers: List<String>,
            contents: List<String>,
            customKeywords: Set<String>
        ): ClassificationResult {
            val sb = StringBuilder()
            if (!searchQuery.isNullOrBlank()) sb.append(searchQuery).append(" ")
            if (!title.isNullOrBlank()) sb.append(title).append(" ")
            headers.forEach { sb.append(it).append(" ") }
            contents.forEach { sb.append(it).append(" ") }
            
            val fullText = sb.toString().trim()
            if (fullText.isEmpty()) {
                return ClassificationResult(null, 0, null)
            }

            // Évaluation via BlockedKeywordEngine
            val check = BlockedKeywordEngine.evaluate(fullText, customKeywords, emptySet())
            if (check.isBlocked) {
                // Score de risque en fonction de la catégorie
                val score = when (check.category) {
                    "Pornographie", "Suicide" -> 98
                    "Extrémisme", "Armes" -> 100
                    "Drogues" -> 90
                    "Jeux d'argent" -> 85
                    "Violence" -> 80
                    "Cybercriminalité" -> 75
                    else -> 50
                }
                return ClassificationResult(check.category, score, check.matchedKeyword)
            }

            return ClassificationResult(null, 0, null)
        }
    }
}
