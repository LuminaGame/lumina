// The Android part of the plugin is only a library module for Flutter's plugin
// loader: libflutter_filament.so comes from the native-assets hook
// (hook/build.dart), not from a CMake build here.
plugins {
    id("com.android.library")
}

android {
    namespace = "com.lumina.flutter_filament"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
    }
}
