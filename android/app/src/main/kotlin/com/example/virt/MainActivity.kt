package com.example.virt

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.guardian.native/control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                "startForegroundService" -> {
                    startGuardianForegroundService()
                    result.success(null)
                }
                "checkPermissions" -> {
                    // Logic to check if accessibility and device admin are granted
                    result.success(mapOf(
                        "accessibility" to true, // Placeholder
                        "deviceAdmin" to true    // Placeholder
                    ))
                }
                "requestDeviceAdmin" -> {
                    // Logic to request device admin
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun updateBlockedApps(apps: List<String>) {
        val prefs = getSharedPreferences("GuardianPrefs", Context.MODE_PRIVATE)
        prefs.edit().putString("blocked_apps", apps.joinToString(",")).apply()
    }

    private fun updateBlockedWebsites(websites: List<String>) {
        val prefs = getSharedPreferences("GuardianPrefs", Context.MODE_PRIVATE)
        prefs.edit().putString("blocked_urls", websites.joinToString(",")).apply()
    }

    private fun startGuardianForegroundService() {
        val serviceIntent = Intent(this, GuardianForegroundService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
}
