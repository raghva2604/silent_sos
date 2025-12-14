package com.example.silent_sos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.FusedLocationProviderClient
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.Timer
import java.util.TimerTask
import androidx.core.app.NotificationCompat
import okio.Buffer
import okio.BufferedSink
import okio.ForwardingSink
import okhttp3.MultipartBody
import okhttp3.RequestBody
import java.io.File
import java.util.concurrent.TimeUnit

class ForegroundRecordingService : Service() {
    companion object {
        const val TAG = "ForegroundRecordingService"
        const val ACTION_START = "com.example.silent_sos.action.START_RECORDING"
        const val ACTION_STOP = "com.example.silent_sos.action.STOP_RECORDING"
        const val ACTION_COMPLETE = "com.example.silent_sos.action.RECORDING_COMPLETE"
        const val EXTRA_MAX_SECONDS = "maxDurationSeconds"
        const val EXTRA_LABEL = "label"
        const val EXTRA_ALLOW_MIC_NOISE = "allowMicNoise"
        const val PREF_KEY_LAST_NATIVE_RECORDING = "last_native_recording_path"
        const val NOTIF_CHANNEL_ID = "silent_sos_recording"
        const val NOTIF_ID = 23573
    }

    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private var stopRunnable: Runnable? = null

    // Location update helpers (requires play-services-location Gradle dependency)
    // TODO: ensure build.gradle.kts contains: implementation("com.google.android.gms:play-services-location:21.0.1")
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private var locationTimer: Timer? = null
    private val httpClient = OkHttpClient()

    private fun getMethodChannel(): io.flutter.plugin.common.MethodChannel? {
        return MainActivity.getMethodChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val action = intent?.action
            if (action == ACTION_START) {
                val max = intent.getIntExtra(EXTRA_MAX_SECONDS, 0)
                val label = intent.getStringExtra(EXTRA_LABEL) ?: "sos_${System.currentTimeMillis()}.m4a"
                startRecording(maxSeconds = max, label = label)
            } else if (action == ACTION_STOP) {
                stopRecording()
            }
        } catch (e: Exception) {
            Log.e(TAG, "onStartCommand error: ${e.localizedMessage}", e)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun createNotification(): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(NOTIF_CHANNEL_ID, "SilentSOS recording", NotificationManager.IMPORTANCE_LOW)
            ch.setSound(null, null)
            nm.createNotificationChannel(ch)
        }

        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pending = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        return NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setContentTitle("SilentSOS recording")
            .setContentText("Recording audio for SOS")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
    }

    private fun startRecording(maxSeconds: Int = 0, label: String = "sos_recording.m4a") {
        try {
            if (recorder != null) return
            val file = java.io.File(filesDir, label)
            outputPath = file.absolutePath

            recorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(outputPath)
                prepare()
                start()
            }

            startForeground(NOTIF_ID, createNotification())

            if (maxSeconds > 0) {
                stopRunnable = Runnable { stopRecording() }
                handler.postDelayed(stopRunnable!!, (maxSeconds * 1000).toLong())
            }
        } catch (e: Exception) {
            Log.e(TAG, "startRecording failed: ${e.localizedMessage}", e)
            try { stopSelf() } catch (_: Exception) {}
        }
    }

    private fun stopRecording() {
        try {
            stopRunnable?.let { handler.removeCallbacks(it) }
            try {
                recorder?.apply {
                    try { stop() } catch (_: Exception) {}
                    release()
                }
            } catch (_: Exception) {}
            val path = outputPath
            recorder = null
            outputPath = null
            // Persist last path to FlutterSharedPreferences so Dart can read it if needed.
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().putString(PREF_KEY_LAST_NATIVE_RECORDING, path).apply()
            } catch (_: Exception) {}

            // Broadcast completion so MainActivity can receive the path synchronously
            try {
                val b = Intent(ACTION_COMPLETE)
                b.putExtra("path", path)
                sendBroadcast(b)
            } catch (_: Exception) {}

            // Upload recording to backend (non-blocking)
            if (path != null) {
                Thread {
                    try {
                        uploadRecordingToBackend(path)
                    } catch (e: Exception) {
                        Log.e(TAG, "upload failed: ${e.localizedMessage}", e)
                    }
                }.start()
            }

        } catch (e: Exception) {
            Log.e(TAG, "stopRecording failed: ${e.localizedMessage}", e)
        } finally {
            try { stopForeground(true) } catch (_: Exception) {}
            try { stopSelf() } catch (_: Exception) {}
        }
    }

    private fun uploadRecordingToBackend(filePath: String) {
        Thread {
            uploadFileWithRetry(filePath, maxAttempts = 5, initialBackoffMs = 1000)
        }.start()
    }

    // Start posting location updates every 30s for a given event id.
    // Requires play-services-location dependency in build.gradle (see TODO above)
    private fun startLocationUpdates(eventId: Int?) {
        try {
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get FusedLocationProviderClient: ${e.localizedMessage}")
            return
        }
        locationTimer = Timer()
        locationTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                try {
                    fusedLocationClient.lastLocation.addOnSuccessListener { loc ->
                        if (loc != null) {
                            val json = JSONObject()
                            json.put("lat", loc.latitude)
                            json.put("lon", loc.longitude)
                            json.put("time", System.currentTimeMillis())
                            json.put("eventId", eventId)
                            postLocation(json)
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }, 0, 30_000)
    }

    private fun stopLocationUpdates() {
        try {
            locationTimer?.cancel()
            locationTimer = null
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun postLocation(json: JSONObject) {
        Thread {
            try {
                val serverUrl = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .getString("server_url", "http://10.0.2.2:3000") ?: "http://10.0.2.2:3000"
                val reqBody = json.toString().toRequestBody("application/json; charset=utf-8".toMediaTypeOrNull())
                val request = Request.Builder()
                    .url("$serverUrl/event/${json.optInt("eventId")}/location")
                    .post(reqBody)
                    .build()
                val resp = httpClient.newCall(request).execute()
                resp.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun uploadFileWithRetry(filePath: String, maxAttempts: Int, initialBackoffMs: Long) {
        var backoffMs = initialBackoffMs
        for (attempt in 1..maxAttempts) {
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val backendUrl = prefs.getString("server_url", "http://10.0.2.2:8000") ?: "http://10.0.2.2:8000"
                val uploadUrl = "$backendUrl/upload_recording"

                val file = File(filePath)
                if (!file.exists()) {
                    Log.w(TAG, "Recording file not found: $filePath")
                    sendUploadResultToFlutter(success = false, errorMsg = "File not found", payload = null)
                    return
                }

                // Create OkHttpClient with timeouts
                val client = OkHttpClient.Builder()
                    .callTimeout(90, TimeUnit.SECONDS)
                    .connectTimeout(15, TimeUnit.SECONDS)
                    .readTimeout(90, TimeUnit.SECONDS)
                    .build()

                // Build multipart request with progress tracking
                val fileRequestBody = ProgressRequestBody(file, "audio/m4a".toMediaTypeOrNull()) { progress ->
                    sendProgressToFlutter(progress)
                }
                val requestBody = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart("file", file.name, fileRequestBody)
                    .build()

                val request = Request.Builder()
                    .url(uploadUrl)
                    .post(requestBody)
                    .build()

                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        Log.i(TAG, "Recording uploaded successfully (attempt $attempt/$maxAttempts)")
                        val responseBody = response.body?.string() ?: "{}"
                        sendUploadResultToFlutter(success = true, errorMsg = null, payload = responseBody)
                        return  // Success, exit retry loop
                    } else {
                        val msg = "HTTP ${response.code}: ${response.message}"
                        Log.w(TAG, "Upload attempt $attempt/$maxAttempts failed: $msg")
                        if (attempt < maxAttempts) {
                            Thread.sleep(backoffMs)
                            backoffMs *= 2  // Exponential backoff
                        } else {
                            sendUploadResultToFlutter(success = false, errorMsg = msg, payload = null)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Upload attempt $attempt/$maxAttempts error: ${e.localizedMessage}", e)
                if (attempt < maxAttempts) {
                    try {
                        Thread.sleep(backoffMs)
                        backoffMs *= 2
                    } catch (_: InterruptedException) {}
                } else {
                    sendUploadResultToFlutter(success = false, errorMsg = e.localizedMessage ?: "Unknown error", payload = null)
                }
            }
        }
    }

    private fun sendProgressToFlutter(progress: Int) {
        try {
            val channel = getMethodChannel()
            if (channel == null) {
                return
            }
            channel.invokeMethod("upload_progress", mapOf("progress" to progress))
        } catch (e: Exception) {
            Log.w(TAG, "Error sending progress to Flutter: ${e.localizedMessage}")
        }
    }

    private fun sendUploadResultToFlutter(success: Boolean, errorMsg: String?, payload: String?) {
        try {
            val channel = getMethodChannel()
            if (channel == null) {
                Log.w(TAG, "MethodChannel not initialized; upload result not sent to Flutter")
                return
            }
            val result = mapOf(
                "success" to success,
                "error" to (errorMsg ?: ""),
                "payload" to (payload ?: "")
            )
            channel.invokeMethod("upload_complete", result)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending upload result to Flutter: ${e.localizedMessage}", e)
        }
    }

    /**
     * ProgressRequestBody wraps a file and reports progress via a callback as it's uploaded.
     */
    private inner class ProgressRequestBody(
        private val file: File,
        private val mediaType: okhttp3.MediaType?,
        private val progressCallback: (Int) -> Unit
    ) : RequestBody() {

        override fun contentType() = mediaType

        override fun contentLength() = file.length()

        override fun writeTo(sink: BufferedSink) {
            val totalBytes = file.length()
            var uploadedBytes = 0L

            file.inputStream().use { input ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    sink.write(buffer, 0, bytesRead)
                    uploadedBytes += bytesRead
                    val progress = (uploadedBytes * 100 / totalBytes).toInt()
                    progressCallback(progress)
                }
            }
            sink.flush()
        }
    }

    override fun onDestroy() {
        try {
            recorder?.release()
        } catch (_: Exception) {}
        // stopLocationUpdates() - re-enable when play-services-location dependency added
        super.onDestroy()
    }
}
