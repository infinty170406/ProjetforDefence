package app.theguardian.child

import java.net.URI
import java.net.URLDecoder

/**
 * Responsable de l'analyse et du parsing structuré des URLs.
 * Fournit des méthodes pour extraire les différents composants d'une URL
 * sans utiliser de simples vérifications par contains().
 * Conçu pour fonctionner sur JVM standard et Android pour être pleinement testable.
 */
class UrlAnalyzer {
    
    data class ParsedUrl(
        val scheme: String,
        val host: String,
        val domain: String,
        val subdomain: String,
        val path: String,
        val query: String,
        val fragment: String
    )

    companion object {
        private const val TAG = "UrlAnalyzer"

        private val ENGINE_DOMAINS = mapOf(
            "google.com" to listOf("q", "query"),
            "google.fr" to listOf("q", "query"),
            "google.ca" to listOf("q", "query"),
            "google.co.uk" to listOf("q", "query"),
            "bing.com" to listOf("q"),
            "duckduckgo.com" to listOf("q"),
            "yahoo.com" to listOf("p", "q"),
            "search.yahoo.com" to listOf("p"),
            "brave.com" to listOf("q"),
            "search.brave.com" to listOf("q"),
            "startpage.com" to listOf("query", "q"),
            "ecosia.org" to listOf("q"),
            "youtube.com" to listOf("search_query", "q"),
            "tiktok.com" to listOf("q"),
            "reddit.com" to listOf("q"),
            "amazon.com" to listOf("k", "field-keywords"),
            "amazon.fr" to listOf("k", "field-keywords"),
            "github.com" to listOf("q"),
            "facebook.com" to listOf("q"),
            "instagram.com" to listOf("q"),
            "pinterest.com" to listOf("q"),
            "pinterest.fr" to listOf("q")
        )

        /**
         * Parse une chaîne d'URL brute en un objet ParsedUrl structuré.
         */
        fun parse(rawUrl: String): ParsedUrl? {
            if (rawUrl.isBlank()) return null
            var cleanUrl = rawUrl.trim()
            if (!cleanUrl.startsWith("http://") && !cleanUrl.startsWith("https://")) {
                cleanUrl = "https://$cleanUrl"
            }
            return try {
                val uri = URI(cleanUrl)
                val scheme = uri.scheme ?: "https"
                val host = uri.host?.lowercase() ?: ""
                val path = uri.path ?: ""
                val query = uri.query ?: ""
                val fragment = uri.fragment ?: ""

                // Extraction du domaine et du sous-domaine
                val (domain, subdomain) = extractDomainParts(host)

                ParsedUrl(
                    scheme = scheme,
                    host = host,
                    domain = domain,
                    subdomain = subdomain,
                    path = path,
                    query = query,
                    fragment = fragment
                )
            } catch (e: Exception) {
                try {
                    android.util.Log.e(TAG, "Failed to parse URL: $rawUrl", e)
                } catch (t: Throwable) {
                    println("[$TAG] Failed to parse URL: $rawUrl: ${e.message}")
                }
                null
            }
        }

        private fun extractDomainParts(host: String): Pair<String, String> {
            if (host.isEmpty()) return Pair("", "")
            val parts = host.split(".")
            if (parts.size <= 2) {
                return Pair(host, "")
            }
            val domain = parts.takeLast(2).joinToString(".")
            val subdomain = parts.dropLast(2).joinToString(".")
            return Pair(domain, subdomain)
        }

        /**
         * Extrait la valeur d'un paramètre de requête.
         */
        fun getQueryParameter(query: String?, paramName: String): String? {
            if (query.isNullOrBlank()) return null
            val pairs = query.split("&")
            for (pair in pairs) {
                val idx = pair.indexOf("=")
                if (idx > 0) {
                    val key = try {
                        URLDecoder.decode(pair.substring(0, idx), "UTF-8")
                    } catch (e: Exception) {
                        pair.substring(0, idx)
                    }
                    if (key == paramName) {
                        return try {
                            URLDecoder.decode(pair.substring(idx + 1), "UTF-8")
                        } catch (e: Exception) {
                            pair.substring(idx + 1)
                        }
                    }
                }
            }
            return null
        }

        /**
         * Détecte si l'URL est une recherche et en extrait le mot-clé.
         */
        fun extractSearchQuery(url: String): String? {
            val parsed = parse(url) ?: return null
            val host = parsed.host
            
            // Trouver si le host correspond à un moteur connu sans utiliser contains()
            var matchedParams: List<String>? = null
            for ((engineHost, params) in ENGINE_DOMAINS) {
                if (host == engineHost || host.endsWith(".$engineHost")) {
                    matchedParams = params
                    break
                }
            }

            val query = parsed.query
            if (matchedParams != null) {
                for (param in matchedParams) {
                    val value = getQueryParameter(query, param)
                    if (!value.isNullOrBlank()) {
                        return value.trim()
                    }
                }
            }

            // Fallback générique sur des paramètres courants
            val commonParams = listOf("q", "query", "search_query", "k", "p", "text", "keyword")
            for (param in commonParams) {
                val value = getQueryParameter(query, param)
                if (!value.isNullOrBlank()) {
                    return value.trim()
                }
            }

            return null
        }

        /**
         * Détermine si le domaine ou sous-domaine de l'URL est bloqué par rapport
         * à une liste de domaines bloqués.
         */
        fun isDomainBlocked(url: String, blockedDomains: Set<String>): Boolean {
            val parsed = parse(url) ?: return false
            val host = parsed.host
            
            for (blocked in blockedDomains) {
                val blockedClean = blocked.lowercase()
                    .replace(Regex("^(https?://)?(www\\.)?"), "")
                    .trim()
                if (blockedClean.isEmpty()) continue

                if (host == blockedClean || host.endsWith(".$blockedClean")) {
                    return true
                }
            }
            return false
        }
    }
}
