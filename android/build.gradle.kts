allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
plugins {
    id("com.android.application") apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
    id("org.jetbrains.kotlin.android") apply false
    id("dev.flutter.flutter-gradle-plugin") apply false
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

subprojects {
    project.plugins.configureEach {
        if (this is com.android.build.gradle.LibraryPlugin) {
            project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                if (namespace == null) {
                    namespace = "com.fix.missing.namespace.${project.name.replace("-", "_")}"
                }
            }
        }
    }
}






tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
