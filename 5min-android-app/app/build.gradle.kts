import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
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
    // Compose BOM 2026.11.01 requires compileSdk 37.1+
    compileSdk {
        version = release(37) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        // Android package segments cannot start with a digit; use fivemin (not 5min).
        applicationId = "chat.fivemin.app"
        minSdk = 26
        targetSdk = 37
        versionCode = 18
        versionName = "1.0.18"
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
                "proguard-rules.pro",
            )
            if (keystorePropsFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
    compileOptions {
        // Language / bytecode level: Java 25 LTS (Gradle 9.1+ / AGP 9.5+).
        sourceCompatibility = JavaVersion.VERSION_25
        targetCompatibility = JavaVersion.VERSION_25
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
    jvmToolchain(25)
}

// APK name: 5min-android-app-{versionName}.apk (AGP 9 Variant API)
androidComponents {
    onVariants { variant ->
        val ver = variant.outputs.first().versionName
        variant.outputs.forEach { output ->
            output.outputFileName.set(
                ver.map { name -> "5min-android-app-${name ?: "unsigned"}.apk" },
            )
        }
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
    val composeBom = platform("androidx.compose:compose-bom:2026.11.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.11.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.1")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.1")
    implementation("androidx.lifecycle:lifecycle-service:2.11.1")
    implementation("androidx.core:core-ktx:1.19.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
}
