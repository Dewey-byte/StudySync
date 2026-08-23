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

// Some plugins (e.g. flutter_secure_storage 11) declare a compileSdk newer than the
// one Flutter targets. The Android SDK now publishes those platforms with a minor
// version ("android-37.0") while AGP resolves them by major only ("android-37"), so
// the build fails to find the target. Clamp plugin modules to the app's compileSdk.
val appCompileSdk = 36

subprojects {
    val clampCompileSdk = {
        extensions.findByName("android")?.withGroovyBuilder {
            val declared = getProperty("compileSdk") as? Int
            if (declared != null && declared > appCompileSdk) {
                setProperty("compileSdk", appCompileSdk)
            }
        }
        Unit
    }
    // `evaluationDependsOn(":app")` above may already have evaluated this project.
    if (state.executed) clampCompileSdk() else afterEvaluate { clampCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
