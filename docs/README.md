[Türkçe](README.tr.md)

# Lumina documentation

Lumina is a 3D game engine for Flutter and Dart, built on the Google Filament renderer, together with Lumina Studio, the desktop editor for Lumina projects. This documentation covers the architecture, how to set up a checkout, and the API reference of the packages in this repository: `flutter_filament`, `lumina_core`, `lumina`, `lumina_widgets`, `lumina_editor_data`, `lumina_plugin_process`, `lumina_editor_api` and `lumina_ui`.

## Where to start

### Game developers

You write games with the `lumina` runtime: a declarative `build()` tree that becomes a world of actors and components.

1. [What is Lumina](en/overview/what-is-lumina.md) and [Layered architecture](en/overview/layers.md)
2. [Requirements](en/getting-started/requirements.md), [Checkout and setup](en/getting-started/setup.md), [Running the editor and tests](en/getting-started/running.md)
3. [lumina (engine core)](en/lumina/index.md), then [Declarative tree](en/lumina/declarative.md), [World, levels and streaming](en/lumina/world.md), [Actors, pawns and characters](en/lumina/object.md) and [Game framework](en/lumina/game.md)
4. The components, [Input](en/lumina/input.md), [Animation](en/lumina/animation.md), [AI](en/lumina/ai.md) and [Save games](en/lumina/save.md) as you need them

### Editor and plugin developers

You extend Lumina Studio with plugins, or work on the editor itself.

1. [What is Lumina](en/overview/what-is-lumina.md) and [Checkout and setup](en/getting-started/setup.md)
2. [Editor plugins](en/plugins/index.md) and the [lumina_editor_api reference](en/lumina_editor_api/api-reference.md)
3. [lumina_ui (Lumina Studio)](en/lumina_ui/index.md), [Main editor: view model and services](en/lumina_ui/main-editor-state.md) and [Sub-editors](en/lumina_ui/sub-editors/index.md)
4. The files the editor and plugins read and write: [lumina_core](en/lumina_core/index.md) (file formats, paths, logger, pure services), then [lumina_editor_data](en/lumina_editor_data/index.md), the editor data layer: [repositories](en/lumina_editor_data/repositories.md) and [use cases and services](en/lumina_editor_data/services.md)

### Engine contributors

You work on the engine, the renderer bindings or the native build.

1. [Layered architecture](en/overview/layers.md), [Repository map](en/overview/repositories.md) and [Data flow](en/overview/data-flow.md)
2. [Checkout and setup](en/getting-started/setup.md), including building Filament, and [Running the editor and tests](en/getting-started/running.md)
3. [flutter_filament](en/flutter_filament/index.md), starting with [Engine, entities and core types](en/flutter_filament/engine.md)
4. [lumina (engine core)](en/lumina/index.md)
5. The native packages of the tools repository: [tools documentation](https://github.com/LuminaGame/tools/tree/main/docs)

## Contents

### Overview

- [What is Lumina](en/overview/what-is-lumina.md) - The engine, the editor and the packages they are made of.
- [Layered architecture](en/overview/layers.md) - The layer diagram and what each layer is responsible for.
- [Repository map](en/overview/repositories.md) - Which LuminaGame repository holds which package, and how they depend on each other.
- [Data flow](en/overview/data-flow.md) - How the main workflows travel through the layers.

### Getting started

- [Requirements](en/getting-started/requirements.md) - SDKs, toolchains and native libraries needed to build Lumina.
- [Checkout and setup](en/getting-started/setup.md) - Sibling checkouts, `dart pub get`, hook settings and building Filament.
- [Running the editor and tests](en/getting-started/running.md) - Starting Lumina Studio, running tests, smoke reports and workspace scripts.

### flutter_filament

- [flutter_filament](en/flutter_filament/index.md) - Dart FFI bindings to Google Filament.
  - [Engine, entities and core types](en/flutter_filament/engine.md) - Engine lifecycle, entities, shared enums, fences, exceptions, callbacks, diagnostics.
  - [Renderer, views and frame pacing](en/flutter_filament/renderer-and-view.md) - Renderer, swap chains, views, render targets, frame pacing, the Flutter widget.
  - [View options and color grading](en/flutter_filament/view-options.md) - Per-view post-processing and quality options, tone mapping and color grading.
  - [DLSS Super Resolution](en/flutter_filament/dlss.md) - NVIDIA DLSS behind dynamic resolution (Vulkan, NVIDIA GPUs, fetched SDK).
  - [Ray tracing](en/flutter_filament/ray-tracing.md) - Vulkan ray query: acceleration structures per scene, ray-traced sun shadows, visibility rays.
  - [ReSTIR direct lighting](en/flutter_filament/restir.md) - Many punctual lights by reservoir resampling with ray-traced visibility.
  - [Scene and geometry](en/flutter_filament/scene-and-geometry.md) - Scenes, renderables, transforms, vertex/index/instance/morph/skinning buffers, filamesh.
  - [Camera and manipulator](en/flutter_filament/camera-and-manipulator.md) - Cameras, projections, exposure and the orbit/map/free-flight camera manipulator.
  - [Lighting and image-based lighting](en/flutter_filament/lighting-and-ibl.md) - Lights, shadows, indirect light, skyboxes, IBL baking and prefiltering.
  - [Materials](en/flutter_filament/materials.md) - Materials, material instances, parameters and the runtime material compiler.
  - [Textures and images](en/flutter_filament/textures-and-images.md) - Textures, samplers, image I/O, image operations, KTX1/KTX2, Basis transcoding.
  - [glTF loading and animation](en/flutter_filament/gltfio.md) - glTF/GLB assets, instances, material providers, animators, Draco decoding.
  - [Math types](en/flutter_filament/math.md) - Vector, quaternion and matrix value types, boxes, frustums, colors, exposure.
  - [Editor primitives, tools and testing](en/flutter_filament/editor-tools-and-testing.md) - Grid, selection box, transform gizmo, offline tools, smoke-test entry point.
  - [Platform integration and GPU selection](en/flutter_filament/platform.md) - Shared engine host, Vulkan GPU listing and preference, web start-up and the platform widget variants.

### lumina_core (pure-Dart foundation)

- [lumina_core (pure-Dart foundation)](en/lumina_core/index.md) - Shared by the engine, the editor and plugin processes; no Flutter, `dart:ui` or FFI.
  - [Math: units, axes and rotations](en/lumina_core/math.md) - `LuminaUnits`, `LuminaAxes`, Euler and control rotations, interpolation, transform snapshots.
  - [File formats and repositories](en/lumina_core/formats.md) - `.lmas` assets, `.lmproject` manifests, level documents, plugin descriptors, landscape, sequencer and theme data, level and plugin repositories.
  - [Services](en/lumina_core/services.md) - Animation authoring, asset index, config files, build fingerprint and cache, engine bootstrap, the engine logger, templates.
  - [Services (continued)](en/lumina_core/services-continued.md) - Generated-code migration, GLB animation tools, glTF packer, config and data folders, plugin packaging, primitive GLB factory, TGA decoder, workspace paths.

### lumina (engine core)

- [lumina (engine core)](en/lumina/index.md) - The declarative 3D game engine and its Filament binding.
  - [Declarative tree](en/lumina/declarative.md) - Build context, build owner, elements, objects and runtime objects.
  - [World, levels and streaming](en/lumina/world.md) - World, levels, subsystems, world partition, level streaming, HLOD, data layers.
  - [Actors, pawns and characters](en/lumina/object.md) - LuminaActor, LuminaPawn, LuminaCharacter and the saveable mixin.
  - [Controllers](en/lumina/controller.md) - Controllers, player controllers and player state.
  - [Components: base, movement, camera, light, audio, collision](en/lumina/components-core.md) - Actor and scene components, movement, camera and spring arm, player input, lights, audio, collision.
  - [Components: meshes and particles](en/lumina/components-mesh-and-particles.md) - Static, instanced, procedural and skeletal meshes, morph targets, particle systems.
  - [Components: environment and landscape](en/lumina/components-environment-and-landscape.md) - Sky, procedural sky, reflection captures, landscape terrain and foliage.
  - [Input](en/lumina/input.md) - Input actions, mapping contexts, keys, modifiers and triggers.
  - [Animation](en/lumina/animation.md) - Anim instances, montages, clips, blend spaces, keyframe tracks, retargeting.
  - [Audio](en/lumina/audio.md) - Audio backend, audio subsystem, sounds and attenuation.
  - [Collision](en/lumina/collision.md) - Collision shapes, filters and profiles, queries, GJK/EPA narrow phase.
  - [Physics](en/lumina/physics.md) - Rigid bodies, mass properties, physical materials, contacts and the physics subsystem.
  - [AI](en/lumina/ai.md) - AI controller, behavior trees, blackboard, navigation, perception.
  - [Materials and post-processing](en/lumina/materials-and-post-process.md) - Engine materials, dynamic material instances, material cache, post-process, scalability, shadows.
  - [Rendering devices](en/lumina/rendering.md) - GPU selection and the render backend in use.
  - [Game framework](en/lumina/game.md) - Game instance, game mode, game state, play state, player camera manager.
  - [User widgets](en/lumina/user-widgets.md) - The script a Widget Blueprint graph runs on.
  - [Save games](en/lumina/save.md) - Save game objects and the save game subsystem.
  - [Blueprints](en/lumina/blueprint/index.md) - Visual scripting: documents, node library, VM, generated code.
    - [Blueprint documents and assets](en/lumina/blueprint/model.md) - Pins, nodes, wires, graphs, functions, macros, interfaces, enums, save-game and montage assets, validation.
    - [Blueprint runtime, VM and node library](en/lumina/blueprint/runtime.md) - The node catalog, the interpreter, Blueprint actors, level and widget Blueprints, delegates.
    - [Blueprint function library](en/lumina/blueprint/function-library.md) - The behaviour of every pure and impure node, shared by the VM and generated code.
    - [Animation Blueprints](en/lumina/blueprint/animation.md) - Animation Blueprint documents, state machines, blend spaces, aim offsets and their instances.
  - [Utilities, math and testing](en/lumina/utilities.md) - Gameplay statics, volumes, timers, viewport picking, math helpers, mesh decimation, smoke artifacts.

### lumina_widgets (the game's Flutter side)

- [lumina_widgets](en/lumina_widgets/index.md) - The game widget and game host (keyboard, pointer, mouse capture), the HUD, web loading, the observable adapters, `lumina_game.dart`.
  - [Game UI widgets (UMG runtime)](en/lumina_widgets/umg.md) - Runtime UMG widgets, element bindings and the widget layer.
  - [Media (video & audio)](en/lumina_widgets/media.md) - media_kit players, controllers, UMG media widgets, the Blueprint video nodes.

### lumina_editor_data (editor data layer)

- [lumina_editor_data (editor data layer)](en/lumina_editor_data/index.md) - Lumina Studio's tooling data layer outside the engine, and the `lumina_editor.dart` umbrella for editor code.
  - [Data layer: use cases and services](en/lumina_editor_data/services.md) - Use cases, the GLB service, OBJ import, code generator, plugin services, thumbnails.
  - [Data layer: use cases and services (continued, part 1)](en/lumina_editor_data/services-continued.md) - More files under `lib/src/services/`, `lib/src/services/blueprint_codegen/`.
  - [Data layer: use cases and services (continued, part 2)](en/lumina_editor_data/services-continued-2.md) - More files under `lib/src/services/`.
  - [Data layer: use cases and services (continued, part 3)](en/lumina_editor_data/services-continued-3.md) - More files under `lib/src/services/`.
  - [Data layer: models and repositories](en/lumina_editor_data/repositories.md) - The asset, collections and project repositories (the models are in `lumina_core`).
  - [Data layer: models and repositories (continued)](en/lumina_editor_data/repositories-continued.md) - More files under `lib/src/repositories/`, `lib/src/repositories/asset_repository/`.

### lumina_editor_api

- [lumina_editor_api](en/lumina_editor_api/index.md) - The dependency-light plugin API of Lumina Studio.
  - [API reference](en/lumina_editor_api/api-reference.md) - Plugin, context, commands, menus, slot buttons, panels, asset types, importers, level access, theme, storage, settings.
  - [MCP tools API](en/lumina_editor_api/mcp.md) - MCP tool, schema, risk and approval types; the editor's MCP tools for plugins.

### lumina_plugin_process

- [lumina_plugin_process](en/lumina_plugin_process/index.md) - The pure-Dart process side of a plugin: process API, runtime, change types, loopback test host.
  - [Plugin processes](en/lumina_plugin_process/plugin-processes.md) - a plugin's risky part in its own process: process API, editor proxies, adapter.

### Editor plugins

- [Editor plugins](en/plugins/index.md) - How plugins are packaged, discovered, enabled and registered.

### lumina_ui (Lumina Studio)

- [lumina_ui (Lumina Studio)](en/lumina_ui/index.md) - The Lumina Studio editor application.
  - [App shell and shared UI](en/lumina_ui/core.md) - App entry, built-in plugin, plugin extension registry, theme, property editors, scene services.
  - [App shell and shared UI (continued, part 1)](en/lumina_ui/core-continued.md) - More files under `lib/`, `lib/testing/`, `lib/ui/core/`, `lib/ui/core/host/`, `lib/ui/core/property_editors/`, `lib/ui/core/services/`, `lib/ui/core/theme/`, `lib/ui/core/widgets/`.
  - [App shell and shared UI (continued, part 2)](en/lumina_ui/core-continued-2.md) - More files under `lib/ui/core/window/`.
  - [Main editor: views](en/lumina_ui/main-editor-views.md) - Viewport, outliner, details, content browser, toolbar, menu bar, output log, dialogs.
  - [Main editor: views (continued)](en/lumina_ui/main-editor-views-continued.md) - More files under `lib/ui/features/main_editor/views/`.
  - [Main editor: view model and services](en/lumina_ui/main-editor-state.md) - `EditorViewModel`, quality settings, gizmos, Play-In-Editor, snapping, picking, shortcuts, commands, transactions.
  - [Main editor: view model and services (continued)](en/lumina_ui/main-editor-state-continued.md) - More files under `lib/ui/features/main_editor/services/`, `lib/ui/features/main_editor/services/pie_controller/`, `lib/ui/features/main_editor/view_models/`, `lib/ui/features/main_editor/view_models/editor_view_model/`.
  - [Launcher and details](en/lumina_ui/launcher-and-details.md) - Project launcher, create-project dialog, component property registry, multi-edit.
  - [Plugin manager](en/lumina_ui/plugin-manager.md) - Plugin manager view and view model, new-plugin wizard.
  - [Source control](en/lumina_ui/source-control.md) - Git service, source control view model, commit, history, revert and identity dialogs.
  - [Marketplace](en/lumina_ui/marketplace.md) - Signing in, browsing, installing listings and license records.
  - [MCP server](en/lumina_ui/mcp-server.md) - The editor's Model Context Protocol server: transport, sessions, registry, jobs, sandbox, snapshots, panel.
  - [MCP tool catalogue](en/lumina_ui/mcp-tools.md) - Every MCP tool the editor offers, by area, with its risk level.
  - [Windows packaging](en/lumina_ui/windows-packaging.md) - Building and signing the MSIX package of Lumina Studio.
  - [Sub-editors](en/lumina_ui/sub-editors/index.md) - The asset editors that open in their own tabs.
    - [Sub-editor framework](en/lumina_ui/sub-editors/framework.md) - Shared 3D preview viewport, hierarchy widget, workspace modal, preview meshes.
    - [Animation editor](en/lumina_ui/sub-editors/animation.md) - Animation sub-editor, dope sheet, retargeting, notifies and curves.
    - [Audio editor](en/lumina_ui/sub-editors/audio.md) - Waveform, transport, attenuation curve, WAV decoding.
    - [Blueprint editor](en/lumina_ui/sub-editors/blueprint.md) - Blueprint sub-editor, component tree, event graph, component registry.
    - [Blueprint editor (continued, part 1)](en/lumina_ui/sub-editors/blueprint-continued.md) - More files under `lib/ui/features/sub_editors/models/`, `lib/ui/features/sub_editors/services/`, `lib/ui/features/sub_editors/view_models/`, `lib/ui/features/sub_editors/views/blueprint/`.
    - [Blueprint editor (continued, part 2)](en/lumina_ui/sub-editors/blueprint-continued-2.md) - More files under `lib/ui/features/sub_editors/views/blueprint/`, `lib/ui/features/sub_editors/views/blueprint/graph_canvas/`, `lib/ui/features/sub_editors/views/blueprint/timeline/`, `lib/ui/features/sub_editors/views/blueprint_enum/`, `lib/ui/features/sub_editors/views/blueprint_interface/`.
    - [Build manager](en/lumina_ui/sub-editors/build-manager.md) - Build steps, validation and Cook & Package through `flutter build`.
    - [Environment lighting](en/lumina_ui/sub-editors/environment-lighting.md) - Sun and time of day, sky and IBL, fog and post-process controls.
    - [Landscape and foliage](en/lumina_ui/sub-editors/landscape.md) - Sculpt brushes, foliage painting, heightmap assets, terrain preview.
    - [Material editor](en/lumina_ui/sub-editors/material.md) - GLSL material source, parameters, compilation and preview.
    - [Navigation editor](en/lumina_ui/sub-editors/navigation.md) - Nav bounds volumes, grid bake, path testing.
    - [Particle editor](en/lumina_ui/sub-editors/particle.md) - Emitter stack, curve and gradient editors, live preview.
    - [Physics asset editor](en/lumina_ui/sub-editors/physics-asset.md) - Bodies, constraints, overlap checks and the physics preview.
    - [Project settings](en/lumina_ui/sub-editors/project-settings.md) - Editing the `.lmproject` manifest by category.
    - [Sequencer](en/lumina_ui/sub-editors/sequencer.md) - Timeline, track tree, curve editor, evaluation and movie rendering.
    - [Static and skeletal mesh editors](en/lumina_ui/sub-editors/meshes.md) - Mesh preview, LODs, collision, material slots, sockets.
    - [Texture editor](en/lumina_ui/sub-editors/texture.md) - Texture preview, mip levels and texture settings.
    - [Widget (UMG) designer](en/lumina_ui/sub-editors/umg.md) - Designer canvas, palette, hierarchy, slot inspector, widget code generation.

## Related documentation

- [tools documentation](https://github.com/LuminaGame/tools/tree/main/docs): `flutter_assimp`, `flutter_riglogic`, `flutter_gstreamer` and `lumina_mouse_capture`.
- [plugins](https://github.com/LuminaGame/plugins): the example editor plugins.
- [marketplace](https://github.com/LuminaGame/marketplace): the Lumina Marketplace server, shared package and web front end.

---

[Next: What is Lumina](en/overview/what-is-lumina.md)
