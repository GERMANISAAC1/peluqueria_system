// android/app/build.gradle.kts
// ⚠️ Reemplaza "com.example.focus_app" por tu applicationId real (debe
// coincidir con el paquete de MainActivity.kt, AppBlockAccessibilityService.kt
// y BootReceiver.kt, y con lo declarado en AndroidManifest.xml).

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.focus_app"
    // compileSdk 36: shared_preferences_android (y otros plugins modernos)
    // ya lo exigen. AGP es retrocompatible, así que compilar contra un SDK
    // más nuevo no reduce el rango de dispositivos que soporta tu app; eso
    // lo controla exclusivamente "minSdk" más abajo.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.focus_app"
        minSdk = 29        // Android 10 — requisito del proyecto
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // TODO producción: reemplazar por tu propio signingConfig antes
            // de publicar; con "debug" solo sirve para builds de prueba.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
