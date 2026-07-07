package com.example.virt

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.window.OnBackInvokedDispatcher

class BlockActivity : Activity() {

    private var backCallback: android.window.OnBackInvokedCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backCallback = android.window.OnBackInvokedCallback {
                // Consommer le retour — l'enfant ne peut pas quitter l'écran de blocage.
            }
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                backCallback!!
            )
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Ne rien faire — empêche le retour sur Android < 13.
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backCallback?.let {
                onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it)
            }
        }
        super.onDestroy()
    }
}
