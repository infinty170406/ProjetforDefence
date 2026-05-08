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
    }

    private val METHOD_CHANNEL    = "app.theguardian.child/system"
    private val EVENT_CHANNEL     = "app.theguardian.child/block_events"
    private val WEB_EVENT_CHANNEL = "app.theguardian.child/web_events"
    private val KEYWORD_EVENT_CHANNEL = "app.theguardian.child/keyword_events"

    private var blockEventSink: EventChannel.EventSink? = null
    private var blockReceiver: BroadcastReceiver? = null

    private var webEventSink: EventChannel.EventSink? = null
    private var webReceiver: BroadcastReceiver? = null

    private var keywordEventSink: EventChannel.EventSink? = null
    private var keywordReceiver: BroadcastReceiver? = null

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

                    "bringToForeground" -> {
                        val intent = Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
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
                        result.success(appList)
                    }

                    "startVpn" -> {
                        val vpnIntent = android.net.VpnService.prepare(this@MainActivity)
                        if (vpnIntent != null) {
                            startActivityForResult(vpnIntent, 100)
                        } else {
                            val intent = Intent(this@MainActivity, GuardianVpnService::class.java).apply {
                                action = GuardianVpnService.ACTION_START
                            }
                            startService(intent)
                        }
                        result.success(null)
                    }

                    "stopVpn" -> {
                        val intent = Intent(this@MainActivity, GuardianVpnService::class.java).apply {
                            action = GuardianVpnService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
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
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 100 && resultCode == android.app.Activity.RESULT_OK) {
            val intent = Intent(this, GuardianVpnService::class.java).apply {
                action = GuardianVpnService.ACTION_START
            }
            startService(intent)
        }
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
                
                // 1. Envoyer à l'UI si elle est ouverte
                webEventSink?.success(mapOf("url" to url, "package" to pkg))
                
                // 2. Envoyer au service de background (Isolate séparé)
                // C'est ici que réside la logique EnforcementService
                sendDataToBackground(context, mapOf(
                    "action" to "web_event",
                    "url" to url,
                    "package" to pkg
                ))
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

    override fun onDestroy() {
        unregisterBlockReceiver()
        unregisterWebReceiver()
        unregisterKeywordReceiver()
        super.onDestroy()
    }

    private fun sendDataToBackground(context: Context, data: Map<String, Any>) {
        try {
            val pref = context.getSharedPreferences("id.flutter.background_service", Context.MODE_PRIVATE)
            val json = JSONObject(data).toString()
            pref.edit().putString("data", json).apply()

            val intent = Intent("id.flutter.background_service.DATA_CHANGED")
            intent.setPackage(context.packageName)
            context.sendBroadcast(intent)
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
