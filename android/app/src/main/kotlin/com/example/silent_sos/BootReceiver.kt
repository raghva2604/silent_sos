package com.example.silent_sos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * BootReceiver: on BOOT_COMPLETED, check user opt-in and start the ForegroundSensorService
 * only when the user has explicitly opted in via the Flutter UI (key: "auto_send_opt_in").
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
                val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val optedIn = prefs.getBoolean("auto_send_opt_in", false)
                if (optedIn) {
                    try {
                        val i = Intent(context, ForegroundSensorService::class.java)
                        i.putExtra("auto_send", true)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(context, i)
                        } else {
                            context.startService(i)
                        }
                    } catch (e: Exception) {
                        android.util.Log.w("BootReceiver", "Failed to start ForegroundSensorService on boot: ${e.localizedMessage}")
                    }
                } else {
                    android.util.Log.i("BootReceiver", "auto_send_opt_in not enabled; skipping auto-start on boot")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("BootReceiver", "onReceive error: ${e.localizedMessage}", e)
        }
    }
}
