plugins {
    id("com.android.application") version "9.5.1" apply false
    // Compose compiler plugin is still separate from AGP built-in Kotlin.
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.21" apply false
}
