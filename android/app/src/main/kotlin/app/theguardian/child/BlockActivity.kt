package app.theguardian.child

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

class BlockActivity : Activity() {
    private var dismissReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        
        val layoutId = resources.getIdentifier("activity_block", "layout", packageName)
        if (layoutId != 0) {
            setContentView(layoutId)
        }

        val reason = intent.getStringExtra("BLOCK_REASON") 
            ?: "Cette application ou ce site est bloqué(e) par vos parents."
            
        val textId = resources.getIdentifier("block_reason_text", "id", packageName)
        if (textId != 0) {
            val textView = findViewById<TextView>(textId)
            textView?.text = reason
        }

        val buttonId = resources.getIdentifier("btn_back_to_home", "id", packageName)
        if (buttonId != 0) {
            val btn = findViewById<Button>(buttonId)
            btn?.setOnClickListener {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
                finish()
            }
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT
            ) {
                // Do nothing to prevent backing out
            }
        }

        dismissReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "app.theguardian.child.DISMISS_BLOCK") {
                    finish()
                }
            }
        }
        val filter = IntentFilter("app.theguardian.child.DISMISS_BLOCK")
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dismissReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(dismissReceiver, filter)
        }
    }

    override fun onDestroy() {
        dismissReceiver?.let {
            unregisterReceiver(it)
        }
        dismissReceiver = null
        super.onDestroy()
    }

    override fun onBackPressed() {
        // Do nothing to prevent backing out
    }
}
