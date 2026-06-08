package com.example.virt

import android.app.Activity
import android.os.Bundle
import android.window.OnBackInvokedDispatcher

class BlockActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)
    }

    override fun onBackPressed() {
        // Do nothing to prevent backing out of the block screen
        // In Android 13+, onBackPressed is deprecated, so we also need OnBackInvokedCallback
    }
}
