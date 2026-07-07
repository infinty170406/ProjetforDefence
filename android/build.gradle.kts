allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    project.repositories.configureEach {
        if (this is MavenArtifactRepository) {
            if (url.toString().contains("jcenter.bintray.com")) {
                url = uri("https://repo1.maven.org/maven2/")
            }
        }
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

    project.plugins.configureEach {
        if (this is com.android.build.gradle.LibraryPlugin) {
            project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                buildToolsVersion = "36.1.0"
                if (namespace == null) {
                    namespace = "com.fix.missing.namespace.${project.name.replace("-", "_")}"
                }
            }
        }
        if (this is com.android.build.gradle.AppPlugin) {
            project.extensions.configure<com.android.build.gradle.AppExtension> {
                buildToolsVersion = "36.1.0"
            }
        }
    }

    project.afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            android.compileSdkVersion(36)
        }
    }

    project.evaluationDependsOn(":app")
}






tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
