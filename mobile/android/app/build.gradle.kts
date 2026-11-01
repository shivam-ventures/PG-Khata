import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Real release signing (fixed 2026-09-25 — see the pre-launch audit, P0-3:
// the release build type was signing with the debug keystore, which cannot
// be uploaded to Play Console). Reads mobile/android/key.properties, which
// is gitignored (android/.gitignore already listed it) — never committed,
// same treatment as local.properties. See key.properties.example for the
// format and mobile/README.md for how to generate the actual keystore.
//
// Falls back to debug signing when key.properties is absent (e.g. a fresh
// checkout, or a developer who only ever runs `flutter run --release`
// locally) so that workflow keeps working without every contributor
// needing a real upload keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.pgkhata.pg_khata"
    compileSdk = flutter.compileSdkVersion
    // No ndkVersion: this app and its current plugins (go_router, flutter_riverpod,
    // google_fonts, url_launcher) have no native/C++ code. Setting ndkVersion makes
    // AGP verify/auto-install that NDK release (a ~2.8GB download) even though
    // nothing here would ever use it. Add it back if a future plugin needs the NDK.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pgkhata.pg_khata"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties on this machine — fall back to debug
                // signing so `flutter run --release` still works locally.
                // A build signed this way must never be distributed; see
                // mobile/README.md for generating a real upload keystore.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
