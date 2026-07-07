plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
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
            storeFile = file("../guardian-release.jks")
            storePassword = "guardian123"
            keyAlias = "guardian-key"
            keyPassword = "guardian123"
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

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
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

// ---------------------------------------------------------------------------
// Fix : certains plugins Flutter (ex. app_links) ne déclarent pas leur propre
// buildToolsVersion et retombent sur la version par défaut d'AGP 8.7.0, qui
// est 34.0.0 — même si ce module "app" force 36.1.0. On force donc la même
// version de Build Tools sur TOUS les sous-projets pour éviter que Gradle
// aille chercher une version non installée.
// ---------------------------------------------------------------------------
rootProject.subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.buildToolsVersion = "36.1.0"
    }
}