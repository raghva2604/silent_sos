plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "com.example.silent_sos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Keep Java 11 compatibility; enable core library desugaring required by some plugins
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.silent_sos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Load key.properties if present for release signing and ensure the referenced keystore file exists
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    var hasKeystore = false
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        val fileProp = (keystoreProperties["storeFile"] as String?) ?: ""
        if (fileProp.isNotEmpty()) {
            val resolved = rootProject.file(fileProp)
            if (resolved.exists()) {
                hasKeystore = true
            }
        }
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                // Resolve keystore path relative to the root project (key.properties may use ../key.jks)
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use release signing config only when a valid keystore file is present.
            if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Fallback to debug signing so local --release builds still succeed without a keystore
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for core library desugaring used by some Android AARs (e.g., flutter_local_notifications)
    // Updated to 2.1.4+ to satisfy AAR metadata requirements (see Flutter plugin errors)
    add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
    // Vosk offline speech recognition (AAR from Maven Central)
    implementation("com.alphacephei:vosk-android:0.3.38")
    // OkHttp for HTTP upload/download in ForegroundRecordingService
    implementation("com.squareup.okhttp3:okhttp:4.11.0")
    // Location services used by SosForegroundService for live location updates
    implementation("com.google.android.gms:play-services-location:21.0.1")

    // Coroutines and lifecycle runtime needed for coroutine-based downloads and lifecycleScope
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")
    
    // CameraX dependencies for native camera integration
    implementation("androidx.camera:camera-core:1.3.0")
    implementation("androidx.camera:camera-camera2:1.3.0")
    implementation("androidx.camera:camera-lifecycle:1.3.0")
    implementation("androidx.camera:camera-view:1.3.0")
    
    // WorkManager for background upload tasks
    implementation("androidx.work:work-runtime-ktx:2.8.1")
    
    // Lottie for animations
    implementation("com.airbnb.android:lottie:6.1.0")
    
    // Google Guava for CameraX ListenableFuture
    implementation("com.google.guava:guava:31.1-android")
}
