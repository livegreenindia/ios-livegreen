import java.util.Properties
import java.io.FileInputStream
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.livegreen.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Load properties from key.properties
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.livegreen.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Keep native debug symbols for crash reporting
        ndk {
            debugSymbolLevel = "SYMBOL_TABLE"
        }
        
        // Google Maps API key from key.properties
        val mapsApiKey = keystoreProperties["MAPS_API_KEY"] as String? ?: ""
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        create("release") {
            // Resolve keystore file relative to the android project root
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                storeFile = rootProject.file(storeFilePath)
            }
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Enable R8 code shrinking and obfuscation
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    
    // Configure native libraries packaging
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
            // Keep debug symbols for crash reporting
            keepDebugSymbols += listOf("*/arm64-v8a/*.so", "*/armeabi-v7a/*.so", "*/x86_64/*.so", "*/x86/*.so")
        }
    }
}

flutter {
    source = "../.."
}
