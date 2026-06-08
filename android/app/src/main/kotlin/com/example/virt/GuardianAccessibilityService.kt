package com.example.virt

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

import android.content.SharedPreferences
import android.view.accessibility.AccessibilityNodeInfo

class GuardianAccessibilityService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {

    private val TAG = "GuardianAccessService"
    private var blockedApps: List<String> = listOf()
    private var blockedUrls: List<String> = listOf()
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
        Log.d(TAG, "Cache updated: \$blockedApps, \$blockedUrls")
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
            Log.d(TAG, "Blocking app: \$packageName")
            showBlockScreen()
            return
        }

        // 3. Web Filtering
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED || 
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            // Supported browsers
            if (packageName == "com.android.chrome" || 
                packageName == "com.sec.android.app.sbrowser" || 
                packageName == "org.mozilla.firefox") {
                
                val url = extractUrlFromNode(event.source)
                if (url != null) {
                    val isBlocked = blockedUrls.any { blocked -> url.contains(blocked, ignoreCase = true) }
                    if (isBlocked) {
                        Log.d(TAG, "Blocking URL: \$url")
                        showBlockScreen()
                    }
                }
            }
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
