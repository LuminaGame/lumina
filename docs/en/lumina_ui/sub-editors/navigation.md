[Türkçe](../../../tr/lumina_ui/sub-editors/navigation.md)

# Navigation editor

The Navigation editor: bounds volumes, agent and grid parameters, a real navigation bake with a walkable-cell overlay, and an A* path tester. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/navigation_sub_editor.dart`](#libuifeaturessub_editorsviewsnavigation_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/navigation_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsnavigation_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/navigation_preview_scene.dart`](#libuifeaturessub_editorsservicesnavigation_preview_scenedart)
- [`lib/ui/features/sub_editors/models/navigation_editor_state.dart`](#libuifeaturessub_editorsmodelsnavigation_editor_statedart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/navigation_thumbnail_validation_steps.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicenavigation_thumbnail_validation_stepsdart)

## `lib/ui/features/sub_editors/views/navigation_sub_editor.dart`

### `class NavigationSubEditor`

Navigation sub-editor: bounds volumes, agent / grid parameters, a real `LuminaNavigationSystem` bake with a walkable-cell overlay and a click-driven A* path tester. The backend is a uniform walkable grid with 8-connected A* — not Recast — and the UI says so.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | Holds the `editorViewModel` property or configuration state. |
| `viewModel` | `NavigationEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<NavigationSubEditor> createState() => _NavigationSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _NavigationSubEditorState`

`_NavigationSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `viewModelForTest` | `NavigationEditorViewModel? get viewModelForTest` | Getter accessor returning the current value of `viewModelForTest`. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _LeftPanel`

`_LeftPanel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `NavigationEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `filterController` | `TextEditingController filterController` | Holds the `filterController` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _VolumeRow`

`_VolumeRow`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `NavigationEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `volume` | `EditorActorNode volume` | Holds the `volume` property or configuration state. |
| `selected` | `bool selected` | Holds the `selected` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _VolumeInspector`

Centre / extent inputs of the selected volume (metres → actor cm / scale).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `NavigationEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `volume` | `EditorActorNode volume` | Holds the `volume` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _RightPanel`

`_RightPanel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `NavigationEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `maskController` | `TextEditingController maskController` | Holds the `maskController` property or configuration state. |
| `maskFocus` | `FocusNode maskFocus` | Holds the `maskFocus` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/navigation_editor_view_model.dart`

### `class NavigationEditorViewModel`

View model of the Navigation sub-editor.  Owns the `NavGridConfig` draft, the selected bounds volume, the path tester endpoints and overlay visibility. [build] unions the level's `NavMeshBoundsVolume` actors into the bounds handed to the real `LuminaNavigationSystem.buildFromWorld` over a collision world derived from the level's mesh geometry, then snapshots per-cell occupancy for the overlay; [testPath] issues real `findPathSync` queries under a stopwatch. Config persists in the level's `navigation` section; volumes are ordinary level actors (undo / outliner / save reuse the editor plumbing).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `editor` | `EditorViewModel editor` | Holds the `editor` property or configuration state. |
| `preview` | `NavigationPreviewScene preview` | Holds the `preview` property or configuration state. |
| `autoRebuildDebounce` | `Duration autoRebuildDebounce` | Debounce applied to auto-rebuilds after scene / config changes. |
| `config` | `NavigationEditorConfig get config` | Getter accessor returning the current value of `config`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `isOpened` | `bool get isOpened` | Checks current state or capability and returns a boolean value. |
| `isBuilding` | `bool get isBuilding` | Checks current state or capability and returns a boolean value. |
| `isStale` | `bool get isStale` | The scene or config changed since the last build. |
| `buildCount` | `int get buildCount` | Getter accessor returning the current value of `buildCount`. |
| `buildError` | `String? get buildError` | Getter accessor returning the current value of `buildError`. |
| `lastBuild` | `NavBuildResult? get lastBuild` | Getter accessor returning the current value of `lastBuild`. |
| `snapshot` | `NavGridSnapshot? get snapshot` | Getter accessor returning the current value of `snapshot`. |
| `navigation` | `LuminaNavigationSystem? get navigation` | The live engine backend of the last build (null before any build). |
| `pathResult` | `NavPathResult? get pathResult` | Getter accessor returning the current value of `pathResult`. |
| `pathStart` | `Vector3? get pathStart` | Getter accessor returning the current value of `pathStart`. |
| `pathGoal` | `Vector3? get pathGoal` | Getter accessor returning the current value of `pathGoal`. |
| `pathTesterMode` | `bool get pathTesterMode` | Getter accessor returning the current value of `pathTesterMode`. |
| `overlayVisible` | `bool get overlayVisible` | Getter accessor returning the current value of `overlayVisible`. |
| `isPreviewAttached` | `bool get isPreviewAttached` | Checks current state or capability and returns a boolean value. |
| `volumeFilter` | `String get volumeFilter` | Getter accessor returning the current value of `volumeFilter`. |
| `volumes` | `List<EditorActorNode> get volumes` | Getter accessor returning the current value of `volumes`. |
| `filteredVolumes` | `List<EditorActorNode> get filteredVolumes` | Getter accessor returning the current value of `filteredVolumes`. |
| `selectedVolume` | `EditorActorNode? get selectedVolume` | Selects the target actor or asset. |
| `canBuild` | `bool get canBuild` | Getter accessor returning the current value of `canBuild`. |
| `buildDisabledReason` | `String get buildDisabledReason` | Getter accessor returning the current value of `buildDisabledReason`. |
| `hudWalkableLabel` | `String get hudWalkableLabel` | Getter accessor returning the current value of `hudWalkableLabel`. |
| `hudGridLabel` | `String get hudGridLabel` | Getter accessor returning the current value of `hudGridLabel`. |
| `hudPathLabel` | `String get hudPathLabel` | Getter accessor returning the current value of `hudPathLabel`. |
| `hudPathBadge` | `String? get hudPathBadge` | `Partial path` / `No path` badge text, null when a full path exists. |
| `pathDebugLine` | `String get pathDebugLine` | Bottom-bar debug line for the last query. |
| `lastBuildLabel` | `String get lastBuildLabel` | Getter accessor returning the current value of `lastBuildLabel`. |
| `open` | `void open()` | Loads the level's `navigation` section, subscribes to the editor and runs an initial build when volumes exist (baked data is derived state and never persisted). |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `setVolumeFilter` | `void setVolumeFilter(String value)` | Updates the `VolumeFilter` parameter and applies changes to the system. |
| `selectVolume` | `void selectVolume(String? id)` | Selects the target actor or asset. |
| `addBoundsVolume` | `EditorActorNode addBoundsVolume()` | Spawns a `NavMeshBoundsVolume` centred on the viewport pivot (bottom face resting on the pivot height) with the default 20×5×20 m extent, as one undoable level edit. |
| `deleteVolume` | `void deleteVolume(String id)` | Releases and safely disposes the specified `Volume` resource. |
| `renameVolume` | `void renameVolume(String id, String name)` | Executes `renameVolume` operation. |
| `focusVolume` | `void focusVolume(String id)` | Executes `focusVolume` operation. |
| `setWalkableLayerMask` | `void setWalkableLayerMask(int mask)` | Updates the `WalkableLayerMask` parameter and applies changes to the system. |
| `setWalkableLayerMaskText` | `bool setWalkableLayerMaskText(String text)` | Parses `0xFF`, `FF` or decimal input; returns false when unparsable. |
| `walkableLayerMaskHex` | `String get walkableLayerMaskHex` | Getter accessor returning the current value of `walkableLayerMaskHex`. |
| `setAutoRebuild` | `void setAutoRebuild(bool on)` | Updates the `AutoRebuild` parameter and applies changes to the system. |
| `build` | `NavBuildResult? build()` | Runs the real grid bake. Returns null (and logs) when there is nothing to bake; never throws into the UI. |
| `setPathTesterMode` | `void setPathTesterMode(bool on)` | Updates the `PathTesterMode` parameter and applies changes to the system. |
| `setOverlayVisible` | `void setOverlayVisible(bool visible)` | Updates the `OverlayVisible` parameter and applies changes to the system. |
| `testPath` | `NavPathResult testPath(Vector3 start, Vector3 goal)` | Runs `findPathSync` between [start] and [goal] (metres) under a stopwatch. |
| `placePathPoint` | `void placePathPoint(Vector3 worldCm)` | Click-driven placement in level centimetres: the first click drops the start flag, the second the goal; later clicks move whichever flag is nearer. Endpoints are projected onto the grid by the engine itself. |
| `clearPath` | `void clearPath()` | Clears all elements from the collection or buffer. |
| `save` | `Future<bool> save()` | Saves the level (`.lmas` + generated Dart) through the editor. |
| `attachPreview` | `void attachPreview(LuminaWorld world)` | Called by the viewport once its lumina world exists on the live engine. |
| `detachPreview` | `void detachPreview(LuminaWorld world)` | Called by the viewport right before it cleans the world up. |
| `floorTapPlaneCm` | `double get floorTapPlaneCm` | Floor height (level cm) the path-tester clicks are unprojected onto: the baked grid's ground, or the first volume's bottom before a build. |
| `navWorldForTest` | `LuminaWorld? get navWorldForTest` | Getter accessor returning the current value of `navWorldForTest`. |

## `lib/ui/features/sub_editors/services/navigation_preview_scene.dart`

**Top-level Functions:**

- **`show CullingMode, FilamentMaterialInstance, FilamentMaterialProvider, MaterialKey`**: Executes `MaterialKey` operation.

### `class NavigationPreviewScene`

Drives the Navigation sub-editor's live viewport through lumina.  The viewport hands over a [LuminaWorld] bound to its Filament engine; this scene mounts the open level's mesh actors, a sun and a plain sky, plus one [LuminaProceduralMeshComponent] whose sections carry the debug geometry: walkable cells (green quads), blocked cells (red quads), the tested path (blue strip hovering 5 cm above the cell floors) and the start / goal flags. Every section is one batched mesh rebuilt only when its data changes — never per frame. Materials are gltfio ubershader instances (unlit, alpha-blended) obtained through flutter_filament's provider; no raw Filament entity work happens here.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Checks current state or capability and returns a boolean value. |
| `world` | `LuminaWorld? get world` | Getter accessor returning the current value of `world`. |
| `meshActorCount` | `int get meshActorCount` | Getter accessor returning the current value of `meshActorCount`. |
| `overlay` | `LuminaProceduralMeshComponent? get overlay` | Getter accessor returning the current value of `overlay`. |
| `overlaySectionCount` | `int get overlaySectionCount` | Number of live overlay sections (walkable / blocked / path / flags). |
| `hasWalkableSection` | `bool get hasWalkableSection` | Checks current state or capability and returns a boolean value. |
| `hasPathSection` | `bool get hasPathSection` | Checks current state or capability and returns a boolean value. |
| `walkableQuadCount` | `int get walkableQuadCount` | Getter accessor returning the current value of `walkableQuadCount`. |
| `blockedQuadCount` | `int get blockedQuadCount` | Getter accessor returning the current value of `blockedQuadCount`. |
| `detach` | `void detach()` | Releases every reference; the viewport owns the world's cleanup. Overlay sections and material instances are freed here because the sections keep native buffers alive. |

## `lib/ui/features/sub_editors/models/navigation_editor_state.dart`

### `class NavMeshBoundsVolume`

`NavMeshBoundsVolume` is a plain level actor: a unit 1 m box whose `scale` *is* its extent in metres, centred on `location`. That way the outliner, undo, save and the viewport transform gizmos work on it with no special plumbing.

**Constructors:**
- `NavMeshBoundsVolume._()`: Initializes `NavMeshBoundsVolume._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isVolume` | `static bool isVolume(EditorActorNode actor)` | Checks current state or capability and returns a boolean value. |
| `extentOf` | `static List<double> extentOf(EditorActorNode actor) => List<double>.from...` | Extent in metres along x / y / z. |
| `centreOf` | `static Vector3 centreOf(EditorActorNode actor)` | Centre in metres. |
| `aabbMetres` | `static Aabb3 aabbMetres(EditorActorNode actor)` | Axis-aligned bounds in metres. |
| `unionBounds` | `static Aabb3? unionBounds(Iterable<EditorActorNode> volumes)` | Union of all volumes' bounds (metres), or null without volumes. |

### `class NavigationEditorConfig`

`NavigationEditorConfig`: `class` representing the data model or functionality of the module.

**Constructors:**
- `NavigationEditorConfig.defaults()`: The engine's own defaults (`NavGridConfig()`), auto-rebuild off.
- `NavigationEditorConfig.fromSection(Map<String, dynamic> section)`: Initializes `NavigationEditorConfig.fromSection(Map<String, dynamic> section)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cellSize` | `double cellSize` | Holds the `cellSize` property or configuration state. |
| `agentRadius` | `double agentRadius` | Holds the `agentRadius` property or configuration state. |
| `agentHeight` | `double agentHeight` | Holds the `agentHeight` property or configuration state. |
| `maxStepHeight` | `double maxStepHeight` | Holds the `maxStepHeight` property or configuration state. |
| `walkableLayerMask` | `int walkableLayerMask` | Holds the `walkableLayerMask` property or configuration state. |
| `autoRebuild` | `bool autoRebuild` | Holds the `autoRebuild` property or configuration state. |
| `toNavGridConfig` | `NavGridConfig toNavGridConfig()` | Executes `toNavGridConfig` operation. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class NavGridSnapshot`

Per-cell occupancy captured from a built `LuminaNavigationSystem` through its public `isWalkable` / `projectPointToNavigation` queries — the engine has no cell-enumeration accessor yet, so the overlay walks the grid by cell centre, which is exact for a uniform grid.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cols` | `int cols` | Holds the `cols` property or configuration state. |
| `rows` | `int rows` | Holds the `rows` property or configuration state. |
| `cellSize` | `double cellSize` | Holds the `cellSize` property or configuration state. |
| `originX` | `double originX` | Holds the `originX` property or configuration state. |
| `originZ` | `double originZ` | Holds the `originZ` property or configuration state. |
| `floorY` | `double floorY` | Holds the `floorY` property or configuration state. |
| `walkableCount` | `int walkableCount` | Holds the `walkableCount` property or configuration state. |
| `cellCount` | `int get cellCount` | Getter accessor returning the current value of `cellCount`. |
| `blockedCount` | `int get blockedCount` | Getter accessor returning the current value of `blockedCount`. |
| `isWalkableCell` | `bool isWalkableCell(int col, int row)` | Checks current state or capability and returns a boolean value. |
| `floorHeightAt` | `double floorHeightAt(int col, int row)` | Executes `floorHeightAt` operation. |
| `cellCenterX` | `double cellCenterX(int col)` | Executes `cellCenterX` operation. |
| `cellCenterZ` | `double cellCenterZ(int row)` | Executes `cellCenterZ` operation. |
| `capture` | `static NavGridSnapshot capture(LuminaNavigationSystem nav, Aabb3 bounds)` | Enumerates the grid exactly as the engine laid it out (`cols = ceil(width / cellSize)`, cell centre = `min + (i + 0.5) * cellSize`). |

### `class NavBuildResult`

`NavBuildResult`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `finishedAt` | `DateTime finishedAt` | Holds the `finishedAt` property or configuration state. |
| `duration` | `Duration duration` | Holds the `duration` property or configuration state. |
| `walkableCells` | `int walkableCells` | Holds the `walkableCells` property or configuration state. |
| `cols` | `int cols` | Holds the `cols` property or configuration state. |
| `rows` | `int rows` | Holds the `rows` property or configuration state. |
| `cellSize` | `double cellSize` | Holds the `cellSize` property or configuration state. |
| `bounds` | `Aabb3 bounds` | Holds the `bounds` property or configuration state. |
| `obstacleCount` | `int obstacleCount` | Holds the `obstacleCount` property or configuration state. |
| `volumeCount` | `int volumeCount` | Holds the `volumeCount` property or configuration state. |
| `cellCount` | `int get cellCount` | Getter accessor returning the current value of `cellCount`. |
| `durationMs` | `double get durationMs` | Getter accessor returning the current value of `durationMs`. |

### `enum NavPathState`

`NavPathState`: Enumeration listing system options and state constants.

### `class NavPathResult`

`NavPathResult`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `start` | `Vector3 start` | Holds the `start` property or configuration state. |
| `goal` | `Vector3 goal` | Holds the `goal` property or configuration state. |
| `path` | `NavPath? path` | Holds the `path` property or configuration state. |
| `queryTimeMs` | `double queryTimeMs` | Holds the `queryTimeMs` property or configuration state. |
| `state` | `NavPathState state` | Holds the `state` property or configuration state. |
| `pointCount` | `int get pointCount` | Getter accessor returning the current value of `pointCount`. |
| `lengthMetres` | `double get lengthMetres` | Getter accessor returning the current value of `lengthMetres`. |

### `class NavObstacleBox`

`NavObstacleBox`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actorId` | `String actorId` | Holds the `actorId` property or configuration state. |
| `actorName` | `String actorName` | Holds the `actorName` property or configuration state. |
| `center` | `Vector3 center` | Holds the `center` property or configuration state. |
| `halfExtent` | `Vector3 halfExtent` | Holds the `halfExtent` property or configuration state. |
| `rotation` | `Quaternion rotation` | Holds the `rotation` property or configuration state. |
| `top` | `double get top` | Getter accessor returning the current value of `top`. |
| `bottom` | `double get bottom` | Getter accessor returning the current value of `bottom`. |

### `class NavigationWorldBuilder`

Turns the open level's actors into the collision world the nav bake reads.

**Constructors:**
- `NavigationWorldBuilder._()`: Initializes `NavigationWorldBuilder._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `obstaclesFrom` | `static List<NavObstacleBox> obstaclesFrom(Iterable<EditorActorNode> actors)` | Collision boxes of every actor that carries real geometry: mesh actors use their parsed mesh bounds × scale; capsule components use their authored radius / half height. Volumes, pawns, lights, folders and environment actors carry no collision. |
| `intersectsXZ` | `static bool intersectsXZ(NavObstacleBox box, Aabb3 bounds)` | Executes `intersectsXZ` operation. |
| `buildWorld` | `static LuminaWorld buildWorld(Iterable<NavObstacleBox> obstacles)` | A pure-Dart `LuminaWorld` (no native context) holding one actor with a block-all `LuminaCollisionComponent` per obstacle — exactly what `LuminaNavigationSystem.buildFromWorld` rasterizes. |
| `signature` | `static String signature(Iterable<EditorActorNode> actors)` | A stable fingerprint of everything the bake depends on (volumes and obstacle transforms) so the editor can tell real scene changes from unrelated notifications. |

## `lib/ui/features/sub_editors/services/build_pipeline_service/navigation_thumbnail_validation_steps.dart`

### `class NavBuildOutcome`

**Constructors:**

- `const NavBuildOutcome(this.status, this.message)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `status` | `final BuildStepStatus status` |  |
| `message` | `final String message` |  |

### `typedef NavigationBuilder`

Delegate seam for the navigation bake so the navigation editor can plug its own build path in; the default reads the level file.

### `class NavigationBuildStep`

**Constructors:**

- `NavigationBuildStep({NavigationBuilder? builder})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `levelFileNavigationBuilder` | `static Future<NavBuildOutcome> levelFileNavigationBuilder(BuildStepContext ctx) async` | Reads `NavMeshBoundsVolume` actors (and the level's `navigation` section) from the active level `.lmas`, then runs the engine's real grid bake ([LuminaNavigationSystem.buildFromWorld]) on a headless world. |

### `class ThumbnailRegenStep`

**Constructors:**

- `ThumbnailRegenStep({ThumbnailService? thumbnailService})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isStale` | `static bool isStale(AssetIndexEntry entry)` | Stale when the asset has no embedded thumbnail, no thumbnail stamp (`metadata.thumbnail_asset_modified`), or its `.lmas` was modified after that stamp (there is no `.thumbnails/` sidecar to compare with). |

### `class AssetValidationStep`

---

[Previous: Material editor](material.md) | [Up: Sub-editors](index.md) | [Next: Particle editor](particle.md)
