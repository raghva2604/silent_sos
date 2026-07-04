package com.example.silent_sos.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

object LiveLocationApi {

    private const val API_URL =
        "https://thtihvjky9.execute-api.ap-south-1.amazonaws.com/prod/update-live-location"
    private const val API_URL_FALLBACK =
        "http://10.0.2.2:3000/prod/update-live-location" // Emulator local fallback

    private val client = OkHttpClient()

    suspend fun sendLiveLocation(
        sessionId: String,
        token: String,
        latitude: Double,
        longitude: Double,
        contacts: List<String>
    ): Boolean = withContext(Dispatchers.IO) {

        val json = JSONObject().apply {
            put("sessionId", sessionId)
            put("token", token)
            put("latitude", latitude)
            put("longitude", longitude)
            put("contacts", JSONArray(contacts))
        }

        val body = json.toString()
            .toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url(API_URL)
            .post(body)
            .build()

        try {
            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) return@withContext true
            }
            // fallback call if primary returned non-2xx (or no response body)
            val fallbackRequest = Request.Builder()
                .url(API_URL_FALLBACK)
                .post(body)
                .build()
            client.newCall(fallbackRequest).execute().use { response ->
                return@withContext response.isSuccessful
            }
        } catch (e: Exception) {
            // Try fallback host for DNS / network issues
            try {
                val fallbackRequest = Request.Builder()
                    .url(API_URL_FALLBACK)
                    .post(body)
                    .build()
                client.newCall(fallbackRequest).execute().use { response ->
                    return@withContext response.isSuccessful
                }
            } catch (fallbackError: Exception) {
                false
            }
        }
    }
}
