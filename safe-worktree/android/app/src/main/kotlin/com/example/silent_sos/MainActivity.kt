package com.example.silent_sos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.delay
import kotlinx.coroutines.CancellationException
import okhttp3.OkHttpClient
import okhttp3.Request
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.app.NotificationChannel
import android.app.NotificationManager
import java.io.IOException
import java.io.FileOutputStream
import java.util.zip.ZipInputStream
import java.io.File
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import android.content.Intent
import android.os.Bundle
import androidx.core.content.ContextCompat
import android.provider.MediaStore
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.app.Activity
import android.app.PendingIntent
import android.util.Log
import android.os.Build
import android.content.ComponentName
import android.content.pm.PackageManager
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.provider.Settings
import android.net.Uri

class MainActivity : FlutterActivity() {
    // disable all native background services as per user request except fall detection
    private val BACKGROUND_DISABLED = false
    // fall detection is enabled and critical for safety
    private val FALL_DETECTION_ENABLED = true

    private lateinit var methodChannel: MethodChannel
    private var pendingPayload: String? = null
    private var flutterEngine: FlutterEngine? = null
    private var pendingRequirePin: Boolean = false
    private var recordingReceiver: BroadcastReceiver? = null
    private var debugReceiver: BroadcastReceiver? = null

    companion object {
        private const val CHANNEL_NAME = "silent_sos/foreground"
        
        @Volatile
        private var sharedMethodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel?) {
            sharedMethodChannel = channel
        }
        
        fun getMethodChannel(): MethodChannel? {
            return sharedMethodChannel
        }
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
        handleAssistantIntent(intent)
        handleIncomingIntent(intent)
        handleFallIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAssistantIntent(intent)
        handleIncomingIntent(intent)
        handleFallIntent(intent)
    }

    private fun handleAssistantIntent(intent: Intent?) {
        val data = intent?.data ?: return
        
        if (data.host == "silent-sos.app" && data.path == "/emergency") {
            Log.d("Assistant", "🔗 Emergency deep link received: ${data.toString()}")
            
            // Set persistent flags so SOS fires even if onNewIntent doesn't trigger again
            getSharedPreferences("assistant", Context.MODE_PRIVATE)
                .edit()
                .putBoolean("pending_sos", true)
                .putString("pending_source", "assistant")
                .putLong("pending_timestamp", System.currentTimeMillis())
                .apply()
            Log.d("Assistant", "✅ Persistent SOS flag set: pending_sos=true, source=assistant")
            
            // Force activity to foreground for OPPO and other OEMs
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(launchIntent)
            
            // Send to Dart via method channel (backup if intent fires)
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, "assistant_bridge")
                    .invokeMethod("start_sos", null)
            }
        }
    }

    /// Handle fall trigger from notification button
    private fun handleFallIntent(intent: Intent?) {
        val isLegacyFallTrigger = intent?.getBooleanExtra("trigger_sos", false) == true && intent.getStringExtra("source") == "fall"
        val isExplicitFallTrigger = intent?.getBooleanExtra("fall_triggered", false) == true

        if (isLegacyFallTrigger || isExplicitFallTrigger) {
            Log.e("FALL_DEBUG", "🔥 Fall intent received, routing fall event")

            intent?.putExtra("fall_triggered", true)
            intent?.putExtra("trigger_source", "fall")
            intent?.putExtra("trigger_time_ms", System.currentTimeMillis())

            // Delay until Flutter engine is attached; if available, forward immediately via shared channel
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    sharedMethodChannel?.invokeMethod("fall_detected", mapOf("trigger" to "fall"))
                    Log.e("FALL_DEBUG", "✅ fall_detected event sent to Dart via sharedMethodChannel")
                } catch (e: Exception) {
                    Log.e("FALL_DEBUG", "❌ Failed to send fall_detected event: ${e.message}")
                }
            }, 300)
        }
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return
        try {
            if (intent.getBooleanExtra("hotword_detected", false)) {
                val phrase = intent.getStringExtra("hotword_phrase") ?: ""
                try {
                    sharedMethodChannel?.invokeMethod("hotword_detected", mapOf("phrase" to phrase))
                } catch (_: Exception) {
                    pendingPayload = "{\"type\":\"hotword\",\"phrase\":\"${phrase.replace("\"","\\\"") }\"}"
                }
            }
            if (intent.getBooleanExtra("fall_detected", false) || intent.getBooleanExtra("fall_triggered", false)) {
                val details = intent.getStringExtra("fall_payload") ?: intent.getStringExtra("trigger_source") ?: "fall"
                try {
                    sharedMethodChannel?.invokeMethod("fall_detected", mapOf("trigger" to details))
                } catch (_: Exception) {
                    pendingPayload = "{\"type\":\"fall\",\"payload\":\"${details.replace("\"","\\\"") }\"}"
                }
            }
            if (intent.getBooleanExtra("require_pin", false) || intent.getBooleanExtra("cancel_request", false)) {
                try {
                    sharedMethodChannel?.invokeMethod("requirePin", mapOf("fromNotification" to true))
                } catch (_: Exception) {
                    pendingRequirePin = true
                }
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (recordingReceiver != null) {
                unregisterReceiver(recordingReceiver!!)
            }
        } catch (_: Exception) {}
        try {
            if (debugReceiver != null) {
                unregisterReceiver(debugReceiver!!)
            }
        } catch (_: Exception) {}
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 101 && resultCode == RESULT_OK) {
            val videoUri = data?.data ?: return
            Thread {
                try {
                    val recorder = VideoRecorder(this)
                    recorder.uploadVideoToS3(videoUri) { videoKey, error ->
                        if (error != null) {
                            try { methodChannel.invokeMethod("videoUploadFailed", mapOf("error" to error)) } catch (_: Exception) {}
                        } else {
                            try { methodChannel.invokeMethod("videoUploadSuccess", mapOf("videoKey" to videoKey)) } catch (_: Exception) {}
                        }
                    }
                } catch (e: Exception) {
                    try { methodChannel.invokeMethod("videoUploadFailed", mapOf("error" to e.localizedMessage)) } catch (_: Exception) {}
                }
            }.start()
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        // Ensure all plugins are registered when overriding configureFlutterEngine
        try {
            GeneratedPluginRegistrant.registerWith(engine)
        } catch (_: Throwable) {}
        super.configureFlutterEngine(engine)
        flutterEngine = engine

        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        setMethodChannel(methodChannel)

        // Stealth Mode Channel
        MethodChannel(engine.dartExecutor.binaryMessenger, "stealth_mode")
            .setMethodCallHandler { call, result ->
                val pm = packageManager
                val main = ComponentName(this, MainActivity::class.java)
                val stealth = ComponentName(this, StealthActivity::class.java)
                if (call.method == "enableStealth") {
                    pm.setComponentEnabledSetting(
                        main,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    pm.setComponentEnabledSetting(
                        stealth,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
                if (call.method == "disableStealth") {
                    pm.setComponentEnabledSetting(
                        main,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    pm.setComponentEnabledSetting(
                        stealth,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
                result.success(true)
            }

        // SOS Method Channel removed (no native background services)
        // Setup Fall Trigger Method Channel
        setupFallTriggerChannel(engine)
        
        // Setup SMS Method Channel for native SMS sending
        setupSMSMethodChannel(engine)

        try {
            if (pendingRequirePin) {
                try { methodChannel.invokeMethod("requirePin", mapOf("fromNotification" to true)) } catch (_: Exception) {}
                pendingRequirePin = false
            }
        } catch (_: Exception) {}

        // --- Vosk STT channel ---
        try {
            val sttChannel = io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "silent_sos/stt")
            val sttEvent = io.flutter.plugin.common.EventChannel(engine.dartExecutor.binaryMessenger, "silent_sos/stt_stream")

            var recognizer: org.vosk.Recognizer? = null
            var speechService: org.vosk.android.SpeechService? = null
            var model: org.vosk.Model? = null
            var sttSink: io.flutter.plugin.common.EventChannel.EventSink? = null

            sttChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initModel" -> {
                        val modelPath = call.argument<String>("modelPath") ?: ""
                        Thread {
                            try {
                                model = org.vosk.Model(modelPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("model_init", e.message, null) }
                            }
                        }.start()
                    }
                    "startListening" -> {
                        val has = ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (!has) {
                            androidx.core.app.ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.RECORD_AUDIO), 1234)
                            result.error("no_perm", "Microphone permission required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            recognizer = org.vosk.Recognizer(model, 16000.0f)
                            speechService = org.vosk.android.SpeechService(recognizer, 16000.0f)
                            speechService?.startListening(object : org.vosk.android.RecognitionListener {
                                override fun onResult(hypothesis: String?) { sttSink?.success(mapOf("type" to "final", "text" to hypothesis)) }
                                override fun onFinalResult(hypothesis: String?) { sttSink?.success(mapOf("type" to "final", "text" to hypothesis)) }
                                override fun onPartialResult(partial: String?) { sttSink?.success(mapOf("type" to "partial", "text" to partial)) }
                                override fun onError(e: Exception?) { sttSink?.error("stt_error", e?.message, null) }
                                override fun onTimeout() { sttSink?.success(mapOf("type" to "timeout")) }
                            })
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("start_error", e.message, null)
                        }
                    }
                    "stopListening" -> {
                        try {
                            speechService?.stop()
                            speechService = null
                            recognizer = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("stop_error", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

            sttEvent.setStreamHandler(object : io.flutter.plugin.common.EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: io.flutter.plugin.common.EventChannel.EventSink?) { sttSink = events }
                override fun onCancel(arguments: Any?) { sttSink = null }
            })
        } catch (_: Throwable) {}

        recordingReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                try {
                    val path = intent?.getStringExtra("path")
                    try { methodChannel.invokeMethod("nativeRecordingComplete", mapOf("path" to path)) } catch (_: Exception) {}
                } catch (_: Exception) {}
            }
        }

        debugReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                try {
                    val payload = intent?.getStringExtra("payload")
                    try { methodChannel.invokeMethod("nativeDiagnostic", mapOf("payload" to payload)) } catch (_: Exception) {}
                } catch (_: Exception) {}
            }
        }

        // ForegroundRecordingService disabled; no receiver needed

        try {
            val df = IntentFilter("com.example.silent_sos.NATIVE_DEBUG")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(debugReceiver!!, df, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(debugReceiver!!, df)
            }
        } catch (_: Exception) {}

        methodChannel.setMethodCallHandler { call, result ->
            // intercept any background-service calls and respond with false/log
            if (BACKGROUND_DISABLED) {
                when (call.method) {
                    "start", "stop", "startNativeRecording", "stopNativeRecording",
                    "startHotwordService", "isRunning", "isActive" -> {
                        Log.i("MainActivity", "BACKGROUND_DISABLED: ignoring method ${call.method}")
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    "setFallDetection" -> {
                        // Allow setFallDetection even when BACKGROUND_DISABLED
                        // This will be handled in the normal handler below
                    }
                    else -> {
                        // continue to normal handler for other methods
                    }
                }
            }
            when (call.method) {
                "setFallDetection" -> {
                    val attemptEnable = (call.argument<Boolean>("enable") ?: true)
                    if (FALL_DETECTION_ENABLED && attemptEnable) {
                        Log.i("MainActivity", "setFallDetection: enabled")
                        // no-op: underlying fall detection is event-driven in native lifecycle
                    } else {
                        Log.i("MainActivity", "setFallDetection: disabled or not available")
                    }
                    result.success(FALL_DETECTION_ENABLED && attemptEnable)
                    return@setMethodCallHandler
                }
                "getSecureVideoLinkNative" -> {
                    val args = call.arguments as? Map<*, *>
                    val videoKey = args?.get("videoKey") as? String
                    if (videoKey.isNullOrEmpty()) {
                        result.error("NO_KEY", "videoKey missing", null)
                        return@setMethodCallHandler
                    }
                    try {
                        SilentSOSApi.getSecureVideoLink(videoKey) { link ->
                            runOnUiThread {
                                if (link != null) result.success(link) else result.success(null)
                            }
                        }
                    } catch (e: Exception) {
                        result.error("NATIVE_CALL_FAILED", e.localizedMessage, null)
                    }
                    return@setMethodCallHandler
                }
                "getPendingPayload" -> {
                    result.success(pendingPayload)
                    pendingPayload = null
                }
                // native background services have been removed; no handlers required
                "downloadVoskModel" -> {
                    val args = call.arguments as? Map<*, *>
                    val url = args?.get("url") as? String
                    if (url.isNullOrEmpty()) {
                        result.error("NO_URL", "url required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        startVoskDownload(url)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DOWNLOAD_START_FAILED", e.localizedMessage, null)
                    }
                }
                "cancelVoskDownload" -> {
                    try {
                        cancelVoskDownload()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_FAILED", e.localizedMessage, null)
                    }
                }
                "requestOverlayPermission" -> {
                    try {
                        val can = Settings.canDrawOverlays(this)
                        if (!can) {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(can)
                    } catch (e: Exception) {
                        result.error("OVERLAY_REQ_FAILED", e.localizedMessage, null)
                    }
                }
                "bringToForeground" -> {
                    val argsMap = call.arguments as? Map<*, *>
                    val intent = Intent(this, MainActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    argsMap?.forEach { (k, v) -> intent.putExtra(k.toString(), v.toString()) }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BRING_TO_FOREGROUND_FAILED", e.localizedMessage, null)
                    }
                }
                "persistLastUploadedMedia", "debugAutoSend" -> result.success(true)
                "sendSms" -> {
                    try {
                        val to = call.argument<String>("to")
                        val body = call.argument<String>("body") ?: ""
                        if (to == null) {
                            result.success(mapOf("success" to false, "error" to "missing_recipient"))
                            return@setMethodCallHandler
                        }
                        val canSend = ContextCompat.checkSelfPermission(this, android.Manifest.permission.SEND_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (!canSend) {
                            result.success(mapOf("success" to false, "error" to "permission_denied"))
                            return@setMethodCallHandler
                        }
                        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val subId = android.telephony.SubscriptionManager.getDefaultSmsSubscriptionId()
                            android.telephony.SmsManager.getSmsManagerForSubscriptionId(subId)
                        } else {
                            android.telephony.SmsManager.getDefault()
                        }
                        val action = "com.example.silent_sos.SMS_SENT_${System.currentTimeMillis()}"
                        val sentIntent = PendingIntent.getBroadcast(this, action.hashCode(), Intent(action), if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)
                        val latch = java.util.concurrent.CountDownLatch(1)
                        var sendOk = false
                        val receiver = object : BroadcastReceiver() {
                            override fun onReceive(ctx: Context?, intent: Intent?) {
                                try { sendOk = this.resultCode == Activity.RESULT_OK } catch (_: Exception) {}
                                finally { try { latch.countDown() } catch (_: Exception) {}; try { unregisterReceiver(this) } catch (_: Exception) {} }
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
                            val awaited = try { latch.await(8, java.util.concurrent.TimeUnit.SECONDS) } catch (_: InterruptedException) { false }
                            result.success(mapOf("success" to (awaited && sendOk)))
                        } catch (e: Exception) {
                            try { unregisterReceiver(receiver) } catch (_: Exception) {}
                            result.success(mapOf("success" to false, "error" to e.localizedMessage))
                        }
                    } catch (e: Exception) {
                        result.success(mapOf("success" to false, "error" to e.localizedMessage))
                    }
                }
                "sendSOS" -> {
                    val args = call.arguments as? Map<*, *>
                    var lambdaUrl = args?.get("lambdaUrl") as? String ?: ""
                    var appSecret = args?.get("appSecret") as? String ?: ""
                    val message = args?.get("message") as? String ?: "🚨 SOS! Please help me"
                    val latitude = args?.get("latitude") as? Double
                    val longitude = args?.get("longitude") as? Double
                    val contactsArg = args?.get("contacts")
                    val contacts = when (contactsArg) {
                        is List<*> -> contactsArg.mapNotNull { it?.toString() }
                        is Array<*> -> contactsArg.mapNotNull { it?.toString() }
                        else -> emptyList()
                    }

                    // fallback to values in res/values/secrets.xml if not provided by caller
                    try {
                        if (lambdaUrl.isEmpty()) lambdaUrl = this.resources.getString(this.resources.getIdentifier("lambda_url", "string", this.packageName))
                    } catch (_: Exception) {}
                    try {
                        if (appSecret.isEmpty()) appSecret = this.resources.getString(this.resources.getIdentifier("app_secret", "string", this.packageName))
                    } catch (_: Exception) {}

                    Thread {
                        try {
                            if (lambdaUrl.isEmpty()) {
                                runOnUiThread { result.error("NO_URL", "lambdaUrl missing", null) }
                                return@Thread
                            }
                            val url = URL(lambdaUrl)
                            val conn = url.openConnection() as HttpURLConnection
                            conn.requestMethod = "POST"
                            conn.setRequestProperty("Content-Type", "application/json")
                            if (appSecret.isNotEmpty()) conn.setRequestProperty("x-app-secret", appSecret)
                            conn.doOutput = true
                            conn.connectTimeout = 15000
                            conn.readTimeout = 15000

                            val json = JSONObject()
                            json.put("message", message)
                            if (latitude != null) json.put("latitude", latitude)
                            if (longitude != null) json.put("longitude", longitude)
                            json.put("contacts", contacts)

                            val writer = OutputStreamWriter(conn.outputStream)
                            writer.write(json.toString())
                            writer.flush()
                            writer.close()

                            val responseCode = conn.responseCode
                            val respStream = if (responseCode in 200..299) conn.inputStream else conn.errorStream
                            val respText = respStream?.bufferedReader()?.use { it.readText() } ?: ""
                            conn.disconnect()

                            runOnUiThread {
                                result.success(mapOf("success" to (responseCode in 200..299), "code" to responseCode, "body" to respText))
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(mapOf("success" to false, "error" to e.localizedMessage)) }
                        }
                    }.start()
                }
                "saveOfflineSOS" -> {
                    val args = call.arguments as? Map<*, *>
                    val payload = args?.get("payload") as? String
                    if (payload == null) {
                        result.error("MISSING_PAYLOAD", "payload required", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val entity = com.example.silent_sos.data.SosEntity(payload = payload)
                            App.db.sosDao().insert(entity)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SAVE_FAILED", e.localizedMessage, null) }
                        }
                    }.start()
                }
                "resendOfflineSOS" -> {
                    Thread {
                        try {
                            val list = App.db.sosDao().getAll()
                            var count = 0
                            for (item in list) {
                                val ok = SilentSosSender.sendPayload(this, item.payload)
                                if (ok) {
                                    App.db.sosDao().delete(item)
                                    count += 1
                                }
                            }
                            runOnUiThread { result.success(mapOf("sent" to count)) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RESEND_FAILED", e.localizedMessage, null) }
                        }
                    }.start()
                }
                "recordVideo" -> {
                    try {
                        val intent = Intent(MediaStore.ACTION_VIDEO_CAPTURE)
                        intent.putExtra(MediaStore.EXTRA_DURATION_LIMIT, 15)
                        intent.putExtra(MediaStore.EXTRA_VIDEO_QUALITY, 1)
                        startActivityForResult(intent, 101)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RECORD_VIDEO_FAILED", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ✅ BULLETPROOF EMAIL CHANNEL
        // Uses native Android Intent.ACTION_SENDTO to guarantee email opens
        // Never silently fails unlike url_launcher mailto: on some devices
        setupEmailChannel(engine)
    }

    private fun setupEmailChannel(engine: FlutterEngine) {
        val emailChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "silent_sos/email")
        emailChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openEmail" -> {
                    try {
                        val recipients = call.argument<String>("recipients") ?: ""
                        val subject = call.argument<String>("subject") ?: ""
                        val body = call.argument<String>("body") ?: ""

                        Log.d("EmailChannel", "Opening email with recipients: $recipients")

                        val intent = Intent(Intent.ACTION_SENDTO).apply {
                            data = Uri.parse("mailto:")
                            putExtra(Intent.EXTRA_EMAIL, recipients.split(",").map { it.trim() }.toTypedArray())
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                            putExtra(Intent.EXTRA_TEXT, body)
                            // Ensure it opens as external app
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }

                        val chooser = Intent.createChooser(intent, "Send Email")
                        chooser.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        
                        try {
                            startActivity(chooser)
                            Log.d("EmailChannel", "✅ Email intent started successfully")
                            result.success(mapOf("success" to true))
                        } catch (e: Exception) {
                            // Fallback: try direct intent if chooser fails
                            Log.w("EmailChannel", "Chooser failed, trying direct intent: ${e.message}")
                            try {
                                startActivity(intent)
                                Log.d("EmailChannel", "✅ Direct email intent started successfully")
                                result.success(mapOf("success" to true))
                            } catch (e2: Exception) {
                                Log.e("EmailChannel", "❌ Both chooser and direct intent failed: ${e2.message}")
                                result.error("EMAIL_INTENT_FAILED", "No email app available: ${e2.message}", null)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("EmailChannel", "❌ Email channel error: ${e.message}")
                        result.error("EMAIL_CHANNEL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private val downloadScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var downloadJob: Job? = null
    private val HOTWORD_NOTIF_CHANNEL = "hotword_dl"
    private val HOTWORD_NOTIF_ID = 222

    private fun createDownloadNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                val ch = NotificationChannel(HOTWORD_NOTIF_CHANNEL, "Model Download", NotificationManager.IMPORTANCE_LOW)
                nm.createNotificationChannel(ch)
            } catch (_: Exception) {}
        }
    }

    private fun showStartTestNotification() {
        try {
            val channelId = "silent_sos_protection"
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(channelId, "Silent SOS Protection", NotificationManager.IMPORTANCE_HIGH)
                ch.description = "Ongoing emergency protection service"
                nm.createNotificationChannel(ch)
            }
            val intent = Intent(this, MainActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            val pending = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            val n = NotificationCompat.Builder(this, channelId)
                .setContentTitle("Silent SOS: test notification")
                .setContentText("This is a diagnostic notification to verify posting works")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pending)
                .setAutoCancel(true)
                .build()
            nm.notify(9999, n)
        } catch (e: Exception) {
            Log.w("MainActivity", "showStartTestNotification failed: ${e.message}")
        }
    }

    private fun startVoskDownload(url: String) {
        downloadJob?.cancel()
        createDownloadNotificationChannel()
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val engine = flutterEngine ?: return
        val hotwordChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "silent_sos/hotword")
        
        downloadJob = downloadScope.launch {
            val client = OkHttpClient.Builder()
                .callTimeout(10, java.util.concurrent.TimeUnit.MINUTES)
                .build()

            val maxRetries = 3
            var attempt = 0
            var success = false
            var lastError: String? = null
            val modelParent = File(filesDir, "vosk-models")
            if (!modelParent.exists()) modelParent.mkdirs()
            val zipFile = File(modelParent, "vosk_download.zip")

            while (attempt < maxRetries && isActive && !success) {
                try {
                    val req = Request.Builder().url(url).build()
                    val resp = client.newCall(req).execute()

                    if (!resp.isSuccessful) {
                        lastError = "HTTP ${resp.code}"
                        throw IOException("HTTP error ${resp.code}")
                    }

                    val body = resp.body ?: throw IOException("Empty response body")
                    val total = body.contentLength()
                    val input = body.byteStream()

                    FileOutputStream(zipFile).use { out ->
                        val buf = ByteArray(8192)
                        var read: Int
                        var downloaded = 0L
                        while (input.read(buf).also { read = it } != -1) {
                            if (!isActive) {
                                out.close()
                                input.close()
                                zipFile.delete()
                                withContext(Dispatchers.Main) {
                                    try { hotwordChannel.invokeMethod("hotwordDownloadError", "Cancelled") } catch (_: Exception) {}
                                    nm.cancel(HOTWORD_NOTIF_ID)
                                }
                                return@launch
                            }
                            out.write(buf, 0, read)
                            downloaded += read
                            if (total > 0) {
                                val progress = ((downloaded * 100) / total).toInt()
                                withContext(Dispatchers.Main) {
                                    try { hotwordChannel.invokeMethod("hotwordDownloadProgress", progress) } catch (_: Exception) {}
                                    val notif = NotificationCompat.Builder(this@MainActivity, HOTWORD_NOTIF_CHANNEL)
                                        .setContentTitle("Downloading Vosk model")
                                        .setContentText("$progress%")
                                        .setProgress(100, progress, false)
                                        .setSmallIcon(android.R.drawable.stat_sys_download)
                                        .setOnlyAlertOnce(true)
                                        .build()
                                    NotificationManagerCompat.from(this@MainActivity).notify(HOTWORD_NOTIF_ID, notif)
                                }
                            }
                        }
                    }

                    ZipInputStream(zipFile.inputStream()).use { zis ->
                        var entry = zis.nextEntry
                        while (entry != null) {
                            if (!isActive) {
                                zipFile.delete()
                                withContext(Dispatchers.Main) {
                                    try { hotwordChannel.invokeMethod("hotwordDownloadError", "Cancelled during extract") } catch (_: Exception) {}
                                    nm.cancel(HOTWORD_NOTIF_ID)
                                }
                                return@launch
                            }
                            val outFile = File(modelParent, entry.name)
                            if (entry.isDirectory) {
                                outFile.mkdirs()
                            } else {
                                outFile.parentFile?.mkdirs()
                                FileOutputStream(outFile).use { fos -> zis.copyTo(fos) }
                            }
                            zis.closeEntry()
                            entry = zis.nextEntry
                        }
                    }
                    zipFile.delete()

                    withContext(Dispatchers.Main) {
                        try { hotwordChannel.invokeMethod("hotwordDownloadCompleted", true) } catch (_: Exception) {}
                        nm.cancel(HOTWORD_NOTIF_ID)
                    }
                    success = true
                } catch (e: Exception) {
                    if (e is CancellationException) {
                        withContext(Dispatchers.Main) {
                            try { hotwordChannel.invokeMethod("hotwordDownloadError", "Cancelled") } catch (_: Exception) {}
                            nm.cancel(HOTWORD_NOTIF_ID)
                        }
                        return@launch
                    }
                    attempt += 1
                    lastError = e.message ?: "Unknown error"
                    if (attempt < maxRetries) {
                        val backoffMs = 2000L * (1L shl (attempt - 1))
                        withContext(Dispatchers.Main) {
                            try { hotwordChannel.invokeMethod("hotwordDownloadProgress", -2) } catch (_: Exception) {}
                        }
                        try { delay(backoffMs) } catch (_: CancellationException) {
                            withContext(Dispatchers.Main) {
                                try { hotwordChannel.invokeMethod("hotwordDownloadError", "Cancelled") } catch (_: Exception) {}
                                nm.cancel(HOTWORD_NOTIF_ID)
                            }
                            return@launch
                        }
                    }
                }
            }

            if (!success) {
                withContext(Dispatchers.Main) {
                    try { hotwordChannel.invokeMethod("hotwordDownloadError", lastError ?: "Download failed") } catch (_: Exception) {}
                    nm.cancel(HOTWORD_NOTIF_ID)
                }
            }
        }
    }

    private fun cancelVoskDownload() {
        downloadJob?.cancel()
        downloadJob = null
        val zipFile = File(filesDir, "vosk-models/vosk_download.zip")
        if (zipFile.exists()) zipFile.delete()
    }

    // SOS method channel and related handlers were removed since no background services remain

    private fun setupFallTriggerChannel(engine: FlutterEngine) {
        val fallChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.example.silent_sos/fall")
        
        fallChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "open_app_for_fall" -> {
                    try {
                        android.util.Log.d("FALL_DEBUG", "✅ open_app_for_fall invoked - triggering fall SOS")
                        
                        // Pass data via Intent extras (more reliable than SharedPreferences)
                        val intent = Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            putExtra("fall_triggered", true)
                            putExtra("trigger_source", "fall")
                            putExtra("trigger_time_ms", System.currentTimeMillis())
                        }
                        startActivity(intent)
                        android.util.Log.d("FALL_DEBUG", "✅ startActivity called with fall_triggered=true")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("FALL_DEBUG", "❌ open_app_for_fall error: ${e.message}")
                        result.error("open_fail", e.message, null)
                    }
                }
                "is_fall_triggered" -> {
                    try {
                        val extras = intent?.extras
                        val fallTriggered = extras?.getBoolean("fall_triggered", false) ?: false
                        android.util.Log.d("FALL_DEBUG", "🔍 is_fall_triggered check: $fallTriggered")
                        result.success(fallTriggered)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "clear_fall_triggered" -> {
                    try {
                        intent?.removeExtra("fall_triggered")
                        intent?.removeExtra("trigger_source")
                        intent?.removeExtra("trigger_time_ms")
                        android.util.Log.d("FALL_DEBUG", "🔍 Cleared fall_triggered extras")
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun setupSMSMethodChannel(engine: FlutterEngine) {
        val smsChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "silent_sos/sms")
        
        smsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    try {
                        @Suppress("UNCHECKED_CAST")
                        val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: emptyList()
                        val message = call.argument<String>("message") ?: ""
                        
                        Log.d("SMSSender", "📱 Sending SMS to ${phoneNumbers.size} numbers: $phoneNumbers")
                        
                        if (phoneNumbers.isEmpty()) {
                            Log.w("SMSSender", "⚠️ No phone numbers provided")
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        
                        // Send SMS directly using SmsManager (bypasses app interception)
                        val smsManager = SmsManager.getDefault()
                        
                        // Send to each number individually
                        var successCount = 0
                        for (phoneNumber in phoneNumbers) {
                            try {
                                // Clean the phone number
                                val cleanNumber = phoneNumber.replace(Regex("[^\\d+]"), "")
                                if (cleanNumber.isNotEmpty()) {
                                    smsManager.sendTextMessage(cleanNumber, null, message, null, null)
                                    successCount++
                                    Log.d("SMSSender", "✅ SMS sent to: $cleanNumber")
                                } else {
                                    Log.w("SMSSender", "⚠️ Invalid phone number: $phoneNumber")
                                }
                            } catch (e: Exception) {
                                Log.e("SMSSender", "❌ Failed to send SMS to $phoneNumber: ${e.message}")
                            }
                        }
                        
                        Log.d("SMSSender", "📊 SMS sending complete: $successCount/${phoneNumbers.size} successful")
                        result.success(successCount > 0) // Return true if at least one SMS was sent
                    } catch (e: Exception) {
                        Log.e("SMSSender", "❌ Error sending SMS: ${e.message}")
                        result.error("sms_error", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}