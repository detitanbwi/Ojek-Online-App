package com.wirodev.wirojek

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val orderId = intent.getStringExtra("order_id") ?: ""

        Log.d("NotificationAction", "Received action: $action for order: $orderId")

        if (action == "DECLINE_ORDER") {
            // Dismiss the notification
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(orderId.hashCode())
            Log.d("NotificationAction", "Decline clicked, notification dismissed.")
        }
    }
}
