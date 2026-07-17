package app.theguardian.child

import java.net.URLDecoder
import java.net.IDN
import java.net.URI
import java.net.HttpURLConnection
import java.net.URL

/**
 * Moteur d'évaluation et de filtrage des sites web.
 * Gère le décodage, la normalisation IDN (Punycode), le support des sous-domaines,
 * la résolution de redirections et de liens raccourcis de manière asynchrone et avec un cache local.
 * Garanti sans l'utilisation de contains() pour la comparaison de domaines.
 */
class WebsiteBlockEngine {

    companion object {
        private const val TAG = "WebsiteBlockEngine"

        private val SHORT_LINK_DOMAINS = setOf(
            "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "buff.ly", "adf.ly"
        )

        // Cache thread-safe basé sur LinkedHashMap standard pour compatibilité JVM/tests
        private val resolvedShortLinksCache = java.util.Collections.synchronizedMap(
            object : java.util.LinkedHashMap<String, String>(16, 0.75f, true) {
                override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?): Boolean {
                    return size > 100
                }
            }
        )

        /**
         * Détermine de manière robuste si l'URL est bloquée.
         */
        fun isBlocked(rawUrl: String, blockedDomains: Set<String>): Boolean {
            val normalizedDomain = normalizeUrlToHost(rawUrl)
            if (normalizedDomain.isEmpty()) return false

            for (blocked in blockedDomains) {
                val blockedNormalized = normalizeUrlToHost(blocked)
                if (blockedNormalized.isEmpty()) continue

                // Match exact ou sous-domaine
                if (normalizedDomain == blockedNormalized || normalizedDomain.endsWith(".$blockedNormalized")) {
                    return true
                }
            }
            return false
        }

        /**
         * Résout de manière asynchrone un lien raccourci ou une redirection, et vérifie si la destination est bloquée.
         * Appelle le callback avec le résultat.
         */
        fun resolveAndCheckAsync(url: String, blockedDomains: Set<String>, callback: (Boolean) -> Unit) {
            val host = normalizeUrlToHost(url)
            if (SHORT_LINK_DOMAINS.contains(host)) {
                val cached = resolvedShortLinksCache[url]
                if (cached != null) {
                    callback(isBlocked(cached, blockedDomains))
                    return
                }
                
                // Résolution asynchrone en arrière-plan
                Thread {
                    try {
                        val connection = URL(url).openConnection() as HttpURLConnection
                        connection.instanceFollowRedirects = false
                        connection.connectTimeout = 1000
                        connection.readTimeout = 1000
                        connection.connect()
                        val redirectUrl = connection.getHeaderField("Location")
                        if (!redirectUrl.isNullOrEmpty()) {
                            resolvedShortLinksCache[url] = redirectUrl
                            callback(isBlocked(redirectUrl, blockedDomains))
                        } else {
                            callback(false)
                        }
                    } catch (e: Exception) {
                        callback(false)
                    }
                }.start()
            } else {
                callback(isBlocked(url, blockedDomains))
            }
        }

        fun normalizeUrlToHost(url: String): String {
            if (url.isBlank()) return ""
            var clean = url.trim()
            
            try {
                clean = URLDecoder.decode(clean, "UTF-8")
            } catch (e: Exception) {
                // Fallback
            }

            if (!clean.startsWith("http://") && !clean.startsWith("https://")) {
                clean = "https://$clean"
            }

            return try {
                val uri = URI(clean)
                var host = uri.host?.lowercase() ?: ""
                
                if (host.startsWith("www.")) {
                    host = host.substring(4)
                }

                try {
                    host = IDN.toASCII(host)
                } catch (e: Exception) {
                    // Ignorer
                }
                host
            } catch (e: Exception) {
                try {
                    android.util.Log.e(TAG, "Error normalizing a URL.", e)
                } catch (t: Throwable) {
                    println("[$TAG] Error normalizing a URL.")
                }
                ""
            }
        }
    }
}
