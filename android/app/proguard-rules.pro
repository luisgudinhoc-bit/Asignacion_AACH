# Reglas de optimización y compatibilidad ProGuard / R8
-dontwarn com.google.mlkit.**
-dontwarn com.google_mlkit_text_recognition.**
-dontwarn com.google.android.gms.**

-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google.android.gms.** { *; }
