package com.finance.app

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.finance.app/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val subFolder = call.argument<String>("subFolder") ?: ""
                    val fileName = call.argument<String>("fileName") ?: ""
                    val bytes = call.argument<ByteArray>("bytes")

                    if (bytes == null) {
                        result.error("ERROR", "No bytes provided", null)
                        return@setMethodCallHandler
                    }

                    val path = if (subFolder.isNotEmpty()) "Download/记一笔/$subFolder" else "Download/记一笔"
                    saveViaMediaStore(fileName, path, bytes, result)
                }
                "openFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    openFile(path, result)
                }
                "openFolder" -> {
                    val path = call.argument<String>("path") ?: ""
                    openFolder(path, result)
                }
                "hasStoragePermission" -> {
                    result.success(hasStoragePermission())
                }
                "requestStoragePermission" -> {
                    requestStoragePermission(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    private fun requestStoragePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
            result.success(true)
        } else {
            result.success(true)
        }
    }

    private fun saveViaMediaStore(fileName: String, relativePath: String, bytes: ByteArray, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = contentResolver
                val mimeType = getMimeType(fileName)

                val contentValues = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                }

                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { outputStream ->
                        outputStream.write(bytes)
                    }
                    result.success(uri.toString())
                } else {
                    result.error("ERROR", "Failed to create MediaStore entry", null)
                }
            } else {
                // Android 9 and below: direct file write
                val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "记一笔")
                if (!dir.exists()) dir.mkdirs()
                val subDir = File(dir, relativePath.replace("Download/记笔/", ""))
                if (!subDir.exists()) subDir.mkdirs()
                val file = File(subDir, fileName)
                file.writeBytes(bytes)
                result.success(Uri.fromFile(file).toString())
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun getMimeType(fileName: String): String {
        return when {
            fileName.endsWith(".db") || fileName.endsWith(".fin") -> "application/octet-stream"
            fileName.endsWith(".csv") -> "text/csv"
            fileName.endsWith(".xlsx") -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            else -> "application/octet-stream"
        }
    }

    private fun openFile(path: String, result: MethodChannel.Result) {
        try {
            val uri = if (path.startsWith("content://")) {
                Uri.parse(path)
            } else {
                val file = File(path)
                Uri.fromFile(file)
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, getMimeType(path))
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun openFolder(path: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(path)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "vnd.android.document/directory")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                // Fallback: open parent directory
                val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "*/*")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
}
