[Türkçe](../../tr/lumina/index.md)

# lumina (engine core)

`lumina` is the engine package: a declarative 3D game runtime built on `flutter_filament`, plus the data layer the editor uses to read and write projects and assets.

## Place in the architecture

`lumina` builds on `flutter_filament` for rendering, on `flutter_riglogic` for facial rigs and on `flutter_assimp` for model import (the last two from the tools repository). `lumina_editor_api` and `lumina_ui` build on it. See [Layered architecture](../overview/layers.md).

## Two halves

- **Runtime** (`lib/src/`): what a game runs. A game describes its world with a declarative `build()` tree ([Declarative tree](declarative.md)); the engine turns it into a [world](world.md) of [actors](object.md) with components, possessed by [controllers](controller.md) and driven by the [game framework](game.md). Runtime classes carry the `Lumina` prefix (`LuminaWorld`, `LuminaActor`, `LuminaStaticMeshComponent`, ...).
- **Data layer** (`lib/data/`, `lib/domain/`): what the editor uses to read and write projects. It holds the `.lmas` asset and `.lmproject` manifest models, repositories, the GLB, OBJ and TGA parsers, the Dart code generator, templates, the plugin services, the logger and auto-save.

## Libraries

- `package:lumina/lumina.dart` exports everything, including the data layer. Lumina Studio imports it.
- `package:lumina/lumina_runtime.dart` exports the runtime without the editor data layer, Assimp and RigLogic, so a game that imports only this library also builds for the web. Generated games import it.

Runtime code never reads files with `File(...)` directly: asset loads without an explicit asset provider go through `LuminaAssets.defaultProvider`, which the generated `main()` sets to Flutter's `rootBundle` (null means the file system, for the editor and tests). Code that passes pointers imports `package:flutter_filament/ffi.dart` and `ffi_package.dart` instead of `dart:ffi` and `package:ffi`.

## Reference pages

| Page | Covers |
|---|---|
| [Declarative tree](declarative.md) | Build context, build owner, elements, objects and runtime objects. |
| [World, levels and streaming](world.md) | World, levels, subsystems, world partition, level streaming, HLOD, data layers. |
| [Actors, pawns and characters](object.md) | LuminaActor, LuminaPawn, LuminaCharacter and the saveable mixin. |
| [Controllers](controller.md) | Controllers, player controllers and player state. |
| [Components: base, movement, camera, light, audio, collision](components-core.md) | Actor and scene components, movement, camera and spring arm, player input, lights, audio, collision. |
| [Components: meshes and particles](components-mesh-and-particles.md) | Static, instanced, procedural and skeletal meshes, morph targets, particle systems. |
| [Components: environment and landscape](components-environment-and-landscape.md) | Sky, procedural sky, reflection captures, landscape terrain and foliage. |
| [Input](input.md) | Input actions, mapping contexts, keys, modifiers and triggers. |
| [Animation](animation.md) | Anim instances, montages, clips, blend spaces, keyframe tracks, retargeting. |
| [Audio](audio.md) | Audio backend, audio subsystem, sounds and attenuation. |
| [Media subsystem (video & audio)](media.md) | Hardware-accelerated video/audio player (media-kit), controllers, UMG widgets, Blueprint nodes. |
| [Collision](collision.md) | Collision shapes, filters and profiles, queries, GJK/EPA narrow phase. |
| [Physics](physics.md) | Rigid bodies, mass properties, physical materials, contacts and the physics subsystem. |
| [AI](ai.md) | AI controller, behavior trees, blackboard, navigation, perception. |
| [Materials and post-processing](materials-and-post-process.md) | Engine materials, dynamic material instances, material cache, post-process, scalability, shadows. |
| [Rendering devices](rendering.md) | GPU selection and the render backend in use. |
| [Game framework](game.md) | Game instance, game mode, game state, HUD, game widget, player camera manager. |
| [Game UI widgets (UMG runtime)](umg.md) | Runtime UMG widgets, element bindings, user widgets and the widget layer. |
| [Save games](save.md) | Save game objects and the save game subsystem. |
| [Blueprints](blueprint/index.md) | Visual scripting: documents, node library, VM, generated code. |
| [Utilities, math and testing](utilities.md) | Gameplay statics, volumes, timers, viewport picking, math helpers, mesh decimation, smoke artifacts. |
| [Data layer: use cases and services](data-services.md) | Use cases, GLB/OBJ/TGA parsers, code generator, templates, plugin services, logger, thumbnails. |
| [Data layer: use cases and services (continued, part 1)](data-services-continued.md) | More files under `lib/data/services/`, `lib/data/services/blueprint_codegen/`. |
| [Data layer: use cases and services (continued, part 2)](data-services-continued-2.md) | More files under `lib/data/services/`. |
| [Data layer: use cases and services (continued, part 3)](data-services-continued-3.md) | More files under `lib/data/services/`. |
| [Data layer: models and repositories](data-models.md) | `.lmas` assets, `.lmproject` manifests, plugin descriptors, sequencer and landscape data, repositories. |
| [Data layer: models and repositories (continued)](data-models-continued.md) | More files under `lib/data/models/`, `lib/data/repositories/`, `lib/data/repositories/asset_repository/`. |

---

[Previous: Platform integration and GPU selection](../flutter_filament/platform.md) | [Up: Lumina documentation](../../README.md) | [Next: Declarative tree](declarative.md)
