import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Push notifications (D-063): Firebase is set up only when google-services.json is here (laptop file or the
// GOOGLE_SERVICES_JSON secret on GitHub Actions). Without it the app builds and runs with push off.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Upload key (D-060): from android/key.properties on the laptop, or from environment variables on GitHub Actions.
// With neither (e.g. a fresh clone), release builds fall back to the debug key so `flutter run --release` still works.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val uploadStoreFile = keyProps.getProperty("storeFile") ?: System.getenv("ANDROID_KEYSTORE_PATH")
val hasUploadKey = uploadStoreFile != null && file(uploadStoreFile).exists()

android {
    namespace = "com.solutiontee.cbt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.solutiontee.cbt"
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
        // AdMob app id (public, not a secret): SolutionTee CBT's own id from the owner's AdMob account (2026-11-07).
        manifestPlaceholders["admobAppId"] = (project.findProperty("ADMOB_APP_ID") as String?)
            ?: System.getenv("ADMOB_APP_ID") ?: "ca-app-pub-2578359096210288~4598149074"
    }

    // Two builds (D-061): "direct" = APK from the website, pays with Paystack;
    // "play" = Play Store, pays with Google Play Billing. Same app id, so one account per phone.
    // `flutter run` / `flutter build apk` use "direct" (pubspec.yaml default-flavor).
    flavorDimensions += "store"
    productFlavors {
        create("direct") { dimension = "store" }
        create("play") { dimension = "store" }
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(uploadStoreFile!!)
                storePassword = keyProps.getProperty("storePassword") ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = keyProps.getProperty("keyAlias") ?: System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = keyProps.getProperty("keyPassword") ?: System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
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

dependencies {
    // FileProvider for the in-app update of the direct app (D-080).
    implementation("androidx.core:core-ktx:1.13.1")
    // Paystack's own payment sheet inside the direct app (D-089). The Play app pays with Google Play Billing.
    "directImplementation"("com.paystack.android:paystack-ui:0.1.8")
}

// The newest Google Mobile Ads SDK pulls androidx.lifecycle 2.11 (compose parts), which needs compileSdk 37; our
// Android Gradle plugin supports 36. Keep lifecycle on 2.10.0 (what the app used before ads; forcing 2.9.4 is the likely cause of the start-up crash) until the toolchain moves to 37 (big update 2, step B).
configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "androidx.lifecycle") useVersion("2.10.0")
    }
}
