package com.example.silent_sos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
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
import android.content.Intent
import android.os.Bundle
import androidx.core.content.ContextCompat
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.app.Activity
import android.app.PendingIntent
import android.util.Log
import android.os.Build

class MainActivity : FlutterActivity() {

    private lateinit var methodChannel: MethodChannel
    private var pendingPayload: String? = null
    private var flutterEngine: FlutterEngine? = null

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
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        flutterEngine = engine

        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        setMethodChannel(methodChannel)

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

        // --- Broadcast receivers for recordings & diagnostics ---
        val recordingReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                try {
                    val path = intent?.getStringExtra("path")
                    try { methodChannel.invokeMethod("nativeRecordingComplete", mapOf("path" to path)) } catch (_: Exception) {}
                } catch (_: Exception) {}
            }
        }

        val debugReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                try {
                    val payload = intent?.getStringExtra("payload")
                    try { methodChannel.invokeMethod("nativeDiagnostic", mapOf("payload" to payload)) } catch (_: Exception) {}
                } catch (_: Exception) {}
            }
        }

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

        // --- Main method channel handler ---
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
                        result.error("START_FAILED", e.localizedMessage, null)
                    }
                }
                "stop" -> {
                    try {
                        stopService(Intent(this, ForegroundSensorService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
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
                "startHotwordService" -> {
                    try {
                        val intent = Intent(this, HotwordService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(this, intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOTWORD_START_FAILED", e.localizedMessage, null)
                    }
                }
                "stopHotwordService" -> {
                    try {
                        stopService(Intent(this, HotwordService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOTWORD_STOP_FAILED", e.localizedMessage, null)
                    }
                }
                "startImageDangerDetection" -> {
                    try {
                        val intent = Intent(this, ImageDangerDetectionService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(this, intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("IMAGE_DANGER_START_FAILED", e.localizedMessage, null)
                    }
                }
                "stopImageDangerDetection" -> {
                    try {
                        stopService(Intent(this, ImageDangerDetectionService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("IMAGE_DANGER_STOP_FAILED", e.localizedMessage, null)
                    }
                }
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
                "setThreshold", "persistLastUploadedMedia", "debugAutoSend" -> result.success(true)
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
                else -> result.notImplemented()
            }
        }
    }

    // --- Vosk model downloader with retry + backoff + cancellation ---
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

                    // Extract
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
}
