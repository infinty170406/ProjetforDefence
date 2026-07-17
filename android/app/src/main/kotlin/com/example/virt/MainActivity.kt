package com.example.virt

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.guardian.native/control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateBlockedAppsList" -> {
                        val apps = call.argument<List<String>>("apps") ?: listOf()
                        updateBlockedApps(apps)
                        result.success(null)
                    }
                    "updateBlockedWebsites" -> {
                        val websites = call.argument<List<String>>("websites") ?: listOf()
                        updateBlockedWebsites(websites)
                        result.success(null)
                    }
                    "updateCustomKeywords" -> {
                        val keywords = call.argument<List<String>>("keywords") ?: listOf()
                        updateCustomKeywords(keywords)
                        result.success(null)
                    }
                    "updateDeviceLock" -> {
                        val locked = call.argument<Boolean>("locked") ?: false
                        updateDeviceLock(locked)
                        result.success(null)
                    }
                    "startForegroundService" -> {
                        startGuardianForegroundService()
                        result.success(null)
                    }
                    "checkPermissions" -> {
                        result.success(
                            mapOf(
                                "accessibility" to isAccessibilityEnabled(),
                                "deviceAdmin" to isDeviceAdminActive()
                            )
                        )
                    }
                    "requestDeviceAdmin" -> {
                        requestDeviceAdmin()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun guardianPrefs() =
        getSharedPreferences("GuardianPrefs", Context.MODE_PRIVATE)

    private fun updateDeviceLock(locked: Boolean) {
        guardianPrefs().edit()
            .putBoolean("device_locked", locked)
            .apply()
    }

    private fun updateBlockedApps(apps: List<String>) {
        guardianPrefs().edit()
            .putString("blocked_apps", apps.joinToString(","))
            .apply()
    }

    private fun updateBlockedWebsites(websites: List<String>) {
        guardianPrefs().edit()
            .putString("blocked_urls", websites.joinToString(","))
            .apply()
    }

    private fun updateCustomKeywords(keywords: List<String>) {
        guardianPrefs().edit()
            .putString("blocked_keywords", keywords.joinToString(","))
            .apply()
    }

    private fun startGuardianForegroundService() {
        try {
            val serviceIntent = Intent(this, GuardianForegroundService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = ComponentName(
            packageName,
            "$packageName.GuardianAccessibilityService"
        ).flattenToString()
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return TextUtils.SimpleStringSplitter(':')
            .also { it.setString(enabled) }
            .any { it.equals(expected, ignoreCase = true) }
    }

    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(this, GuardianDeviceAdminReceiver::class.java)
        return dpm.isAdminActive(admin)
    }

    private fun requestDeviceAdmin() {
        val admin = ComponentName(this, GuardianDeviceAdminReceiver::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, admin)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "The Guardian a besoin de cette permission pour protéger l'appareil."
            )
        }
        startActivity(intent)
    }
}
