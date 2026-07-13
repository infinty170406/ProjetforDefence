package app.theguardian.child

import java.util.Locale

/**
 * Moteur d'évaluation et de blocage des mots-clés.
 * Compare les entrées et textes avec les listes noires parentales et les catégories prédéfinies.
 */
class BlockedKeywordEngine {

    companion object {
        private val CATEGORY_KEYWORDS = mapOf(
            "Pornographie" to setOf("porn", "xxx", "sex", "sexe", "nsfw", "hentai", "nude", "nu", "anal", "vagina", "pussy", "dick"),
            "Violence" to setOf("gore", "blood", "sang", "meurtre", "murder", "tuer", "kill", "death", "mort", "torture"),
            "Drogues" to setOf("drugs", "drogue", "drogues", "cocaine", "heroin", "cannabis", "weed", "marijuana", "meth"),
            "Jeux d'argent" to setOf("gambling", "gamble", "casino", "poker", "betting", "paris sportifs", "roulette", "blackjack"),
            "Armes" to setOf("weapon", "weapons", "armes", "arme", "gun", "guns", "fusil", "pistolet", "explosif", "bomb"),
            "Suicide" to setOf("suicide", "suicider", "kill myself", "me tuer", "self harm", "auto mutilation"),
            "Cybercriminalité" to setOf("hack", "hacker", "hacking", "ddos", "ransomware", "malware", "phishing", "darknet"),
            "Extrémisme" to setOf("isis", "daesh", "jihad", "terrorist", "terroriste", "terrorism", "nazi", "hitler")
        )

        class KeywordCheckResult(
            val isBlocked: Boolean,
            val category: String?,
            val matchedKeyword: String
        )

        fun isKeywordMatched(textLower: String, keyword: String): Boolean {
            val keywordLower = keyword.lowercase(Locale.getDefault()).trim()
            if (keywordLower.isEmpty()) return false
            
            // For safety and to prevent false positives, we enforce word boundary matching.
            // Some keywords can be matched as prefixes (e.g. "porn" in "pornography").
            val isPrefixAllowed = when (keywordLower) {
                "porn", "sex", "sexe", "nude", "suicide", "hack", "drug", "drogue", "weed" -> true
                else -> keywordLower.length >= 4 && keywordLower != "anal" && keywordLower != "sang" && keywordLower != "mort"
            }
            
            val pattern = if (isPrefixAllowed) {
                "(?U)\\b${Regex.escape(keywordLower)}"
            } else {
                "(?U)\\b${Regex.escape(keywordLower)}\\b"
            }
            
            return Regex(pattern).containsMatchIn(textLower)
        }

        fun evaluate(
            text: String,
            customBlacklist: Set<String>,
            customWhitelist: Set<String>,
            blockedCategories: Set<String> = emptySet(),
            ignoreCategoryRestriction: Boolean = false
        ): KeywordCheckResult {
            if (text.isBlank()) return KeywordCheckResult(false, null, "")
            val textLower = text.lowercase(Locale.getDefault())

            // 1. Vérifier la liste blanche en priorité
            for (word in customWhitelist) {
                val wordLower = word.lowercase(Locale.getDefault()).trim()
                if (wordLower.isNotEmpty() && isKeywordMatched(textLower, wordLower)) {
                    return KeywordCheckResult(false, null, "")
                }
            }

            // 2. Vérifier la liste noire personnalisée des parents
            for (word in customBlacklist) {
                val wordLower = word.lowercase(Locale.getDefault()).trim()
                if (wordLower.isEmpty()) continue
                
                if (wordLower.contains("[") || wordLower.contains("*") || wordLower.contains("?") || 
                    wordLower.contains("+") || wordLower.contains("^") || wordLower.contains("$") ||
                    wordLower.contains("(") || wordLower.contains(")")) {
                    try {
                        val regex = Regex(wordLower, RegexOption.IGNORE_CASE)
                        if (regex.containsMatchIn(textLower)) {
                            return KeywordCheckResult(true, "Parental Block", wordLower)
                        }
                    } catch (e: Exception) {
                        if (isKeywordMatched(textLower, wordLower)) {
                            return KeywordCheckResult(true, "Parental Block", wordLower)
                        }
                    }
                } else {
                    if (isKeywordMatched(textLower, wordLower)) {
                        return KeywordCheckResult(true, "Parental Block", wordLower)
                    }
                }
            }

            // 3. Vérifier les catégories prédéfinies
            for ((category, keywords) in CATEGORY_KEYWORDS) {
                for (keyword in keywords) {
                    if (isKeywordMatched(textLower, keyword)) {
                        val isBlocked = ignoreCategoryRestriction || blockedCategories.contains(category)
                        return KeywordCheckResult(isBlocked, category, keyword)
                    }
                }
            }

            return KeywordCheckResult(false, null, "")
        }
    }
}
