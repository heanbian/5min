# Keep Compose / app entry points used via reflection
-keepclassmembers class * extends android.app.Application { *; }
-keepclassmembers class * extends android.app.Service { *; }
-keepclassmembers class * extends android.content.BroadcastReceiver { *; }

# Kotlin / Coroutines
-dontwarn kotlinx.coroutines.**
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Shared JSON catalog keys are string-based; no model obfuscation needed beyond defaults
