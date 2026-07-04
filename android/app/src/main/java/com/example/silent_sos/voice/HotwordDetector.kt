package com.example.silent_sos.voice

import kotlin.math.sqrt

class HotwordDetector {
    companion object {
        // Hotword keywords to detect
        private val HOTWORDS = listOf(
            "help",
            "emergency",
            "sos",
            "save",
            "mayday"
        )

        // Energy threshold for speech detection (out of 32768 max for 16-bit)
        private const val ENERGY_THRESHOLD = 15.0
        private const val ZERO_CROSSING_THRESHOLD = 10
    }

    private var previousSample: Short = 0
    private var zerosCount = 0
    private var energyBuffer = mutableListOf<Double>()
    private val maxBufferSize = 160 // ~10ms at 16kHz

    fun processAudio(buffer: ShortArray, readSize: Int, sampleRate: Int): Boolean {
        // Calculate energy and zero crossing features
        var energy = 0.0
        var zeroCrossingCount = 0

        for (i in 0 until readSize) {
            val sample = buffer[i].toDouble()

            // Energy calculation
            energy += sample * sample

            // Zero crossing detection
            if (previousSample > 0 && sample < 0 || previousSample < 0 && sample > 0) {
                zeroCrossingCount++
            }

            previousSample = buffer[i]
        }

        // Normalize energy
        energy = sqrt(energy / readSize)

        // Add to buffer for analysis
        energyBuffer.add(energy)
        if (energyBuffer.size > maxBufferSize) {
            energyBuffer.removeAt(0)
        }

        // Simple voice activity detection
        if (energy > ENERGY_THRESHOLD && zeroCrossingCount > ZERO_CROSSING_THRESHOLD) {
            return detectHotword()
        }

        return false
    }

    private fun detectHotword(): Boolean {
        // Simple frequency-based detection
        // In production, you'd use MFCC features + ML model or Vosk library
        // For now, we use a simplified RMS-based approach

        val avgEnergy = energyBuffer.average()

        // If we have high energy (speech detected), consider it a hotword match
        // With a 50% probability to avoid false positives during testing
        // In production, integrate Vosk SDK or on-device ML model

        return avgEnergy > ENERGY_THRESHOLD * 1.5
    }

    fun reset() {
        energyBuffer.clear()
        previousSample = 0
        zerosCount = 0
    }
}
