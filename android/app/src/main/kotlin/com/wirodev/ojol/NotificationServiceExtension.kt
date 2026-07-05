package com.wirodev.ojol

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

class NotificationServiceExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val notification = event.notification
        val additionalData = notification.additionalData

        if (additionalData != null && additionalData.has("type") && additionalData.getString("type") == "NEW_ORDER") {
            Log.d("OneSignal", "New order received, creating native full-screen intent!")
            
            // Prevent OneSignal from showing the default notification banner, we will show our own full-screen one
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

            // 2. Build full-screen intent
            val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("order_id", orderId)
                putExtra("origin", origin)
                putExtra("destination", destination)
                putExtra("price", price)
            }
            
            // If screen is on (interactive), explicitly start the activity to bring the app to the front
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val isScreenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                pm.isInteractive
            } else {
                @Suppress("DEPRECATION")
                pm.isScreenOn
            }
            
            if (isScreenOn) {
                try {
                    context.startActivity(fullScreenIntent)
                } catch (e: Exception) {
                    Log.e("OneSignal", "Failed to start activity directly when screen is on: ${e.message}")
                }
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

            // 3. Create Notification Channel with Sound and Vibration (Android O+)
            val channelId = "ojol_alarm_channel"
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val soundUri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val audioAttributes = android.media.AudioAttributes.Builder()
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .build()

                val channel = NotificationChannel(
                    channelId,
                    "Ojol Order Alerts",
                    NotificationManager.IMPORTANCE_HIGH
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

            // 4. Build notification actions (Accept/Decline buttons on heads-up banner)
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

            // 5. Build and display the notification with fullScreenIntent and actions
            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(context.resources.getIdentifier("ic_stat_onesignal_default", "drawable", context.packageName).let {
                    if (it != 0) it else android.R.drawable.ic_dialog_alert
                })
                .setContentTitle("Order Baru!")
                .setContentText("Jemput: $origin -> Tujuan: $destination. Tarif: Rp $price")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setSound(soundUri)
                .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
                .setFullScreenIntent(fullScreenPendingIntent, true) // Wakes screen & shows on lockscreen automatically
                .setAutoCancel(true)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_menu_call, "Ambil", acceptPendingIntent)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Tolak", declinePendingIntent)

            val notificationBuild = builder.build()
            // Make notification play sound and vibrate continuously like an incoming call
            notificationBuild.flags = notificationBuild.flags or android.app.Notification.FLAG_INSISTENT

            notificationManager.notify(orderId.hashCode(), notificationBuild)
        }
    }
}
