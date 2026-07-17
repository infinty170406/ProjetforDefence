package app.theguardian.child

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import androidx.work.WorkManager
import android.content.pm.PackageManager
import android.os.PowerManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream
import org.json.JSONObject
import id.flutter.flutter_background_service.FlutterBackgroundServicePlugin

/**
 * MainActivity
 *
 * Deux canaux Flutter :
 *
 * 1. MethodChannel "app.theguardian.child/system"
 *    - openUsageAccessSettings  : ouvre les paramètres PACKAGE_USAGE_STATS
 *    - openAccessibilitySettings: ouvre les paramètres d'accessibilité
 *    - isAccessibilityEnabled   : retourne true/false
 *    - openOverlaySettings      : ouvre les paramètres d'overlay (SYSTEM_ALERT_WINDOW)
 *    - updateBlockedPackages    : met à jour la liste des packages bloqués dans
 *                                  GuardianAccessibilityService (List<String>)
 *
 * 2. EventChannel "app.theguardian.child/block_events"
 *    Stream unidirectionnel Android → Flutter.
 *    Émet un Map {"package": String, "reason": String} quand l'AccessibilityService
 *    détecte une app bloquée au premier plan.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GuardianWorker.scheduleIfNeeded(this)
        WatchdogReceiver.schedule(this)
        // FIX BUG #5: gérer un SHOW_BLOCK au cold start (AccessibilityService a lancé l'app)
        handleBlockIntent(intent)
        handleRestartIntent(intent)
    }

    // FIX BUG #5: gérer un SHOW_BLOCK quand l'app était déjà ouverte
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleBlockIntent(intent)
        handleRestartIntent(intent)
    }

    private fun handleRestartIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("RESTART_SERVICE", false) == true) {
            android.util.Log.i("MainActivity", "RESTART_SERVICE received, sending app to background")
            moveTaskToBack(true)
        }
    }

    private fun handleBlockIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("SHOW_BLOCK", false) == true) {
            val reason = intent.getStringExtra("BLOCK_REASON") ?: "Cette application est bloquée."
            val pkg    = intent.getStringExtra("BLOCK_PACKAGE") ?: ""
            android.util.Log.i("MainActivity", "SHOW_BLOCK received: $reason")

            // Toujours stocker en SharedPreferences (filet de sécurité)
            val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
            prefs.edit()
                .putString("flutter.guardian_pending_block", reason)
                .putString("flutter.guardian_pending_package", pkg)
                .apply()

            // Tenter la livraison immédiate si le sink est prêt
            val delivered = blockEventSink?.let {
                it.success(mapOf("package" to pkg, "reason" to reason))
                true
            } ?: false

            if (!delivered) {
                // Réessayer après 800ms (Flutter a le temps de monter)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    blockEventSink?.success(mapOf("package" to pkg, "reason" to reason))
                }, 800)
            }
        }
    }

    private val METHOD_CHANNEL    = "app.theguardian.child/system"
    private val EVENT_CHANNEL     = "app.theguardian.child/block_events"
    private val WEB_EVENT_CHANNEL = "app.theguardian.child/web_events"
    private val KEYWORD_EVENT_CHANNEL = "app.theguardian.child/keyword_events"
    private val FOREGROUND_EVENT_CHANNEL = "app.theguardian.child/foreground_events"

    private var blockEventSink: EventChannel.EventSink? = null
    private var blockReceiver: BroadcastReceiver? = null

    private var webEventSink: EventChannel.EventSink? = null
    private var webReceiver: BroadcastReceiver? = null

    private var keywordEventSink: EventChannel.EventSink? = null
    private var keywordReceiver: BroadcastReceiver? = null

    private var foregroundEventSink: EventChannel.EventSink? = null
    private var foregroundReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel ────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                        result.success(null)
                    }

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                        result.success(null)
                    }

                    "isAccessibilityEnabled" -> {
                        result.success(GuardianAccessibilityService.isEnabled(this))
                    }

                    "openOverlaySettings" -> {
                        startActivity(Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName")
                        ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) })
                        result.success(null)
                    }

                    /**
                     * Met à jour la liste des packages bloqués dans l'AccessibilityService.
                     * Appelé par EnforcementService chaque fois que les règles Firestore changent.
                     * Argument : List<String> packages
                     */
                    "updateBlockedPackages" -> {
                        @Suppress("UNCHECKED_CAST")
                        val packages = (call.arguments as? List<*>)
                            ?.filterIsInstance<String>()
                            ?.toSet()
                            ?: emptySet()
                        GuardianAccessibilityService.blockedPackages = packages
                        result.success(null)
                    }

                    "updateCustomKeywords" -> {
                        @Suppress("UNCHECKED_CAST")
                        val keywords = (call.arguments as? List<*>)
                            ?.filterIsInstance<String>()
                            ?.toSet()
                            ?: emptySet()
                        GuardianAccessibilityService.customKeywords = keywords
                        result.success(null)
                    }

                    "updateBlockedWebsites" -> {
                        @Suppress("UNCHECKED_CAST")
                        val websites = (call.arguments as? List<*>)
                            ?.filterIsInstance<String>()
                            ?.toSet()
                            ?: emptySet()
                        GuardianAccessibilityService.blockedWebsites = websites
                        result.success(null)
                    }

                    "bringToForeground" -> {
                        val intent = Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        startActivity(intent)
                        result.success(null)
                    }

                    "goHome" -> {
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(homeIntent)
                        result.success(null)
                    }

                    "makeEmergencyCall" -> {
                        val phoneNumber = call.argument<String>("phoneNumber") ?: "112"
                        val intent = Intent(Intent.ACTION_DIAL).apply {
                            data = android.net.Uri.parse("tel:$phoneNumber")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    }

                    "hasOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }

                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    }

                    "scheduleWatchdog" -> {
                        GuardianWorker.scheduleIfNeeded(this)
                        WatchdogReceiver.schedule(this)
                        result.success(null)
                    }

                    "getInstalledApps" -> {
                        Thread {
                            try {
                                val pm = packageManager
                                val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                                val appList = mutableListOf<Map<String, String>>()
                                
                                for (app in packages) {
                                    if (pm.getLaunchIntentForPackage(app.packageName) != null) {
                                        val iconBase64 = try {
                                            val icon = pm.getApplicationIcon(app.packageName)
                                            getIconBase64(icon)
                                        } catch (e: Exception) {
                                            ""
                                        }

                                        appList.add(mapOf(
                                            "packageName" to app.packageName,
                                            "appName" to pm.getApplicationLabel(app).toString(),
                                            "iconBase64" to iconBase64
                                        ))
                                    }
                                }
                                runOnUiThread {
                                    result.success(appList)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("GET_APPS_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }

        // ── EventChannel (Block Events) ──────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    blockEventSink = events
                    registerBlockReceiver()
                }
                override fun onCancel(arguments: Any?) {
                    blockEventSink = null
                    unregisterBlockReceiver()
                }
            })

        // ── EventChannel (Web Events) ──────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WEB_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    webEventSink = events
                    registerWebReceiver()
                }
                override fun onCancel(arguments: Any?) {
                    webEventSink = null
                    unregisterWebReceiver()
                }
            })

        // ── EventChannel (Keyword Events) ──────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, KEYWORD_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    keywordEventSink = events
                    registerKeywordReceiver()
                }
                override fun onCancel(arguments: Any?) {
                    keywordEventSink = null
                    unregisterKeywordReceiver()
                }
            })

        // ── EventChannel (Foreground Events) ──────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    foregroundEventSink = events
                    registerForegroundReceiver()
                }
                override fun onCancel(arguments: Any?) {
                    foregroundEventSink = null
                    unregisterForegroundReceiver()
                }
            })
    }

    private fun registerBlockReceiver() {
        blockReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != GuardianAccessibilityService.ACTION_BLOCK_APP) return
                val pkg    = intent.getStringExtra(GuardianAccessibilityService.EXTRA_PACKAGE) ?: return
                val reason = intent.getStringExtra(GuardianAccessibilityService.EXTRA_REASON) ?: ""
                blockEventSink?.success(mapOf("package" to pkg, "reason" to reason))
            }
        }
        registerReceiver(
            blockReceiver,
            IntentFilter(GuardianAccessibilityService.ACTION_BLOCK_APP),
            RECEIVER_NOT_EXPORTED
        )
    }

    private fun unregisterBlockReceiver() {
        blockReceiver?.let { unregisterReceiver(it) }
        blockReceiver = null
    }

    private fun registerWebReceiver() {
        webReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != GuardianAccessibilityService.ACTION_URL_DETECTED) return
                val url = intent.getStringExtra(GuardianAccessibilityService.EXTRA_URL) ?: return
                val pkg = intent.getStringExtra(GuardianAccessibilityService.EXTRA_URL_PACKAGE) ?: ""
                val searchQuery = intent.getStringExtra(GuardianAccessibilityService.EXTRA_SEARCH_QUERY)
                val title = intent.getStringExtra("title")
                val category = intent.getStringExtra("category")
                val riskLevel = intent.getStringExtra("risk_level")
                val isSiteBlocked = intent.getBooleanExtra("is_site_blocked", false)
                val isWordBlocked = intent.getBooleanExtra("is_word_blocked", false)
                val status = intent.getStringExtra("status")
                val date = intent.getStringExtra("date")
                val time = intent.getStringExtra("time")
                
                val eventMap = mutableMapOf<String, Any>("url" to url, "package" to pkg)
                if (searchQuery != null) {
                    eventMap["searchQuery"] = searchQuery
                }
                if (title != null) eventMap["title"] = title
                if (category != null) eventMap["category"] = category
                if (riskLevel != null) eventMap["riskLevel"] = riskLevel
                eventMap["isSiteBlocked"] = isSiteBlocked
                eventMap["isWordBlocked"] = isWordBlocked
                if (status != null) eventMap["status"] = status
                if (date != null) eventMap["date"] = date
                if (time != null) eventMap["time"] = time
                
                // 1. Envoyer à l'UI si elle est ouverte
                webEventSink?.success(eventMap)
                
                // 2. Envoyer au service de background (Isolate séparé)
                eventMap["action"] = "web_event"
                sendDataToBackground(context, eventMap)
            }
        }
        registerReceiver(
            webReceiver,
            IntentFilter(GuardianAccessibilityService.ACTION_URL_DETECTED),
            RECEIVER_NOT_EXPORTED
        )
    }

    private fun unregisterWebReceiver() {
        webReceiver?.let { unregisterReceiver(it) }
        webReceiver = null
    }

    private fun registerKeywordReceiver() {
        keywordReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != GuardianAccessibilityService.ACTION_KEYWORD_DETECTED) return
                val keyword = intent.getStringExtra(GuardianAccessibilityService.EXTRA_KEYWORD) ?: return
                val pkg     = intent.getStringExtra(GuardianAccessibilityService.EXTRA_KEYWORD_PACKAGE) ?: ""
                
                // 1. Envoyer à l'UI 
                keywordEventSink?.success(mapOf("keyword" to keyword, "package" to pkg))

                // 2. Envoyer au service de background
                sendDataToBackground(context, mapOf(
                    "action" to "keyword_event",
                    "keyword" to keyword,
                    "package" to pkg
                ))
            }
        }
        registerReceiver(
            keywordReceiver,
            IntentFilter(GuardianAccessibilityService.ACTION_KEYWORD_DETECTED),
            RECEIVER_NOT_EXPORTED
        )
    }

    private fun unregisterKeywordReceiver() {
        keywordReceiver?.let { unregisterReceiver(it) }
        keywordReceiver = null
    }

    private fun registerForegroundReceiver() {
        foregroundReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != GuardianAccessibilityService.ACTION_FOREGROUND_CHANGED) return
                val pkg = intent.getStringExtra(GuardianAccessibilityService.EXTRA_FOREGROUND_PACKAGE) ?: return
                
                foregroundEventSink?.success(mapOf("package" to pkg))
                
                sendDataToBackground(context, mapOf(
                    "action" to "foreground_event",
                    "package" to pkg
                ))
            }
        }
        registerReceiver(
            foregroundReceiver,
            IntentFilter(GuardianAccessibilityService.ACTION_FOREGROUND_CHANGED),
            RECEIVER_NOT_EXPORTED
        )
    }

    private fun unregisterForegroundReceiver() {
        foregroundReceiver?.let { unregisterReceiver(it) }
        foregroundReceiver = null
    }

    override fun onDestroy() {
        unregisterBlockReceiver()
        unregisterWebReceiver()
        unregisterKeywordReceiver()
        unregisterForegroundReceiver()
        super.onDestroy()
    }

    private fun sendDataToBackground(context: Context, data: Map<String, Any>) {
        try {
            val action = data["action"] as? String ?: return
            val args = JSONObject()
            for ((key, value) in data) {
                if (key != "action") {
                    args.put(key, value)
                }
            }
            val json = JSONObject().apply {
                put("method", action)
                put("args", args)
            }
            FlutterBackgroundServicePlugin.servicePipe.invoke(json)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getIconBase64(drawable: Drawable): String {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 1
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 1
            val b = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(b)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            b
        }

        // Redimensionnement en 64x64 pour optimiser l'espace Firestore
        val scaledBitmap = Bitmap.createScaledBitmap(bitmap, 64, 64, true)
        val out = ByteArrayOutputStream()
        scaledBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        val bytes = out.toByteArray()
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }
}
