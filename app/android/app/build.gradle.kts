import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.quantlog.pension_compass"
    compileSdk = 36  // targetSdk 36 요구 (flutter 기본값이 낮을 수 있어 명시)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.quantlog.pensioncompass"
        minSdk = flutter.minSdkVersion
        // Play 정책(2026-08-31): 최신 안드로이드 1년 이내 타겟 필수 — API 36.
        // 구 35 고정 사유였던 AdMob WorkManager 크래시는 work-runtime 2.10.1
        // 명시 + proguard keep 으로 근본 수정됨 (dd52da7) — 실기기 기동 검증 완료.
        targetSdk = 36  // Android 16
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

dependencies {
    // play-services-ads 25.x가 초기화하는 WorkManager가 transitive로 work 2.7.0/room 2.2.5
    // 화석 버전에 잡혀 기동 즉시 WorkDatabase 생성 크래시 → 최신 강제 (2026-07-09 실기기 진단)
    implementation("androidx.work:work-runtime:2.10.1")
}
