[Türkçe](../../tr/overview/repositories.md)

# Repository map

The Lumina code base is split across several repositories of the LuminaGame organisation. This page lists what each repository contains and how the repositories reference each other through git dependencies.

## Repositories

| Repository | Contents |
|---|---|
| [lumina](https://github.com/LuminaGame/lumina) | This repository: `flutter_filament`, `lumina_core`, `lumina`, `lumina_editor_data`, `lumina_plugin_process`, `lumina_plugin_protocol`, `lumina_editor_api` and `lumina_ui`, plus `tool/ci.sh` and this documentation. |
| [tools](https://github.com/LuminaGame/tools) | Native and FFI packages the engine builds on: `flutter_assimp`, `flutter_riglogic`, `flutter_gstreamer`, `lumina_smoke` (the smoke-test system) and `lumina_mouse_capture`. Documented in the [tools documentation](https://github.com/LuminaGame/tools/tree/main/docs). |
| [plugins](https://github.com/LuminaGame/plugins) | Example editor plugins: `lumina_plugin_pcg` (procedural content generation, the reference example of the plugin API) and `lumina_plugin_miniai` (an AI assistant panel). |
| [marketplace](https://github.com/LuminaGame/marketplace) | The Lumina Marketplace: the `shelf` API server, the shared package (`lumina_marketplace_shared`, DTOs and `MarketplaceClient`) and the Flutter web front end. |
| [test-assets](https://github.com/LuminaGame/test-assets) | Shared 3D models and fixtures used by tests and smoke tests (Git LFS, optional). |

Google Filament is not in any repository. Lumina uses Filament v1.77.2 with a few local patches, built once into static libraries (see [Checkout and setup](../getting-started/setup.md)).

## Workspaces

Every multi-package repository is a Dart pub workspace managed with melos 7: the root `pubspec.yaml` lists the packages under `workspace:`, each package declares `resolution: workspace`, and one `pubspec.lock` covers them all. The root pubspec of this repository lists `flutter_filament`, `lumina`, `lumina_core`, `lumina_editor_data`, `lumina_plugin_process`, `lumina_plugin_protocol`, `lumina_editor_api` and `lumina_ui` (and the example apps) and defines the melos scripts `analyze`, `format`, `format:check`, `test` and `smoke`.

## How the repositories depend on each other

Repositories reference each other through git dependencies:

| Consumer | Dependency | Source |
|---|---|---|
| `flutter_filament`, `lumina`, `lumina_ui` | `lumina_smoke`, `flutter_gstreamer` (smoke tests) | tools (git) |
| `lumina`, `lumina_ui` | `flutter_assimp`, `flutter_riglogic` | tools (git) |
| `lumina`, `lumina_ui` | `lumina_mouse_capture` | tools |
| `lumina_ui` | `lumina_marketplace_shared` | marketplace (git) |
| `lumina_ui` (dev) | `lumina_plugin_pcg`, `lumina_plugin_miniai` | plugins (git) |
| plugins | `lumina`, `lumina_core`, `lumina_editor_api` | lumina (git) |
| marketplace web front end | `lumina`, `flutter_filament` | a `../lumina` checkout next to it |

Inside this repository the packages use path dependencies (`lumina` on `../flutter_filament` and `../lumina_core`, `lumina_ui` on `../lumina`, and so on).

For local development across sibling checkouts, a gitignored `pubspec_overrides.yaml` at the workspace root points the git dependencies at the neighbouring folders (pub workspaces read overrides from the root only):

```yaml
dependency_overrides:
  flutter_assimp:
    path: ../tools/flutter_assimp
  flutter_riglogic:
    path: ../tools/flutter_riglogic
  flutter_gstreamer:
    path: ../tools/flutter_gstreamer
  lumina_marketplace_shared:
    path: ../marketplace/shared
  lumina_plugin_pcg:
    path: ../plugins/lumina_plugin_pcg
  lumina_plugin_miniai:
    path: ../plugins/lumina_plugin_miniai
```

---

[Previous: Layered architecture](layers.md) | [Up: Lumina documentation](../../README.md) | [Next: Data flow](data-flow.md)
