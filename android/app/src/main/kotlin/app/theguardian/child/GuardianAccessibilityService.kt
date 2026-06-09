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
import org.json.JSONArray
import org.json.JSONObject

/**
 * GuardianAccessibilityService
 *
 * Détecte chaque changement d'app au premier plan via AccessibilityEvent.
 * Quand une app bloquée est détectée, envoie un broadcast local que Flutter
 * intercepte via le MethodChannel pour déclencher l'écran de blocage.
 *
 * La liste des packages bloqués est maintenue en mémoire et mise à jour
 * depuis Flutter via [updateBlockedPackages].
 */
class GuardianAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "GuardianA11y"
        const val ACTION_BLOCK_APP = "app.theguardian.child.BLOCK_APP"
        const val ACTION_URL_DETECTED = "app.theguardian.child.URL_DETECTED"
        const val ACTION_KEYWORD_DETECTED = "app.theguardian.child.KEYWORD_DETECTED"
        const val EXTRA_PACKAGE    = "blocked_package"
        const val EXTRA_REASON     = "block_reason"
        const val EXTRA_URL        = "detected_url"
        const val EXTRA_URL_PACKAGE = "url_package"
        const val EXTRA_SEARCH_QUERY = "search_query"
        const val EXTRA_KEYWORD    = "detected_keyword"
        const val EXTRA_KEYWORD_PACKAGE = "keyword_package"
        const val ACTION_FOREGROUND_CHANGED = "app.theguardian.child.FOREGROUND_CHANGED"
        const val EXTRA_FOREGROUND_PACKAGE = "foreground_package"
        const val OWN_PACKAGE      = "app.theguardian.child"

        // Instance statique pour permettre la mise à jour depuis Flutter
        var instance: GuardianAccessibilityService? = null
            private set

        // Packages bloqués — mis à jour en temps réel depuis EnforcementService
        @Volatile var blockedPackages: Set<String> = emptySet()

        // Mots-clés personnalisés
        @Volatile var customKeywords: Set<String> = emptySet()

        // Sites web bloqués
        @Volatile var blockedWebsites: Set<String> = emptySet()

        // Browsers supportés pour l'extraction d'URL
        private val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "com.sec.android.app.sbrowser",
            "org.mozilla.firefox",
            "com.opera.browser",
            "com.microsoft.emmx", // Edge
            "com.brave.browser",
            "com.duckduckgo.mobile.android"
        )

        /**
         * Vérifie si ce service est activé dans les paramètres Android.
         */
        fun isEnabled(context: android.content.Context): Boolean {
            val expected = ComponentName(
                context.packageName,
                "${ context.packageName }.GuardianAccessibilityService"
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

    // Anti-spam pour les mots-clés
    private val keywordLastDetected = mutableMapOf<String, Long>()
    private val KEYWORD_COOLDOWN_MS = 10_000L // 10 secondes
    private var lastScreenReadTime = 0L
    private val SCREEN_READ_COOLDOWN_MS = 2000L // 2 secondes
    private var prefsListener: android.content.SharedPreferences.OnSharedPreferenceChangeListener? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
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
        
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        loadRulesFromPrefs()
        
        prefsListener = android.content.SharedPreferences.OnSharedPreferenceChangeListener { sharedPreferences, key ->
            if (key?.startsWith("flutter.guardian_") == true) {
                loadRulesFromPrefs()
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)
        
        Log.i(TAG, "AccessibilityService connected — ready to enforce and filter web.")
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
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in loadRulesFromPrefs: ${e.message}")
        }
    }
    


    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        val pkg = event.packageName?.toString() ?: return

        // Ne jamais se bloquer soi-même ni les apps système UI
        if (pkg == OWN_PACKAGE || pkg.startsWith("com.android.systemui")) {
            return
        }

        // 0. Auto-défense : Empêcher l'enfant de désactiver le Guardian dans les paramètres
        if (pkg == "com.android.settings") {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                val screenText = extractTextFromNode(rootNode).lowercase()
                val dangerousWords = setOf(
                    "accessibility", "accessibilité", 
                    "device admin", "administrateur",
                    "désinstaller", "uninstall", 
                    "guardian"
                )
                for (word in dangerousWords) {
                    if (screenText.contains(word)) {
                        Log.i(TAG, "Preventing settings bypass: $word detected. Redirecting home.")
                        performGlobalAction(GLOBAL_ACTION_HOME)
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(homeIntent)
                        rootNode.recycle()
                        return
                    }
                }
                rootNode.recycle()
            }
        }

        // Ne pas traiter les apps système pures (sauf si elles sont dans la liste bloquée)
        if (!blockedPackages.contains(pkg) && isSystemPackage(pkg)) {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                broadcastForegroundPackage(pkg)
            }
            return
        }

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            broadcastForegroundPackage(pkg)
        }

        // 1. Détection de package bloqué (Apps) - instantané sur n'importe quel événement
        if (blockedPackages.contains(pkg)) {
            blockApp(pkg)
            return
        }

        // 2. Détection d'URL (Web Filtering) et recherches web
        if (BROWSER_PACKAGES.contains(pkg) || pkg == "com.google.android.googlequicksearchbox") {
            val rootNode = rootInActiveWindow ?: return
            val url = findUrlInNode(rootNode, pkg)
            val searchQuery = findSearchQueryInNode(rootNode, pkg)
            
            if (url != null || searchQuery != null) {
                val finalUrl = url ?: "https://www.google.com/search?q=${android.net.Uri.encode(searchQuery)}"
                Log.d(TAG, "Detected URL/Search in $pkg: $finalUrl (Query: $searchQuery)")
                broadcastUrl(finalUrl, searchQuery, pkg)
                
                // Vérification native immédiate du blocage web
                if (blockedWebsites.isNotEmpty()) {
                    val finalUrlLower = finalUrl.lowercase()
                        .replace(Regex("^(https?://)?(www\\.)?"), "")
                        
                    for (blocked in blockedWebsites) {
                        val blockedClean = blocked.lowercase()
                            .replace(Regex("^(https?://)?(www\\.)?"), "")
                            
                        if (finalUrlLower.contains(blockedClean)) {
                            Log.i(TAG, "Native web blocking triggered for $blocked in $finalUrl")
                            blockUrl(pkg, blocked)
                            return
                        }
                    }
                }
            }
        }

        // 3. Détection de mots-clés (Frappe et affichage)
        if (customKeywords.isNotEmpty()) {
            if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
                checkKeywords(event.text, pkg)
            } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                checkScreenContent(pkg)
            }
        }
    }

    private fun isSystemPackage(pkg: String): Boolean {
        // Apps utilisateur bloquables — ne jamais les considérer comme système
        val userApps = setOf(
            "com.google.android.youtube",
            "com.google.android.apps.youtube.kids",
            "com.google.android.gm",
            "com.google.android.googlequicksearchbox",
            "com.android.chrome",
            "com.android.vending",
            "com.whatsapp",
            "com.snapchat.android",
            "com.instagram.android",
            "com.facebook.katana",
            "com.tiktok",
            "com.zhiliaoapp.musically",
            // Apps MIUI utilisateur
            "com.miui.gallery",
            "com.miui.video",
            "com.miui.player",
            "com.miui.notes",
            "com.miui.browser"
        )
        if (userApps.contains(pkg)) return false

        return pkg.startsWith("com.android.") ||
               pkg.startsWith("com.google.android.") ||
               pkg.startsWith("com.miui.") ||
               pkg.startsWith("com.xiaomi.") ||
               pkg.startsWith("com.qualcomm.") ||
               pkg.startsWith("com.mediatek.") ||
               pkg.startsWith("android.") ||
               pkg == "android"
    }

    private fun blockApp(pkg: String) {
        Log.i(TAG, "Blocked app detected at foreground: $pkg. Redirecting to home.")

        // 1. Simuler un appui sur le bouton Accueil d'Android (Action native immédiate)
        performGlobalAction(GLOBAL_ACTION_HOME)
        
        // Fallback d'intent au cas où
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)

        // Récupérer le motif de blocage dynamique depuis SharedPreferences si présent
        var reason = "Cette application est bloquée par vos parents."
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val storedReason = prefs.getString("flutter.guardian_block_reason_$pkg", null)
            if (storedReason != null) {
                reason = storedReason
            } else {
                val globalReason = prefs.getString("flutter.guardian_block_reason", null)
                if (globalReason != null) {
                    reason = globalReason
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading block reason: ${e.message}")
        }

        // 2. Broadcast pour MainActivity si elle est vivante (EventChannel Flutter)
        val broadcastIntent = Intent(ACTION_BLOCK_APP).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_PACKAGE, pkg)
            putExtra(EXTRA_REASON, reason)
        }
        sendBroadcast(broadcastIntent)

        // 3. Lancer BlockActivity directement
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
        Log.i(TAG, "Blocked URL detected at foreground: $blockedDomain. Redirecting to home.")

        // 1. Simuler un appui sur le bouton Accueil d'Android (Action native immédiate)
        performGlobalAction(GLOBAL_ACTION_HOME)
        
        // Fallback d'intent
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)

        val reason = "Ce site web ($blockedDomain) est bloqué par vos parents."

        // 2. Broadcast pour MainActivity si elle est vivante (EventChannel Flutter)
        val broadcastIntent = Intent(ACTION_BLOCK_APP).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_PACKAGE, pkg)
            putExtra(EXTRA_REASON, reason)
        }
        sendBroadcast(broadcastIntent)

        // 3. Lancer BlockActivity directement
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
        // FIX BUG #1 : aussi enqueuer pour le background isolate Flutter
        enqueueEvent("foreground_event", mapOf("package" to pkg))
    }

    private fun findUrlInNode(root: AccessibilityNodeInfo, pkg: String): String? {
        // IDs communs des barres d'adresse selon le navigateur
        val urlBarIds = when (pkg) {
            "com.android.chrome" -> arrayOf("com.android.chrome:id/url_bar")
            "com.sec.android.app.sbrowser" -> arrayOf("com.sec.android.app.sbrowser:id/location_bar_edit_text")
            "org.mozilla.firefox" -> arrayOf("org.mozilla.firefox:id/url_bar_title", "org.mozilla.firefox:id/mozac_browser_toolbar_url_view")
            "com.microsoft.emmx" -> arrayOf("com.microsoft.emmx:id/url_bar_text")
            "com.brave.browser" -> arrayOf("com.brave.browser:id/url_bar")
            "com.duckduckgo.mobile.android" -> arrayOf("com.duckduckgo.mobile.android:id/omnibarTextInput")
            else -> arrayOf("url_bar", "address_bar", "location_bar", "url_view") // Essayer des IDs génériques
        }

        for (id in urlBarIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (nodes != null && nodes.isNotEmpty()) {
                val node = nodes[0]
                val text = node.text?.toString()
                node.recycle()
                if (!text.isNullOrBlank()) return text
            }
        }

        // --- NOUVEAU : Fallback par recherche de contenu si l'ID a changé ---
        // On cherche des nœuds éditables ou qui ressemblent à une barre d'adresse
        return findUrlRecursive(root, 0)
    }

    private fun findSearchQueryInNode(root: AccessibilityNodeInfo, pkg: String): String? {
        val searchBoxIds = arrayOf(
            "com.google.android.googlequicksearchbox:id/search_box",
            "com.google.android.googlequicksearchbox:id/search_edit_frame",
            "com.android.chrome:id/search_box_text",
            "com.android.chrome:id/url_bar"
        )

        for (id in searchBoxIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (nodes != null && nodes.isNotEmpty()) {
                for (node in nodes) {
                    val text = node.text?.toString()
                    val hint = node.hintText?.toString()?.lowercase() ?: ""
                    node.recycle()
                    // Si le champ de texte n'est pas une URL
                    if (!text.isNullOrBlank() && !text.startsWith("http") && !text.contains("/")) {
                        return text
                    }
                }
            }
        }
        return null
    }

    private fun findUrlRecursive(node: AccessibilityNodeInfo?, depth: Int): String? {
        if (node == null || depth > 50) return null // Sécurité pour éviter les boucles infinies

        // Si le nœud est éditable et contient un point, c'est peut-être l'URL
        if (node.isEditable && node.text != null) {
            val text = node.text.toString()
            if (text.contains(".") && !text.contains(" ")) {
                return text
            }
        }

        // Explorer les enfants
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            val result = findUrlRecursive(child, depth + 1)
            if (result != null) return result
        }

        return null
    }

    private fun checkKeywords(texts: List<CharSequence>?, pkg: String) {
        if (texts.isNullOrEmpty() || customKeywords.isEmpty()) return
        val textStr = texts.joinToString(" ").lowercase()
        
        for (keyword in customKeywords) {
            val kwLower = keyword.lowercase()
            if (textStr.contains(kwLower)) {
                val now = System.currentTimeMillis()
                val lastTime = keywordLastDetected[kwLower] ?: 0L
                if (now - lastTime > KEYWORD_COOLDOWN_MS) {
                    keywordLastDetected[kwLower] = now
                    Log.i(TAG, "Keyword detected: $keyword in $pkg")
                    broadcastKeywordDetected(keyword, pkg)
                }
            }
        }
    }

    private fun checkScreenContent(pkg: String) {
        val now = System.currentTimeMillis()
        if (now - lastScreenReadTime < SCREEN_READ_COOLDOWN_MS) return
        lastScreenReadTime = now

        val rootNode = rootInActiveWindow ?: return
        val screenText = extractTextFromNode(rootNode).lowercase()
        
        for (keyword in customKeywords) {
            val kwLower = keyword.lowercase()
            if (screenText.contains(kwLower)) {
                val lastTime = keywordLastDetected[kwLower] ?: 0L
                if (now - lastTime > KEYWORD_COOLDOWN_MS) {
                    keywordLastDetected[kwLower] = now
                    Log.i(TAG, "Keyword detected on screen: $keyword in $pkg")
                    broadcastKeywordDetected(keyword, pkg)
                }
            }
        }
    }

    private fun extractTextFromNode(node: AccessibilityNodeInfo?): String {
        if (node == null) return ""
        val sb = java.lang.StringBuilder()
        if (!node.text.isNullOrBlank()) {
            sb.append(node.text).append(" ")
        }
        if (!node.contentDescription.isNullOrBlank()) {
            sb.append(node.contentDescription).append(" ")
        }
        for (i in 0 until node.childCount) {
            sb.append(extractTextFromNode(node.getChild(i)))
        }
        return sb.toString()
    }

    private fun broadcastKeywordDetected(keyword: String, pkg: String) {
        val intent = Intent(ACTION_KEYWORD_DETECTED).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_KEYWORD, keyword)
            putExtra(EXTRA_KEYWORD_PACKAGE, pkg)
        }
        sendBroadcast(intent)
        // FIX BUG #1 : enqueuer pour le background isolate Flutter
        enqueueEvent("keyword_event", mapOf("keyword" to keyword, "package" to pkg))
    }

    private fun broadcastUrl(url: String, searchQuery: String?, pkg: String) {
        val intent = Intent(ACTION_URL_DETECTED).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_URL, url)
            putExtra(EXTRA_URL_PACKAGE, pkg)
            if (searchQuery != null) {
                putExtra(EXTRA_SEARCH_QUERY, searchQuery)
            }
        }
        sendBroadcast(intent)
        // FIX BUG #1 : enqueuer pour le background isolate Flutter
        val eventMap = mutableMapOf("url" to url, "package" to pkg)
        if (searchQuery != null) {
            eventMap["searchQuery"] = searchQuery
        }
        enqueueEvent("web_event", eventMap)
    }

    /**
     * Écrit un événement dans SharedPreferences en utilisant une clé unique.
     * Le fichier FlutterSharedPreferences est lisible par Dart via SharedPreferences.getInstance().
     * FIX BUG #1 + #3 + Race Conditions: Chaque événement a sa propre clé.
     */
    private fun enqueueEvent(action: String, extras: Map<String, String>) {
        try {
            val prefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val obj = JSONObject().apply {
                put("action", action)
                put("ts", System.currentTimeMillis())
                extras.forEach { (k, v) -> put(k, v) }
            }
            // Créer une clé unique avec timestamp et random
            val ts = System.currentTimeMillis()
            val rnd = (Math.random() * 1000).toInt()
            val key = "flutter.guardian_event_${ts}_${rnd}"
            
            prefs.edit().putString(key, obj.toString()).apply()
            Log.v(TAG, "enqueueEvent: $action -> $key")
        } catch (e: Exception) {
            Log.e(TAG, "enqueueEvent error: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AccessibilityService interrupted.")
    }

    override fun onDestroy() {
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefsListener?.let { prefs.unregisterOnSharedPreferenceChangeListener(it) }
        instance = null
        super.onDestroy()
    }
}
