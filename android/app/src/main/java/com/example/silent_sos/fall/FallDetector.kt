package com.example.silent_sos.fall

import android.hardware.SensorManager
import kotlin.math.sqrt

class FallDetector(
    private val onFallDetected: () -> Unit
) {
    companion object {
        private const val GRAVITY_EARTH = SensorManager.GRAVITY_EARTH
        private const val STILLNESS_THRESHOLD = 0.5f // m/s²
        private const val STILLNESS_CHECK_DURATION = 2000L // 2 seconds
    }

    private var lastAccelX = 0f
    private var lastAccelY = 0f
    private var lastAccelZ = 0f

    private var impactDetectedTime = 0L
    private var stillnessStartTime = 0L
    private var isCheckingStillness = false

    fun processAccelerometerData(
        x: Float,
        y: Float,
        z: Float,
        userThreshold: Float,
        timestamp: Long
    ) {
        // Calculate total acceleration (gForce)
        val gForce = sqrt(x * x + y * y + z * z) / GRAVITY_EARTH

        // Detect impact (acceleration above threshold)
        if (gForce > userThreshold && !isCheckingStillness) {
            impactDetectedTime = timestamp
            isCheckingStillness = true
            stillnessStartTime = timestamp
        }

        // If we're checking for stillness after impact
        if (isCheckingStillness) {
            // Calculate current acceleration magnitude
            val currentMagnitude = sqrt(x * x + y * y + z * z) / GRAVITY_EARTH

            // Check if device is still (low acceleration = close to gravity only)
            val expectedGravity = GRAVITY_EARTH
            val actualDifference = currentMagnitude - expectedGravity

            // Update last known accelerations for derivative (motion detection)
            val deltaX = (x - lastAccelX)
            val deltaY = (y - lastAccelY)
            val deltaZ = (z - lastAccelZ)
            val motionDelta = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)

            // If stillness detected (low motion change and low variance from gravity)
            if (motionDelta < STILLNESS_THRESHOLD && actualDifference.absoluteValue < 0.3f) {
                val stillnessDuration = timestamp - stillnessStartTime

                // If stillness maintained for minimum duration, trigger fall
                if (stillnessDuration >= STILLNESS_CHECK_DURATION) {
                    onFallDetected()
                    resetState()
                    return
                }
            } else {
                // Motion detected, reset stillness check
                stillnessStartTime = timestamp
            }

            // Timeout: if more than 3 seconds since impact without confirmed fall
            if (timestamp - impactDetectedTime > 3000L) {
                resetState()
            }
        }

        // Update last accelerations
        lastAccelX = x
        lastAccelY = y
        lastAccelZ = z
    }

    private fun resetState() {
        isCheckingStillness = false
        impactDetectedTime = 0L
        stillnessStartTime = 0L
    }
}

// Extension for Float.absoluteValue (in case not available in older SDK)
private val Float.absoluteValue: Float get() = if (this < 0) -this else this
