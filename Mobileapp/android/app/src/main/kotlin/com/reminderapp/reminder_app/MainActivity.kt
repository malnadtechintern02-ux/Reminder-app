package com.reminderapp.reminder_app

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.reminderapp.reminder_app/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        result.success(am.canScheduleExactAlarms())
                    } else {
                        result.success(true)
                    }
                }
                "requestExactAlarmsPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "openAppDetailsSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getMediaUriForFile" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        try {
                            val file = java.io.File(filePath)
                            if (!file.exists()) {
                                android.util.Log.w("MainActivity", "getMediaUriForFile: file does not exist at $filePath")
                                result.success(null)
                                return@setMethodCallHandler
                            }

                            val extension = file.extension.lowercase()
                            val mimeType = android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "audio/mpeg"

                            // 1. Check if already present in MediaStore
                            val projection = arrayOf(android.provider.MediaStore.Audio.Media._ID)
                            val selection = "${android.provider.MediaStore.Audio.Media.DISPLAY_NAME} = ?"
                            val selectionArgs = arrayOf(file.name)
                            var foundUri: android.net.Uri? = null

                            contentResolver.query(
                                android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                                projection,
                                selection,
                                selectionArgs,
                                null
                            )?.use { cursor ->
                                if (cursor.moveToFirst()) {
                                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media._ID))
                                    foundUri = android.content.ContentUris.withAppendedId(
                                        android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                                        id
                                    )
                                }
                            }

                            if (foundUri != null) {
                                var isValid = false
                                try {
                                    contentResolver.openInputStream(foundUri!!)?.use { stream ->
                                        if (stream.available() > 0 || file.length() > 0) {
                                            isValid = true
                                        }
                                    }
                                } catch (e: Exception) {
                                    isValid = false
                                }
                                if (isValid) {
                                    android.util.Log.d("MainActivity", "getMediaUriForFile: found existing valid uri $foundUri")
                                    result.success(foundUri.toString())
                                    return@setMethodCallHandler
                                } else {
                                    try {
                                        contentResolver.delete(foundUri!!, null, null)
                                    } catch (ignored: Exception) {}
                                }
                            }

                            // 2. Insert into Android MediaStore Alarms
                            val values = android.content.ContentValues().apply {
                                put(android.provider.MediaStore.Audio.Media.DISPLAY_NAME, file.name)
                                put(android.provider.MediaStore.Audio.Media.TITLE, file.nameWithoutExtension)
                                put(android.provider.MediaStore.Audio.Media.MIME_TYPE, mimeType)
                                put(android.provider.MediaStore.Audio.Media.IS_ALARM, 1)
                                put(android.provider.MediaStore.Audio.Media.IS_RINGTONE, 1)
                                put(android.provider.MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                                    put(android.provider.MediaStore.Audio.Media.RELATIVE_PATH, android.os.Environment.DIRECTORY_ALARMS)
                                    put(android.provider.MediaStore.Audio.Media.IS_PENDING, 1)
                                }
                            }

                            var newUri = contentResolver.insert(
                                android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                                values
                            )

                            if (newUri == null) {
                                val altName = "${file.nameWithoutExtension}_${System.currentTimeMillis()}.${file.extension}"
                                values.put(android.provider.MediaStore.Audio.Media.DISPLAY_NAME, altName)
                                newUri = contentResolver.insert(
                                    android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                                    values
                                )
                            }

                            if (newUri != null) {
                                contentResolver.openOutputStream(newUri)?.use { outStream ->
                                    file.inputStream().use { inStream ->
                                        inStream.copyTo(outStream)
                                    }
                                }
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                                    values.clear()
                                    values.put(android.provider.MediaStore.Audio.Media.IS_PENDING, 0)
                                    contentResolver.update(newUri, values, null, null)
                                }
                                android.util.Log.d("MainActivity", "getMediaUriForFile: successfully inserted into MediaStore $newUri")
                                result.success(newUri.toString())
                            } else {
                                android.media.MediaScannerConnection.scanFile(
                                    applicationContext,
                                    arrayOf(file.absolutePath),
                                    null
                                ) { _, uri ->
                                    runOnUiThread {
                                        android.util.Log.d("MainActivity", "getMediaUriForFile: scanned fallback uri $uri")
                                        result.success(uri?.toString())
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "getMediaUriForFile failed", e)
                            result.success(null)
                        }
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

