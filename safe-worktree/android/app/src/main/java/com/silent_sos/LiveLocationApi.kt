package com.silent_sos

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

object LiveLocationApi {
    private val client = OkHttpClient()

    fun sendSos(sessionId: String, latitude: Double, longitude: Double, verifiedEmail: String? = null) {
        val json = JSONObject().apply {
            put("sessionId", sessionId)
            put("latitude", latitude)
            put("longitude", longitude)
            put("emails", JSONArray(listOf(verifiedEmail ?: "your_verified_email@example.com")))
            put("contacts", JSONArray())
        }

        val requestBody =
            json.toString().toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url(ApiConfig.SOS_URL)
            .post(requestBody)
            .addHeader("Content-Type", "application/json")
            .addHeader("x-app-secret", ApiConfig.APP_SECRET)
            .build()

        // Execute synchronously on caller thread — ensure you call from a background thread
        client.newCall(request).execute().use { response ->
            // No-op: caller can inspect response if needed
        }
    }
}
