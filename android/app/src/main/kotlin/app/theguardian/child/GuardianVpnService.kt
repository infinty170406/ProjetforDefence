package app.theguardian.child

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import kotlin.concurrent.thread

/**
 * GuardianVpnService
 * 
 * DEPRECATED: Web filtering is now handled by GuardianAccessibilityService
 * to avoid cutting the internet connection on the child's device.
 */
class GuardianVpnService : VpnService() {

    companion object {
        const val ACTION_START = "app.theguardian.child.START_VPN"
        const val ACTION_STOP = "app.theguardian.child.STOP_VPN"
        private const val TAG = "GuardianVpn"
        
        var isRunning = false
            private set
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_START) {
            startVpn()
        } else if (action == ACTION_STOP) {
            stopVpn()
        }
        return START_STICKY
    }

    private fun startVpn() {
        if (vpnInterface != null) return

        try {
            val builder = Builder()
            builder.addAddress("10.0.0.2", 32)
            // builder.addRoute("0.0.0.0", 0) // COMMENTÉ : Évite de couper tout internet car le tunnel n'est pas encore un relais complet
            builder.addDnsServer("8.8.8.8")
            builder.setSession("Guardian DNS Filter")
            builder.setBlocking(true)

            vpnInterface = builder.establish()
            isRunning = true

            Log.i(TAG, "VPN Started")

            vpnThread = thread {
                runVpnTunnel()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN", e)
            stopVpn()
        }
    }

    private fun runVpnTunnel() {
        val vpnFileDescriptor = vpnInterface?.fileDescriptor ?: return
        val inputStream = FileInputStream(vpnFileDescriptor)
        val outputStream = FileOutputStream(vpnFileDescriptor)
        val packet = ByteBuffer.allocate(32767)

        try {
            while (isRunning && !Thread.interrupted()) {
                val length = inputStream.read(packet.array())
                if (length > 0) {
                    // TODO: Un parseur TCP/IP complet (ex: lwip ou tun2socks) est nécessaire
                    // pour analyser les paquets DNS (UDP 53) et bloquer les requêtes
                    // contenant les domaines interdits, tout en relayant le reste du trafic.
                    
                    // Pour le moment, l'implémentation basique drop tous les paquets
                    // ce qui coupe internet (effet de blocage absolu).
                    packet.clear()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "VPN Tunnel error", e)
        } finally {
            try { inputStream.close() } catch (e: Exception) {}
            try { outputStream.close() } catch (e: Exception) {}
        }
    }

    private fun stopVpn() {
        isRunning = false
        vpnThread?.interrupt()
        vpnThread = null
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to close VPN interface", e)
        }
        vpnInterface = null
        Log.i(TAG, "VPN Stopped")
        stopSelf()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
