@file:Suppress("DEPRECATION")

import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import java.io.File
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Release signing: copy keystore.properties.example → keystore.properties (gitignored)
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties()
if (keystorePropsFile.exists()) {
    keystorePropsFile.inputStream().use { keystoreProps.load(it) }
}

android {
    namespace = "chat.fivemin.app"
    compileSdk = 37

    defaultConfig {
        // Android package segments cannot start with a digit; use fivemin (not 5min).
        applicationId = "chat.fivemin.app"
        minSdk = 26
        targetSdk = 37
        versionCode = 12
        versionName = "1.0.12"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        create("release") {
            if (keystorePropsFile.exists()) {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (keystorePropsFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

// 正式包文件名：5min-android-app-{versionName}.apk / .aab
android.applicationVariants.configureEach {
    val ver = versionName
    outputs.configureEach {
        (this as BaseVariantOutputImpl).outputFileName = "5min-android-app-$ver.apk"
    }
}

afterEvaluate {
    tasks.findByName("bundleRelease")?.doLast {
        val ver = android.defaultConfig.versionName
        val dir = layout.buildDirectory.dir("outputs/bundle/release").get().asFile
        val wanted = File(dir, "5min-android-app-$ver.aab")
        dir.listFiles()
            ?.filter { it.isFile && it.extension == "aab" && it.absolutePath != wanted.absolutePath }
            ?.forEach { src ->
                if (wanted.exists()) wanted.delete()
                src.renameTo(wanted)
            }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0")
    implementation("androidx.lifecycle:lifecycle-service:2.11.0")
    implementation("androidx.core:core-ktx:1.19.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("androidx.datastore:datastore-preferences:1.3.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
