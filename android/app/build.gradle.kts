plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.howmuch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    val configuredApplicationId = providers.gradleProperty("howmuchApplicationId")
        .orElse(providers.environmentVariable("HOWMUCH_APPLICATION_ID"))
        .orElse("com.example.howmuch")
        .get()
    val releaseStoreFile = providers.gradleProperty("howmuchReleaseStoreFile")
        .orElse(providers.environmentVariable("HOWMUCH_RELEASE_STORE_FILE")).orNull
    val releaseStorePassword = providers.gradleProperty("howmuchReleaseStorePassword")
        .orElse(providers.environmentVariable("HOWMUCH_RELEASE_STORE_PASSWORD")).orNull
    val releaseKeyAlias = providers.gradleProperty("howmuchReleaseKeyAlias")
        .orElse(providers.environmentVariable("HOWMUCH_RELEASE_KEY_ALIAS")).orNull
    val releaseKeyPassword = providers.gradleProperty("howmuchReleaseKeyPassword")
        .orElse(providers.environmentVariable("HOWMUCH_RELEASE_KEY_PASSWORD")).orNull
    val releaseSigningConfigured = listOf(
        releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword,
    ).all { !it.isNullOrBlank() } && configuredApplicationId != "com.example.howmuch"

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = configuredApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }

    val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
        taskName.endsWith("assembleRelease") || taskName.endsWith("bundleRelease")
    }
    if (releaseTaskRequested) {
        check(releaseSigningConfigured) {
            "Android release requires HOWMUCH_APPLICATION_ID and release keystore properties. Debug signing is disabled."
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
