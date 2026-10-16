# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Supabase / PostgreSQL
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Connectivity
-keep class com.baseflow.connectivity.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep annotations used by Flutter's deferred components
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod