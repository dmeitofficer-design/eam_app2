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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ─── FORCE ALL SUBPROJECTS TO COMPILE AGAINST API 36 SAFELY ─────────────────
subprojects {
    val configureAndroid = {
        if (hasProperty("android")) {
            val androidExt = extensions.findByName("android")
            androidExt?.javaClass?.methods?.forEach { method ->
                if (method.name == "setCompileSdk" || method.name == "setCompileSdkVersion") {
                    try {
                        method.invoke(androidExt, 36)
                    } catch (e: Exception) {
                        // Fail silently
                    }
                }
            }
        }
    }

    // Check if the project configuration is already locked/completed
    if (state.executed) {
        configureAndroid()
    } else {
        afterEvaluate { 
            configureAndroid() 
        }
    }
}