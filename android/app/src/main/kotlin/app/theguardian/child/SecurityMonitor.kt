package app.theguardian.child

import android.content.Context
import android.os.UserManager
import android.provider.Settings
import android.util.Log
import org.json.JSONObject

/**
 * Surveille la sécurité de l'application et détecte les tentatives de contournement.
 * Détecte le Safe Mode, le multi-utilisateur, le clonage d'applications,
 * la perte de permissions (superposition/overlay) et les tentatives de désinstallation.
 */
class SecurityMonitor(private val context: Context) {

    companion object {
        private const val TAG = "SecurityMonitor"
    }

    /**
     * Effectue un audit complet des paramètres de sécurité de l'appareil
     * et génère des alertes en cas de tentative de contournement.
     */
    fun auditSecurity(): Map<String, Any> {
        val results = mutableMapOf<String, Any>()
        
        // 1. Détection du Safe Mode
        val isSafeMode = context.packageManager.isSafeMode
        results["safe_mode"] = isSafeMode
        if (isSafeMode) {
            triggerSecurityAlert("Safe Mode détecté : L'appareil a démarré en mode sans échec.")
        }

        // 2. Détection du Multi-Utilisateur / Profil Invité
        try {
            val userManager = context.getSystemService(Context.USER_SERVICE) as UserManager
            val isSystemUser = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                userManager.isSystemUser
            } else {
                true
            }
            results["is_system_user"] = isSystemUser
            if (!isSystemUser) {
                triggerSecurityAlert("Profil invité ou utilisateur secondaire actif sur l'appareil.")
            }
        } catch (e: Exception) {
            try {
                Log.e(TAG, "Error checking user manager", e)
            } catch (t: Throwable) {
                println("[$TAG] Error checking user manager: ${e.message}")
            }
        }

        // 3. Détection du clonage d'application / Dual Apps
        val isCloned = checkAppCloning()
        results["app_cloned"] = isCloned
        if (isCloned) {
            triggerSecurityAlert("Tentative de clonage de l'application Guardian détectée.")
        }

        // 4. Détection de la perte de la permission de superposition (Draw Overlay)
        try {
            val hasOverlayPermission = Settings.canDrawOverlays(context)
            results["has_overlay_permission"] = hasOverlayPermission
            if (!hasOverlayPermission) {
                triggerSecurityAlert("La permission de superposition d'écran a été retirée.")
            }
        } catch (e: Exception) {
            try {
                Log.e(TAG, "Error checking overlay permission", e)
            } catch (t: Throwable) {
                println("[$TAG] Error checking overlay permission: ${e.message}")
            }
        }

        return results
    }

    private fun checkAppCloning(): Boolean {
        val appPath = context.filesDir.absolutePath
        return appPath.contains("/999/") || appPath.contains("/parallel/") || appPath.contains("/dual/")
    }

    /**
     * Enregistre l'alerte de sécurité dans les SharedPreferences locales
     * afin de la synchroniser avec Firebase.
     */
    fun triggerSecurityAlert(description: String) {
        try {
            Log.w(TAG, "SECURITY ALERT: $description")
        } catch (t: Throwable) {
            println("[$TAG] SECURITY ALERT: $description")
        }
        
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val obj = JSONObject().apply {
                put("action", "security_alert")
                put("ts", System.currentTimeMillis())
                put("description", description)
                put("type", "Bypass Attempt")
            }
            val key = "flutter.guardian_event_${System.currentTimeMillis()}_${(Math.random() * 1000).toInt()}"
            prefs.edit().putString(key, obj.toString()).apply()
        } catch (e: Exception) {
            try {
                Log.e(TAG, "Failed to record security alert", e)
            } catch (t: Throwable) {
                println("[$TAG] Failed to record security alert: ${e.message}")
            }
        }
    }
}
