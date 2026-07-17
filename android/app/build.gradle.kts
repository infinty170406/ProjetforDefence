import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("kotlin-kapt")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Keystore credentials are deliberately kept outside source control.
// Copy ../key.properties.example to ../key.properties locally, or have CI
// generate android/key.properties from its secret store before a release build.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

android {
    namespace = "app.theguardian.child"
    compileSdk = 36
    buildToolsVersion = "36.1.0"
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "app.theguardian.child"
        minSdk = 24
        targetSdk = 35
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = requireNotNull(keystoreProperties.getProperty("storeFile")) {
                    "Missing storeFile in android/key.properties"
                }
                storeFile = rootProject.file(storeFilePath)
                storePassword = requireNotNull(keystoreProperties.getProperty("storePassword")) {
                    "Missing storePassword in android/key.properties"
                }
                keyAlias = requireNotNull(keystoreProperties.getProperty("keyAlias")) {
                    "Missing keyAlias in android/key.properties"
                }
                keyPassword = requireNotNull(keystoreProperties.getProperty("keyPassword")) {
                    "Missing keyPassword in android/key.properties"
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

// Keep debug builds usable without a local release key, but prevent an unsigned
// or accidentally debug-signed release from being assembled.
tasks.matching { it.name == "validateSigningRelease" }.configureEach {
    doFirst {
        check(keystorePropertiesFile.exists()) {
            "Release signing is not configured. Create android/key.properties from key.properties.example."
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    // Room — historique local persistant (indépendant de Flutter)
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")
    // Coroutines (CoroutineWorker + Firebase await())
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
    // Firebase Android SDK natif — sync directe sans Flutter
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-functions")
    testImplementation("junit:junit:4.13.2")
}

configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.13.1")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.appcompat:appcompat:1.6.1")
        force("androidx.emoji2:emoji2:1.4.0")
        force("androidx.emoji2:emoji2-views-helper:1.4.0")
    }
}
