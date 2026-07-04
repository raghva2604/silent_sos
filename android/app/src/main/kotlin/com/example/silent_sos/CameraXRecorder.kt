package com.example.silent_sos

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class CameraXRecorder(
    private val context: Context
) {

    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var videoCapture: VideoCapture<Recorder>? = null

    fun record(
        cameraSelector: CameraSelector,
        durationSec: Int,
        onFinished: (String) -> Unit
    ) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()

                val recorder = Recorder.Builder()
                    .setQualitySelector(QualitySelector.from(Quality.HD))
                    .build()

                videoCapture = VideoCapture.withOutput(recorder)

                // Create a minimal lifecycle owner for the service
                val lifecycleOwner = object : LifecycleOwner {
                    private val registry = LifecycleRegistry(this)
                    init {
                        registry.currentState = Lifecycle.State.STARTED
                    }
                    override val lifecycle: Lifecycle
                        get() = registry
                }

                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    videoCapture
                )

                val videoDir = File(context.getExternalFilesDir(null), "sos_videos")
                if (!videoDir.exists()) {
                    videoDir.mkdirs()
                }

                val outputFile = File(
                    videoDir,
                    "sos_${System.currentTimeMillis()}.mp4"
                )

                Log.d("CameraXRecorder", "Recording to: ${outputFile.absolutePath}")

                val outputOptions = FileOutputOptions.Builder(outputFile).build()

                val recording = videoCapture!!.output
                    .prepareRecording(context, outputOptions)
                    .apply {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            withAudioEnabled()
                        }
                    }
                    
                    .start(ContextCompat.getMainExecutor(context)) { event ->
                        when (event) {
                            is VideoRecordEvent.Start -> {
                                Log.d("CameraXRecorder", "Recording started: ${outputFile.name}")
                            }
                            is VideoRecordEvent.Finalize -> {
                                if (event.hasError()) {
                                    Log.e("CameraXRecorder", "Recording error: ${event.error}")
                                    onFinished("")
                                } else {
                                    Log.d("CameraXRecorder", "Recording finished: ${outputFile.absolutePath}")
                                    onFinished(outputFile.absolutePath)
                                }
                                cameraProvider.unbindAll()
                            }
                            else -> {}
                        }
                    }

                // Stop after duration
                Thread {
                    Thread.sleep(durationSec * 1000L)
                    recording.stop()
                }.start()

            } catch (e: Exception) {
                Log.e("CameraXRecorder", "Recording setup error: ${e.message}", e)
                onFinished("")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun shutdown() {
        cameraExecutor.shutdown()
    }
}

