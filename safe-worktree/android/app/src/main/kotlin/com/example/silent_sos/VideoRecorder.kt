package com.example.silent_sos

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL

class VideoRecorder(private val context: Context) {

    fun recordVideo() {
        try {
            val intent = Intent(MediaStore.ACTION_VIDEO_CAPTURE)
            intent.putExtra(MediaStore.EXTRA_DURATION_LIMIT, 15)
            intent.putExtra(MediaStore.EXTRA_VIDEO_QUALITY, 1)
            // Will be handled via startActivityForResult in MainActivity
            Log.d("VideoRecorder", "Video intent created")
        } catch (e: Exception) {
            Log.e("VideoRecorder", "recordVideo failed: ${e.localizedMessage}")
        }
    }

    fun uploadVideoToS3(videoUri: Uri, onComplete: (videoKey: String?, error: String?) -> Unit) {
        Thread {
            try {
                // 1. Get presigned upload URL from Lambda
                val uploadUrlAndKey = getPresignedUploadUrl() ?: run {
                    onComplete(null, "Failed to get presigned URL")
                    return@Thread
                }
                val uploadUrl = uploadUrlAndKey.first
                val videoKey = uploadUrlAndKey.second

                // 2. Upload video bytes to S3
                val videoFile = File(videoUri.path ?: "")
                if (!videoFile.exists()) {
                    onComplete(null, "Video file not found")
                    return@Thread
                }

                val success = uploadBytesToUrl(uploadUrl, videoFile)
                if (success) {
                    Log.d("VideoRecorder", "Video uploaded to S3: $videoKey")
                    onComplete(videoKey, null)
                } else {
                    onComplete(null, "Upload failed")
                }
            } catch (e: Exception) {
                Log.e("VideoRecorder", "uploadVideoToS3 failed: ${e.localizedMessage}")
                onComplete(null, e.localizedMessage)
            }
        }.start()
    }

    private fun getPresignedUploadUrl(): Pair<String, String>? {
        return try {
            val lambdaUrl = try {
                context.resources.getString(context.resources.getIdentifier("lambda_url", "string", context.packageName))
            } catch (_: Exception) { "" }
            if (lambdaUrl.isEmpty()) return null

            val url = URL("$lambdaUrl?action=getPresignedUploadUrl")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 10000
            conn.readTimeout = 10000

            val responseCode = conn.responseCode
            if (responseCode !in 200..299) {
                Log.e("VideoRecorder", "Failed to get presigned URL: $responseCode")
                return null
            }

            val response = conn.inputStream.bufferedReader().use { it.readText() }
            conn.disconnect()

            // Parse JSON response: {"uploadUrl": "...", "videoKey": "..."}
            val uploadUrl = extractJsonField(response, "uploadUrl") ?: return null
            val videoKey = extractJsonField(response, "videoKey") ?: return null

            Pair(uploadUrl, videoKey)
        } catch (e: Exception) {
            Log.e("VideoRecorder", "getPresignedUploadUrl exception: ${e.localizedMessage}")
            null
        }
    }

    private fun uploadBytesToUrl(uploadUrl: String, videoFile: File): Boolean {
        return try {
            val url = URL(uploadUrl)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "PUT"
            conn.setRequestProperty("Content-Type", "video/mp4")
            conn.doOutput = true
            conn.connectTimeout = 30000
            conn.readTimeout = 30000

            val bytes = FileInputStream(videoFile).use { it.readBytes() }
            conn.outputStream.use { it.write(bytes) }

            val responseCode = conn.responseCode
            conn.disconnect()

            responseCode in 200..299
        } catch (e: Exception) {
            Log.e("VideoRecorder", "uploadBytesToUrl failed: ${e.localizedMessage}")
            false
        }
    }

    private fun extractJsonField(json: String, field: String): String? {
        val regex = """"$field"\s*:\s*"([^"]+)"""".toRegex()
        return regex.find(json)?.groupValues?.get(1)
    }
}
