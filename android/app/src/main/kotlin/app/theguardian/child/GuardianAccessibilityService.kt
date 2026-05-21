package app.theguardian.child

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.WindowManager
import android.view.View
import android.view.Gravity
import android.graphics.PixelFormat
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Button
import android.graphics.Color
import android.graphics.Typeface

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
        const val EXTRA_KEYWORD    = "detected_keyword"
        const val EXTRA_KEYWORD_PACKAGE = "keyword_package"
        const val OWN_PACKAGE      = "app.theguardian.child"

        // Instance statique pour permettre la mise à jour depuis Flutter
        var instance: GuardianAccessibilityService? = null
            private set

        // Packages bloqués — mis à jour en temps réel depuis EnforcementService
        @Volatile var blockedPackages: Set<String> = emptySet()

        // Mots-clés personnalisés
        @Volatile var customKeywords: Set<String> = emptySet()

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

    // Overlay Window properties
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        serviceInfo = serviceInfo.apply {
            eventTypes    = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                            AccessibilityEvent.TYPE_VIEW_SCROLLED
            feedbackType  = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags         = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                            AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        Log.i(TAG, "AccessibilityService connected — ready to enforce and filter web.")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        // Ne jamais se bloquer soi-même
        if (pkg == OWN_PACKAGE || pkg.startsWith("com.android.systemui")) {
            hideOverlay()
            return
        }

        // 1. Détection de package bloqué (Apps) - instantané sur n'importe quel événement
        if (blockedPackages.contains(pkg)) {
            blockApp(pkg)
            return
        } else {
            if (pkg != OWN_PACKAGE) {
                hideOverlay()
            }
        }

        // 2. Détection d'URL (Web Filtering)
        if (BROWSER_PACKAGES.contains(pkg)) {
            val rootNode = rootInActiveWindow ?: return
            val url = findUrlInNode(rootNode, pkg)
            if (url != null) {
                Log.d(TAG, "Detected URL in $pkg: $url")
                broadcastUrl(url, pkg)
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

    private fun blockApp(pkg: String) {
        Log.i(TAG, "Blocked app detected at foreground: $pkg. Showing Overlay.")
        
        showOverlay("Application bloquée")
        
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        
        val intent = Intent(ACTION_BLOCK_APP).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_PACKAGE, pkg)
            putExtra(EXTRA_REASON, "Cette application est bloquée par vos parents.")
        }
        sendBroadcast(intent)
    }

    private fun showOverlay(reason: String) {
        if (isOverlayShowing) return
        
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#E53935"))
            gravity = Gravity.CENTER
            setPadding(64, 64, 64, 64)
        }

        val title = TextView(this).apply {
            text = "Accès Restreint"
            textSize = 32f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setTypeface(null, Typeface.BOLD)
        }

        val message = TextView(this).apply {
            text = reason
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 64)
        }

        val homeButton = Button(this).apply {
            text = "Retour à l'accueil"
            setBackgroundColor(Color.WHITE)
            setTextColor(Color.parseColor("#E53935"))
            setOnClickListener {
                hideOverlay()
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            }
        }

        layout.addView(title)
        layout.addView(message)
        layout.addView(homeButton)

        overlayView = layout

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager?.addView(overlayView, params)
            isOverlayShowing = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlay", e)
        }
    }

    private fun hideOverlay() {
        if (!isOverlayShowing) return
        try {
            windowManager?.removeView(overlayView)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove overlay", e)
        }
        isOverlayShowing = false
        overlayView = null
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
    }

    private fun broadcastUrl(url: String, pkg: String) {
        val intent = Intent(ACTION_URL_DETECTED).apply {
            setPackage(OWN_PACKAGE)
            putExtra(EXTRA_URL, url)
            putExtra(EXTRA_URL_PACKAGE, pkg)
        }
        sendBroadcast(intent)
    }

    override fun onInterrupt() {
        Log.w(TAG, "AccessibilityService interrupted.")
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
