allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround: some third-party plugin Android modules (older versions) do not
// specify an `android.namespace` in their Gradle scripts which causes AGP
// to fail during configuration on newer Android Gradle Plugin versions.
// For known plugin modules (e.g., the `record` plugin), set a default
// namespace here after evaluation to allow the build to continue. This is a
// local workaround; prefer upgrading plugin versions for long-term fixes.
try {
    // Import is optional — the class will be available when the Android Gradle
    // plugin is on the classpath during configuration.
    @Suppress("UNUSED_VARIABLE")
    val libExtClass = try {
        Class.forName("com.android.build.gradle.LibraryExtension")
    } catch (_: Throwable) { null }

    subprojects {
        afterEvaluate {
            try {
                if (project.name == "record") {
                    val androidExt = extensions.findByName("android")
                    if (androidExt != null) {
                        // Use reflection to set the namespace property to avoid
                        // a hard dependency on the AGP classes at Gradle config time.
                        try {
                            val method = androidExt::class.java.methods.firstOrNull { m -> m.name == "setNamespace" || m.name == "namespace" }
                            if (method != null) {
                                // prefer setter if available
                                try {
                                    method.invoke(androidExt, "com.example.record")
                                } catch (_: Throwable) {
                                    try {
                                        // fallback: attempt to set field via reflection
                                        val f = androidExt::class.java.getDeclaredField("namespace")
                                        f.isAccessible = true
                                        f.set(androidExt, "com.example.record")
                                    } catch (_: Throwable) {}
                                }
                            }
                        } catch (_: Throwable) {}
                    }
                }
            } catch (_: Throwable) {}
        }
    }
} catch (_: Throwable) {}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
