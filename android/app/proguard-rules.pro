# ==============================================================================
# OMNI Motorista PRO — Regras R8 / ProGuard para Build Release (APK / AAB)
# Destino: android/app/proguard-rules.pro
# Resolve erro :app:minifyReleaseWithR8 do google_mlkit_text_recognition
# ==============================================================================

# 1. Google ML Kit Text Recognition — Suprime classes opcionais de alfabetos asiáticos/índicos
#    (O app utiliza apenas TextRecognitionScript.latin para CPF, RG/CIN, CNH, CRLV e Comprovantes)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# 2. Preserva classes essenciais do Google ML Kit (Face Detection + OCR Latin)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.android.gms.internal.mlkit_**

# 3. Flutter / Gson / Firebase Realtime Database
-keepattributes *Annotation*
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepclassmembers class * {
    @com.google.firebase.database.PropertyName <fields>;
    @com.google.firebase.database.PropertyName <methods>;
}
