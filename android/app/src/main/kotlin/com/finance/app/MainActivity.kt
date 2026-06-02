package com.finance.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val STORAGE_CHANNEL = "com.finance.app/storage"
    private val NOTIFICATION_CHECK_CHANNEL = "com.finance.app/notification_check"
    private val NOTIFICATION_EVENT_CHANNEL = "com.finance.app/notification_events"

    companion object {
        const val AUTO_BOOKKEEPING_CHANNEL = "auto_bookkeeping_service"
        const val AUTO_BOOKKEEPING_NOTIFICATION_ID = 2001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Storage channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val subFolder = call.argument<String>("subFolder") ?: ""
                    val fileName = call.argument<String>("fileName") ?: ""
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) { result.error("ERROR", "No bytes", null); return@setMethodCallHandler }
                    val path = if (subFolder.isNotEmpty()) "Download/记一笔/$subFolder" else "Download/记一笔"
                    saveViaMediaStore(fileName, path, bytes, result)
                }
                "openFile" -> { openFile(call.argument<String>("path") ?: "", result) }
                "openFolder" -> { openFolder(call.argument<String>("path") ?: "", result) }
                "hasStoragePermission" -> { result.success(hasStoragePermission()) }
                "requestStoragePermission" -> { requestStoragePermission(result) }
                "getApkPath" -> { result.success(applicationInfo.sourceDir) }
                else -> result.notImplemented()
            }
        }

        // Notification check channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHECK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> { result.success(isNotificationListenerEnabled()) }
                "openNotificationListenerSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }
                "showNotification" -> { showAutoBookkeepingNotification(); result.success(true) }
                "hideNotification" -> { hideAutoBookkeepingNotification(); result.success(true) }
                else -> result.notImplemented()
            }
        }

        // Notification EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationListenerServiceImpl.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    NotificationListenerServiceImpl.eventSink = null
                }
            }
        )
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat?.contains(packageName) == true
    }

    private fun showAutoBookkeepingNotification() {
        android.util.Log.d("MainActivity", "Showing auto-bookkeeping notification")
        val channel = NotificationChannel(AUTO_BOOKKEEPING_CHANNEL, "自动记账服务", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "用于显示自动记账服务运行状态"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)

        val intent = Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
        val pendingIntent = PendingIntent.getActivity(this, AUTO_BOOKKEEPING_NOTIFICATION_ID, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(this, AUTO_BOOKKEEPING_CHANNEL)
            .setContentTitle("正在检测支付通知")
            .setContentText("收到支付通知会自动弹出确认框")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

        getSystemService(NotificationManager::class.java).notify(AUTO_BOOKKEEPING_NOTIFICATION_ID, notification)
    }

    private fun hideAutoBookkeepingNotification() {
        getSystemService(NotificationManager::class.java).cancel(AUTO_BOOKKEEPING_NOTIFICATION_ID)
    }

    private fun hasStoragePermission(): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Environment.isExternalStorageManager() else true

    private fun requestStoragePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
            startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName")))
        }
        result.success(true)
    }

    private fun saveViaMediaStore(fileName: String, relativePath: String, bytes: ByteArray, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = contentResolver
                val cv = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, getMimeType(fileName))
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                }
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv)
                if (uri != null) { resolver.openOutputStream(uri)?.use { it.write(bytes) }; result.success(uri.toString()) }
                else result.error("ERROR", "Failed", null)
            } else {
                val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "记一笔")
                if (!dir.exists()) dir.mkdirs()
                val file = File(dir, fileName); file.writeBytes(bytes); result.success(Uri.fromFile(file).toString())
            }
        } catch (e: Exception) { result.error("ERROR", e.message, null) }
    }

    private fun getMimeType(fileName: String): String = when {
        fileName.endsWith(".db") || fileName.endsWith(".fin") -> "application/octet-stream"
        fileName.endsWith(".csv") -> "text/csv"
        fileName.endsWith(".xlsx") -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        else -> "application/octet-stream"
    }

    private fun openFile(path: String, result: MethodChannel.Result) {
        try {
            val uri = if (path.startsWith("content://")) Uri.parse(path) else Uri.fromFile(File(path))
            startActivity(Intent(Intent.ACTION_VIEW, uri).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION) })
            result.success(true)
        } catch (e: Exception) { result.error("ERROR", e.message, null) }
    }

    private fun openFolder(path: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(path)
            try { startActivity(Intent(Intent.ACTION_VIEW, uri).apply { setDataAndType(uri, "vnd.android.document/directory"); addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }) }
            catch (_: Exception) { startActivity(Intent(Intent.ACTION_VIEW, uri).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }) }
            result.success(true)
        } catch (e: Exception) { result.error("ERROR", e.message, null) }
    }
}
