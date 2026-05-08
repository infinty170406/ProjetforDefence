# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Background service
-keep class id.flutter.flutter_background_service.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Ton app
-keep class app.theguardian.child.** { *; }

# Général
-keepattributes *Annotation*
-dontwarn io.flutter.**