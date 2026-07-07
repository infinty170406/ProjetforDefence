package app.theguardian.child

import org.junit.Assert.*
import org.junit.Test

/**
 * Tests unitaires pour les moteurs du système de surveillance parentale.
 */
class SurveillanceEngineTest {

    @Test
    fun testUrlAnalyzer() {
        val url = "https://sub.domain.com/search?q=casino#part"
        val parsed = UrlAnalyzer.parse(url)
        assertNotNull(parsed)
        assertEquals("https", parsed!!.scheme)
        assertEquals("sub.domain.com", parsed.host)
        assertEquals("domain.com", parsed.domain)
        assertEquals("sub", parsed.subdomain)
        assertEquals("/search", parsed.path)
        assertEquals("q=casino", parsed.query)
        assertEquals("part", parsed.fragment)
    }

    @Test
    fun testWebsiteBlockEngine() {
        val blockedList = setOf("gamble.com", "badsite.co.uk")
        assertTrue(WebsiteBlockEngine.isBlocked("http://gamble.com/somepage", blockedList))
        assertTrue(WebsiteBlockEngine.isBlocked("https://sub.gamble.com", blockedList))
        assertFalse(WebsiteBlockEngine.isBlocked("https://google.com", blockedList))
    }

    @Test
    fun testBlockedKeywordEngine() {
        val blacklist = setOf("badword")
        val whitelist = setOf("goodword")

        val resultBlacklist = BlockedKeywordEngine.evaluate("this is a badword", blacklist, whitelist)
        assertTrue(resultBlacklist.isBlocked)
        assertEquals("Parental Block", resultBlacklist.category)

        val resultWhitelist = BlockedKeywordEngine.evaluate("this is a badword and goodword", blacklist, whitelist)
        assertFalse(resultWhitelist.isBlocked)

        val resultCategory = BlockedKeywordEngine.evaluate("how to gamble online", blacklist, whitelist)
        assertTrue(resultCategory.isBlocked)
        assertEquals("Jeux d'argent", resultCategory.category)
    }

    @Test
    fun testContentClassifier() {
        val customKeywords = setOf("customblocked")
        val result = ContentClassifier.classify(
            searchQuery = "poker online",
            title = "Play Poker Now",
            headers = listOf("Casino Games"),
            contents = listOf("Welcome to the gambling zone"),
            customKeywords = customKeywords
        )
        assertEquals("Jeux d'argent", result.category)
        assertTrue(result.riskScore >= 80)
    }

    @Test
    fun testSearchDetector() {
        val query = SearchDetector.extractSearchQuery("https://www.google.com/search?q=my+query+here")
        assertEquals("my query here", query)
        assertEquals("my query here", SearchDetector.getLastSearch())
    }

    @Test
    fun testNavigationContextManager() {
        val manager = NavigationContextManager()
        manager.recordSearch("casino")
        manager.recordNavigation("https://wikipedia.org/wiki/Casino", "Casino - Wikipedia")
        
        val search = manager.getAssociatedSearch("com.android.chrome")
        assertEquals("casino", search)
    }

    @Test
    fun testEventDeduplicator() {
        val deduplicator = EventDeduplicator()
        assertFalse(deduplicator.isDuplicateUrl("https://site.com"))
        assertTrue(deduplicator.isDuplicateUrl("https://site.com"))
        assertFalse(deduplicator.isDuplicateUrl("https://othersite.com"))
    }
}
