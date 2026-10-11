[Türkçe](../../tr/lumina_ui/android-quest-packaging.md)

# Android and Meta Quest packaging

A project builds an Android APK, and with the **Meta Quest** XR profile a standalone headset app that launches immersive. This page covers the Android target from Project Settings to the headset: the settings, the manifest the build composes, the enabled plugins' runtime modules as game dependencies, signing, the cook, and Play on Device with a Quest.

## Project Settings → Packaging → Android

Tick **Android** under Target Platforms and an **Android** section appears (`.lmproject` `packaging.android`, `ProjectAndroidSettings` in `lumina_core`):

| Setting | Key | Default |
|---|---|---|
| XR Profile | `xr` | `none` (phone / tablet); `quest` for a headset |
| Application Id | `application_id` | empty: `com.lumina.<project_snake>` |
| Version | `version_name`, `version_code` | `1.0.0`, `1` |
| SDK Levels | `min_sdk`, `target_sdk` | `24` / `34`; Quest: `32` / `34` |
| ABIs | `abis` | `arm64-v8a` |
| Refresh Rate (Quest) | `refresh_rate` | `72` (90 and 120 selectable) |
| Multiview (Quest) | `multiview` | on |
| Impeller | `impeller` | on; off for Quest |
| Signing | `keystore_path`, `key_alias` | empty: Flutter's debug key |

The Quest floors come from Meta's Horizon Store requirements, read on 2026-10-11: minSdk 32 and targetSdk 34 are recommended for every in-lifecycle Quest, and apps created in the Developer Dashboard after 2026-03-01 must target API 34. Choosing the Quest profile raises the SDK levels to those floors, keeps arm64 only and turns Impeller off.

Keystore passwords are never stored in the project. Gradle reads them from `LUMINA_ANDROID_KEYSTORE_PASSWORD` and `LUMINA_ANDROID_KEY_PASSWORD` (the key password falls back to the store password).

**Manifest Preview** shows, read-only, the `AndroidManifest.xml` the next build composes. Each line carries its source: `template` (Flutter's manifest and your own edits to it), `project` (the project's settings) or the name of the plugin that contributed it.

## The composed manifest

`AndroidManifestComposer` (`lumina_editor_data/lib/src/packaging/android/`) writes the game's `android/app/src/main/AndroidManifest.xml` from three inputs:

1. Flutter's template, plus whatever you edited in it;
2. the project's Android settings: Impeller off becomes the `io.flutter.embedding.android.EnableImpeller=false` meta-data;
3. each enabled plugin's `android` contributions (below).

Everything it adds sits between `<!-- BEGIN LUMINA (generated) -->` and `<!-- END LUMINA (generated) -->` markers. There is one block per place: the features and permissions after `<manifest>`, the queries, the launcher activity's MAIN intent filter, and the `<application>` meta-data. Composing again removes those blocks first, so your edits outside them stay and the file does not grow. Disabling a plugin removes what it added.

Activity attributes cannot sit inside a comment, so they are set directly on the main activity's start tag. `configChanges` is merged as a set of flags. An attribute a plugin set stays after that plugin is disabled.

The output is deterministic: entries are sorted by name and duplicates are merged. A feature that any contributor requires is required, and the highest `version` wins. Android XR's `android.window.PROPERTY_XR_ACTIVITY_START_MODE` is always dropped, even from a hand-copied manifest, because Horizon OS ignores it.

## A plugin's `android` section

A plugin declares its manifest needs in its `.lmplugin` (`PluginAndroidContributions` in `lumina_core`):

```json
"android": {
  "uses_features": [
    {"name": "android.hardware.vr.headtracking", "required": true, "version": 1},
    {"name": "com.oculus.feature.PASSTHROUGH", "required": false, "required_when_used": "LuminaMetaPassthroughComponent"},
    {"name": "oculus.software.handtracking", "required": false, "when_used": "LuminaMetaHandTrackingComponent"}
  ],
  "permissions": ["org.khronos.openxr.permission.OPENXR", {"name": "com.oculus.permission.HAND_TRACKING", "when_used": "LuminaMetaHandTrackingComponent"}],
  "intent_categories": ["com.oculus.intent.category.VR", "org.khronos.openxr.intent.category.IMMERSIVE_HMD"],
  "meta_data": [{"name": "com.oculus.supportedDevices", "value": "quest3|quest3s|quest2|questpro"}],
  "queries": ["<provider android:authorities=\"org.khronos.openxr.runtime_broker;org.khronos.openxr.system_runtime_broker\" />"],
  "activity_attributes": {"launchMode": "singleTask", "screenOrientation": "landscape"}
}
```

- `when_used` names a component class: the entry is added only when one of the project's levels or Blueprints uses that class.
- `required_when_used` makes a feature required once that class is used.
- `queries` entries must each be one `<provider …/>` or `<intent>…</intent>` element.
- Unknown keys are refused with their path (for example `android.uses_features[0].requird`), and values are XML-escaped.

The OpenXR plugin contributes head tracking, the VR and IMMERSIVE_HMD launcher categories, the loader's broker permissions and queries, and the activity attributes of an immersive app. The MetaXR plugin contributes `com.oculus.supportedDevices`, passthrough (required when a level uses `LuminaMetaPassthroughComponent`), and hand tracking only when it is used.

## Runtime modules become game dependencies

Every enabled plugin with a `"type": "runtime"` module becomes a dependency of the game, without hand edits (`RuntimeModuleDependencies`):

- `pubspec.yaml` lists the plugin packages between `# BEGIN LUMINA PLUGINS (generated)` and `# END LUMINA PLUGINS` under `dependencies:`. A plugin folder in a git checkout with a remote is listed by URL and commit; any other plugin folder is listed by path.
- A git plugin that is checked out locally is pinned to that checkout in the gitignored `pubspec_overrides.yaml`, together with the local packages the plugin's own overrides name. Relinking the engine keeps that block.
- `lib/plugin_runtime_modules.g.dart` imports each module's library and calls `<registration_class>.register(kPluginRuntimeSettings)`. The generated `main()` runs `registerPluginRuntimeModules()` first. The settings map carries `project_name` and the project's Android settings (`xr`, `refresh_rate`, `multiview`, …).

These steps run before every target's build. Disabling a plugin and building again removes its dependency, its pins and its registration.

## Cook & Package

On the engine side, Android is buildable when the Android toolchain is ready (`flutter doctor`) and the Filament Android archives are on disk. `HostBuildTargets.androidArchivesReason` looks for `<filament>/out/android-release/filament/lib/arm64-v8a/libfilament.a` under `LUMINA_FILAMENT_DIR`, else under the engine's `flutter_filament.filament_dir` hook setting. When the archives are missing, the reason names `dart run tool/filament/fetch_prebuilt.dart --android`.

An Android cook then does the following:

1. composes the manifest and writes the Gradle settings. The application id is also the namespace, so `MainActivity` moves into that package. The step also writes the SDK levels, the versions, an `abiFilters` block and the release signing when a keystore is set. The Build Manager log shows the manifest's changed lines;
2. regenerates the game code;
3. runs `flutter build apk --release|--debug --target-platform android-arm64`;
4. copies the APK to `build/package/android/<project>-<version>.apk`, writes a `.sha256` next to it and reports its size. APKs above 1 GB, the store limit without expansion files, get a warning.

`lumina_editor_data/tool/android_quest/cook_android_quest_test.dart` runs the whole flow on this machine. It creates a blank project, enables OpenXR and MetaXR, cooks a Quest APK, and checks with `aapt2 dump xmltree` that every entry the composer generated is in the packaged manifest. It runs with `LUMINA_ANDROID_COOK=1` and is skipped without an Android SDK.

## Play on Device with a Meta Quest

Play's dropdown lists a connected headset by model, Horizon OS version (`ro.hzos.build.display_name`) and battery, for example `Quest 3S · Horizon OS 2.7.0` above `Android 14.0 ("UpsideDownCake") | arm64 | battery 93 %`. Choosing it does the following:

1. prepares the Android app with the project's Meta Quest profile. If the project has not chosen the Quest profile, its defaults are used for this run only;
2. regenerates the game code, so `main()` registers the plugins' runtime modules;
3. runs `flutter build apk --debug --target-platform android-arm64`, then `adb -s <serial> install -r …`;
4. launches the app with `adb -s <serial> shell am start -n <application id>/.MainActivity`;
5. streams `adb logcat --pid` into the Output Log.

While the game runs, the toolbar offers **Stop** (`am force-stop`) and two capture buttons:

- the camera button takes a screenshot with `adb exec-out screencap -p`;
- the video button records 15 s with `adb shell screenrecord --time-limit`, pulls the file and removes it from the device.

Both captures are saved into the project's `Saved/Captures/`. Without someone wearing the headset, captures show what the runtime composes: an immersive app's passthrough layer can appear dark there.

---

[Up: lumina_ui](index.md)
