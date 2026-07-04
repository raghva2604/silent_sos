package com.example.silent_sos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.example.silent_sos.data.SosEntity

class NetworkReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (isInternetAvailable(context)) {
            Thread {
                try {
                    val list = App.db.sosDao().getAll()
                    for (item in list) {
                        val ok = SilentSosSender.sendPayload(context, item.payload)
                        if (ok) {
                            App.db.sosDao().delete(item)
                        }
                    }
                } catch (_: Exception) {}
            }.start()
        }
    }

    private fun isInternetAvailable(context: Context): Boolean {
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
            val network = cm.activeNetwork ?: return false
            val capabilities = cm.getNetworkCapabilities(network) ?: return false
            return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } catch (_: Exception) {
            return false
        }
    }
}
