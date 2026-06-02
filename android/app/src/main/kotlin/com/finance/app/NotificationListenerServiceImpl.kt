package com.finance.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel

class NotificationListenerServiceImpl : NotificationListenerService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null
        private val listenedPackages = setOf(
            "com.tencent.mm",
            "com.eg.android.AlipayGphone",
            "com.unionpay"
        )
        private const val TAG = "NotificationListener"
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListener connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListener disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        if (sbn.packageName !in listenedPackages) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        if (title.isEmpty() && text.isEmpty()) return

        val packageName = sbn.packageName
        val timestamp = sbn.postTime

        Log.d(TAG, "Notification from $packageName: title=$title, text=$text")

        val map = mapOf(
            "packageName" to packageName,
            "title" to title,
            "text" to text,
            "timestamp" to timestamp
        )

        try {
            eventSink?.success(map)
            Log.d(TAG, "Sent to Flutter via EventChannel")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send to Flutter: ${e.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No-op
    }
}
