package com.example.silent_sos

import android.content.Context
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

object SilentSosSender {
    // Reads defaults from resources similar to MainActivity behavior
    fun sendPayload(context: Context, payloadJson: String): Boolean {
        val lambdaUrl = try { context.resources.getString(context.resources.getIdentifier("lambda_url", "string", context.packageName)) } catch (_: Exception) { "" }
        val appSecret = try { context.resources.getString(context.resources.getIdentifier("app_secret", "string", context.packageName)) } catch (_: Exception) { "" }
        if (lambdaUrl.isEmpty()) return false
        return try {
            val url = URL(lambdaUrl)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            if (appSecret.isNotEmpty()) conn.setRequestProperty("x-app-secret", appSecret)
            conn.doOutput = true
            conn.connectTimeout = 15000
            conn.readTimeout = 15000

            val writer = OutputStreamWriter(conn.outputStream)
            writer.write(payloadJson)
            writer.flush()
            writer.close()

            val responseCode = conn.responseCode
            conn.disconnect()
            responseCode in 200..299
        } catch (_: Exception) {
            false
        }
    }
}
