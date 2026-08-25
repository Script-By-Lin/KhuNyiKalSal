package com.khunyikalsal.khu_nyi_kal_sal

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.khunyikalsal/emergency_trigger"
    private var methodChannel: MethodChannel? = null

    // Hardware button click counter for triple-click emergency trigger
    private var keyPressCount = 0
    private var lastKeyPressTime: Long = 0
    private val TRIPLE_CLICK_INTERVAL_MS: Long = 1500

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "ping") {
                result.success("pong")
            } else {
                result.notImplemented()
            }
        }
        // Check if started from App Shortcut intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if ("com.khunyikalsal.ACTION_QUICK_SOS" == action) {
            methodChannel?.invokeMethod("onQuickSosShortcut", null)
        } else if ("com.khunyikalsal.ACTION_DISASTER_RADAR" == action) {
            methodChannel?.invokeMethod("onDisasterRadarShortcut", null)
        }
    }

    /**
     * Intercepts hardware volume / physical button presses.
     * When 3 clicks are detected within 1.5 seconds, triggers immediate Emergency SOS in Flutter.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val action = event.action
        val keyCode = event.keyCode

        if (action == KeyEvent.ACTION_DOWN) {
            if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                val currentTime = System.currentTimeMillis()
                if (currentTime - lastKeyPressTime <= TRIPLE_CLICK_INTERVAL_MS) {
                    keyPressCount++
                } else {
                    keyPressCount = 1
                }
                lastKeyPressTime = currentTime

                if (keyPressCount >= 3) {
                    keyPressCount = 0
                    // Trigger emergency alarm & screen navigation in Flutter
                    methodChannel?.invokeMethod("onEmergencyTripleClick", mapOf("timestamp" to currentTime))
                    return true // Consume event
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
