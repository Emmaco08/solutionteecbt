# Release-build shrinker (R8) rules for SolutionTee CBT (big update 2, step B).
#
# Google Mobile Ads brings WorkManager. WorkManager creates its Room database by reflection ("WorkDatabase_Impl"),
# and R8 removed/renamed it, so the app crashed on start: "Failed to create an instance of
# androidx.work.impl.WorkDatabase". Keep Room databases and WorkManager's own classes.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# Google Mobile Ads and the consent SDK (their own rules normally cover this; kept explicitly for safety).
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.ads.**
