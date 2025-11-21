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
import androidx.core.app.NotificationCompat

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

        } catch (e: Exception) {
            Log.e(TAG, "stopRecording failed: ${e.localizedMessage}", e)
        } finally {
            try { stopForeground(true) } catch (_: Exception) {}
            try { stopSelf() } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        try {
            recorder?.release()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
