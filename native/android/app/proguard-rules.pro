# Mosslet ProGuard Rules

# Keep native bridge classes
-keep class com.mosslet.app.JsonBridge { *; }
-keep class com.mosslet.app.Bridge { *; }
-keep class com.mosslet.app.SecureStorage { *; }
-keep class com.mosslet.app.PushNotificationService { *; }

# Keep WebView JavaScript interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }

# AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
