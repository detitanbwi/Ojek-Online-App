package com.wirodev.wirojek

import android.content.Context
import android.app.NotificationManager
import android.app.KeyguardManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.provider.Settings
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wirodev.wirojek/intent"
    private var orderData: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Programmatic flags to turn screen on and show above lockscreen on Android 10+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        // Trigger MethodChannel call if Flutter is already running
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod("onNewOrder", orderData)
        }
    }

    private fun handleIntent(intent: Intent) {
        if (intent.hasExtra("order_id")) {
            orderData = mapOf(
                "order_id" to (intent.getStringExtra("order_id") ?: ""),
                "origin" to (intent.getStringExtra("origin") ?: ""),
                "destination" to (intent.getStringExtra("destination") ?: ""),
                "price" to (intent.getStringExtra("price") ?: ""),
                "action" to (intent.getStringExtra("action") ?: "")
            )
        }
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialOrder") {
                result.success(orderData)
                // Clear after read so we don't reload it
                orderData = null
            } else if (call.method == "dismissNotification") {
                val id = call.argument<String>("order_id") ?: ""
                try {
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancel(id.hashCode())
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else if (call.method == "checkOverlayPermission") {
                result.success(checkOverlayPermission())
            } else if (call.method == "requestOverlayPermission") {
                requestOverlayPermission()
                result.success(true)
            } else if (call.method == "openNavigation") {
                val destination = call.argument<String>("destination") ?: ""
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=" + Uri.encode(destination)))
                    intent.setPackage("com.google.android.apps.maps")
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                    } else {
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/search/?api=1&query=" + Uri.encode(destination)))
                        startActivity(browserIntent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/search/?api=1&query=" + Uri.encode(destination)))
                        startActivity(browserIntent)
                        result.success(true)
                    } catch (ex: Exception) {
                        result.error("ERROR", ex.message, null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
