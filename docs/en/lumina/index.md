[Türkçe](../../tr/lumina/index.md)

# lumina (engine core)

`lumina` is the engine package: a declarative 3D game runtime built on `flutter_filament`. It holds no Flutter UI: the game widget, input glue, HUD, UMG widgets and media players are [lumina_widgets](../lumina_widgets/index.md). The data layer the editor uses to read and write projects and assets is its own package, [lumina_editor_data](../lumina_editor_data/index.md).

## Place in the architecture

`lumina` builds on `lumina_core` (the pure-Dart foundation) and on `flutter_filament` for rendering. Assimp and RigLogic are editor tooling: `lumina_editor_data` depends on them, the engine does not. `lumina_editor_data`, `lumina_editor_api` and `lumina_ui` build on it. See [Layered architecture](../overview/layers.md).

## What it holds

- **Runtime** (`lib/src/`): what a game runs. A game describes its world with a declarative `build()` tree ([Declarative tree](declarative.md)); the engine turns it into a [world](world.md) of [actors](object.md) with components, possessed by [controllers](controller.md) and driven by the [game framework](game.md). Runtime classes carry the `Lumina` prefix (`LuminaWorld`, `LuminaActor`, `LuminaStaticMeshComponent`, ...).
- **Asset readers the runtime uses** (`lib/src/assets/`): the encoded image decoder, `LuminaGlbLoader` (lumina_core's pure `GlbReader` with Filament's Draco decoder and the platform image codec), the level asset manifest and the level mesh material lookup. The project input binder (`lib/src/input/project_input_binder.dart`) turns a `.lmproject`'s input settings into actions and mapping contexts.
- **Not here:** the editor data layer (asset and project repositories, importers, thumbnails, the code generators, project editor builds, the plugin registry and template generator, the use cases) is [lumina_editor_data](../lumina_editor_data/index.md). The pure formats and services are [lumina_core](../lumina_core/index.md), which `lumina` re-exports. `test/architecture/engine_without_editor_data_test.dart` walks every library `lumina.dart` and `lumina_runtime.dart` reach and fails on `lumina_editor_data`, the analyzer, Assimp, RigLogic or an editor repository.

## Libraries

- `package:lumina/lumina.dart` exports the engine and the `lumina_core` libraries it always exported. Editor code imports `package:lumina_editor_data/lumina_editor.dart` instead, which adds the editor data layer.
- `package:lumina/lumina_runtime.dart` exports the engine runtime a game needs, web-safe. Generated games import `package:lumina_widgets/lumina_game.dart`, which re-exports it with the game UI; compiled Blueprint classes import it directly.

No library either barrel reaches imports a Flutter UI library (`widgets`, `material`, `rendering`, `gestures`, `services`, …), media_kit, shadcn_flutter or lumina_mouse_capture; the engine imports flutter_filament's widget-free `package:flutter_filament/filament.dart`. `dart:ui` is used only by the three image-codec libraries `test/architecture/engine_has_no_widgets_test.dart` lists, `package:flutter/foundation.dart` by none. Engine state notifies through `lumina_core`'s `ChangeSignal` / `Observable` (`LuminaGameInstance`, `LuminaPlayerController.cursorState`, `LuminaWidgetSubsystem.activeWidgets`, `LuminaGraphicsDevices.inUse`). What the engine needs from the app comes through seams `lumina_widgets` fills at start-up: `LuminaPlatform` (the platform, `isWeb`), `LuminaAssets.bundleProvider` (bundled package assets) and `LuminaVideoPlayback.factory` (the Blueprint video nodes' player).

The barrels are for users of the package: no library inside `lumina/lib` imports `lumina.dart` or `lumina_runtime.dart`; each imports the files it uses, so the barrels stay leaves of the import graph and no cycle runs through them. Engine objects carry the engine's own `LuminaObjectKey`, and `lumina_object.dart` reaches no Flutter library. `test/architecture/` guards both (`import_cycles_test.dart`, `flutter_free_object_root_test.dart`).

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
| [Motion matching](motion-matching.md) | Pose search databases, trajectory prediction, inertialization, the Motion Matching state pose. |
| [Traversal](traversal.md) | Obstacle check, hurdle / vault / mantle chooser, root-motion slot montages with motion warping. |
| [Audio](audio.md) | Audio backend, audio subsystem, sounds and attenuation. |
| [Collision](collision.md) | Collision shapes, filters and profiles, queries, GJK/EPA narrow phase. |
| [Physics](physics.md) | Rigid bodies, mass properties, physical materials, contacts, joints and the physics subsystem. |
| [Ragdolls, falls and getting up](ragdoll.md) | Physics assets and their generator, ragdolls driving the mesh, falls into ragdoll, heavy landings, get-up clips. |
| [AI](ai.md) | AI controller, behavior trees, blackboard, navigation, perception. |
| [Materials and post-processing](materials-and-post-process.md) | Engine materials, dynamic material instances, material cache, post-process, scalability, shadows. |
| [Rendering devices](rendering.md) | GPU selection and the render backend in use. |
| [Game framework](game.md) | Game instance, game mode, game state, HUD, game widget, player camera manager. |
| [User widgets](user-widgets.md) | The script a Widget Blueprint graph runs on (`LuminaUserWidget`, `LuminaUserWidgets`). The widgets themselves, the game widget, the HUD and media players are in [lumina_widgets](../lumina_widgets/index.md). |
| [Save games](save.md) | Save game objects and the save game subsystem. |
| [Blueprints](blueprint/index.md) | Visual scripting: documents, node library, VM, generated code. |
| [Utilities, math and testing](utilities.md) | Gameplay statics, volumes, timers, viewport picking, math helpers, mesh decimation, the asset readers (image decoder, GLB loader, level asset manifest), smoke artifacts. |

---

[Previous: Platform integration and GPU selection](../flutter_filament/platform.md) | [Up: Lumina documentation](../../README.md) | [Next: Declarative tree](declarative.md)
