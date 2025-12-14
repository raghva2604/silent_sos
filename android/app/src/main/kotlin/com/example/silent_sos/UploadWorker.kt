// app/src/main/java/com/example/silent_sos/UploadWorker.kt
// WorkManager job for presigned S3 upload flow

package com.example.silent_sos

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class UploadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return withContext(Dispatchers.IO) {
            try {
                val userId = inputData.getString("userId") ?: return@withContext Result.failure()
                val timestamp = inputData.getLong("timestamp", System.currentTimeMillis())
                val lat = inputData.getDouble("lat", 0.0)
                val lon = inputData.getDouble("lon", 0.0)
                val source = inputData.getString("source") ?: "manual"
                val frontImagePath = inputData.getString("frontImagePath") ?: ""
                val backImagePath = inputData.getString("backImagePath") ?: ""
                val audioPath = inputData.getString("audioPath") ?: ""

                // Step 1: Request presigned URLs from backend
                val files = mutableListOf<JSONObject>()
                
                if (frontImagePath.isNotEmpty()) {
                    files.add(JSONObject(mapOf(
                        "fileName" to File(frontImagePath).name,
                        "contentType" to "image/jpeg",
                        "keyPrefix" to "sos"
                    )))
                }
                if (backImagePath.isNotEmpty()) {
                    files.add(JSONObject(mapOf(
                        "fileName" to File(backImagePath).name,
                        "contentType" to "image/jpeg",
                        "keyPrefix" to "sos"
                    )))
                }
                if (audioPath.isNotEmpty()) {
                    files.add(JSONObject(mapOf(
                        "fileName" to File(audioPath).name,
                        "contentType" to "audio/mp4",
                        "keyPrefix" to "sos"
                    )))
                }

                val presignRequest = JSONObject(mapOf("files" to JSONArray(files)))
                val presignResponse = postJson(
                    "$BACKEND_URL/api/presign",
                    presignRequest
                )

                val presigned = presignResponse.getJSONArray("presigned")
                val objectUrls = mutableListOf<String>()

                // Step 2: Upload each file to S3 using presigned URLs
                for (i in 0 until presigned.length()) {
                    val presignedItem = presigned.getJSONObject(i)
                    val putUrl = presignedItem.getString("putUrl")
                    val objectUrl = presignedItem.getString("objectUrl")
                    val fileName = presignedItem.getString("fileName")

                    // Determine which file to upload
                    val filePath = when {
                        fileName.contains("front") && frontImagePath.isNotEmpty() -> frontImagePath
                        fileName.contains("back") && backImagePath.isNotEmpty() -> backImagePath
                        fileName.contains(".m4a") && audioPath.isNotEmpty() -> audioPath
                        else -> continue
                    }

                    val file = File(filePath)
                    if (!file.exists()) continue

                    // PUT file to S3
                    putFileToS3(putUrl, file, presignedItem.getString("contentType"))
                    objectUrls.add(objectUrl)
                }

                // Step 3: POST final SOS record with object URLs to backend
                val sosPayload = JSONObject(mapOf(
                    "userId" to userId,
                    "timestamp" to timestamp,
                    "lat" to lat,
                    "lon" to lon,
                    "source" to source,
                    "media" to JSONObject(mapOf(
                        "frontUrl" to (objectUrls.getOrNull(0) ?: ""),
                        "backUrl" to (objectUrls.getOrNull(1) ?: ""),
                        "audioUrl" to (objectUrls.getOrNull(2) ?: "")
                    ))
                ))

                val sosResponse = postJson("$BACKEND_URL/api/sos", sosPayload)
                
                if (sosResponse.getBoolean("ok")) {
                    // Cleanup local files
                    File(frontImagePath).delete()
                    File(backImagePath).delete()
                    File(audioPath).delete()
                    
                    Result.success()
                } else {
                    Result.retry()
                }
            } catch (e: Exception) {
                e.printStackTrace()
                Result.retry()
            }
        }
    }

    private fun postJson(url: String, json: JSONObject): JSONObject {
        val client = OkHttpClient()
        val body = json.toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder().url(url).post(body).build()
        
        val response = client.newCall(request).execute()
        return JSONObject(response.body?.string() ?: "{}")
    }

    private fun putFileToS3(putUrl: String, file: File, contentType: String) {
        val client = OkHttpClient()
        val body = file.asRequestBody(contentType.toMediaType())
        val request = Request.Builder()
            .url(putUrl)
            .put(body)
            .header("Content-Type", contentType)
            .build()
        
        val response = client.newCall(request).execute()
        if (!response.isSuccessful) {
            throw Exception("S3 PUT failed: ${response.code}")
        }
    }

    companion object {
        private const val BACKEND_URL = "http://your-backend-url:4000" // Set this to your backend URL
    }
}
