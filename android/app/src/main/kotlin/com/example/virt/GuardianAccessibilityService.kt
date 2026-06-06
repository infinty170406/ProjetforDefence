package com.example.virt

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class GuardianAccessibilityService : AccessibilityService() {

    private val TAG = "GuardianAccessService"

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }

        val packageName = event.packageName?.toString() ?: return
        Log.d(TAG, "Package opened: \$packageName")

        val prefs = getSharedPreferences("GuardianPrefs", Context.MODE_PRIVATE)
        val blockedAppsString = prefs.getString("blocked_apps", "") ?: ""
        val blockedApps = blockedAppsString.split(",").filter { it.isNotEmpty() }

        if (blockedApps.contains(packageName)) {
            Log.d(TAG, "Blocking package: \$packageName")
            
            // Redirect to home screen
            performGlobalAction(GLOBAL_ACTION_HOME)
            
            // Alternatively, start a blocking activity:
            // val intent = Intent(this, MainActivity::class.java).apply {
            //     flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            //     putExtra("block_reason", "Cette application est bloquée par tes parents.")
            // }
            // startActivity(intent)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service Connected")
    }
}
