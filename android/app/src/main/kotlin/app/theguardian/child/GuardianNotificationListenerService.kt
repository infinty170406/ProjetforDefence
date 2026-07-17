package app.theguardian.child

import android.content.Context
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import android.util.LruCache
import kotlinx.coroutines.*
import org.json.JSONArray

class GuardianNotificationListenerService : NotificationListenerService() {

    private val serviceScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val memoryCache = LruCache<String, GeminiAnalysisResult>(100)

    companion object {
        private const val TAG = "NotificationListener"
        private const val DUPLICATE_CACHE_AGE_MS = 5 * 60 * 1000L // 5 minutes

        private val DEFAULT_MONITORED_PACKAGES = setOf(
            "com.whatsapp",
            "com.instagram.android",
            "com.snapchat.android",
            "com.facebook.orca", // Messenger
            "com.facebook.katana", // Facebook
            "com.zhiliaoapp.musically", // TikTok
            "com.tiktok",
            "com.twitter.android",
            "org.telegram.messenger",
            "com.google.android.apps.messaging", // Google Messages (SMS)
            "com.android.mms", // Default SMS
            "com.discord" // Discord
        )
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "GuardianNotificationListenerService created.")
    }

    override fun onDestroy() {
        serviceScope.cancel()
        super.onDestroy()
        Log.i(TAG, "GuardianNotificationListenerService destroyed.")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!isAccountMonitoringEnabled()) return

        val packageName = sbn.packageName

        // 1. Filtrer les applications surveillées choisies par le parent (Étape 1)
        val monitored = getMonitoredPackages()
        if (!monitored.contains(packageName)) {
            return
        }

        // 2. Récupérer l'importance de la notification
        val importance = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ranking = Ranking()
            if (currentRanking.getRanking(sbn.key, ranking)) {
                ranking.importance
            } else {
                3 // DEFAULT
            }
        } else {
            3
        }

        // 3. Extraction (Étape 2)
        val extracted = NotificationExtractor.extract(this, sbn, importance)
        if (extracted.isIgnored) {
            return
        }

        // 4. Lancement de la coroutine d'analyse
        serviceScope.launch {
            processNotification(extracted, sbn)
        }
    }

    private suspend fun processNotification(extracted: ExtractedNotification, sbn: StatusBarNotification) {
        val cacheKey = "${extracted.packageName}:${extracted.sender}:${extracted.messageText}"

        // A. Vérifier le cache mémoire (Étape 10 : Optimisations)
        var analysisResult = memoryCache.get(cacheKey)
        if (analysisResult != null) {
            Log.d(TAG, "Found notification result in memory cache.")
            applyDecision(extracted, sbn, analysisResult)
            return
        }

        // B. Vérifier le cache persistant SQLite (Étape 10 : Optimisations)
        val dbDuplicate = withContext(Dispatchers.IO) {
            NotificationHistoryRepository.findRecentDuplicate(
                applicationContext,
                extracted.packageName,
                extracted.sender,
                extracted.messageText,
                DUPLICATE_CACHE_AGE_MS
            )
        }
        if (dbDuplicate != null) {
            Log.d(TAG, "Found notification result in database cache.")
            analysisResult = GeminiAnalysisResult(
                risk = dbDuplicate.riskLevel,
                score = dbDuplicate.score,
                category = dbDuplicate.geminiCategory,
                blocked = dbDuplicate.decision == NotificationDecision.DISMISS.name || dbDuplicate.decision == NotificationDecision.BLOCK_AND_ALERT.name,
                confidence = 1.0,
                reason = dbDuplicate.reason
            )
            memoryCache.put(cacheKey, analysisResult)
            applyDecision(extracted, sbn, analysisResult)
            return
        }

        // C. Appeler l'analyse de l'API Gemini (Étape 3)
        Log.i(TAG, "Analyzing a new notification through the authenticated backend.")
        analysisResult = GeminiNotificationAnalyzer.analyze(applicationContext, extracted)

        // D. Sauvegarder dans le cache mémoire
        memoryCache.put(cacheKey, analysisResult)

        // E. Appliquer la décision (Étape 4 et 5)
        applyDecision(extracted, sbn, analysisResult)
    }

    private fun applyDecision(
        extracted: ExtractedNotification,
        sbn: StatusBarNotification,
        result: GeminiAnalysisResult
    ) {
        // Évaluation du risque (Étape 4)
        val decision = NotificationRiskEngine.evaluate(result)
        Log.d(TAG, "Notification evaluation: risk=${result.risk} decision=$decision")

        // Exécution de l'action de blocage / suppression (Étape 5)
        if (decision == NotificationDecision.DISMISS || decision == NotificationDecision.BLOCK_AND_ALERT) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    cancelNotification(sbn.key)
                    Log.i(TAG, "Notification canceled after a ${result.category} risk decision.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel notification: ${e.message}")
            }
        }

        // Enregistrement historique + Alerte parent (Étape 5 et 6)
        NotificationRiskEngine.processDecision(applicationContext, extracted, result, decision)
    }


    private fun isAccountMonitoringEnabled(): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return when {
            prefs.contains("flutter.guardian_monitor_account_activity") ->
                prefs.getBoolean("flutter.guardian_monitor_account_activity", false)
            prefs.contains("guardian_monitor_account_activity") ->
                prefs.getBoolean("guardian_monitor_account_activity", false)
            else -> false
        }
    }

    private fun getMonitoredPackages(): Set<String> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("monitored_notification_packages", null)
            ?: prefs.getString("flutter.monitored_notification_packages", null)
        if (raw.isNullOrBlank()) {
            return DEFAULT_MONITORED_PACKAGES
        }
        return try {
            val array = JSONArray(raw)
            val set = mutableSetOf<String>()
            for (i in 0 until array.length()) {
                set.add(array.getString(i))
            }
            set
        } catch (e: Exception) {
            raw.split(",")
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .toSet()
                .ifEmpty { DEFAULT_MONITORED_PACKAGES }
        }
    }
}
