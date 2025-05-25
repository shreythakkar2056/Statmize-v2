plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app"               // Replace with your app's namespace
    compileSdk = flutter.compileSdkVersion      // Uses Flutter compileSdkVersion
    ndkVersion = "27.0.12077973"                 // Set your NDK version if needed

    defaultConfig {
        applicationId = "com.example.app"        // Replace with your app ID
        minSdk = 31                             // Set minimum SDK to 31 for Bluetooth permissions
        targetSdk = flutter.targetSdkVersion      // Flutter target SDK version
        versionCode = flutter.versionCode         // App version code
        versionName = flutter.versionName         // App version name
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        getByName("release") {
            // Using debug signingConfig here, change if you have a release signing config
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."    // Points to the Flutter module location relative to this file
}