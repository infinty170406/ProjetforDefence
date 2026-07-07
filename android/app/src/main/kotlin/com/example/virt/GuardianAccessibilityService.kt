package com.example.virt

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityNodeInfo
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FieldValue

class GuardianAccessibilityService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {

    private val TAG = "GuardianAccessService"
    private var lastRecordedUrl: String = ""
    private var lastRecordedTime: Long = 0
    private var blockedApps: List<String> = listOf()
    private var blockedUrls: List<String> = listOf()
    private var blockedKeywords: List<String> = listOf()
    private lateinit var prefs: SharedPreferences

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service Connected")
        prefs = getSharedPreferences("GuardianPrefs", Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(this)
        updateCache()
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        updateCache()
    }

    private fun updateCache() {
        val appsString = prefs.getString("blocked_apps", "") ?: ""
        blockedApps = appsString.split(",").filter { it.isNotEmpty() }
        
        val urlsString = prefs.getString("blocked_urls", "") ?: ""
        blockedUrls = urlsString.split(",").filter { it.isNotEmpty() }

        val keywordsString = prefs.getString("blocked_keywords", "") ?: ""
        blockedKeywords = keywordsString.split(",").filter { it.isNotEmpty() }

        Log.d(TAG, "Cache updated: apps=$blockedApps, urls=$blockedUrls, keywords=$blockedKeywords")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return

        // 1. Anti-Bypass (Self-Protection)
        if (packageName == "com.android.settings") {
            val textNodes = mutableListOf<String>()
            extractTextFromNode(event.source, textNodes)
            val settingsText = textNodes.joinToString(" ").lowercase()
            if (settingsText.contains("accessibilité") || settingsText.contains("accessibility") || 
                settingsText.contains("device admin") || settingsText.contains("administration")) {
                Log.d(TAG, "Blocking Settings Anti-Bypass")
                showBlockScreen()
                return
            }
        }

        // 2. App Blocking
        if (blockedApps.contains(packageName)) {
            Log.d(TAG, "Blocking app: $packageName")
            showBlockScreen()
            return
        }

        // 2b. Mots-clés personnalisés (frappe ou contenu affiché)
        if (blockedKeywords.isNotEmpty()) {
            if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
                val text = event.text?.joinToString(" ")?.lowercase() ?: ""
                if (text.isNotEmpty() && blockedKeywords.any { text.contains(it.lowercase()) }) {
                    Log.d(TAG, "Blocking keyword in $packageName")
                    showBlockScreen()
                    return
                }
            } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                val textNodes = mutableListOf<String>()
                extractTextFromNode(event.source, textNodes)
                val screenText = textNodes.joinToString(" ").lowercase()
                if (blockedKeywords.any { screenText.contains(it.lowercase()) }) {
                    Log.d(TAG, "Blocking keyword on screen in $packageName")
                    showBlockScreen()
                    return
                }
            }
        }

        // 3. Web Filtering
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED || 
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            // Supported browsers
            if (packageName == "com.android.chrome" || 
                packageName == "com.sec.android.app.sbrowser" || 
                packageName == "org.mozilla.firefox") {
                
                val url = extractUrlFromNode(event.source)
                if (url != null && url.isNotEmpty() && !url.contains(" ")) {
                    val isBlocked = blockedUrls.any { blocked -> url.contains(blocked, ignoreCase = true) }
                    if (isBlocked) {
                        Log.d(TAG, "Blocking URL: $url")
                        showBlockScreen()
                    } else {
                        logUrlToFirestore(url)
                    }
                }
            }
        }
    }

    private fun logUrlToFirestore(url: String) {
        val currentTime = System.currentTimeMillis()
        if (url == lastRecordedUrl && (currentTime - lastRecordedTime) < 10000) {
            return // Skip duplicate
        }
        
        lastRecordedUrl = url
        lastRecordedTime = currentTime

        try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val parentId = flutterPrefs.getString("flutter.parent_id", null)
            val childId = flutterPrefs.getString("flutter.child_id", null)

            if (parentId.isNullOrEmpty() || childId.isNullOrEmpty()) {
                Log.e(TAG, "Missing parent/child IDs in SharedPreferences.")
                return
            }

            val db = FirebaseFirestore.getInstance()
            val historyRef = db.collection("parents").document(parentId)
                .collection("children").document(childId)
                .collection("inventory").document("websites")
                .collection("history")

            val data = hashMapOf(
                "url" to url,
                "title" to "Website",
                "timestamp" to FieldValue.serverTimestamp()
            )

            historyRef.add(data)
                .addOnSuccessListener { Log.d(TAG, "Successfully logged URL to Firestore: $url") }
                .addOnFailureListener { e -> Log.e(TAG, "Failed to log URL", e) }
                
        } catch (e: Exception) {
            Log.e(TAG, "Error logging URL to Firestore", e)
        }
    }

    private fun showBlockScreen() {
        val intent = Intent(this, BlockActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(intent)
    }

    private fun extractUrlFromNode(nodeInfo: AccessibilityNodeInfo?): String? {
        if (nodeInfo == null) return null

        if (nodeInfo.viewIdResourceName != null) {
            val viewId = nodeInfo.viewIdResourceName
            if (viewId == "com.android.chrome:id/url_bar" ||
                viewId == "com.sec.android.app.sbrowser:id/location_bar_edit_text" ||
                viewId == "org.mozilla.firefox:id/mozac_browser_toolbar_url_view") {
                return nodeInfo.text?.toString()
            }
        }

        for (i in 0 until nodeInfo.childCount) {
            val childNode = nodeInfo.getChild(i)
            val url = extractUrlFromNode(childNode)
            if (url != null) return url
        }
        return null
    }

    private fun extractTextFromNode(nodeInfo: AccessibilityNodeInfo?, textList: MutableList<String>) {
        if (nodeInfo == null) return
        if (nodeInfo.text != null) {
            textList.add(nodeInfo.text.toString())
        }
        for (i in 0 until nodeInfo.childCount) {
            extractTextFromNode(nodeInfo.getChild(i), textList)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::prefs.isInitialized) {
            prefs.unregisterOnSharedPreferenceChangeListener(this)
        }
    }
}
