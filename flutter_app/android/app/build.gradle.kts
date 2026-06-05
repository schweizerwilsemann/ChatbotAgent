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

dependencies {
    implementation(files("libs/merchant-1.0.25.aar"))
    implementation("com.google.code.gson:gson:2.8.5")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.appcompat:appcompat:1.2.0")
    implementation("androidx.fragment:fragment:1.3.0")
    implementation("androidx.constraintlayout:constraintlayout:2.0.4")
}

configurations.all {
    resolutionStrategy {
        force("com.squareup.okhttp3:okhttp:4.12.0")
    }
}

flutter {
    source = "../.."
}
