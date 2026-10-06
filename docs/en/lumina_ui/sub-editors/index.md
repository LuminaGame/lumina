[Türkçe](../../../tr/lumina_ui/sub-editors/index.md)

# Sub-editors

Every asset type in Lumina Studio opens in a dedicated sub-editor tab. Sub-editors follow the same MVVM layout: a view, a view model, services for previews and processing, and models for the asset document.

## How a sub-editor is put together

Opening an asset from the content browser opens its sub-editor in a tab of the main editor. All sub-editor code lives under `lib/ui/features/sub_editors/`:

- `views/`: the widgets. Views that share a domain live in their own folder (`views/blueprint/`, `views/landscape/`, `views/material/`, `views/particle/`, `views/sequencer/`, `views/skeletal_mesh/`, `views/umg/`, ...).
- `view_models/`: one ChangeNotifier view model per sub-editor, which loads the asset from its `.lmas` file and saves it back.
- `services/`: preview scenes, decoders, code generators and pipelines.
- `models/`: the asset document and editor state types.
- `widgets/`: larger reusable widgets such as the animation dope sheet.

Previews are real: every 3D preview is a live Filament scene, usually driven through a `LuminaWorld`, and the values an editor shows come from the same engine types the game runs.

## Sub-editors

| Page | Covers |
|---|---|
| [Sub-editor framework](framework.md) | Shared 3D preview viewport, hierarchy widget, workspace modal, preview meshes. |
| [Animation editor](animation.md) | Animation sub-editor, dope sheet, retargeting, notifies and curves. |
| [Audio editor](audio.md) | Waveform, transport, attenuation curve, WAV decoding. |
| [Blueprint editor](blueprint.md) | Blueprint sub-editor, component tree, event graph, component registry. |
| [Blueprint editor (continued, part 1)](blueprint-continued.md) | More files under `lib/ui/features/sub_editors/models/`, `lib/ui/features/sub_editors/services/`, `lib/ui/features/sub_editors/view_models/`, `lib/ui/features/sub_editors/views/blueprint/`. |
| [Blueprint editor (continued, part 2)](blueprint-continued-2.md) | More files under `lib/ui/features/sub_editors/views/blueprint/`, `lib/ui/features/sub_editors/views/blueprint/graph_canvas/`, `lib/ui/features/sub_editors/views/blueprint/timeline/`, `lib/ui/features/sub_editors/views/blueprint_enum/`, `lib/ui/features/sub_editors/views/blueprint_interface/`. |
| [Build manager](build-manager.md) | Build steps, validation and Cook & Package through `flutter build`. |
| [Environment lighting](environment-lighting.md) | Sun and time of day, sky and IBL, fog and post-process controls. |
| [Landscape and foliage](landscape.md) | Sculpt brushes, foliage painting, heightmap assets, terrain preview. |
| [Material editor](material.md) | GLSL material source, parameters, compilation and preview. |
| [Navigation editor](navigation.md) | Nav bounds volumes, grid bake, path testing. |
| [Particle editor](particle.md) | Emitter stack, curve and gradient editors, live preview. |
| [Physics asset editor](physics-asset.md) | Bodies, constraints, overlap checks and the physics preview. |
| [Project settings](project-settings.md) | Editing the `.lmproject` manifest by category. |
| [Sequencer](sequencer.md) | Timeline, track tree, curve editor, evaluation and movie rendering. |
| [Static and skeletal mesh editors](meshes.md) | Mesh preview, LODs, collision, material slots, sockets. |
| [Texture editor](texture.md) | Texture preview, mip levels and texture settings. |
| [Theme editor](theme.md) | UI theme authoring, color palette tokens, component styles, custom styles, and live showcase preview. |
| [Widget (UMG) designer](umg.md) | Designer canvas, palette, hierarchy, slot inspector, widget code generation. |

---

[Previous: Windows packaging](../windows-packaging.md) | [Up: lumina_ui (Lumina Studio)](../index.md) | [Next: Sub-editor framework](framework.md)
