plugins {
    id("com.google.gms.google-services") version "4.4.1" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
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

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}