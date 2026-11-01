# PG Khata release ProGuard/R8 rules.
#
# This app has no native/C++ code and every plugin currently used
# (flutter_riverpod, go_router, google_fonts, url_launcher, image_picker,
# file_picker, csv, supabase_flutter, flutter_dotenv) is a well-behaved,
# mature Flutter plugin — none of them are known to need custom -keep rules
# beyond what the Flutter Gradle plugin already bundles automatically.
#
# The one rule below is NOT optional: Flutter's engine references Play
# Core's deferred-components/split-install APIs even when a project (like
# this one) never uses deferred components, and those classes aren't on
# the compile classpath — without this, R8 fails the build with
# "Missing class com.google.android.play.core...". This is a known,
# widely-documented Flutter+R8 interaction, not specific to this app.
-dontwarn com.google.android.play.core.**

# If a future release build fails with a "missing class"/"can't find
# referenced class" R8 error for a specific plugin, add a targeted -keep
# for that class here rather than broadening this file speculatively.
