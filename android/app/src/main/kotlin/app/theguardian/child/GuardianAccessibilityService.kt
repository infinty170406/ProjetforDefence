package app.theguardian.child

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Orchestrateur central du service d'accessibilité.
 * Délègue l'analyse des arbres, le filtrage des événements, la sécurité,
 * le debouncing et la catégorisation de contenu aux modules SOLID dédiés.
 */
class GuardianAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "GuardianA11y"
        const val ACTION_BLOCK_APP = "app.theguardian.child.BLOCK_APP"
        const val ACTION_URL_DETECTED = "app.theguardian.child.URL_DETECTED"
        const val EXTRA_PACKAGE    = "blocked_package"
        const val EXTRA_REASON     = "block_reason"
        const val EXTRA_URL        = "detected_url"
        const val EXTRA_URL_PACKAGE = "url_package"
        const val EXTRA_SEARCH_QUERY = "search_query"
        const val ACTION_FOREGROUND_CHANGED = "app.theguardian.child.FOREGROUND_CHANGED"
        const val EXTRA_FOREGROUND_PACKAGE = "foreground_package"
        const val OWN_PACKAGE      = "app.theguardian.child"

        const val ACTION_KEYWORD_DETECTED = "app.theguardian.child.KEYWORD_DETECTED"
        const val EXTRA_KEYWORD = "detected_keyword"
        const val EXTRA_KEYWORD_PACKAGE = "keyword_package"

        var instance: GuardianAccessibilityService? = null
            private set

        @Volatile var blockedPackages: Set<String> = emptySet()
        @Volatile var customKeywords: Set<String> = emptySet()
        @Volatile var blockedWebsites: Set<String> = emptySet()
        @Volatile var currentlyBlockedPackage: String? = null

        // Configuration du filtrage des catégories
        @Volatile var blockAdult: Boolean = false
        @Volatile var blockViolence: Boolean = false
        @Volatile var blockGambling: Boolean = false
        @Volatile var blockDrugs: Boolean = true
        @Volatile var blockSexualPredators: Boolean = true
        @Volatile var blockSelfHarm: Boolean = true
        @Volatile var blockCyberbullying: Boolean = true
        @Volatile var blockEatingDisorders: Boolean = false

        fun isEnabled(context: Context): Boolean {
            val expected = ComponentName(
                context.packageName,
                "${context.packageName}.GuardianAccessibilityService"
            ).flattenToString()
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return TextUtils.SimpleStringSplitter(':')
                .also { it.setString(enabled) }
                .any { it.equals(expected, ignoreCase = true) }
        }
    }

    // Composants collaboratifs injectés
    private lateinit var navigationContextManager: NavigationContextManager
    private lateinit var timelineManager: TimelineManager
    private lateinit var eventReporter: EventReporter
    private lateinit var securityMonitor: SecurityMonitor
    private lateinit var eventDeduplicator: EventDeduplicator
    private lateinit var eventDebouncer: EventDebouncer
    private lateinit var appUsageMonitor: AppUsageMonitor
    private lateinit var syncManager: SyncManager

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var prefsListener: android.content.SharedPreferences.OnSharedPreferenceChangeListener? = null

    private val reloadRunnable = object : Runnable {
        override fun run() {
            loadRulesFromPrefs()
            handler.postDelayed(this, 5000)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        navigationContextManager = NavigationContextManager()
        timelineManager = TimelineManager()
        eventReporter = EventReporter(applicationContext)
        securityMonitor = SecurityMonitor(applicationContext)
        eventDeduplicator = EventDeduplicator()
        eventDebouncer = EventDebouncer()
        appUsageMonitor = AppUsageMonitor(applicationContext)
        syncManager = SyncManager(applicationContext)

        serviceInfo = serviceInfo.apply {
            eventTypes    = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                            AccessibilityEvent.TYPE_VIEW_SCROLLED or
                            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType  = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags         = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                            AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        
        loadRulesFromPrefs()
        
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefsListener = android.content.SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key?.startsWith("flutter.guardian_") == true) {
                loadRulesFromPrefs()
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)
        handler.postDelayed(reloadRunnable, 5000)

        // Audit de sécurité initial
        securityMonitor.auditSecurity()
        
        Log.i(TAG, "AccessibilityService connected — SOLID orchestrator mode initialized.")
    }
    
    private fun loadRulesFromPrefs() {
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            val appsJson = prefs.getString("flutter.guardian_blocked_packages_json", "[]") ?: "[]"
            val appsArray = org.json.JSONArray(appsJson)
            val newApps = mutableSetOf<String>()
            for (i in 0 until appsArray.length()) newApps.add(appsArray.getString(i))
            blockedPackages = newApps

            val keywordsJson = prefs.getString("flutter.guardian_custom_keywords_json", "[]") ?: "[]"
            val keywordsArray = org.json.JSONArray(keywordsJson)
            val newKeywords = mutableSetOf<String>()
            for (i in 0 until keywordsArray.length()) newKeywords.add(keywordsArray.getString(i))
            customKeywords = newKeywords

            val websitesJson = prefs.getString("flutter.guardian_blocked_websites_json", "[]") ?: "[]"
            val websitesArray = org.json.JSONArray(websitesJson)
            val newWebsites = mutableSetOf<String>()
            for (i in 0 until websitesArray.length()) newWebsites.add(websitesArray.getString(i))
            blockedWebsites = newWebsites

            blockAdult = prefs.getBoolean("flutter.guardian_block_adult", false)
            blockViolence = prefs.getBoolean("flutter.guardian_block_violence", false)
            blockGambling = prefs.getBoolean("flutter.guardian_block_gambling", false)
            blockDrugs = prefs.getBoolean("flutter.guardian_block_drugs", true)
            blockSexualPredators = prefs.getBoolean("flutter.guardian_block_sexual_predators", true)
            blockSelfHarm = prefs.getBoolean("flutter.guardian_block_self_harm", true)
            blockCyberbullying = prefs.getBoolean("flutter.guardian_block_cyberbullying", true)
            blockEatingDisorders = prefs.getBoolean("flutter.guardian_block_eating_disorders", false)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in loadRulesFromPrefs: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        // 1. Filtrer et catégoriser l'événement d'accessibilité via l'EventParser
        val eventType = AccessibilityEventParser.parseEvent(event)
        if (eventType == AccessibilityEventParser.EventType.IGNORED) {
            return
        }

        // 2. Traitement anti-contournement (anti-bypass)
        if (eventType == AccessibilityEventParser.EventType.BYPASS_ATTEMPT) {
            securityMonitor.triggerSecurityAlert("Tentative de contournement dans le package $pkg.")
            performGlobalAction(GLOBAL_ACTION_HOME)
            return
        }

        // 3. Suivi du focus d'application
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            appUsageMonitor.onAppForeground(pkg)
            broadcastForegroundPackage(pkg)

            // DISMISS NATIVE BLOCK IF FOREGROUND PACKAGE CHANGED
            val blockedPkg = currentlyBlockedPackage
            if (blockedPkg != null) {
                if (pkg != blockedPkg && pkg != OWN_PACKAGE && pkg != "android") {
                    Log.i(TAG, "Foreground package changed from blocked $blockedPkg to $pkg. Dismissing block screen.")
                    currentlyBlockedPackage = null
                    val dismissIntent = Intent("app.theguardian.child.DISMISS_BLOCK").apply {
                        setPackage(OWN_PACKAGE)
                    }
                    sendBroadcast(dismissIntent)
                }
            }
        }

        // 4. Blocage immédiat d'application configurée
        if (blockedPackages.contains(pkg)) {
            blockApp(pkg)
            return
        }

        // 5. Analyse Web & Recherche (si WEB_NAVIGATION)
        if (eventType == AccessibilityEventParser.EventType.WEB_NAVIGATION) {
            processWebNavigation(event, pkg)
        }
    }

    private fun processWebNavigation(event: AccessibilityEvent, pkg: String) {
        val eventKey = "$pkg:${event.eventType}"
        if (!eventDebouncer.shouldProcess(eventKey)) {
            return
        }

        val rootNode = rootInActiveWindow ?: return
        try {
            val scan = AccessibilityTreeAnalyzer.analyze(rootNode)
            val windowTitle = AccessibilityTreeAnalyzer.extractPageTitleFromEvent(event)
            val pageTitle = windowTitle ?: scan.pageTitle ?: ""

            // Processus YouTube spécifique
            if (pkg == "com.google.android.youtube") {
                processYouTubeApp(rootNode, pkg)
            }

            val rawUrl = scan.url
            val rawSearch = scan.searchQuery

            // Détection de mot-clé bloqué en temps réel dans les champs de saisie (EditText)
            var blockedKeywordQuery: String? = null
            for (etText in scan.editTexts) {
                if (etText.isNotEmpty() && !looksLikeUrl(etText)) {
                    val evaluation = BlockedKeywordEngine.evaluate(etText, customKeywords, emptySet())
                    if (evaluation.isBlocked) {
                        blockedKeywordQuery = etText
                        break
                    }
                }
            }

            if (blockedKeywordQuery != null) {
                if (!eventDeduplicator.isDuplicateSearch(blockedKeywordQuery)) {
                    blockKeyword(pkg, blockedKeywordQuery)
                    val evaluation = BlockedKeywordEngine.evaluate(blockedKeywordQuery, customKeywords, emptySet())
                    timelineManager.buildEvent(
                        appPackage = pkg,
                        searchQuery = blockedKeywordQuery,
                        title = "Recherche Bloquée: $blockedKeywordQuery",
                        url = rawUrl ?: "search?q=$blockedKeywordQuery",
                        category = evaluation.category ?: "Mot Bloqué",
                        riskScore = 100,
                        status = "Bloqué"
                    )
                    eventReporter.sendReport(EventReporter.Report(
                        url = rawUrl ?: "search?q=$blockedKeywordQuery",
                        appPackage = pkg,
                        searchQuery = blockedKeywordQuery,
                        title = "Recherche Bloquée: $blockedKeywordQuery",
                        category = evaluation.category ?: "Mot Bloqué",
                        riskLevel = "Élevé",
                        isSiteBlocked = false,
                        isWordBlocked = true,
                        status = "Bloqué"
                    ))
                }
                return
            }

            // Détection de recherche standard depuis le texte saisi ou l'URL
            val searchQuery = rawSearch ?: if (rawUrl != null) SearchDetector.extractSearchQuery(rawUrl) else null

            // 1. Validation de mot-clé bloqué (avant chargement de l'URL)
            if (searchQuery != null && searchQuery.isNotEmpty()) {
                val evaluation = BlockedKeywordEngine.evaluate(searchQuery, customKeywords, emptySet())
                if (evaluation.isBlocked) {
                    if (!eventDeduplicator.isDuplicateSearch(searchQuery)) {
                        blockKeyword(pkg, searchQuery)
                        timelineManager.buildEvent(
                            appPackage = pkg,
                            searchQuery = searchQuery,
                            title = "Recherche Bloquée: $searchQuery",
                            url = rawUrl ?: "search?q=$searchQuery",
                            category = evaluation.category ?: "Mot Bloqué",
                            riskScore = 100,
                            status = "Bloqué"
                        )
                        eventReporter.sendReport(EventReporter.Report(
                            url = rawUrl ?: "search?q=$searchQuery",
                            appPackage = pkg,
                            searchQuery = searchQuery,
                            title = "Recherche Bloquée: $searchQuery",
                            category = evaluation.category ?: "Mot Bloqué",
                            riskLevel = "Élevé",
                            isSiteBlocked = false,
                            isWordBlocked = true,
                            status = "Bloqué"
                        ))
                    }
                    return
                }
            }

            // 2. Validation d'URL bloquée
            if (rawUrl != null) {
                // Déduplication URL
                if (eventDeduplicator.isDuplicateUrl(rawUrl)) return

                // Vérification du blocage de site robuste
                if (WebsiteBlockEngine.isBlocked(rawUrl, blockedWebsites)) {
                    blockUrl(pkg, rawUrl)
                    timelineManager.buildEvent(pkg, null, pageTitle, rawUrl, "Site Bloqué", 100, "Bloqué")
                    eventReporter.sendReport(EventReporter.Report(
                        url = rawUrl,
                        appPackage = pkg,
                        searchQuery = null,
                        title = pageTitle.ifBlank { UrlAnalyzer.parse(rawUrl)?.host ?: rawUrl },
                        category = "Site Bloqué",
                        riskLevel = "Élevé",
                        isSiteBlocked = true,
                        isWordBlocked = false,
                        status = "Bloqué"
                    ))
                    return
                }

                // 3. Traitement de la recherche autorisée (avec classification de sécurité additionnelle)
                if (searchQuery != null && searchQuery.isNotEmpty()) {
                    if (eventDeduplicator.isDuplicateSearch(searchQuery)) return
                    
                    navigationContextManager.recordSearch(searchQuery)
                    
                    val classification = ContentClassifier.classify(
                        searchQuery,
                        pageTitle,
                        scan.headers,
                        scan.importantContent,
                        customKeywords
                    )

                    val shouldBlock = classification.category != null && isCategoryBlocked(classification.category) ||
                                    classification.matchedKeyword != null && customKeywords.contains(classification.matchedKeyword)

                    if (shouldBlock) {
                        blockUrl(pkg, "search?q=$searchQuery")
                        timelineManager.buildEvent(pkg, searchQuery, "Recherche Bloquée", rawUrl, classification.category, classification.riskScore, "Bloqué")
                        eventReporter.sendReport(EventReporter.Report(
                            url = rawUrl,
                            appPackage = pkg,
                            searchQuery = searchQuery,
                            title = "Recherche: $searchQuery",
                            category = classification.category ?: "Mot Bloqué",
                            riskLevel = "Élevé",
                            isSiteBlocked = false,
                            isWordBlocked = true,
                            status = "Bloqué"
                        ))
                        return
                    }

                    timelineManager.buildEvent(pkg, searchQuery, "Recherche: $searchQuery", rawUrl, classification.category, classification.riskScore, "Autorisé")
                    eventReporter.sendReport(EventReporter.Report(
                        url = rawUrl,
                        appPackage = pkg,
                        searchQuery = searchQuery,
                        title = "Recherche: $searchQuery",
                        category = classification.category,
                        riskLevel = if (classification.riskScore > 70) "Élevé" else if (classification.riskScore > 30) "Moyen" else "Faible",
                        isSiteBlocked = false,
                        isWordBlocked = false,
                        status = "Autorisé"
                    ))
                } else {
                    // 4. Traitement de navigation classique (avec classification)
                    navigationContextManager.recordNavigation(rawUrl, pageTitle)
                    val associatedSearch = navigationContextManager.getAssociatedSearch(pkg)

                    val classification = ContentClassifier.classify(
                        associatedSearch,
                        pageTitle,
                        scan.headers,
                        scan.importantContent,
                        customKeywords
                    )

                    val shouldBlock = classification.category != null && isCategoryBlocked(classification.category) ||
                                    classification.matchedKeyword != null && customKeywords.contains(classification.matchedKeyword)

                    if (shouldBlock) {
                        blockUrl(pkg, rawUrl)
                        timelineManager.buildEvent(pkg, associatedSearch, pageTitle, rawUrl, classification.category, classification.riskScore, "Bloqué")
                        eventReporter.sendReport(EventReporter.Report(
                            url = rawUrl,
                            appPackage = pkg,
                            searchQuery = associatedSearch,
                            title = pageTitle.ifBlank { UrlAnalyzer.parse(rawUrl)?.host ?: rawUrl },
                            category = classification.category ?: "Contenu Bloqué",
                            riskLevel = "Élevé",
                            isSiteBlocked = false,
                            isWordBlocked = false,
                            status = "Bloqué"
                        ))
                        return
                    }

                    timelineManager.buildEvent(pkg, associatedSearch, pageTitle, rawUrl, classification.category, classification.riskScore, "Autorisé")
                    eventReporter.sendReport(EventReporter.Report(
                        url = rawUrl,
                        appPackage = pkg,
                        searchQuery = associatedSearch,
                        title = pageTitle.ifBlank { UrlAnalyzer.parse(rawUrl)?.host ?: rawUrl },
                        category = classification.category,
                        riskLevel = if (classification.riskScore > 70) "Élevé" else if (classification.riskScore > 30) "Moyen" else "Faible",
                        isSiteBlocked = false,
                        isWordBlocked = false,
                        status = "Autorisé"
                    ))
                }
            }
        } finally {
            rootNode.recycle()
        }
    }

    private fun blockKeyword(pkg: String, keyword: String) {
        currentlyBlockedPackage = pkg
        Log.i(TAG, "Blocked keyword detected at foreground: $keyword.")

        val reason = "La recherche du mot-clé '$keyword' est bloquée par vos parents."

        val broadcastIntent = Intent(ACTION_KEYWORD_DETECTED).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_KEYWORD, keyword)
            putExtra(EXTRA_KEYWORD_PACKAGE, pkg)
        }
        sendBroadcast(broadcastIntent)

        val blockAppIntent = Intent(ACTION_BLOCK_APP).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_PACKAGE, pkg)
            putExtra(EXTRA_REASON, reason)
        }
        sendBroadcast(blockAppIntent)

        val blockIntent = Intent(applicationContext, BlockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra("BLOCK_REASON", reason)
            putExtra("BLOCK_PACKAGE", pkg)
        }
        startActivity(blockIntent)
    }

    private fun blockUrl(pkg: String, blockedDomain: String) {
        currentlyBlockedPackage = pkg
        Log.i(TAG, "Blocked URL detected at foreground: $blockedDomain.")

        val reason = "Ce site web ou cette recherche ($blockedDomain) est bloqué(e) par vos parents."

        val broadcastIntent = Intent(ACTION_BLOCK_APP).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_PACKAGE, pkg)
            putExtra(EXTRA_REASON, reason)
        }
        sendBroadcast(broadcastIntent)

        val blockIntent = Intent(applicationContext, BlockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra("BLOCK_REASON", reason)
            putExtra("BLOCK_PACKAGE", pkg)
        }
        startActivity(blockIntent)
    }

    private fun processYouTubeApp(rootNode: AccessibilityNodeInfo, pkg: String) {
        val ytTitleNodes = rootNode.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/title")
        val ytTitle = if (ytTitleNodes != null && ytTitleNodes.isNotEmpty()) {
            val txt = ytTitleNodes[0].text?.toString()
            ytTitleNodes[0].recycle()
            txt
        } else null
        
        val ytChannelNodes = rootNode.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/channel_name")
        val ytChannel = if (ytChannelNodes != null && ytChannelNodes.isNotEmpty()) {
            val txt = ytChannelNodes[0].text?.toString()
            ytChannelNodes[0].recycle()
            txt
        } else null
        
        if (ytTitle != null) {
            if (!eventDeduplicator.isDuplicateSearch(ytTitle)) {
                timelineManager.buildEvent(pkg, null, "Vidéo: $ytTitle", "https://www.youtube.com/watch?v=app", "Divertissement", 10, "Autorisé")
                eventReporter.sendReport(EventReporter.Report(
                    url = "https://www.youtube.com/watch?v=app",
                    appPackage = pkg,
                    searchQuery = null,
                    title = "Vidéo: $ytTitle (${ytChannel ?: "Inconnu"})",
                    category = "Divertissement",
                    riskLevel = "Faible",
                    isSiteBlocked = false,
                    isWordBlocked = false,
                    status = "Autorisé"
                ))
            }
        }
    }

    private fun isCategoryBlocked(category: String): Boolean {
        return when (category) {
            "Pornographie" -> blockAdult
            "Violence" -> blockViolence
            "Jeux d'argent" -> blockGambling
            "Drogues", "Armes" -> blockDrugs
            "Suicide" -> blockSelfHarm
            "Extrémisme" -> blockViolence
            "Harcèlement" -> blockCyberbullying
            "Cybercriminalité" -> blockCyberbullying
            else -> false
        }
    }

    private fun blockApp(pkg: String) {
        currentlyBlockedPackage = pkg
        Log.i(TAG, "Blocked app detected at foreground: $pkg.")
        
        var reason = "Cette application est bloquée par vos parents."
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            reason = prefs.getString("flutter.guardian_block_reason_$pkg", null)
                ?: prefs.getString("flutter.guardian_block_reason", null)
                ?: "Cette application est bloquée par vos parents."
        } catch (e: Exception) {
            Log.e(TAG, "Error reading block reason: ${e.message}")
        }

        val broadcastIntent = Intent(ACTION_BLOCK_APP).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_PACKAGE, pkg)
            putExtra(EXTRA_REASON, reason)
        }
        sendBroadcast(broadcastIntent)

        val blockIntent = Intent(applicationContext, BlockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra("BLOCK_REASON", reason)
            putExtra("BLOCK_PACKAGE", pkg)
        }
        startActivity(blockIntent)
    }

    private fun broadcastForegroundPackage(pkg: String) {
        val intent = Intent(ACTION_FOREGROUND_CHANGED).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_FOREGROUND_PACKAGE, pkg)
        }
        sendBroadcast(intent)
        
        // Log localement via SyncManager
        syncManager.queueEvent("foreground_event", mapOf("package" to pkg))
    }

    private fun looksLikeUrl(text: String): Boolean {
        if (text.startsWith("http://") || text.startsWith("https://")) return true
        if (text.contains(".") && !text.contains(" ") && text.length > 3) {
            val lastDot = text.lastIndexOf('.')
            if (lastDot > 0 && lastDot < text.length - 1) {
                val tld = text.substring(lastDot + 1)
                if (tld.length in 2..6 && tld.all { it.isLetter() }) {
                    return true
                }
            }
        }
        return false
    }

    override fun onInterrupt() {
        Log.w(TAG, "AccessibilityService interrupted.")
    }

    override fun onDestroy() {
        appUsageMonitor.onAppBackground()
        handler.removeCallbacks(reloadRunnable)
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefsListener?.let { prefs.unregisterOnSharedPreferenceChangeListener(it) }
        instance = null
        super.onDestroy()
    }
}