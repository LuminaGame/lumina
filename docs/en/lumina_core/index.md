[Türkçe](../../tr/lumina_core/index.md)

# lumina_core (pure-Dart foundation)

`lumina_core` is the foundation that Lumina's engine, Lumina Studio and plugin processes share. It holds the math rules, Lumina's file formats and the repositories that read and write them, the engine logger, workspace and data paths, and the tooling services that need no renderer. It has no Flutter, `dart:ui` or FFI dependency. A plain Dart program (a plugin process, a command-line tool, a server) can therefore read a `.lmproject`, a level or a `.lmplugin` with `dart run`.

## Place in the architecture

`lumina_core` sits below `lumina`. Its dependencies are pure Dart packages only: `path`, `crypto`, `yaml`, `pub_semver`, `vector_math` and `meta`. `lumina` depends on it and re-exports it. `package:lumina/lumina.dart` and `package:lumina/lumina_runtime.dart` export the same libraries as before, so engine and game code does not change. `lumina_editor_api`, `lumina_ui` and the plugins import it directly:

```dart
import 'package:lumina_core/lumina_core.dart';
```

The package lives in the lumina repository (`lumina_core/`) and is a member of its pub workspace. See [Layered architecture](../overview/layers.md).

## What it holds

| Area | Contents | Reference |
| :--- | :--- | :--- |
| Change notification | `ChangeSignal`, `Observable<T>`, `ChangeEmitter`, `ObservableValue<T>`: listeners without Flutter, see below | this page |
| Math | `LuminaUnits` (1 unit = 1 cm), `LuminaAxes` (stored Z-up, runtime Y-up), Euler and control-rotation helpers, interpolation, `LuminaTransformSnapshot` | [Math](math.md) |
| File formats | `.lmas` assets (`LuminaAsset`, `LuminaAssetSummary`), the `.lmproject` manifest (`LuminaProject` and its settings), level documents (`LuminaLevelDocument`), landscape and sequencer data, `.lmplugin` descriptors (`LuminaPluginDescriptor`, `PluginIsolation`), theme documents, recent projects | [File formats and repositories](formats.md) |
| Repositories | `LuminaLevelRepository` (level `.lmas` files), `PluginRepository` (plugin discovery and `.lmplugin` validation) | [File formats and repositories](formats.md) |
| Services | `EngineLoggerService`, `LuminaWorkspace`, `LuminaDataDir`, `LuminaConfigDir`, config JSON files, the asset index, the project editor build fingerprint and cache, engine bootstrap and source vendoring, the glTF packer, the primitive GLB factory, the TGA decoder, GLB animation merging and retargeting, game and level templates, plugin packaging, release assets | [Services](services.md), [Services (continued)](services-continued.md) |

The library is one barrel, `package:lumina_core/lumina_core.dart`. The files are under `lib/src/foundation/`, `lib/src/math/`, `lib/src/formats/`, `lib/src/repositories/` and `lib/src/services/`.

## Change notification without Flutter

`lib/src/foundation/observable.dart` holds the pure counterparts of Flutter's `Listenable`, `ValueListenable`, `ChangeNotifier` and `ValueNotifier`, with the same member names:

| Type | Role |
| :--- | :--- |
| `ChangeSignal` | `addListener` / `removeListener`: something that tells its listeners it changed. |
| `Observable<T>` | A `ChangeSignal` with a current `value`. |
| `ChangeEmitter` | The usual `ChangeSignal`: `notifyListeners()` calls every listener registered at that moment, in order (one that throws does not stop the others; the first error is rethrown afterwards); `hasListeners`, `dispose()` (adding a listener afterwards is a `StateError`). |
| `ObservableValue<T>` | An `Observable` with a settable `value`; setting an equal value notifies nobody. |

The plugin process API (`lumina_plugin_process`) uses them for its live values: `PluginProcessContext.pluginSettings`, a slot button's `state`, a menu item's `checked`, the level's `changes`. The engine notifies through them too (`LuminaGameInstance`, a player controller's `cursorState`, the widget subsystem's `activeWidgets`, the GPU in use). `lumina_widgets` converts them to and from Flutter's types (`asValueListenable()`, `asListenable()`, `asObservable()`, `asChangeSignal()`); `lumina_editor_api` re-exports those views.

## What stays in the engine

`lumina_core` is shared foundation, not engine logic. World, actors, components, collision, physics, AI, animation, Blueprints and save games stay in `lumina`. The editor data layer files that need Flutter, the renderer, Assimp or the analyzer (the asset and project repositories, the GLB import service, importers, thumbnails, the code generators) are [lumina_editor_data](../lumina_editor_data/index.md). The GLB reader itself is here (`GlbReader`, pure Dart); the engine adds Filament's Draco decoder and the platform image codec through `LuminaGlbLoader`.

Two `lumina_core` types have engine-side additions in `lumina`, exported by `package:lumina/lumina.dart`:

- **Level Blueprints.** A level document stores its Level Blueprint as JSON: `LuminaLevelDocument.levelBlueprintJson`, `hasLevelBlueprint` and `LuminaLevelDocument.levelBlueprintKey` (`'levelBlueprint'`). The engine's `lib/src/blueprint/level_blueprint_storage.dart` reads it into its own graph type. It adds the `levelBlueprint` getter and setter and `levelActorRefs` on `LuminaLevelDocument`, and `loadLevelBlueprint` / `saveLevelBlueprint` on `LuminaLevelRepository`. Setting an empty Blueprint removes the key, as before.
- **Theme colours.** A theme document stores colours as ARGB ints (`0xAARRGGBB`), and `colorInt(token)` reads one. The engine's `lib/src/umg/theme_document_colors.dart` adds the Flutter `Color` views: `colorOf(token)` on `LuminaThemeDocument`, and `bgColor` / `fgColor` / `bColor` on `LuminaComponentStyle`.

## Removed import paths

The `@Deprecated` one-line re-exports that kept the old paths working for one release are gone, and so is `package:lumina/data/`. Import the barrel instead:

| Old path | Now |
| :--- | :--- |
| `package:lumina/data/models/*.dart` (asset, project, level, plugin descriptor, landscape, sequencer, theme formats) | `package:lumina_core/lumina_core.dart` |
| `package:lumina/data/repositories/level_repository.dart`, `plugin_repository.dart` | `package:lumina_core/lumina_core.dart` |
| `package:lumina/data/services/<pure service>.dart` (workspace paths, data/config dirs, logger, glTF packer, TGA decoder, …) | `package:lumina_core/lumina_core.dart` |
| `package:lumina/src/math/*.dart`, `package:lumina/src/components/camera/camera_math.dart` | `package:lumina_core/lumina_core.dart` (also re-exported by `lumina.dart` / `lumina_runtime.dart`) |

The Level Blueprint extension of the level document and repository and the colour extension of the theme document come with `package:lumina/lumina.dart` and `package:lumina_widgets/lumina_widgets.dart`. Lumina Studio's `test/architecture/no_deprecated_lumina_paths_test.dart` fails on any import of a removed, deep or `@Deprecated` Lumina path, and on a `@Deprecated` library left in the engine.

## Using it from a pure-Dart program

```dart
import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';

Future<void> main(List<String> args) async {
  final dir = args.single;
  final manifest = Directory(dir).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.lmproject'));
  final project = LuminaProject.fromMap(jsonDecode(await manifest.readAsString()) as Map<String, dynamic>);

  final level = LuminaLevelRepository(dir).load(project.activeLevel);
  print('${project.projectName}: ${level?.actors.length ?? 0} actors in ${level?.name}');

  final plugins = await PluginRepository(
    roots: [PluginScanRoot(dir: Directory('$dir/plugins'), origin: PluginOrigin.project)],
  ).scanAll();
  for (final p in plugins.plugins) {
    print('${p.name} ${p.version} runs ${p.effectiveIsolation(project).manifestValue}');
  }
}
```

## Tests

`lumina_core` tests run with `dart test` from the package directory, not with `flutter test`:

```bash
cd lumina_core
dart test test/architecture/pure_dart_test.dart test/formats_round_trip_test.dart
```

- `test/architecture/pure_dart_test.dart` walks the import graph of every library in the package, including the packages they import, and fails on `package:flutter`, any `flutter_*` package, `dart:ui`, `dart:ffi`, `package:ffi` or `package:lumina`. The fact that it runs under `dart test` is part of the proof.
- `test/formats_round_trip_test.dart` writes a `.lmproject`, a level with actors, world partition and a Level Blueprint, and a `.lmplugin` with `isolation` and `process_class` to a temp folder. It reads each one, writes it back and reads it again. It also checks that units and axes convert as the engine expects.
- The tests of the moved files (models, project settings, the plugin isolation manifest, the build cache, source vendoring, engine bootstrap, workspace paths, the TGA decoder, the GLB retargeter and others) live under `test/` in the same layout as before.

---

[Up: Documentation index](../../README.md) | [Next: Math: units, axes and rotations](math.md)
