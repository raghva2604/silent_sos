import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException

object SilentSOSApi {

    // 🔐 Your Lambda Function URL
    private const val LAMBDA_URL =
        "https://yc5qjfslrvzcyxjo4rbtfxuun40vdivu.lambda-url.ap-south-1.on.aws/"

    // 🔐 Same secret as Lambda
    private const val APP_SECRET = "Niha@2604"

    private val client = OkHttpClient()

    fun getSecureVideoLink(
        videoKey: String,
        callback: (String?) -> Unit
    ) {
        val json = JSONObject()
        json.put("videoKey", videoKey)

        val body = json.toString()
            .toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url(LAMBDA_URL)
            .post(body)
            .addHeader("Content-Type", "application/json")
            .addHeader("x-app-secret", APP_SECRET) // ✅ REQUIRED
            .build()

        client.newCall(request).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: IOException) {
                e.printStackTrace()
                callback(null)
            }

            override fun onResponse(
                call: okhttp3.Call,
                response: okhttp3.Response
            ) {
                response.use {
                    if (!it.isSuccessful) {
                        callback(null)
                        return
                    }

                    val responseBody = it.body?.string()
                    val jsonResponse = JSONObject(responseBody ?: "")
                    val downloadUrl = jsonResponse.optString("downloadUrl")

                    callback(downloadUrl)
                }
            }
        })
    }
}
