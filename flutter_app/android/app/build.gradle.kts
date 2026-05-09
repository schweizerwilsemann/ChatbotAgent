plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

androidComponents {
    beforeVariants(
        selector()
            .withFlavor("env" to "appDev")
            .withBuildType("release")
    ) { variantBuilder ->
        variantBuilder.enable = false
    }
}

android {
    namespace = "com.example.sports_venue_chatbot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.sports_venue_chatbot"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"
    productFlavors {
        create("appDev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Sports Venue [DEV]")
        }
        create("appDevRelease") {
            dimension = "env"
            applicationIdSuffix = ".devrelease"
            versionNameSuffix = "-dev-release"
            resValue("string", "app_name", "Sports Venue [DEV RELEASE]")
        }
        create("appProd") {
            dimension = "env"
            resValue("string", "app_name", "Sports Venue")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
