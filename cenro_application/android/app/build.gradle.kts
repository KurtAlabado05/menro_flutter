plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Parentheses are mandatory here!
    id("com.google.gms.google-services") 
}

android {
    namespace = "com.example.cenro_application"
    compileSdk = flutter.compileSdkVersion
    
    defaultConfig {
        applicationId = "com.example.cenro_application"
        
        // Change this from 'flutter.minSdkVersion' to 21
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}
