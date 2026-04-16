-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keepattributes *Annotation*
-dontwarn com.google.firebase.**

-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.**

# Used by several Flutter plugins (HTTP stack).
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
