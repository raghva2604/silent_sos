package com.example.silent_sos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.vosk.LibVosk
import org.vosk.Model
import org.vosk.Recognizer
import org.json.JSONObject
import java.util.Locale

class HotwordService : Service() {
    companion object {
        const val CHANNEL_ID = "hotword_channel"
        const val NOTIF_ID = 5678
    }

    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var listeningThread: Thread? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, createNotification("Hotword listener active"))
        // LibVosk log level left as default (avoid API mismatch)

        // Initialize Flutter method channel to communicate with Dart (optional but useful)
        try {
            val engineField = application::class.java.getDeclaredField("flutterEngine")
            engineField.isAccessible = true
            val engine = engineField.get(application) as? FlutterEngine
            if (engine != null) {
                methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "silent_sos/hotword")
            }
        } catch (e: Exception) {
            // fallback: we will launch activity with Intent if channel not found
        }

        // load model from app files dir (preferred) or sdcard; if missing, attempt runtime download
        Thread {
            try {
                var modelPath = getAppModelPathIfExists()
                if (modelPath == null) {
                    // attempt to download model into filesDir from configured URL
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val modelUrl = prefs.getString("hotword_model_url", "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip")
                    if (!modelUrl.isNullOrBlank()) {
                        try {
                            val dest = filesDir.resolve("vosk-models")
                            if (!dest.exists()) dest.mkdirs()
                            val downloaded = downloadAndExtractModel(modelUrl, dest)
                            if (downloaded != null) modelPath = downloaded
                        } catch (e: Exception) {
                            // download failed, fall back to SD card path
                        }
                    }
                }

                if (modelPath == null) modelPath = getModelPath()
                model = Model(modelPath)
                startListening()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun getModelPath(): String {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Flutter stores keys with "flutter." prefix
        val modelDir = prefs.getString("flutter.hotword_model_dir", "")
        if (!modelDir.isNullOrBlank()) {
            return modelDir
        }
        // Fallback to old preference key (SD card path)
        val modelPath = prefs.getString("vosk_model_path", "/sdcard/vosk-model-small-en-us-0.15")
        return modelPath ?: "/sdcard/vosk-model-small-en-us-0.15"
    }

    private fun getAppModelPathIfExists(): String? {
        val base = filesDir.resolve("vosk-models")
        if (base.exists() && base.isDirectory) {
            // find first child directory that looks like a model
            val candidate = base.listFiles()?.firstOrNull { it.isDirectory }
            if (candidate != null) return candidate.absolutePath
        }
        return null
    }

    private fun downloadAndExtractModel(url: String, destParent: java.io.File): String? {
        // Downloads a zip to temp, extracts, and moves a candidate folder to destParent
        val tmpZip = java.io.File.createTempFile("vosk_model", ".zip", cacheDir)
        try {
            val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            conn.connectTimeout = 30_000
            conn.readTimeout = 120_000
            conn.requestMethod = "GET"
            conn.connect()
            if (conn.responseCode != 200) throw java.io.IOException("HTTP ${conn.responseCode}")
            conn.inputStream.use { input ->
                java.io.FileOutputStream(tmpZip).use { out ->
                    input.copyTo(out)
                }
            }

            // extract
            val extractDir = java.io.File(cacheDir, "vosk_model_extract_${System.currentTimeMillis()}")
            if (!extractDir.exists()) extractDir.mkdirs()
            java.util.zip.ZipInputStream(java.io.BufferedInputStream(java.io.FileInputStream(tmpZip))).use { zis ->
                var entry = zis.nextEntry
                while (entry != null) {
                    val outFile = java.io.File(extractDir, entry.name)
                    if (entry.isDirectory) {
                        outFile.mkdirs()
                    } else {
                        outFile.parentFile?.mkdirs()
                        java.io.FileOutputStream(outFile).use { fos ->
                            zis.copyTo(fos)
                        }
                    }
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }

            // locate candidate model folder (heuristic: folder containing 'am' or 'model')
            val candidate = extractDir.listFiles()?.firstOrNull { f ->
                if (!f.isDirectory) return@firstOrNull false
                val hasAm = java.io.File(f, "am").exists()
                val hasModel = java.io.File(f, "model").exists()
                hasAm || hasModel
            } ?: extractDir

            val dest = java.io.File(destParent, candidate.name)
            if (dest.exists()) dest.deleteRecursively()
            candidate.renameTo(dest)
            return dest.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        } finally {
            try { if (tmpZip.exists()) tmpZip.delete() } catch (_: Exception) {}
        }
    }

    private fun startListening() {
        if (model == null) return
        recognizer = Recognizer(model, 16000.0f)
        val bufferSize = AudioRecord.getMinBufferSize(
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
        recorder.startRecording()

        listeningThread = Thread {
            val data = ShortArray(2048)
            val customPhrase = getCustomPhrase()
            while (!Thread.currentThread().isInterrupted) {
                val read = recorder.read(data, 0, data.size)
                if (read > 0) {
                    val accepted = recognizer!!.acceptWaveForm(data, read)
                    val resultJson = if (accepted) recognizer!!.result else recognizer!!.partialResult
                    val text = extractText(resultJson).lowercase(Locale.getDefault())
                    if (customPhrase.isNotBlank() && text.contains(customPhrase)) {
                        onHotwordDetected(customPhrase)
                    }
                }
            }
            recorder.stop()
            recorder.release()
        }
        listeningThread?.start()
    }

    private fun extractText(jsonStr: String): String {
        return try {
            val jo = JSONObject(jsonStr)
            if (jo.has("text")) jo.getString("text") else jo.optString("partial", "")
        } catch (e: Exception) {
            ""
        }
    }

    private fun getCustomPhrase(): String {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("custom_hotword", "")?.lowercase(Locale.getDefault()) ?: ""
    }

    private fun onHotwordDetected(phrase: String) {
        try {
            methodChannel?.invokeMethod("hotword_detected", mapOf("phrase" to phrase))
        } catch (e: Exception) { /* ignore */ }

        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        intent.putExtra("hotword_detected", true)
        intent.putExtra("hotword_phrase", phrase)
        startActivity(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(CHANNEL_ID, "Hotword Listener", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(text: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, CHANNEL_ID)
        } else {
            android.app.Notification.Builder(this)
        }
        builder.setContentTitle("SOS Listening")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
        return builder.build()
    }

    override fun onDestroy() {
        listeningThread?.interrupt()
        recognizer?.close()
        try {
            model?.close()
        } catch (e: Exception) {
            // ignore
        }
        model = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
