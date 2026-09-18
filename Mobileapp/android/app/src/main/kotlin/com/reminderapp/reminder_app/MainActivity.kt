package com.reminderapp.reminder_app

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.reminderapp.reminder_app/settings"
    private var wakeLock: PowerManager.WakeLock? = null
    private var activeAlarmReminderId: String? = null
    private var methodChannel: MethodChannel? = null

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager != null) {
                if (wakeLock?.isHeld == true) {
                    wakeLock?.release()
                }
                @Suppress("DEPRECATION")
                wakeLock = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "TimeBell:AlarmWakeLock"
                ).apply {
                    setReferenceCounted(false)
                    acquire(60 * 1000L) // Stay awake up to 60 seconds while alarm rings
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error acquiring wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error releasing wake lock", e)
        }
    }

    private fun wakeUpScreen() {
        acquireWakeLock()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun clearKeepScreenOn() {
        releaseWakeLock()
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setTurnScreenOn(false)
        }
    }

    private fun handleAlarmIntent(intent: Intent?) {
        if (intent == null) return
        val reminderId = intent.getStringExtra("reminder_id")
        if (intent.action == "com.reminderapp.ALARM_TRIGGER" || reminderId != null) {
            if (!reminderId.isNullOrEmpty()) {
                activeAlarmReminderId = reminderId
                wakeUpScreen()
                runOnUiThread {
                    methodChannel?.invokeMethod("onAlarmTriggered", reminderId)
                }
            }
        }
    }

    private fun getAlarmRequestCode(uuid: String): Int {
        var hash = 5381
        for (i in 0 until uuid.length) {
            hash = ((hash shl 5) + hash) + uuid[i].code
            hash = hash and 0x03FFFFFF
        }
        return hash
    }

    private fun scheduleNativeAlarm(reminderId: String, triggerAtMillis: Long, title: String) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val requestCode = getAlarmRequestCode(reminderId)

            val alarmIntent = Intent(applicationContext, MainActivity::class.java).apply {
                action = "com.reminderapp.ALARM_TRIGGER"
                putExtra("reminder_id", reminderId)
                putExtra("alarm_title", title)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                applicationContext,
                requestCode,
                alarmIntent,
                flags
            )

            val showIntent = PendingIntent.getActivity(
                applicationContext,
                requestCode + 500000,
                alarmIntent,
                flags
            )

            val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            android.util.Log.d("MainActivity", "Native AlarmClock scheduled for $reminderId at $triggerAtMillis")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error scheduling native alarm", e)
        }
    }

    private fun cancelNativeAlarm(reminderId: String) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val requestCode = getAlarmRequestCode(reminderId)
            val alarmIntent = Intent(applicationContext, MainActivity::class.java).apply {
                action = "com.reminderapp.ALARM_TRIGGER"
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(
                applicationContext,
                requestCode,
                alarmIntent,
                flags
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            android.util.Log.d("MainActivity", "Native AlarmClock cancelled for $reminderId")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error cancelling native alarm", e)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeUpScreen()
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        wakeUpScreen()
        handleAlarmIntent(intent)
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAlarmReminderId" -> {
                    val id = activeAlarmReminderId
                    activeAlarmReminderId = null
                    result.success(id)
                }
                "scheduleNativeAlarm" -> {
                    val reminderId = call.argument<String>("reminderId")
                    val triggerAtMillis = (call.argument<Number>("triggerAtMillis"))?.toLong()
                    val title = call.argument<String>("title") ?: "Alarm"
                    if (reminderId != null && triggerAtMillis != null) {
                        scheduleNativeAlarm(reminderId, triggerAtMillis, title)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing reminderId or triggerAtMillis", null)
                    }
                }
                "cancelNativeAlarm" -> {
                    val reminderId = call.argument<String>("reminderId")
                    if (reminderId != null) {
                        cancelNativeAlarm(reminderId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing reminderId", null)
                    }
                }
                "wakeUpScreen" -> {
                    wakeUpScreen()
                    result.success(true)
                }
                "clearKeepScreenOn" -> {
                    clearKeepScreenOn()
                    result.success(true)
                }
                "canUseFullScreenIntent" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                        result.success(nm?.canUseFullScreenIntent() ?: true)
                    } else {
                        result.success(true)
                    }
                }
                "requestFullScreenIntentPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
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

