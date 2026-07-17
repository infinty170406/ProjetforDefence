plugins {
    id("com.google.gms.google-services") version "4.4.1" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// API moderne (Gradle 8+) au lieu de rootProject.buildDir / project.buildDir,
// dépréciés et sources d'avertissements bloquants avec Gradle 8.13.
rootProject.layout.buildDirectory.set(file("../build"))
subprojects {
    project.layout.buildDirectory.set(
        file("${rootProject.layout.buildDirectory.get().asFile}/${project.name}")
    )
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
            force("androidx.appcompat:appcompat:1.6.1")
            force("androidx.emoji2:emoji2:1.4.0")
            force("androidx.emoji2:emoji2-views-helper:1.4.0")
        }
    }
}

subprojects {
    project.configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.support" && !requested.name.contains("multidex")) {
                useVersion("28.0.0")
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Fix Build Tools : certains plugins Flutter (ex. app_links) ne déclarent pas
// leur propre buildToolsVersion et retombent sur le défaut d'AGP (34.0.0).
// On force donc la même version sur tous les sous-modules. Note : on utilise
// buildToolsVersion (String), PAS compileSdk (Int), qui n'existe pas sur
// BaseExtension.
// ---------------------------------------------------------------------------
subprojects {
    if (project.name != "app") {
        project.plugins.configureEach {
            if (this is com.android.build.gradle.LibraryPlugin) {
                project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                    buildToolsVersion = "36.1.0"
                    compileSdkVersion(36)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}