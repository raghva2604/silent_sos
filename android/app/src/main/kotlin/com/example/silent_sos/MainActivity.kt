package com.example.silent_sos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import androidx.core.content.ContextCompat
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.app.PendingIntent
import android.app.Activity
import android.util.Log
import android.os.Build

class MainActivity : FlutterActivity() {

    private lateinit var methodChannel: MethodChannel
    private var pendingPayload: String? = null

    companion object {
        private const val CHANNEL_NAME = "silent_sos/foreground"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            }
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        // Forward native recording complete events to Dart
        val recordingReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                try {
                    val path = intent?.getStringExtra("path")
                    val map = HashMap<String, Any?>()
                    map["path"] = path
                    try {
                        methodChannel.invokeMethod("nativeRecordingComplete", map)
                    } catch (_: Exception) {}
                } catch (_: Exception) {}
            }
        }

        // Forward native diagnostics from services to Dart
        val debugReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                try {
                    val payload = intent?.getStringExtra("payload")
                    val map = HashMap<String, Any?>()
                    map["payload"] = payload
                    try {
                        methodChannel.invokeMethod("nativeDiagnostic", map)
                    } catch (_: Exception) {}
                } catch (_: Exception) {}
            }
        }

        // Register receiver (best-effort)
        try {
            val filter = IntentFilter(ForegroundRecordingService.ACTION_COMPLETE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(recordingReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(recordingReceiver, filter)
            }
        } catch (_: Exception) {}

        try {
            val df = IntentFilter("com.example.silent_sos.NATIVE_DEBUG")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(debugReceiver, df, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(debugReceiver, df)
            }
        } catch (_: Exception) {}

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingPayload" -> {
                    result.success(pendingPayload)
                    pendingPayload = null
                }

                "start" -> {
                    try {
                        val intent = Intent(this, ForegroundSensorService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(this, intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "start failed: ${e.localizedMessage}", e)
                        result.error("START_FAILED", e.localizedMessage, null)
                    }
                }

                "stop" -> {
                    try {
                        val intent = Intent(this, ForegroundSensorService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "stop failed: ${e.localizedMessage}", e)
                        result.error("STOP_FAILED", e.localizedMessage, null)
                    }
                }

                "startNativeRecording" -> {
                    try {
                        val intent = Intent(this, ForegroundRecordingService::class.java)
                        intent.action = ForegroundRecordingService.ACTION_START
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(this, intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NATIVE_RECORD_START_FAILED", e.localizedMessage, null)
                    }
                }

                "stopNativeRecording" -> {
                    try {
                        val intent = Intent(this, ForegroundRecordingService::class.java)
                        intent.action = ForegroundRecordingService.ACTION_STOP
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NATIVE_RECORD_STOP_FAILED", e.localizedMessage, null)
                    }
                }

                "setThreshold", "persistLastUploadedMedia", "debugAutoSend" -> {
                    // Acknowledge these simple operations from Dart; actual storage is handled in Dart
                    result.success(true)
                }

                "sendSms" -> {
                    // Expect arguments: { to: string, body: string }
                    try {
                        val to = call.argument<String>("to")
                        val body = call.argument<String>("body") ?: ""
                        if (to == null) {
                            result.success(mapOf("success" to false, "error" to "missing_recipient"))
                            return@setMethodCallHandler
                        }

                        // Permission check
                        val canSend = ContextCompat.checkSelfPermission(this, android.Manifest.permission.SEND_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (!canSend) {
                            result.success(mapOf("success" to false, "error" to "permission_denied"))
                            return@setMethodCallHandler
                        }

                        // Use SmsManager to send and wait briefly for broadcast result
                        val smsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                            val subId = android.telephony.SubscriptionManager.getDefaultSmsSubscriptionId()
                            android.telephony.SmsManager.getSmsManagerForSubscriptionId(subId)
                        } else {
                            android.telephony.SmsManager.getDefault()
                        }

                        val action = "com.example.silent_sos.SMS_SENT_MANUAL_${System.currentTimeMillis()}"
                        val sentIntent = PendingIntent.getBroadcast(this, action.hashCode(), Intent(action), if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)

                        val latch = java.util.concurrent.CountDownLatch(1)
                        var sendOk = false
                        val receiver = object : BroadcastReceiver() {
                            override fun onReceive(ctx: Context?, intent: Intent?) {
                                try {
                                    val rc = this.getResultCode()
                                    sendOk = rc == Activity.RESULT_OK
                                } catch (_: Exception) {
                                } finally {
                                    try { latch.countDown() } catch (_: Exception) {}
                                    try { unregisterReceiver(this) } catch (_: Exception) {}
                                }
                            }
                        }

                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
                            } else {
                                registerReceiver(receiver, IntentFilter(action))
                            }
                        } catch (_: Exception) {}

                        try {
                            smsManager.sendTextMessage(to, null, body, sentIntent, null)
                        } catch (e: Exception) {
                            try { unregisterReceiver(receiver) } catch (_: Exception) {}
                            result.success(mapOf("success" to false, "error" to (e.localizedMessage ?: "send_failed")))
                            return@setMethodCallHandler
                        }

                        try {
                            val awaited = try { latch.await(8, java.util.concurrent.TimeUnit.SECONDS) } catch (_: InterruptedException) { false }
                            if (!awaited) {
                                result.success(mapOf("success" to false, "error" to "timeout"))
                            } else {
                                result.success(mapOf("success" to sendOk))
                            }
                        } catch (e: Exception) {
                            result.success(mapOf("success" to false, "error" to e.localizedMessage))
                        }
                    } catch (e: Exception) {
                        result.success(mapOf("success" to false, "error" to e.localizedMessage))
                    }
                }

                "sendSmsDetailed" -> {
                    // Args: { to: string, body: string }
                    try {
                        val to = call.argument<String>("to")
                        val body = call.argument<String>("body") ?: ""
                        if (to == null) {
                            result.success(mapOf("success" to false, "error" to "missing_recipient"))
                            return@setMethodCallHandler
                        }

                        val smsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                            val subId = android.telephony.SubscriptionManager.getDefaultSmsSubscriptionId()
                            android.telephony.SmsManager.getSmsManagerForSubscriptionId(subId)
                        } else {
                            android.telephony.SmsManager.getDefault()
                        }

                        val attempts = ArrayList<Map<String, Any?>>()

                        // We'll attempt up to 3 times, supporting multipart messages
                        for (attempt in 1..3) {
                            var attemptSuccess = false
                            var attemptTimedOut = false
                            var attemptError: String? = null
                            try {
                                val parts = smsManager.divideMessage(body)
                                if (parts.size > 1) {
                                    val partCount = parts.size
                                    val latch = java.util.concurrent.CountDownLatch(partCount)
                                    val sentIntents = ArrayList<PendingIntent>()
                                    val receivers = ArrayList<BroadcastReceiver>()
                                    for (i in parts.indices) {
                                        val actionPart = "com.example.silent_sos.SMS_SENT_D_${to}_${i}_${System.currentTimeMillis()}_a${attempt}"
                                        val sentIntent = PendingIntent.getBroadcast(this, actionPart.hashCode(), Intent(actionPart), if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)
                                        val receiver = object : BroadcastReceiver() {
                                            override fun onReceive(ctx: Context?, intent: Intent?) {
                                                try {
                                                    val rc = this.getResultCode()
                                                    if (rc == Activity.RESULT_OK) {
                                                        // nothing special per-part
                                                    }
                                                } catch (_: Exception) {
                                                } finally {
                                                    try { latch.countDown() } catch (_: Exception) {}
                                                    try { unregisterReceiver(this) } catch (_: Exception) {}
                                                }
                                            }
                                        }
                                        try {
                                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                                                registerReceiver(receiver, IntentFilter(actionPart), Context.RECEIVER_NOT_EXPORTED)
                                            } else {
                                                registerReceiver(receiver, IntentFilter(actionPart))
                                            }
                                        } catch (_: Exception) {}
                                        receivers.add(receiver)
                                        sentIntents.add(sentIntent)
                                    }
                                    try {
                                        smsManager.sendMultipartTextMessage(to, null, parts, sentIntents, null)
                                        val awaited = try { latch.await(10, java.util.concurrent.TimeUnit.SECONDS) } catch (ie: InterruptedException) { false }
                                        if (!awaited) {
                                            attemptTimedOut = true
                                        } else {
                                            attemptSuccess = true
                                        }
                                    } catch (se: Exception) {
                                        attemptError = se.localizedMessage
                                    } finally {
                                        for (r in receivers) try { unregisterReceiver(r) } catch (_: Exception) {}
                                    }
                                } else {
                                    val action = "com.example.silent_sos.SMS_SENT_D_${to}_${System.currentTimeMillis()}_a${attempt}"
                                    val sentIntent = PendingIntent.getBroadcast(this, action.hashCode(), Intent(action), if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)
                                    val latch = java.util.concurrent.CountDownLatch(1)
                                    val receiver = object : BroadcastReceiver() {
                                        override fun onReceive(ctx: Context?, intent: Intent?) {
                                            try {
                                                val rc = this.getResultCode()
                                                attemptSuccess = rc == Activity.RESULT_OK
                                            } catch (ex: Exception) {
                                                attemptError = ex.localizedMessage
                                                attemptSuccess = false
                                            } finally {
                                                try { latch.countDown() } catch (_: Exception) {}
                                                try { unregisterReceiver(this) } catch (_: Exception) {}
                                            }
                                        }
                                    }
                                    try {
                                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                                            registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
                                        } else {
                                            registerReceiver(receiver, IntentFilter(action))
                                        }
                                        smsManager.sendTextMessage(to, null, body, sentIntent, null)
                                        val awaited = try { latch.await(10, java.util.concurrent.TimeUnit.SECONDS) } catch (ie: InterruptedException) { false }
                                        if (!awaited) attemptTimedOut = true
                                    } catch (se: Exception) {
                                        attemptError = se.localizedMessage
                                    } finally {
                                        try { unregisterReceiver(receiver) } catch (_: Exception) {}
                                    }
                                }
                            } catch (e: Exception) {
                                attemptError = e.localizedMessage
                            }
                            attempts.add(mapOf("attempt" to attempt, "success" to attemptSuccess, "timedOut" to attemptTimedOut, "error" to attemptError))
                            if (attemptSuccess) break
                            try { Thread.sleep(400) } catch (_: Exception) {}
                        }

                        result.success(mapOf("success" to (attempts.any { it["success"] == true }), "attempts" to attempts))
                    } catch (e: Exception) {
                        result.success(mapOf("success" to false, "error" to e.localizedMessage))
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}