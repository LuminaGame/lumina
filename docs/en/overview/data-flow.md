[Türkçe](../../tr/overview/data-flow.md)

# Data flow

This page follows the main workflows of Lumina, such as model import, rendering and code generation, from the editor down to the native libraries, and names the API that each layer contributes.

## Workflows across the layers

Each row is one workflow. Read it left to right, from where it starts in the editor to the native code that does the work.

| Workflow / feature | Initiator (`lumina_ui`) | Plugin API (`lumina_editor_api`) | Engine logic (`lumina`) | Native rendering / compute (`flutter_*`) |
| :--- | :--- | :--- | :--- | :--- |
| **Model import** | Content Browser (drag and drop) | `EditorImporter` | `ImportAssetUseCase`, `GlbParserService` | `flutter_assimp` (`convertFileToGlb`) |
| **Facial deformation** | Skeletal Mesh / Animation sub-editor | Details customization | `SkeletalMeshComponent`, `AnimInstance` | `flutter_riglogic` (`calculate`, `getBlendShapes`) |
| **PBR 3D rendering** | Viewport (`ViewportWidget`) | - | `LuminaWorld`, `StaticMeshComponent` | `flutter_filament` (`FilamentEngine`, `FilamentView`) |
| **Visual scripting** | Blueprint sub-editor | `EditorAssetTypeHandler` | `LuminaActor`, `ActorComponent` | Code generation (`CodeGeneratorService`) |
| **Open-world streaming** | Main editor viewport | - | `WorldPartition`, `LevelStreaming` | `FilamentScene` (`addEntity`, `removeEntity`) |
| **Auto-save and code generation** | Background timer | - | `AutoSaveTimerService`, `SaveLevelUseCase` | Disk I/O (`.lmas`, `.lmproject`) |

## Where to read more

- Model import: [Data layer: use cases and services](../lumina_editor_data/services.md) and the [flutter_assimp reference](https://github.com/LuminaGame/tools/tree/main/docs).
- Facial deformation: [Components: meshes and particles](../lumina/components-mesh-and-particles.md), [Animation](../lumina/animation.md) and the [flutter_riglogic reference](https://github.com/LuminaGame/tools/tree/main/docs).
- Rendering: [Renderer, views and frame pacing](../flutter_filament/renderer-and-view.md) and [Main editor: views](../lumina_ui/main-editor-views.md).
- Visual scripting: [Blueprint editor](../lumina_ui/sub-editors/blueprint.md).
- Streaming: [World, levels and streaming](../lumina/world.md).
- Saving: [Data layer: models and repositories](../lumina_editor_data/repositories.md).

---

[Previous: Repository map](repositories.md) | [Up: Lumina documentation](../../README.md) | [Next: Requirements](../getting-started/requirements.md)
