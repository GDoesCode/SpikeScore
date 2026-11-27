plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// SpikeScore Lite is this app built with --dart-define=SPIKESCORE_LITE=true
// (see app/LITE.md). Flutter hands the dart-defines to Gradle base64-encoded,
// so read them here and give Lite its own app ID and name. Without the flag
// the app is built exactly as before.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotEmpty() }
        ?.map { String(java.util.Base64.getDecoder().decode(it)) }
        ?.mapNotNull { d ->
            val i = d.indexOf('=')
            if (i > 0) d.substring(0, i) to d.substring(i + 1) else null
        }
        ?.toMap()
        ?: emptyMap()
val isLite = dartDefines["SPIKESCORE_LITE"] == "true"

android {
    namespace = "com.JustG.spikescore"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (isLite) "com.JustG.spikescore.lite" else "com.JustG.spikescore"
        manifestPlaceholders["appLabel"] = if (isLite) "SpikeScore Lite" else "spikescore"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
