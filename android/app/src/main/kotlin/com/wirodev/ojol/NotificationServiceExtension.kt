package com.wirodev.ojol

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

class NotificationServiceExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val notification = event.notification
        val additionalData = notification.additionalData

        if (additionalData != null && additionalData.has("type") && additionalData.getString("type") == "NEW_ORDER") {
            Log.d("OneSignal", "New order received, processing notification routing...")
            
            // Prevent OneSignal from showing the default notification banner
            event.preventDefault()
            
            val context = event.context
            val orderId = additionalData.optString("order_id") ?: "0"
            val origin = additionalData.optString("origin") ?: "Unknown"
            val destination = additionalData.optString("destination") ?: "Unknown"
            val price = additionalData.optString("price") ?: "0"

            // 1. Wake up the screen using PowerManager WakeLock
            try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val wakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "OjolApp:WakeLockTag"
                )
                wakeLock.acquire(10000) // Keep screen on for 10 seconds
            } catch (e: Exception) {
                Log.e("OneSignal", "WakeLock error: ${e.message}")
            }

            // 2. Build intents
            val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("order_id", orderId)
                putExtra("origin", origin)
                putExtra("destination", destination)
                putExtra("price", price)
            }
            
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            
            val fullScreenPendingIntent = PendingIntent.getActivity(
                context,
                orderId.hashCode(),
                fullScreenIntent,
                flags
            )

            val acceptIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("order_id", orderId)
                putExtra("origin", origin)
                putExtra("destination", destination)
                putExtra("price", price)
                putExtra("action", "ACCEPT")
            }
            val acceptPendingIntent = PendingIntent.getActivity(
                context,
                orderId.hashCode() + 1,
                acceptIntent,
                flags
            )

            val declineIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = "DECLINE_ORDER"
                putExtra("order_id", orderId)
            }
            val declinePendingIntent = PendingIntent.getBroadcast(
                context,
                orderId.hashCode() + 2,
                declineIntent,
                flags
            )

            // Check overlay permission to decide if we can launch activity directly or need the heads-up fallback
            val hasOverlayPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(context)
            } else {
                true
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val soundUri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE)

            if (hasOverlayPermission) {
                // Case A: Overlay permission is granted. Launch activity directly.
                Log.d("OneSignal", "Overlay permission granted. Launching activity and showing standard notification (no heads-up pop-up).")
                
                try {
                    context.startActivity(fullScreenIntent)
                } catch (e: Exception) {
                    Log.e("OneSignal", "Failed to start activity directly: ${e.message}")
                }

                // Show a default notification so we still play the ringtone but don't show the heads-up banner on top of the UI
                val defaultChannelId = "ojol_default_channel"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val audioAttributes = android.media.AudioAttributes.Builder()
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .build()

                    val channel = NotificationChannel(
                        defaultChannelId,
                        "Ojol Standard Alerts",
                        NotificationManager.IMPORTANCE_DEFAULT // plays sound but DOES NOT show heads-up banner
                    ).apply {
                        description = "Standard ojol order alerts"
                        enableLights(true)
                        enableVibration(true)
                        setSound(soundUri, audioAttributes)
                    }
                    notificationManager.createNotificationChannel(channel)
                }

                val builder = NotificationCompat.Builder(context, defaultChannelId)
                    .setSmallIcon(context.resources.getIdentifier("ic_stat_onesignal_default", "drawable", context.packageName).let {
                        if (it != 0) it else android.R.drawable.ic_dialog_alert
                    })
                    .setContentTitle("Order Baru!")
                    .setContentText("Jemput: $origin -> Tujuan: $destination. Tarif: Rp $price")
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT) // Standard priority, no heads-up
                    .setSound(soundUri)
                    .setAutoCancel(true)

                val notificationBuild = builder.build()
                notificationBuild.flags = notificationBuild.flags or android.app.Notification.FLAG_INSISTENT // Keep playing sound
                notificationManager.notify(orderId.hashCode(), notificationBuild)

            } else {
                // Case B: No overlay permission. Display heads-up banner with action buttons.
                Log.d("OneSignal", "Overlay permission not granted. Displaying heads-up banner.")

                val alarmChannelId = "ojol_alarm_channel"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val audioAttributes = android.media.AudioAttributes.Builder()
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .build()

                    val channel = NotificationChannel(
                        alarmChannelId,
                        "Ojol Order Alerts",
                        NotificationManager.IMPORTANCE_HIGH // shows heads-up banner
                    ).apply {
                        description = "Urgent ojol order incoming alerts"
                        enableLights(true)
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 1000, 500, 1000, 500, 1000)
                        setSound(soundUri, audioAttributes)
                        lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                    }
                    notificationManager.createNotificationChannel(channel)
                }

                val builder = NotificationCompat.Builder(context, alarmChannelId)
                    .setSmallIcon(context.resources.getIdentifier("ic_stat_onesignal_default", "drawable", context.packageName).let {
                        if (it != 0) it else android.R.drawable.ic_dialog_alert
                    })
                    .setContentTitle("Order Baru!")
                    .setContentText("Jemput: $origin -> Tujuan: $destination. Tarif: Rp $price")
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setSound(soundUri)
                    .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
                    .setFullScreenIntent(fullScreenPendingIntent, true)
                    .setAutoCancel(true)
                    .setOngoing(true)
                    .addAction(android.R.drawable.ic_menu_call, "Ambil", acceptPendingIntent)
                    .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Tolak", declinePendingIntent)

                val notificationBuild = builder.build()
                notificationBuild.flags = notificationBuild.flags or android.app.Notification.FLAG_INSISTENT // Keep playing sound
                notificationManager.notify(orderId.hashCode(), notificationBuild)
            }
        }
    }
}
