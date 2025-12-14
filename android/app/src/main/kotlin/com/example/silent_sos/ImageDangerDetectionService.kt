package com.example.silent_sos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.graphics.YuvImage
import android.hardware.Camera
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * ImageDangerDetectionService: periodically captures camera frames and analyzes them
 * via the backend /analyze_image endpoint for danger indicators (violence, blood, falls, weapons).
 */
class ImageDangerDetectionService : Service() {
    private val TAG = "ImageDangerDetection"
    private val CHANNEL_ID = "image_danger_channel"
    private val NOTIF_ID = 5679
    private val CAPTURE_INTERVAL_MS = 10000L  // Capture every 10 seconds
    
    private var camera: Camera? = null
    private var handler: Handler? = null
    private var captureRunnable: Runnable? = null
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, createNotification("Image danger detection active"))
        handler = Handler(Looper.getMainLooper())
        startPeriodicCapture()
    }
    
    private fun startPeriodicCapture() {
        captureRunnable = Runnable {
            try {
                captureAndAnalyzeFrame()
            } catch (e: Exception) {
                Log.w(TAG, "Frame capture error: ${e.localizedMessage}")
            }
            handler?.postDelayed(captureRunnable!!, CAPTURE_INTERVAL_MS)
        }
        handler?.post(captureRunnable!!)
    }
    
    private fun captureAndAnalyzeFrame() {
        try {
            // Request permission check
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA)
                != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                Log.w(TAG, "Camera permission not granted")
                return
            }
            
            if (camera == null) {
                camera = Camera.open(Camera.CameraInfo.CAMERA_FACING_BACK)
            }
            
            // Set up preview callback
            camera?.setPreviewCallback { data, cam ->
                Thread {
                    try {
                        if (data != null) {
                            val params = cam.parameters
                            val size = params.previewSize
                            val width = size.width
                            val height = size.height
                            
                            // Convert NV21 YUV to JPEG
                            val yuv = YuvImage(data, android.graphics.ImageFormat.NV21, width, height, null)
                            val output = ByteArrayOutputStream()
                            yuv.compressToJpeg(Rect(0, 0, width, height), 80, output)
                            val jpegData = output.toByteArray()
                            
                            uploadFrameToServer(jpegData)
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Frame processing error: ${e.localizedMessage}")
                    }
                }.start()
            }
            
            camera?.startPreview()
        } catch (e: Exception) {
            Log.e(TAG, "captureAndAnalyzeFrame error: ${e.localizedMessage}", e)
        }
    }
    
    private fun uploadFrameToServer(jpegData: ByteArray) {
        Thread {
            try {
                val serverUrl = getServerUrl()
                if (serverUrl.isBlank()) {
                    Log.w(TAG, "Server URL not configured")
                    return@Thread
                }
                
                val url = "$serverUrl/analyze_image"
                val body = jpegData.toRequestBody("image/jpeg".toMediaTypeOrNull())
                
                val request = Request.Builder()
                    .url(url)
                    .post(body)
                    .build()
                
                val response = httpClient.newCall(request).execute()
                if (response.isSuccessful) {
                    val responseBody = response.body?.string() ?: return@Thread
                    val json = JSONObject(responseBody)
                    val label = json.optString("label", "normal")
                    val score = json.optDouble("score", 0.0)
                    
                    // If danger detected with high confidence, trigger SOS
                    if (label != "normal" && score > 0.75) {
                        triggerSOSFromImage(label, score)
                    }
                    Log.i(TAG, "Frame analysis: $label (score: $score)")
                } else {
                    Log.w(TAG, "Server returned ${response.code}")
                }
                response.close()
            } catch (e: IOException) {
                Log.w(TAG, "Upload error: ${e.localizedMessage}")
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected error in uploadFrameToServer", e)
            }
        }.start()
    }
    
    private fun triggerSOSFromImage(label: String, score: Double) {
        try {
            Log.i(TAG, "Danger detected via image: $label ($score)")
            // Trigger SOS via MethodChannel or broadcast
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            intent.putExtra("image_danger_detected", true)
            intent.putExtra("danger_label", label)
            intent.putExtra("danger_score", score)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "triggerSOSFromImage error: ${e.localizedMessage}")
        }
    }
    
    private fun getServerUrl(): String {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getString("flutter.server_url", "http://localhost:8000") ?: ""
        } catch (e: Exception) {
            ""
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Image Danger Detection", NotificationManager.IMPORTANCE_LOW)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(text: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        builder.setContentTitle("Image Danger Detection")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
        return builder.build()
    }
    
    override fun onDestroy() {
        handler?.removeCallbacks(captureRunnable ?: return)
        try {
            camera?.stopPreview()
            camera?.release()
        } catch (e: Exception) {
            Log.w(TAG, "Camera release error: ${e.localizedMessage}")
        }
        camera = null
        super.onDestroy()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}
