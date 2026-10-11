[Türkçe](../../tr/lumina_editor_data/packaging.md)

# Packaging (Android)

`lib/src/packaging/` prepares a game for an Android build: the manifest, the Gradle settings and the enabled plugins' runtime modules. Lumina Studio's Build Manager, Project Settings and Play on Device call it through `AndroidPackagingHooks` (lumina_ui). The workflow is described in [Android and Meta Quest packaging](../lumina_ui/android-quest-packaging.md).

## `lib/src/packaging/android/android_manifest_composer.dart`

| Member | Purpose |
| :--- | :--- |
| `AndroidManifestComposer.compose({template, settings, plugins, usedClasses})` | Flutter's template + `ProjectAndroidSettings` + each plugin's `PluginAndroidContributions` → `ComposedAndroidManifest`. The additions go between `begin` / `end` markers, one block per place. Composing again first removes the earlier blocks (`withoutGenerated`). The output is sorted and duplicates are merged: the stronger `required` and the highest `version` win. Activity attributes are set on the main activity, with `configChanges` merged. `refusedProperties` (Android XR's start mode) are dropped. |
| `ComposedAndroidManifest` | `xml`, `lines` (each a `ComposedManifestLine` with its `source`: `template`, `project` or a plugin name), `summary`. |

## `lib/src/packaging/android/android_gradle_configurator.dart`

`AndroidGradleConfigurator.configure(gradle, settings, projectName)` rewrites `android/app/build.gradle.kts`. It writes the namespace and application id (one value), `minSdk`, `targetSdk`, `versionCode`, `versionName`, an `abiFilters` block and the signing. With a keystore the signing uses a `luminaRelease` config whose passwords come from `LUMINA_ANDROID_KEYSTORE_PASSWORD` / `LUMINA_ANDROID_KEY_PASSWORD`; without one it uses Flutter's debug key. `apply(projectDir, settings, projectName)` also moves `MainActivity` into the new package.

## `lib/src/packaging/runtime_module_dependencies.dart`

| Member | Purpose |
| :--- | :--- |
| `RuntimeModuleDependencies.resolve(enabled)` | The enabled plugins' runtime modules as `RuntimeModuleDependency`: the package, the library, the registration class, the git source (URL, path in the repository, HEAD) when the plugin folder is a git checkout, and the local closure its own `pubspec_overrides.yaml` pins. |
| `apply(projectDir, deps, {settings})` | Writes the pubspec block (`pubspecBegin` / `pubspecEnd`), the overrides block (`ProjectEngineLink.pluginOverridesBegin`; packages the engine link already pins are left out) and `lib/plugin_runtime_modules.g.dart` (`registerPluginRuntimeModules()`, `kPluginRuntimeSettings`). An empty `deps` removes all three. |

`DartCodeGeneratorService.generateMainDart(pluginRuntimeModules: true)` imports the registration and calls it first in `main()`. `GenerateDartCodeUseCase` sets the flag once the file exists.

## `lib/src/packaging/android/android_packaging.dart`

| Member | Purpose |
| :--- | :--- |
| `AndroidPackaging.prepare(projectDir, project, plugins)` | Composes the manifest (with the component classes the plugins' conditions name, scanned off the UI isolate by `usedClasses`), writes the Gradle settings and applies the runtime modules. Returns `AndroidPreparation`, whose `manifestDiff` holds the changed lines for the build log. |
| `preview(projectDir, project, plugins)` | The manifest a build would compose, without writing anything. |
| `applyRuntimeModules(...)` | Runtime modules only; every target's build runs it. |
| `runtimeSettings(project)` | `project_name` and the Android settings the registrations receive. |
| `targetPlatforms(settings)` | The `--target-platform` values of the ABIs. |
| `finishPackage(packageDir, projectName, versionName)` | Renames the APK to `<project>-<version>.apk`, writes `.sha256` and warns above `storeLimitBytes` (1 GB). |

The real cook runner is `tool/android_quest/cook_android_quest_test.dart` (`LUMINA_ANDROID_COOK=1`).

---

[Up: lumina_editor_data](index.md)
