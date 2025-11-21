package com.example.silent_sos

import android.app.Notification
import android.content.pm.ServiceInfo
import android.app.NotificationChannel
import android.app.Activity
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class ForegroundSensorService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var accelSensor: Sensor? = null
    private val CHANNEL_ID = "silent_sos_fg"
    private val NOTIF_ID = 101
    // Handler and scheduled Runnable used to coordinate the native auto-send countdown
    private var uiHandler: android.os.Handler? = null
    private var scheduledAutoSend: Runnable? = null

    

    override fun onCreate() {
        super.onCreate()
        try {
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            accelSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            createNotificationChannel()
            val notification = buildNotification("SilentSOS active", "Monitoring for falls")
            try {
                // On Android Q+ we must specify a foreground service type when starting a foreground service.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try {
                        startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
                    } catch (e: Exception) {
                        // Fall back to the two-arg call if the three-arg isn't available for any reason
                        android.util.Log.w("ForegroundSensorService", "startForeground with type failed, falling back: ${e.localizedMessage}")
                        startForeground(NOTIF_ID, notification)
                    }
                } else {
                    startForeground(NOTIF_ID, notification)
                }
            } catch (e: Exception) {
                android.util.Log.e("ForegroundSensorService", "startForeground failed: ${e.localizedMessage}", e)
            }
            // Use faster sampling to improve spike/free-fall detection
            accelSensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
            // Handler for scheduling the auto-send countdown
            uiHandler = android.os.Handler(android.os.Looper.getMainLooper())
            instance = this
            // Register a receiver for confirmation actions from notifications
            try {
                val filter = IntentFilter()
                filter.addAction("com.example.silent_sos.ACTION_CONFIRM_SEND")
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    // Android 13+ requires explicit exported/not-exported flag for dynamically registered receivers
                    registerReceiver(confirmReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(confirmReceiver, filter)
                }
            } catch (_: Exception) {}
            // Try to read an initial threshold value from FlutterSharedPreferences if present (best-effort)
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val maybe = prefs.getString("fallThreshold", null)
                if (maybe != null) {
                    try { fallThresholdG = maybe.toDouble() } catch (_: Exception) {}
                }
            } catch (_: Exception) {}
        } catch (e: Exception) {
            // Catch any unexpected errors during service start so the process doesn't crash
            android.util.Log.e("ForegroundSensorService", "onCreate error: ${e.localizedMessage}", e)
        }
    }

    // Receiver for confirmation action from notification
    private val confirmReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            try {
                performAutoSendNow()
            } catch (_: Exception) {}
        }
    }

    private var awaitingVerification = false
    private val verificationSamples = mutableListOf<Double>()
    // Pre-spike circular buffer of (timestampMs, g)
    private val preSpikeSamples = mutableListOf<Pair<Long, Double>>()

    companion object {
        // Default threshold (g) for impact detection. Can be updated from Dart via MethodChannel.
        @JvmStatic
        var fallThresholdG: Double = 6.0
        @JvmStatic
        fun setThreshold(v: Double) { fallThresholdG = v }

        // current live service instance (best-effort access from other classes)
        @JvmStatic
        var instance: ForegroundSensorService? = null
            private set

        @JvmStatic
        fun cancelPendingAutoSend() {
            try {
                instance?.cancelPendingSend()
            } catch (_: Exception) {}
        }

        @JvmStatic
        fun confirmSendNow() {
            try {
                instance?.performAutoSendNow()
            } catch (_: Exception) {}
        }

        // Tunable constants for native detection parity with Dart
        const val PRE_SPIKE_MS: Long = 1200
        const val VERIFICATION_MS: Long = 1500
        const val FREE_FALL_THRESHOLD_G: Double = 0.6
        const val PRE_MOVEMENT_VARIANCE_THRESHOLD: Double = 0.5
        const val POST_SPIKE_QUIET_THRESHOLD: Double = 0.7
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        try { uiHandler?.removeCallbacksAndMessages(null) } catch (_: Exception) {}
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        // Not a bound service
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "SilentSOS Foreground"
            // Use HIGH importance so full-screen intents (urgent alerts) can surface the Activity
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, text: String, payload: String? = null, fullScreen: Boolean = false): Notification {
        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        // Attach a payload so MainActivity can forward this to Dart as a notification tap.
        payload?.let { intent.putExtra("payload", it) }
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)

        // Add an action so the user can confirm the auto-send from the notification
        try {
            val confirmIntent = Intent("com.example.silent_sos.ACTION_CONFIRM_SEND")
            val confirmPending = PendingIntent.getBroadcast(this, 0, confirmIntent, if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)
            builder.addAction(NotificationCompat.Action(0, "Confirm send now", confirmPending))
        } catch (_: Exception) {}

        if (fullScreen) {
            builder.setFullScreenIntent(pendingIntent, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                try {
                    val channel = nm.getNotificationChannel(CHANNEL_ID)
                    channel?.importance = NotificationManager.IMPORTANCE_HIGH
                } catch (_: Exception) {}
            }
        }

        return builder.build()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        try {
            event ?: return
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            val g = Math.sqrt((x * x + y * y + z * z).toDouble()) / 9.8

            val now = System.currentTimeMillis()

            // Maintain a short pre-spike buffer (timestamp, g)
            preSpikeSamples.add(Pair(now, g))
            // purge old samples
            while (preSpikeSamples.isNotEmpty() && now - preSpikeSamples.first().first > PRE_SPIKE_MS) {
                preSpikeSamples.removeAt(0)
            }

            // If already awaiting verification, collect samples
            if (awaitingVerification) {
                verificationSamples.add(g)
                return
            }

            // Spike detection using companion threshold
            if (g > fallThresholdG) {
                awaitingVerification = true
                verificationSamples.clear()

                // compute pre-spike stats
                var preMin = Double.MAX_VALUE
                var preSum = 0.0
                var preSumSq = 0.0
                val preCount = preSpikeSamples.size
                for (s in preSpikeSamples) {
                    val vv = s.second
                    if (vv < preMin) preMin = vv
                    preSum += vv
                    preSumSq += vv * vv
                }
                val preMean = if (preCount > 0) preSum / preCount else 0.0
                val preVariance = if (preCount > 1) (preSumSq - (preSum * preSum) / preCount) / (preCount - 1) else 0.0

                val freeFallDetected = preMin < FREE_FALL_THRESHOLD_G
                val preMovementDetected = preVariance > PRE_MOVEMENT_VARIANCE_THRESHOLD

                // schedule verification after a short window (VERIFICATION_MS)
                val handler = android.os.Handler(android.os.Looper.getMainLooper())
                handler.postDelayed({
                    try {
                        if (verificationSamples.isEmpty()) {
                            awaitingVerification = false
                            return@postDelayed
                        }
                        var sum = 0.0
                        for (s in verificationSamples) sum += Math.abs(s - 1.0)
                        val avgDev = sum / verificationSamples.size

                        // If device quiet after impact, and either free-fall or pre-movement detected, treat as fall
                        if (avgDev < POST_SPIKE_QUIET_THRESHOLD && (freeFallDetected || preMovementDetected)) {
                            // Read user preferences to decide whether to auto-send
                            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                                val nativeAutoSend = prefs.getBoolean("native_auto_send", false)

                            // Vibrate briefly using default amplitude
                            try {
                                val vibrator: android.os.Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    val vm = getSystemService(android.os.VibratorManager::class.java)
                                    vm?.defaultVibrator
                                } else {
                                    getSystemService(android.os.Vibrator::class.java)
                                }
                                vibrator?.let {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        it.vibrate(android.os.VibrationEffect.createOneShot(400, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                                    } else {
                                        @Suppress("DEPRECATION")
                                        it.vibrate(400)
                                    }
                                }
                            } catch (_: Exception) {}

                            // Post an urgent notification. Use full-screen only when the device
                            // is locked or the screen is off — otherwise post a heads-up notification
                            // so we don't unexpectedly bring the app to foreground while the user
                            // is actively using another app.
                            try {
                                val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                                val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) pm.isInteractive else pm.isScreenOn
                                val kg = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                                val isLocked = kg.isKeyguardLocked
                                var useFullScreen = !isInteractive || isLocked
                                // Honor user preference to force full-screen overlay when detection occurs
                                try {
                                    val prefForce = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).getBoolean("force_fullscreen_on_detection", false)
                                    if (prefForce) useFullScreen = true
                                } catch (_: Exception) {}

                                val nm2 = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                                val notif = buildNotification("Fall detected", "Are you safe? Tap to respond.", "fall_alert", fullScreen = useFullScreen)
                                nm2.notify(9999, notif)
                            } catch (_: Exception) {}

                            // Schedule an auto-send after the user-selected countdown (best-effort read from prefs)
                            try {
                                val secs = prefs.getInt("sosTimerDuration", 10)

                                // Give the Flutter UI extra time to come to foreground, record and upload media
                                // when the app is launched automatically. This buffer is conservative.
                                val launchBufferSecs = 20

                                // Optionally, launch the main Activity so the Flutter UI can start recording
                                val autoLaunch = prefs.getBoolean("auto_launch_on_detection", true)
                                if (autoLaunch) {
                                    try {
                                        val launchIntent = Intent(this, MainActivity::class.java)
                                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                        launchIntent.putExtra("payload", "fall_alert")
                                        startActivity(launchIntent)
                                        android.util.Log.i("ForegroundSensorService", "Auto-launched MainActivity to allow recording on detection")
                                    } catch (lae: Exception) {
                                        android.util.Log.w("ForegroundSensorService", "Auto-launch failed: ${lae.localizedMessage}")
                                    }
                                }

                                try { scheduledAutoSend?.let { uiHandler?.removeCallbacks(it) } } catch (_: Exception) {}
                                val runnable = Runnable {
                                    try {
                                        performAutoSendNow()
                                    } catch (_: Exception) {}
                                }
                                scheduledAutoSend = runnable
                                val delayMs = ((secs + if (autoLaunch) launchBufferSecs else 0) * 1000).toLong()
                                uiHandler?.postDelayed(runnable, delayMs)
                                android.util.Log.i("ForegroundSensorService", "Scheduled auto-send in ${delayMs / 1000} seconds (base=$secs, autoLaunch=$autoLaunch)")
                                // Start periodic posting of location to the tracking session (if created by Flutter)
                                try {
                                    val poster = object : Runnable {
                                        override fun run() {
                                            try {
                                                // Read persisted FlutterSharedPreferences for current_tracking_session
                                                val fsp = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                                                val cur = fsp.getString("current_tracking_session", null)
                                                if (cur != null) {
                                                    try {
                                                        val obj = org.json.JSONObject(cur)
                                                        val sid = obj.optString("sessionId")
                                                        val token = obj.optString("token")
                                                        if (sid.isNotEmpty() && token.isNotEmpty()) {
                                                            // Try to obtain last known location quickly
                                                            try {
                                                                var lat: Double? = null
                                                                var lon: Double? = null
                                                                val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
                                                                val providers: List<String> = lm.getProviders(true)
                                                                for (p in providers) {
                                                                    val loc = lm.getLastKnownLocation(p)
                                                                    if (loc != null) { lat = loc.latitude; lon = loc.longitude; break }
                                                                }
                                                                if (lat != null && lon != null) {
                                                                    // POST to server
                                                                    try {
                                                                        val prefs2 = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                                                                        // Use server_url only; whatsapp_backend_url removed
                                                                        val backend = prefs2.getString("server_url", "http://10.0.2.2:3000")
                                                                        val url = java.net.URL("${'$'}backend/track/${'$'}sid/update?token=${'$'}token")
                                                                        val conn = url.openConnection() as java.net.HttpURLConnection
                                                                        conn.requestMethod = "POST"
                                                                        conn.connectTimeout = 5000
                                                                        conn.readTimeout = 5000
                                                                        conn.doOutput = true
                                                                        conn.setRequestProperty("Content-Type", "application/json")
                                                                        val body = "{\"lat\":${'$'}lat,\"lon\":${'$'}lon,\"ts\":${'$'}{System.currentTimeMillis()}}"
                                                                        try {
                                                                            val os = conn.outputStream
                                                                            os.write(body.toByteArray(Charsets.UTF_8))
                                                                            os.flush()
                                                                            os.close()
                                                                            val code = conn.responseCode
                                                                            android.util.Log.i("ForegroundSensorService", "Posted tracking update to $sid -> HTTP $code")
                                                                        } catch (px: Exception) { android.util.Log.w("ForegroundSensorService", "post update failed: ${'$'}{px.message}") }
                                                                        try { conn.disconnect() } catch (_: Exception) {}
                                                                    } catch (uEx: Exception) { android.util.Log.w("ForegroundSensorService", "post location error: ${'$'}{uEx.message}") }
                                                                }
                                                            } catch (_: Exception) {}
                                                        }
                                                    } catch (_: Exception) {}
                                                }
                                            } catch (_: Exception) {}
                                            // reschedule
                                            try { uiHandler?.postDelayed(this, 10000) } catch (_: Exception) {}
                                        }
                                    }
                                    // start first run after 2s
                                    uiHandler?.postDelayed(poster, 2000)
                                } catch (_: Exception) {}
                            } catch (_: Exception) {}
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("ForegroundSensorService", "verification error: ${e.localizedMessage}", e)
                    } finally {
                        awaitingVerification = false
                        verificationSamples.clear()
                    }
                }, VERIFICATION_MS)
            }
        } catch (e: Exception) {
            // Log and swallow any exceptions here -- best-effort behavior only
            android.util.Log.e("ForegroundSensorService", "onSensorChanged error: ${e.localizedMessage}", e)
        }
    }
    private fun cancelPendingSend() {
        try {
            try { scheduledAutoSend?.let { uiHandler?.removeCallbacks(it) } } catch (_: Exception) {}
            scheduledAutoSend = null
            android.util.Log.i("ForegroundSensorService", "Cancelled pending auto-send")
        } catch (_: Exception) {}
    }

    private fun performAutoSendNow() {
        try {
            android.util.Log.i("ForegroundSensorService", "performAutoSendNow invoked")
            // Emit diagnostic that auto-send flow started
            try {
                val dbg = org.json.JSONObject()
                dbg.put("event", "performAutoSendNow_invoked")
                dbg.put("ts", System.currentTimeMillis())
                val it = Intent("com.example.silent_sos.NATIVE_DEBUG")
                it.putExtra("payload", dbg.toString())
                try { sendBroadcast(it) } catch (_: Exception) {}
            } catch (_: Exception) {}
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val set = prefs.getStringSet("selected_contacts", emptySet())
            val recipients: List<String> = set?.toList() ?: emptyList()

            if (recipients.isEmpty()) {
                try {
                    val dbg2 = org.json.JSONObject()
                    dbg2.put("event", "no_recipients")
                    dbg2.put("ts", System.currentTimeMillis())
                    dbg2.put("recipients_count", 0)
                    val it2 = Intent("com.example.silent_sos.NATIVE_DEBUG")
                    it2.putExtra("payload", dbg2.toString())
                    try { sendBroadcast(it2) } catch (_: Exception) {}
                } catch (_: Exception) {}
            }

            // Try to obtain a last-known location (best-effort)
            var lat: Double? = null
            var lon: Double? = null
            try {
                val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
                val providers: List<String> = lm.getProviders(true)
                for (p in providers) {
                    val loc = lm.getLastKnownLocation(p)
                    if (loc != null) {
                        lat = loc.latitude
                        lon = loc.longitude
                        break
                    }
                }
            } catch (_: Exception) {}

            val locationPart = if (lat != null && lon != null) "https://maps.google.com/?q=$lat,$lon" else "Location unavailable"
            var message = "🆘 SILENTSOS EMERGENCY\nMy location: $locationPart"
            // Include any short live-tracking URL persisted by the Flutter layer so recipients
            // can open the public tracker page directly.
            try {
                val short = prefs.getString("last_tracking_shorturl", null)
                if (!short.isNullOrEmpty()) {
                    message += "\nLive: $short"
                    android.util.Log.i("ForegroundSensorService", "Including short live-tracking URL in native send: $short")
                }
            } catch (e: Exception) {
                android.util.Log.w("ForegroundSensorService", "Error reading last_tracking_shorturl: ${e.localizedMessage}")
            }

            // Use explicit opt-in for boot auto-send. The opt-in key is set from Flutter
            // via the Debug/Settings UI (`auto_send_opt_in`). If true, allow automatic
            // sends to proceed without requiring the older `native_auto_send` flag.
            val optInAutoSend = prefs.getBoolean("auto_send_opt_in", false)
            if (optInAutoSend && recipients.isNotEmpty()) {
                try {
                    // Configurable retry behavior: wait for last_uploaded_media to appear
                    val waitForMedia = prefs.getBoolean("auto_wait_for_media", true)
                    val maxRetries = prefs.getInt("auto_wait_retries", 3)
                    val retryIntervalMs = prefs.getInt("auto_wait_interval_ms", 5000)

                    val sendRunnable = Runnable {
                        try {
                            var msg = message
                            // Try to include any last-uploaded media links persisted by the Flutter layer
                            try {
                                val stored = prefs.getStringSet("last_uploaded_media", emptySet())
                                if (stored != null && stored.isNotEmpty()) {
                                    val mediaText = stored.joinToString("\n")
                                    // Append media links to message
                                    if (!msg.contains("Media:")) {
                                        msg += "\nMedia: $mediaText"
                                    }
                                    android.util.Log.i("ForegroundSensorService", "Including ${stored.size} media links in native send")
                                } else {
                                    android.util.Log.i("ForegroundSensorService", "No last_uploaded_media present at send time")
                                }
                            } catch (e: Exception) {
                                android.util.Log.w("ForegroundSensorService", "Error reading last_uploaded_media: ${e.localizedMessage}")
                            }

                            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val subId = android.telephony.SubscriptionManager.getDefaultSmsSubscriptionId()
                                android.telephony.SmsManager.getSmsManagerForSubscriptionId(subId)
                            } else {
                                android.telephony.SmsManager.getDefault()
                            }

                            // Permission check: if SEND_SMS not granted, notify user to grant permission
                            val canSendSms = ContextCompat.checkSelfPermission(this, android.Manifest.permission.SEND_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED
                            if (!canSendSms) {
                                try {
                                    val settingsIntent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                    settingsIntent.data = android.net.Uri.parse("package:" + packageName)
                                    settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    val pi = PendingIntent.getActivity(this, 0, settingsIntent, if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)
                                    val nb = NotificationCompat.Builder(this, CHANNEL_ID)
                                        .setContentTitle("SilentSOS needs SMS permission")
                                        .setContentText("Grant SEND_SMS permission to allow automatic SOS sending")
                                        .setSmallIcon(R.mipmap.ic_launcher)
                                        .setContentIntent(pi)
                                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                                        .setCategory(NotificationCompat.CATEGORY_CALL)
                                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                                    nm.notify(9001, nb.build())
                                } catch (_: Exception) {}
                                try {
                                    val dbg3 = org.json.JSONObject()
                                    dbg3.put("event", "permission_denied_send_sms")
                                    dbg3.put("ts", System.currentTimeMillis())
                                    val it3 = Intent("com.example.silent_sos.NATIVE_DEBUG")
                                    it3.putExtra("payload", dbg3.toString())
                                    try { sendBroadcast(it3) } catch (_: Exception) {}
                                } catch (_: Exception) {}
                            }

                            for (to in recipients) {
                                try {
                                    if (!canSendSms) continue

                                    val parts = smsManager.divideMessage(msg)
                                    // Perform sending on a background thread with up to 3 attempts to improve reliability
                                    Thread {
                                        try {
                                            val attemptResults = ArrayList<Map<String, Any?>>()
                                            for (attempt in 1..3) {
                                                var attemptSuccess = false
                                                var attemptError: String? = null
                                                var attemptTimedOut = false
                                                try {
                                                    if (parts.size > 1) {
                                                        // multipart: wait for all part broadcasts
                                                        val partCount = parts.size
                                                        val latch = java.util.concurrent.CountDownLatch(partCount)
                                                        val sentIntents = ArrayList<PendingIntent>()
                                                        val receivers = ArrayList<BroadcastReceiver>()
                                                        for (i in parts.indices) {
                                                            val actionPart = "com.example.silent_sos.SMS_SENT_${to}_${i}_${System.currentTimeMillis()}_a${attempt}"
                                                            val sentIntent = PendingIntent.getBroadcast(this, actionPart.hashCode(), Intent(actionPart), if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)
                                                            val receiver = object : BroadcastReceiver() {
                                                                override fun onReceive(ctx: Context?, intent: Intent?) {
                                                                    try {
                                                                        val rc = this.getResultCode()
                                                                        android.util.Log.i("ForegroundSensorService", "SMS multipart part result=$rc for $to (attempt=$attempt)")
                                                                        if (rc == Activity.RESULT_OK) {
                                                                            // treat individual part OK as a countdown
                                                                        }
                                                                    } catch (ex: Exception) {
                                                                        android.util.Log.w("ForegroundSensorService", "multipart onReceive error: ${ex.localizedMessage}")
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
                                                            android.util.Log.i("ForegroundSensorService", "Attempt $attempt: sent multipart SMS to $to")
                                                            val awaited = try { latch.await(10, java.util.concurrent.TimeUnit.SECONDS) } catch (ie: InterruptedException) { false }
                                                            if (!awaited) {
                                                                attemptTimedOut = true
                                                                android.util.Log.w("ForegroundSensorService", "Attempt $attempt: multipart SMS timed out for $to")
                                                            } else {
                                                                attemptSuccess = true
                                                            }
                                                        } catch (se: Exception) {
                                                            attemptError = "multipart send exception: ${se.localizedMessage}"
                                                            android.util.Log.e("ForegroundSensorService", "Attempt $attempt multipart SMS send failed for $to: ${se.localizedMessage}", se)
                                                        } finally {
                                                            // unregister any remaining receivers just in case
                                                            for (r in receivers) try { unregisterReceiver(r) } catch (_: Exception) {}
                                                        }
                                                            // Emit attempt summary for each attempt
                                                            try {
                                                                val ajs = org.json.JSONObject()
                                                                ajs.put("event", "sms_attempt")
                                                                ajs.put("recipient", to)
                                                                ajs.put("attempt", attempt)
                                                                ajs.put("success", attemptSuccess)
                                                                ajs.put("timedOut", attemptTimedOut)
                                                                if (attemptError != null) ajs.put("error", attemptError)
                                                                val ait = Intent("com.example.silent_sos.NATIVE_DEBUG")
                                                                ait.putExtra("payload", ajs.toString())
                                                                try { sendBroadcast(ait) } catch (_: Exception) {}
                                                            } catch (_: Exception) {}
                                                    } else {
                                                        val action = "com.example.silent_sos.SMS_SENT_${to}_${System.currentTimeMillis()}_a${attempt}"
                                                        val sentIntent = PendingIntent.getBroadcast(this, action.hashCode(), Intent(action), if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT)
                                                        val latch = java.util.concurrent.CountDownLatch(1)
                                                        val receiver = object : BroadcastReceiver() {
                                                            override fun onReceive(ctx: Context?, intent: Intent?) {
                                                                try {
                                                                    val rc = this.getResultCode()
                                                                    android.util.Log.i("ForegroundSensorService", "SMS_SENT broadcast resultCode=$rc for recipient=$to (attempt=$attempt)")
                                                                    attemptSuccess = rc == Activity.RESULT_OK
                                                                } catch (ex: Exception) {
                                                                    android.util.Log.w("ForegroundSensorService", "onReceive error: ${ex.localizedMessage}")
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
                                                            smsManager.sendTextMessage(to, null, msg, sentIntent, null)
                                                            android.util.Log.i("ForegroundSensorService", "Attempt $attempt: sendTextMessage called for $to")
                                                            val awaited = try { latch.await(10, java.util.concurrent.TimeUnit.SECONDS) } catch (ie: InterruptedException) { false }
                                                            if (!awaited) {
                                                                attemptTimedOut = true
                                                                android.util.Log.w("ForegroundSensorService", "Attempt $attempt: SMS_SENT did not arrive within timeout for $to")
                                                            }
                                                        } catch (se: Exception) {
                                                            attemptError = "sendTextMessage exception: ${se.localizedMessage}"
                                                            android.util.Log.e("ForegroundSensorService", "Attempt $attempt sendTextMessage failed for $to: ${se.localizedMessage}", se)
                                                        } finally {
                                                            try { unregisterReceiver(receiver) } catch (_: Exception) {}
                                                        }
                                                    }
                                                } catch (e: Exception) {
                                                    attemptError = "unexpected error: ${e.localizedMessage}"
                                                    android.util.Log.e("ForegroundSensorService", "Attempt $attempt unexpected error for $to: ${e.localizedMessage}", e)
                                                }

                                                attemptResults.add(mapOf("attempt" to attempt, "success" to attemptSuccess, "timedOut" to attemptTimedOut, "error" to attemptError))
                                                if (attemptSuccess) break
                                                try { Thread.sleep(400) } catch (_: Exception) {}
                                            }
                                            android.util.Log.i("ForegroundSensorService", "Send attempts for $to -> $attemptResults")
                                        } catch (e: Exception) {
                                            android.util.Log.e("ForegroundSensorService", "Background send thread error for $to: ${e.localizedMessage}", e)
                                        }
                                    }.start()
                                    
                                    // continue to next recipient; background thread will handle per-recipient attempts
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                    
                                } catch (_: Exception) {}
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("ForegroundSensorService", "sendRunnable error: ${e.localizedMessage}", e)
                        }
                    }

                    if (waitForMedia) {
                        var attempt = 0
                        val tryUntil = maxRetries
                        val checker = object : Runnable {
                            override fun run() {
                                try {
                                    val stored = prefs.getStringSet("last_uploaded_media", emptySet())
                                    if (stored != null && stored.isNotEmpty()) {
                                        android.util.Log.i("ForegroundSensorService", "Found last_uploaded_media on attempt ${attempt + 1}")
                                        sendRunnable.run()
                                        return
                                    }
                                    attempt += 1
                                    if (attempt <= tryUntil) {
                                        android.util.Log.i("ForegroundSensorService", "last_uploaded_media not found, retrying in ${retryIntervalMs}ms (attempt $attempt/$tryUntil)")
                                        uiHandler?.postDelayed(this, retryIntervalMs.toLong())
                                    } else {
                                        android.util.Log.i("ForegroundSensorService", "Giving up waiting for media after $tryUntil attempts; sending without media")
                                        sendRunnable.run()
                                    }
                                } catch (e: Exception) {
                                    android.util.Log.w("ForegroundSensorService", "checker error: ${e.localizedMessage}")
                                    sendRunnable.run()
                                }
                            }
                        }
                        // Start checking immediately
                        uiHandler?.post(checker)
                    } else {
                        // No waiting requested, send immediately
                        sendRunnable.run()
                    }
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            android.util.Log.e("ForegroundSensorService", "performAutoSendNow error: ${e.localizedMessage}", e)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
