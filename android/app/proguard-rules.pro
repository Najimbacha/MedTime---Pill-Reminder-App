# ML Kit Text Recognition - Ignore missing optional languages
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# RevenueCat ProGuard Rules
-keep class com.revenuecat.purchases.** { *; }

# AdMob ProGuard Rules
-keep public class com.google.android.gms.ads.** {
   public *;
}
