package app.theguardian.child

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver
 *
 * Reçoit BOOT_COMPLETED et MY_PACKAGE_REPLACED pour relancer automatiquement
 * le foreground service de Guardian au démarrage de l'appareil ou après une
 * mise à jour de l'app.
 *
 * Flutter (flutter_background_service) est configuré avec autoStart: true,
 * mais ce receiver garantit le redémarrage même si Flutter ne l'a pas déjà fait.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GuardianBoot"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            Log.i(TAG, "Boot/update received — starting Guardian background service.")
            // flutter_background_service gère son propre démarrage via autoStart,
            // mais on peut lancer MainActivity en arrière-plan pour initialiser Flutter.
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
            if (launchIntent != null) {
                context.startActivity(launchIntent)
            }
        }
    }
}
