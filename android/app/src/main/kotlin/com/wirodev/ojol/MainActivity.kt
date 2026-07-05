package com.wirodev.ojol

import android.content.Context
import android.app.NotificationManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wirodev.ojol/intent"
    private var orderData: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
            } else {
                result.notImplemented()
            }
        }
    }
}
