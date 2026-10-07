[Türkçe](../../tr/lumina_editor_data/index.md)

# lumina_editor_data (editor data layer)

`lumina_editor_data` is Lumina Studio's tooling data layer: what the editor reads, writes, imports and generates. It lives outside the engine, so a game that imports `lumina` carries none of it, and the engine can be reasoned about without the editor.

## Place in the architecture

`lumina_editor_data` sits between the engine and the editor. It depends on `lumina_core` (formats, paths, logger), `lumina` (the engine: templates, Blueprint types and the code generators' targets), `flutter_filament` (offscreen thumbnail renders), `flutter_assimp` (model import), `flutter_riglogic` (MetaHuman DNA rigs), the analyzer (the Blueprint function scanner) and `package:image`. `lumina_ui` and the editor plugins build on it. The engine never imports it: `lumina/test/architecture/engine_without_editor_data_test.dart` walks every library `lumina.dart` and `lumina_runtime.dart` reach and fails if one of them is `lumina_editor_data`, the analyzer, Assimp, RigLogic or an editor repository. See [Layered architecture](../overview/layers.md).

The package holds no widgets: `test/architecture/no_widgets_test.dart` fails on any library of the package that imports `package:flutter/widgets.dart`, `material.dart`, `cupertino.dart` or `shadcn_flutter`. Its own import cycles are limited to two file pairs (`test/architecture/import_cycles_test.dart`).

## Libraries

- `package:lumina_editor_data/lumina_editor_data.dart`: the editor data layer alone (what `lumina.dart` exported from `lib/data` and `lib/domain` before the split).
- `package:lumina_editor_data/lumina_editor.dart`: the umbrella for editor code (Lumina Studio, editor plugins). It exports `lumina_core`, `lumina`, `lumina_widgets`, `lumina_editor_data`, `flutter_assimp` and `flutter_riglogic`: what `package:lumina/lumina.dart` exported before the split.

```dart
import 'package:lumina_editor_data/lumina_editor.dart';
```

Generated games import `package:lumina_widgets/lumina_game.dart` (`kLuminaGameLibrary`): the launcher (`main.dart`, which shows a `LuminaGameHost` and calls `LuminaWidgets.ensureInitialized()`), levels, `input/project_input.g.dart`, the character and game mode, and the UMG widget classes. Compiled Blueprint classes and their registries use the engine only and import `package:lumina/lumina_runtime.dart`.

## What it holds

| Area | Contents | Reference |
| :--- | :--- | :--- |
| Repositories | `AssetRepository` (scanning, imports, families, thumbnails, file operations), `ProjectRepository` (create, open, recent projects, templates), `CollectionsRepository` | [Repositories](repositories.md), [Repositories (continued)](repositories-continued.md) |
| Importers | `AssimpImportService`, `FbxImportService`, `ObjImportService`, `ObjParserService`, `GlbParserService` (the import sanitizer: TGA to PNG, the texture budget, four skin influences), `ImportQueue`, `ImportFolderScanner`, image conversion, mesh collision, mesh physics | [Use cases and services](services.md), [part 2](services-continued-2.md), [part 3](services-continued-3.md) |
| Thumbnails | `ThumbnailService`, `FilamentThumbnailRenderer`, the thumbnail sidecar migration | [Use cases and services](services.md), [part 2](services-continued-2.md), [part 3](services-continued-3.md) |
| Code generation | `DartCodeGeneratorService`, `BlueprintDartGenerator`, `BlueprintFunctionScanner`, `BlueprintFunctionManifest`, `LuminaBlueprintClassRegistry`, `LuminaProjectBlueprintAssets`, the base eye height migration, app icons and the web loading screen | [Use cases and services](services.md), [part 1](services-continued.md), [part 3](services-continued-3.md) |
| Project editor builds | `EditorHostGeneratorService`, `EditorBuildService` | [Use cases and services, part 2](services-continued-2.md) |
| Plugins | `PluginRegistryService`, `PluginTemplateGeneratorService` | [Use cases and services](services.md) |
| Derived data | `DerivedDataCache`, `AssetReferenceGraph` | [Use cases and services](services.md), [part 1](services-continued.md) |
| Rigs | `RigLogicEvaluator` (MetaHuman DNA facial rigs) | [Use cases and services, part 3](services-continued-3.md) |
| Use cases | `SaveLevelUseCase`, `GenerateDartCodeUseCase`, `ImportAssetUseCase` and their results | [Use cases and services](services.md) |

The files are under `lib/src/repositories/`, `lib/src/services/` and `lib/src/domain/`.

## What stayed in the engine

Some files of the old `lumina/lib/data` are what a running game, or Play-In-Editor, needs. They stayed in `lumina`:

- the GLB loader (`LuminaGlbLoader`, `lib/src/assets/glb_loader.dart`): lumina_core's pure `GlbReader` with Filament's Draco decoder and the platform image codec. The landscape's foliage meshes read through it. `GlbParserService.parseGlb` here is the same reader plus the import sanitizer;
- the encoded image decoder, the level asset manifest and the level mesh material lookup (`lib/src/assets/`);
- the project input binder (`lib/src/input/project_input_binder.dart`).

See [Utilities](../lumina/utilities.md) and [Input](../lumina/input.md).

## Moving editor code over

The old `package:lumina/data/...` and `package:lumina/domain/...` paths are gone. Editor code and plugins import the umbrella, or a narrower package when that is all they use:

| Before | After |
| :--- | :--- |
| `package:lumina/lumina.dart` (editor code) | `package:lumina_editor_data/lumina_editor.dart` |
| `package:lumina/data/repositories/asset_repository.dart`, `project_repository.dart` | `package:lumina_editor_data/lumina_editor.dart` |
| `package:lumina/data/services/<service>.dart` | `package:lumina_editor_data/lumina_editor.dart` |
| `package:lumina/domain/...` | `package:lumina_editor_data/lumina_editor.dart` |

A package that does this adds `lumina_editor_data` to its dependencies. Engine-only code keeps `package:lumina/lumina.dart`; code that only reads or writes formats (`LuminaAsset`, `LuminaProject`, levels, plugin descriptors) imports `package:lumina_core/lumina_core.dart` ([removed import paths](../lumina_core/index.md#removed-import-paths)), and a plugin's process part `package:lumina_plugin_process/lumina_plugin_process.dart`.

## Tests and smoke

The data-layer tests are in `lumina_editor_data/test/`, laid out as they were in `lumina/test/`. Some of them read the engine's own test fixtures (the Blueprint documents and generated-code goldens under `lumina/test/blueprint/`) by relative path. The editor-and-engine smoke files (animation, Blueprint, collision, physics, input, derived data, domain, packaging, web) are in `test/smoke/` and run through the package's `tool/smoke_report.dart`, like every package's smoke report.

---

[Previous: Utilities, math and testing](../lumina/utilities.md) | [Up: Lumina documentation](../../README.md) | [Next: Data layer: use cases and services](services.md)
