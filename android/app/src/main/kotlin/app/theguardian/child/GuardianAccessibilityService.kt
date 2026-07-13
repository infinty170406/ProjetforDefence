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

    private val eventQueue = java.util.Collections.synchronizedList(mutableListOf<AccessibilityEvent>())
    @Volatile private var isReloadingRules = false
    private var pendingSearchRunnable: Runnable? = null

    // Heartbeat natif — écrit toutes les 5 minutes pour que GuardianWorker sache
    // que le moteur d'accessibilité tourne SANS dépendre du runtime Flutter.
    private val heartbeatRunnable = object : Runnable {
        override fun run() {
            writeNativeHeartbeat()
            handler.postDelayed(this, 5 * 60 * 1000L)
        }
    }

    private val reloadRunnable = object : Runnable {
        override fun run() {
            reloadRules()
        }
    }

    private fun reloadRules() {
        synchronized(this) {
            if (isReloadingRules) return
            isReloadingRules = true
        }
        Log.i(TAG, "Starting clean rules reload sequence...")
        
        // Stop all observers and unregister preference listener
        handler.removeCallbacks(reloadRunnable)
        pendingSearchRunnable?.let { handler.removeCallbacks(it) }
        pendingSearchRunnable = null
        
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefsListener?.let { prefs.unregisterOnSharedPreferenceChangeListener(it) }
        
        // Clear all caches, rules, category configurations, etc.
        blockedPackages = emptySet()
        customKeywords = emptySet()
        blockedWebsites = emptySet()
        blockAdult = false
        blockViolence = false
        blockGambling = false
        blockDrugs = false
        blockSexualPredators = false
        blockSelfHarm = false
        blockCyberbullying = false
        blockEatingDisorders = false
        
        eventDebouncer.clear()
        eventDeduplicator.clear()
        navigationContextManager.clear()
        
        try {
            loadRulesFromPrefs()
            Log.i(TAG, "Rules loaded from preferences successfully.")
        } catch (e: Exception) {
            Log.e(TAG, "Error reloading rules: ${e.message}")
        } finally {
            // Restore observers
            prefsListener = android.content.SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
                if (key?.startsWith("flutter.guardian_") == true) {
                    reloadRules()
                }
            }
            prefs.registerOnSharedPreferenceChangeListener(prefsListener)
            handler.postDelayed(reloadRunnable, 5000)
            
            isReloadingRules = false
            Log.i(TAG, "Rules reload completed. Processing ${eventQueue.size} queued events.")
            
            // Process queued events
            val queued = synchronized(eventQueue) {
                val list = ArrayList(eventQueue)
                eventQueue.clear()
                list
            }
            for (evt in queued) {
                try {
                    onAccessibilityEvent(evt)
                } finally {
                    evt.recycle()
                }
            }
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
                            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED or
                            AccessibilityEvent.TYPE_WINDOWS_CHANGED or
                            AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED or
                            AccessibilityEvent.TYPE_VIEW_FOCUSED or
                            AccessibilityEvent.TYPE_VIEW_CLICKED
            feedbackType  = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags         = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                            AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        
        reloadRules()

        // Écrire immédiatement le heartbeat natif au démarrage du service
        writeNativeHeartbeat()
        // Planifier les heartbeats périodiques (toutes les 5 minutes)
        handler.postDelayed(heartbeatRunnable, 5 * 60 * 1000L)

        // Audit de sécurité initial
        securityMonitor.auditSecurity()
        
        Log.i(TAG, "AccessibilityService connected — SOLID orchestrator mode initialized.")
    }

    /**
     * Écrit le timestamp courant dans SharedPreferences sous la clé lue par GuardianWorker
     * et WatchdogReceiver. Utilise le même prefixe 'flutter.' car les deux lisent
     * 'flutter.guardian_service_heartbeat' dans FlutterSharedPreferences.
     */
    private fun writeNativeHeartbeat() {
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putLong("flutter.guardian_service_heartbeat", System.currentTimeMillis()).apply()
            Log.d(TAG, "Native heartbeat written.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write native heartbeat: ${e.message}")
        }
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

    private fun isValidInput(text: String?): Boolean {
        if (text == null) return false
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return false
        if (trimmed.equals("null", ignoreCase = true)) return false
        if (trimmed.equals("undefined", ignoreCase = true)) return false
        return true
    }

    private fun scanForBypassKeywords(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        val text = node.text?.toString()?.lowercase(java.util.Locale.getDefault()) ?: ""
        val contentDesc = node.contentDescription?.toString()?.lowercase(java.util.Locale.getDefault()) ?: ""
        
        if (text.contains("guardian") || contentDesc.contains("guardian")) {
            return true
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val found = scanForBypassKeywords(child)
                child.recycle()
                if (found) return true
            }
        }
        return false
    }

    private fun scanForSettingsBypass(node: AccessibilityNodeInfo?): Boolean {
        val texts = mutableListOf<String>()
        gatherAllTexts(node, texts, 0)
        
        val hasGuardian = texts.any { it.contains("guardian", ignoreCase = true) }
        if (hasGuardian) {
            val hasBypassWord = texts.any {
                it.contains("force stop", ignoreCase = true) ||
                it.contains("forcer l'arrêt", ignoreCase = true) ||
                it.contains("disable", ignoreCase = true) ||
                it.contains("désactiver", ignoreCase = true) ||
                it.contains("uninstall", ignoreCase = true) ||
                it.contains("désinstaller", ignoreCase = true) ||
                it.contains("accessibilité", ignoreCase = true) ||
                it.contains("accessibility", ignoreCase = true) ||
                it.contains("admin", ignoreCase = true)
            }
            if (hasBypassWord) {
                return true
            }
        }
        return false
    }

    private fun gatherAllTexts(node: AccessibilityNodeInfo?, list: MutableList<String>, depth: Int) {
        if (node == null || list.size > 100 || depth > 20) return
        val text = node.text?.toString()?.trim() ?: ""
        val contentDesc = node.contentDescription?.toString()?.trim() ?: ""
        if (text.isNotEmpty()) list.add(text)
        if (contentDesc.isNotEmpty()) list.add(contentDesc)
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                gatherAllTexts(child, list, depth + 1)
                child.recycle()
            }
        }
    }

    private fun isDeviceActivated(): Boolean {
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val childPath = prefs.getString("flutter.child_path", null)
        val childId = prefs.getString("flutter.child_id", null)
        return !childPath.isNullOrBlank() && !childId.isNullOrBlank()
    }

    private fun checkBypassAttempt(rootNode: AccessibilityNodeInfo?, pkg: String): Boolean {
        if (rootNode == null) return false
        
        if (!isDeviceActivated()) {
            return false
        }
        
        if (pkg == "com.google.android.packageinstaller" || pkg == "com.android.packageinstaller" || pkg == "com.sec.android.app.packageinstaller") {
            if (scanForBypassKeywords(rootNode)) {
                Log.w(TAG, "Blocked PackageInstaller action targeting Guardian.")
                return true
            }
        }
        
        if (pkg == "com.android.settings") {
            if (scanForSettingsBypass(rootNode)) {
                Log.w(TAG, "Blocked Settings bypass action targeting Guardian.")
                return true
            }
        }
        
        return false
    }

    private fun checkMultiWindowBlock() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            val interactiveWindows = windows
            for (window in interactiveWindows) {
                val root = window.root
                if (root != null) {
                    val pkg = root.packageName?.toString() ?: ""
                    if (blockedPackages.contains(pkg)) {
                        Log.i(TAG, "Multi-window block triggered for $pkg")
                        root.recycle()
                        blockApp(pkg)
                        break
                    }
                    root.recycle()
                }
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        if (isReloadingRules) {
            synchronized(eventQueue) {
                try {
                    val eventCopy = AccessibilityEvent.obtain(event)
                    eventQueue.add(eventCopy)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to copy accessibility event", e)
                }
            }
            return
        }
        
        val pkg = event.packageName?.toString() ?: return

        // Capture the root node ONCE here to avoid a race condition caused by calling
        // rootInActiveWindow multiple times. Between two calls the active window can
        // change, so the second call may return null and silently drop the event.
        val rootSnapshot = rootInActiveWindow

        // Anti-bypass Settings & Installer check (uses the same snapshot)
        if (rootSnapshot != null) {
            val isBypass = try {
                checkBypassAttempt(rootSnapshot, pkg)
            } catch (e: Exception) {
                Log.e(TAG, "Bypass check error", e)
                false
            }
            if (isBypass) {
                rootSnapshot.recycle()
                securityMonitor.triggerSecurityAlert("Tentative de contournement dans le package $pkg.")
                performGlobalAction(GLOBAL_ACTION_HOME)
                return
            }
        }

        // Multi-window check
        checkMultiWindowBlock()

        // 1. Filtrer et catégoriser l'événement d'accessibilité via l'EventParser
        val eventType = AccessibilityEventParser.parseEvent(event)
        if (eventType == AccessibilityEventParser.EventType.IGNORED) {
            rootSnapshot?.recycle()
            return
        }

        if (eventType == AccessibilityEventParser.EventType.BYPASS_ATTEMPT) {
            rootSnapshot?.recycle()
            if (isDeviceActivated()) {
                securityMonitor.triggerSecurityAlert("Tentative de contournement dans le package $pkg.")
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
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
            rootSnapshot?.recycle()
            blockApp(pkg)
            return
        }

        // 5. Analyse Web & Recherche (si WEB_NAVIGATION)
        if (eventType == AccessibilityEventParser.EventType.WEB_NAVIGATION) {
            // rootSnapshot may be null if the window closed between the event and now;
            // processWebNavigation handles null safely.
            processWebNavigation(event, pkg, rootSnapshot)
        } else {
            rootSnapshot?.recycle()
        }
    }

    /**
     * @param rootNode Pre-captured root node from onAccessibilityEvent. The caller owns the
     *                 lifecycle; this function recycles it in the finally block.
     *                 Passing null causes an early return so no NPE occurs.
     */
    private fun processWebNavigation(event: AccessibilityEvent, pkg: String, rootNode: AccessibilityNodeInfo?) {
        if (rootNode == null) {
            Log.w(TAG, "processWebNavigation: rootNode is null for $pkg — event dropped.")
            return
        }
        try {
            val scan = AccessibilityTreeAnalyzer.analyze(rootNode, blockedWebsites, customKeywords, getBlockedCategories())
            val windowTitle = AccessibilityTreeAnalyzer.extractPageTitleFromEvent(event)
            val pageTitle = windowTitle ?: scan.pageTitle ?: ""

            // Processus YouTube spécifique
            if (pkg == "com.google.android.youtube") {
                processYouTubeApp(rootNode, pkg)
            }

            // Check if tree analyzer exited early due to a blocked item
            if (scan.isBlockedEarly && scan.blockedItem != null) {
                val item = scan.blockedItem
                if (looksLikeUrl(item)) {
                    blockUrl(pkg, item)
                    reportBlockedUrl(pkg, item, pageTitle)
                } else {
                    blockKeyword(pkg, item)
                    reportBlockedKeyword(pkg, item, scan.url)
                }
                return
            }

            val rawUrl = scan.url
            val rawSearch = scan.searchQuery

            // Validate all inputs for null/empty/undefined
            val cleanUrl = if (isValidInput(rawUrl)) rawUrl else null
            val cleanSearch = if (isValidInput(rawSearch)) rawSearch else null

            // 1. Détection de mot-clé bloqué en temps réel dans les champs de saisie (EditText)
            Log.d(TAG, "[KW] Scanning ${scan.editTexts.size} EditText(s) in $pkg — categories=${getBlockedCategories()}, customKW=${customKeywords.size}")
            var blockedKeywordQuery: String? = null
            for (etText in scan.editTexts) {
                if (isValidInput(etText) && !looksLikeUrl(etText)) {
                    val evaluation = BlockedKeywordEngine.evaluate(etText, customKeywords, emptySet(), getBlockedCategories())
                    Log.d(TAG, "[KW] EditText='$etText' → isBlocked=${evaluation.isBlocked}, kw='${evaluation.matchedKeyword}', cat='${evaluation.category}'")
                    if (evaluation.isBlocked) {
                        blockedKeywordQuery = etText
                        break
                    }
                }
            }

            if (blockedKeywordQuery != null) {
                if (!eventDeduplicator.isDuplicateSearch(blockedKeywordQuery)) {
                    blockKeyword(pkg, blockedKeywordQuery)
                    reportBlockedKeyword(pkg, blockedKeywordQuery, cleanUrl)
                }
                return
            }

            // 2. Détection de recherche standard depuis le texte saisi ou l'URL
            val searchQuery = cleanSearch ?: if (cleanUrl != null) SearchDetector.extractSearchQuery(cleanUrl) else null
            val cleanSearchQuery = if (isValidInput(searchQuery)) searchQuery else null

            if (cleanSearchQuery != null) {
                val evaluation = BlockedKeywordEngine.evaluate(cleanSearchQuery, customKeywords, emptySet(), getBlockedCategories())
                Log.d(TAG, "[KW] SearchQuery='$cleanSearchQuery' → isBlocked=${evaluation.isBlocked}, kw='${evaluation.matchedKeyword}', cat='${evaluation.category}'")
                if (evaluation.isBlocked) {
                    if (!eventDeduplicator.isDuplicateSearch(cleanSearchQuery)) {
                        blockKeyword(pkg, cleanSearchQuery)
                        reportBlockedKeyword(pkg, cleanSearchQuery, cleanUrl)
                    }
                    return
                }
            }

            // 3. Validation d'URL bloquée
            if (cleanUrl != null) {
                if (WebsiteBlockEngine.isBlocked(cleanUrl, blockedWebsites)) {
                    blockUrl(pkg, cleanUrl)
                    reportBlockedUrl(pkg, cleanUrl, pageTitle)
                    return
                }
            }

            // 4. Debounced standard/allowed search & navigation processing to avoid logging every character
            val isEnterPressed = event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED ||
                (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED &&
                 event.text?.any { it.contains("\n") || it.contains("\r") } == true)

            if (cleanSearchQuery != null) {
                // Cancel any pending search evaluations
                pendingSearchRunnable?.let { handler.removeCallbacks(it) }
                
                val runSearch = Runnable {
                    if (!isValidInput(cleanSearchQuery) || eventDeduplicator.isDuplicateSearch(cleanSearchQuery)) return@Runnable
                    navigationContextManager.recordSearch(cleanSearchQuery)
                    
                    val classification = ContentClassifier.classify(
                        cleanSearchQuery,
                        pageTitle,
                        scan.headers.filter { isValidInput(it) },
                        scan.importantContent.filter { isValidInput(it) },
                        customKeywords
                    )

                    val shouldBlock = classification.category != null && isCategoryBlocked(classification.category) ||
                                      classification.matchedKeyword != null && customKeywords.contains(classification.matchedKeyword)

                    if (shouldBlock) {
                        blockUrl(pkg, "search?q=$cleanSearchQuery")
                        reportBlockedSearchCategory(pkg, cleanSearchQuery, cleanUrl, classification)
                    } else {
                        reportAllowedSearch(pkg, cleanSearchQuery, cleanUrl, classification)
                    }
                }

                if (isEnterPressed) {
                    runSearch.run()
                } else {
                    pendingSearchRunnable = runSearch
                    handler.postDelayed(runSearch, 1000)
                }
            } else if (cleanUrl != null) {
                // Classify and report navigation
                if (eventDeduplicator.isDuplicateUrl(cleanUrl)) return
                
                navigationContextManager.recordNavigation(cleanUrl, pageTitle)
                val associatedSearch = navigationContextManager.getAssociatedSearch(pkg)
                val cleanAssoc = if (isValidInput(associatedSearch)) associatedSearch else null

                val classification = ContentClassifier.classify(
                    cleanAssoc,
                    pageTitle,
                    scan.headers.filter { isValidInput(it) },
                    scan.importantContent.filter { isValidInput(it) },
                    customKeywords
                )

                val shouldBlock = classification.category != null && isCategoryBlocked(classification.category) ||
                                  classification.matchedKeyword != null && customKeywords.contains(classification.matchedKeyword)

                if (shouldBlock) {
                    blockUrl(pkg, cleanUrl)
                    reportBlockedUrlCategory(pkg, cleanAssoc, pageTitle, cleanUrl, classification)
                } else {
                    reportAllowedUrl(pkg, cleanAssoc, pageTitle, cleanUrl, classification)
                }
            }

        } finally {
            rootNode.recycle()
        }
    }

    private fun reportBlockedKeyword(pkg: String, keyword: String, url: String?) {
        val finalUrl = url ?: "search?q=$keyword"
        timelineManager.buildEvent(
            appPackage = pkg,
            searchQuery = keyword,
            title = "Recherche Bloquée: $keyword",
            url = finalUrl,
            category = "Mot Bloqué",
            riskScore = 100,
            status = "Bloqué"
        )
        eventReporter.sendReport(EventReporter.Report(
            url = finalUrl,
            appPackage = pkg,
            searchQuery = keyword,
            title = "Recherche Bloquée: $keyword",
            category = "Mot Bloqué",
            riskLevel = "Élevé",
            isSiteBlocked = false,
            isWordBlocked = true,
            status = "Bloqué"
        ))
    }

    private fun reportBlockedUrl(pkg: String, url: String, pageTitle: String) {
        val title = if (pageTitle.isBlank()) UrlAnalyzer.parse(url)?.host ?: url else pageTitle
        timelineManager.buildEvent(pkg, null, title, url, "Site Bloqué", 100, "Bloqué")
        eventReporter.sendReport(EventReporter.Report(
            url = url,
            appPackage = pkg,
            searchQuery = null,
            title = title,
            category = "Site Bloqué",
            riskLevel = "Élevé",
            isSiteBlocked = true,
            isWordBlocked = false,
            status = "Bloqué"
        ))
    }

    private fun reportBlockedSearchCategory(pkg: String, query: String, url: String?, classification: ContentClassifier.ClassificationResult) {
        val finalUrl = url ?: "search?q=$query"
        timelineManager.buildEvent(pkg, query, "Recherche Bloquée", finalUrl, classification.category, classification.riskScore, "Bloqué")
        eventReporter.sendReport(EventReporter.Report(
            url = finalUrl,
            appPackage = pkg,
            searchQuery = query,
            title = "Recherche: $query",
            category = classification.category ?: "Mot Bloqué",
            riskLevel = "Élevé",
            isSiteBlocked = false,
            isWordBlocked = true,
            status = "Bloqué"
        ))
    }

    private fun reportAllowedSearch(pkg: String, query: String, url: String?, classification: ContentClassifier.ClassificationResult) {
        val finalUrl = url ?: "search?q=$query"
        timelineManager.buildEvent(pkg, query, "Recherche: $query", finalUrl, classification.category, classification.riskScore, "Autorisé")
        eventReporter.sendReport(EventReporter.Report(
            url = finalUrl,
            appPackage = pkg,
            searchQuery = query,
            title = "Recherche: $query",
            category = classification.category,
            riskLevel = if (classification.riskScore > 70) "Élevé" else if (classification.riskScore > 30) "Moyen" else "Faible",
            isSiteBlocked = false,
            isWordBlocked = false,
            status = "Autorisé"
        ))
    }

    private fun reportBlockedUrlCategory(pkg: String, assocSearch: String?, pageTitle: String, url: String, classification: ContentClassifier.ClassificationResult) {
        val title = if (pageTitle.isBlank()) UrlAnalyzer.parse(url)?.host ?: url else pageTitle
        timelineManager.buildEvent(pkg, assocSearch, title, url, classification.category, classification.riskScore, "Bloqué")
        eventReporter.sendReport(EventReporter.Report(
            url = url,
            appPackage = pkg,
            searchQuery = assocSearch,
            title = title,
            category = classification.category ?: "Contenu Bloqué",
            riskLevel = "Élevé",
            isSiteBlocked = false,
            isWordBlocked = false,
            status = "Bloqué"
        ))
    }

    private fun reportAllowedUrl(pkg: String, assocSearch: String?, pageTitle: String, url: String, classification: ContentClassifier.ClassificationResult) {
        val title = if (pageTitle.isBlank()) UrlAnalyzer.parse(url)?.host ?: url else pageTitle
        timelineManager.buildEvent(pkg, assocSearch, title, url, classification.category, classification.riskScore, "Autorisé")
        eventReporter.sendReport(EventReporter.Report(
            url = url,
            appPackage = pkg,
            searchQuery = assocSearch,
            title = title,
            category = classification.category,
            riskLevel = if (classification.riskScore > 70) "Élevé" else if (classification.riskScore > 30) "Moyen" else "Faible",
            isSiteBlocked = false,
            isWordBlocked = false,
            status = "Autorisé"
        ))
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
        performGlobalAction(GLOBAL_ACTION_BACK)
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
        performGlobalAction(GLOBAL_ACTION_BACK)
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

    private fun getBlockedCategories(): Set<String> {
        val set = mutableSetOf<String>()
        if (blockAdult) set.add("Pornographie")
        if (blockViolence) {
            set.add("Violence")
            set.add("Extrémisme")
        }
        if (blockGambling) set.add("Jeux d'argent")
        if (blockDrugs) {
            set.add("Drogues")
            set.add("Armes")
        }
        if (blockSelfHarm) set.add("Suicide")
        if (blockCyberbullying) {
            set.add("Harcèlement")
            set.add("Cybercriminalité")
        }
        return set
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
        handler.removeCallbacks(heartbeatRunnable)
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefsListener?.let { prefs.unregisterOnSharedPreferenceChangeListener(it) }
        instance = null
        super.onDestroy()
    }
}