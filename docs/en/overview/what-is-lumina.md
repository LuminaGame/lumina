[Türkçe](../../tr/overview/what-is-lumina.md)

# What is Lumina

Lumina is a 3D game engine written in Dart and Flutter on top of Google Filament, together with its editor, Lumina Studio. This page explains what the engine and the editor do and which packages make them up.

## The engine

The engine is the `lumina` package. A game describes its world declaratively: a `build()` tree of objects that the engine turns into a live world of actors, pawns, characters and their components. Around that core the engine provides:

- worlds, levels, level streaming, world partition, hierarchical LOD and data layers;
- actors, pawns, characters, controllers and the game framework (game instance, game mode, game state, HUD, player camera manager);
- components for meshes (static, instanced, procedural, skeletal), lights, cameras and spring arms, movement, audio, particles, sky and landscape;
- collision with a GJK/EPA narrow phase, character movement and physics subsystems;
- AI: behavior trees, a blackboard, grid navigation with A* and sight/hearing perception;
- skeletal animation: clips, anim instances with state machines, montages, blend spaces and retargeting;
- action-based input with mapping contexts, modifiers and triggers;
- post-processing, scalability profiles and shadow settings;
- save games.

Rendering goes through `flutter_filament`, the Dart FFI binding to Google Filament, which draws with Vulkan, OpenGL or Metal on desktop and with WebGL2 in the browser. A game that imports only `package:lumina/lumina_runtime.dart` (the runtime without the editor data layer, Assimp and RigLogic) also builds for the web.

## The editor

Lumina Studio is the `lumina_ui` package, a desktop Flutter app built with shadcn_flutter. It has a 3D viewport, an outliner, a details inspector, a content browser and an output log, a Play-In-Editor mode, Git source control, a plugin manager, and a set of sub-editors for individual asset types: materials, Blueprints, widgets (UMG), animation, audio, particles, landscape and foliage, navigation, physics assets, static and skeletal meshes, textures, environment lighting, the sequencer, project settings and the build manager.

Projects are folders on disk with a `.lmproject` manifest; every asset is a `.lmas` file. The editor generates Dart code for the game from those files, so a shipped game is an ordinary Flutter app.

Plugins extend the editor through `lumina_editor_api`, a small contract package that depends only on `lumina`.

## The packages

| Package | Repository | Role |
|---|---|---|
| `flutter_filament` | lumina | Dart FFI bindings to Google Filament v1.77.0 |
| `lumina` | lumina | Engine runtime and the editor-facing data layer |
| `lumina_editor_api` | lumina | Plugin API of Lumina Studio |
| `lumina_ui` | lumina | Lumina Studio, the editor app |
| `flutter_assimp` | tools | Dart FFI bindings to Assimp: model import to GLB |
| `flutter_riglogic` | tools | Dart FFI bindings to MetaHuman RigLogic |
| `flutter_gstreamer` | tools | Dart FFI bindings to GStreamer, used to encode smoke-test videos |
| `lumina_smoke` | tools | The smoke-test system: artifacts, video checks and the report runner |
| `lumina_mouse_capture` | tools | Pointer capture for games and Play-In-Editor (Linux) |

See the [repository map](repositories.md) for where each package lives and the [layered architecture](layers.md) for how they depend on each other.

---

[Previous: Lumina documentation](../../README.md) | [Up: Lumina documentation](../../README.md) | [Next: Layered architecture](layers.md)
