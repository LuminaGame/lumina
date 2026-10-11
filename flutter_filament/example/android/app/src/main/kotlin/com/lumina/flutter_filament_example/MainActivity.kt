package com.lumina.flutter_filament_example

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Creates the app's external files folder (Android/data/<id>/files) as
        // the app's own, so models pushed there with adb are readable by the
        // first light sample.
        getExternalFilesDir(null)?.resolve("first_light")?.mkdirs()
    }
}
