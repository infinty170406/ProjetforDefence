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

        val resultCategory = BlockedKeywordEngine.evaluate(
            text = "how to gamble online",
            customBlacklist = blacklist,
            customWhitelist = whitelist,
            ignoreCategoryRestriction = true
        )
        assertTrue(resultCategory.isBlocked)
        assertEquals("Jeux d'argent", resultCategory.category)
    }

    @Test
    fun testBlockedKeywordEngineMultiCategory() {
        // Suppose "Pornographie" is blocked, but "Jeux d'argent" (gambling) is not.
        val blockedCategories = setOf("Pornographie")
        
        // The text contains both: "gamble" (Jeux d'argent) and "porn" (Pornographie).
        // Since "Pornographie" is blocked, the engine should block it.
        val result = BlockedKeywordEngine.evaluate(
            text = "online gamble porn videos",
            customBlacklist = emptySet(),
            customWhitelist = emptySet(),
            blockedCategories = blockedCategories,
            ignoreCategoryRestriction = false
        )
        assertTrue(result.isBlocked)
        assertEquals("Pornographie", result.category)
        assertEquals("porn", result.matchedKeyword)
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
    fun testBlockedKeywordEngineRegex() {
        val blacklist = setOf("b[a4]dw.*d", "^startofword")
        val whitelist = emptySet<String>()

        val resultRegex1 = BlockedKeywordEngine.evaluate("this is a b4dword indeed", blacklist, whitelist)
        assertTrue(resultRegex1.isBlocked)
        assertEquals("Parental Block", resultRegex1.category)

        val resultRegex2 = BlockedKeywordEngine.evaluate("startofword is here", blacklist, whitelist)
        assertTrue(resultRegex2.isBlocked)

        val resultRegex3 = BlockedKeywordEngine.evaluate("no match b5dword", blacklist, whitelist)
        assertFalse(resultRegex3.isBlocked)
    }

    @Test
    fun testEventDeduplicator() {
        val deduplicator = EventDeduplicator()
        assertFalse(deduplicator.isDuplicateUrl("https://site.com"))
        assertTrue(deduplicator.isDuplicateUrl("https://site.com"))
        assertFalse(deduplicator.isDuplicateUrl("https://othersite.com"))
    }

    @Test
    fun testNotificationRiskEngine() {
        val safeResult = GeminiAnalysisResult(
            risk = "SAFE",
            score = 10,
            category = "NONE",
            blocked = false,
            confidence = 0.99,
            reason = "Complètement inoffensif"
        )
        assertEquals(NotificationDecision.ALLOW, NotificationRiskEngine.evaluate(safeResult))

        val warningResult = GeminiAnalysisResult(
            risk = "MEDIUM",
            score = 45,
            category = "ESCROQUERIE",
            blocked = false,
            confidence = 0.85,
            reason = "Contient un lien promotionnel suspect"
        )
        assertEquals(NotificationDecision.WARNING, NotificationRiskEngine.evaluate(warningResult))

        val blockResult = GeminiAnalysisResult(
            risk = "CRITICAL",
            score = 95,
            category = "GROOMING",
            blocked = true,
            confidence = 0.98,
            reason = "Tentative explicite de rendez-vous suspect"
        )
        assertEquals(NotificationDecision.BLOCK_AND_ALERT, NotificationRiskEngine.evaluate(blockResult))
    }
}
