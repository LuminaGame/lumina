[English](../../../en/lumina_ui/sub-editors/navigation.md)

# Navigasyon editörü

Navigasyon editörü: sınır volume'ları, agent ve grid parametreleri, yürünebilir hücre katmanıyla gerçek bir navigasyon bake'i ve bir A* yol test aracı. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/navigation_sub_editor.dart`](#libuifeaturessub_editorsviewsnavigation_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/navigation_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsnavigation_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/navigation_preview_scene.dart`](#libuifeaturessub_editorsservicesnavigation_preview_scenedart)
- [`lib/ui/features/sub_editors/models/navigation_editor_state.dart`](#libuifeaturessub_editorsmodelsnavigation_editor_statedart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/navigation_thumbnail_validation_steps.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicenavigation_thumbnail_validation_stepsdart)

## `lib/ui/features/sub_editors/views/navigation_sub_editor.dart`

### `class NavigationSubEditor`

Navigation sub-editor: bounds volumes, agent / grid parameters, a real `LuminaNavigationSystem` bake with a walkable-cell overlay and a click-driven A* path tester. The backend is a uniform walkable grid with 8-connected A* — not Recast — and the UI says so.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | `editorViewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `NavigationEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<NavigationSubEditor> createState() => _NavigationSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _NavigationSubEditorState`

`_NavigationSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `viewModelForTest` | `NavigationEditorViewModel? get viewModelForTest` | `viewModelForTest` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _LeftPanel`

`_LeftPanel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `NavigationEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `filterController` | `TextEditingController filterController` | `filterController` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _VolumeRow`

`_VolumeRow`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `NavigationEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `volume` | `EditorActorNode volume` | `volume` alanını (field/property) ve ilişkili veriyi saklar. |
| `selected` | `bool selected` | `selected` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _VolumeInspector`

Centre / extent inputs of the selected volume (metres → actor cm / scale).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `NavigationEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `volume` | `EditorActorNode volume` | `volume` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _RightPanel`

`_RightPanel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `NavigationEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `maskController` | `TextEditingController maskController` | `maskController` alanını (field/property) ve ilişkili veriyi saklar. |
| `maskFocus` | `FocusNode maskFocus` | `maskFocus` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/navigation_editor_view_model.dart`

### `class NavigationEditorViewModel`

View model of the Navigation sub-editor.  Owns the `NavGridConfig` draft, the selected bounds volume, the path tester endpoints and overlay visibility. [build] unions the level's `NavMeshBoundsVolume` actors into the bounds handed to the real `LuminaNavigationSystem.buildFromWorld` over a collision world derived from the level's mesh geometry, then snapshots per-cell occupancy for the overlay; [testPath] issues real `findPathSync` queries under a stopwatch. Config persists in the level's `navigation` section; volumes are ordinary level actors (undo / outliner / save reuse the editor plumbing).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `editor` | `EditorViewModel editor` | `editor` alanını (field/property) ve ilişkili veriyi saklar. |
| `preview` | `NavigationPreviewScene preview` | `preview` alanını (field/property) ve ilişkili veriyi saklar. |
| `autoRebuildDebounce` | `Duration autoRebuildDebounce` | Debounce applied to auto-rebuilds after scene / config changes. |
| `config` | `NavigationEditorConfig get config` | `config` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isOpened` | `bool get isOpened` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isBuilding` | `bool get isBuilding` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isStale` | `bool get isStale` | The scene or config changed since the last build. |
| `buildCount` | `int get buildCount` | `buildCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `buildError` | `String? get buildError` | `buildError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastBuild` | `NavBuildResult? get lastBuild` | `lastBuild` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `snapshot` | `NavGridSnapshot? get snapshot` | `snapshot` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `navigation` | `LuminaNavigationSystem? get navigation` | The live engine backend of the last build (null before any build). |
| `pathResult` | `NavPathResult? get pathResult` | `pathResult` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `pathStart` | `Vector3? get pathStart` | `pathStart` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `pathGoal` | `Vector3? get pathGoal` | `pathGoal` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `pathTesterMode` | `bool get pathTesterMode` | `pathTesterMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `overlayVisible` | `bool get overlayVisible` | `overlayVisible` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isPreviewAttached` | `bool get isPreviewAttached` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `volumeFilter` | `String get volumeFilter` | `volumeFilter` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `volumes` | `List<EditorActorNode> get volumes` | `volumes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `filteredVolumes` | `List<EditorActorNode> get filteredVolumes` | `filteredVolumes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedVolume` | `EditorActorNode? get selectedVolume` | İlgili aktör veya varlığı seçili duruma getirir. |
| `canBuild` | `bool get canBuild` | `canBuild` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `buildDisabledReason` | `String get buildDisabledReason` | `buildDisabledReason` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hudWalkableLabel` | `String get hudWalkableLabel` | `hudWalkableLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hudGridLabel` | `String get hudGridLabel` | `hudGridLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hudPathLabel` | `String get hudPathLabel` | `hudPathLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hudPathBadge` | `String? get hudPathBadge` | `Partial path` / `No path` badge text, null when a full path exists. |
| `pathDebugLine` | `String get pathDebugLine` | Bottom-bar debug line for the last query. |
| `lastBuildLabel` | `String get lastBuildLabel` | `lastBuildLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `open` | `void open()` | Loads the level's `navigation` section, subscribes to the editor and runs an initial build when volumes exist (baked data is derived state and never persisted). |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `setVolumeFilter` | `void setVolumeFilter(String value)` | `VolumeFilter` parametresini günceller ve sisteme uygular. |
| `selectVolume` | `void selectVolume(String? id)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `addBoundsVolume` | `EditorActorNode addBoundsVolume()` | Spawns a `NavMeshBoundsVolume` centred on the viewport pivot (bottom face resting on the pivot height) with the default 20×5×20 m extent, as one undoable level edit. |
| `deleteVolume` | `void deleteVolume(String id)` | Belirtilen `Volume` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `renameVolume` | `void renameVolume(String id, String name)` | `renameVolume` işlemini gerçekleştirir. |
| `focusVolume` | `void focusVolume(String id)` | `focusVolume` işlemini gerçekleştirir. |
| `setWalkableLayerMask` | `void setWalkableLayerMask(int mask)` | `WalkableLayerMask` parametresini günceller ve sisteme uygular. |
| `setWalkableLayerMaskText` | `bool setWalkableLayerMaskText(String text)` | Parses `0xFF`, `FF` or decimal input; returns false when unparsable. |
| `walkableLayerMaskHex` | `String get walkableLayerMaskHex` | `walkableLayerMaskHex` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setAutoRebuild` | `void setAutoRebuild(bool on)` | `AutoRebuild` parametresini günceller ve sisteme uygular. |
| `build` | `NavBuildResult? build()` | Runs the real grid bake. Returns null (and logs) when there is nothing to bake; never throws into the UI. |
| `setPathTesterMode` | `void setPathTesterMode(bool on)` | `PathTesterMode` parametresini günceller ve sisteme uygular. |
| `setOverlayVisible` | `void setOverlayVisible(bool visible)` | `OverlayVisible` parametresini günceller ve sisteme uygular. |
| `testPath` | `NavPathResult testPath(Vector3 start, Vector3 goal)` | Runs `findPathSync` between [start] and [goal] (metres) under a stopwatch. |
| `placePathPoint` | `void placePathPoint(Vector3 worldCm)` | Click-driven placement in level centimetres: the first click drops the start flag, the second the goal; later clicks move whichever flag is nearer. Endpoints are projected onto the grid by the engine itself. |
| `clearPath` | `void clearPath()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `save` | `Future<bool> save()` | Saves the level (`.lmas` + generated Dart) through the editor. |
| `attachPreview` | `void attachPreview(LuminaWorld world)` | Called by the viewport once its lumina world exists on the live engine. |
| `detachPreview` | `void detachPreview(LuminaWorld world)` | Called by the viewport right before it cleans the world up. |
| `floorTapPlaneCm` | `double get floorTapPlaneCm` | Floor height (level cm) the path-tester clicks are unprojected onto: the baked grid's ground, or the first volume's bottom before a build. |
| `navWorldForTest` | `LuminaWorld? get navWorldForTest` | `navWorldForTest` özelliğinin anlık değerini okuyan getter erişimcisi. |

## `lib/ui/features/sub_editors/services/navigation_preview_scene.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`show CullingMode, FilamentMaterialInstance, FilamentMaterialProvider, MaterialKey`**: `MaterialKey` işlemini gerçekleştirir.

### `class NavigationPreviewScene`

Drives the Navigation sub-editor's live viewport through lumina.  The viewport hands over a [LuminaWorld] bound to its Filament engine; this scene mounts the open level's mesh actors, a sun and a plain sky, plus one [LuminaProceduralMeshComponent] whose sections carry the debug geometry: walkable cells (green quads), blocked cells (red quads), the tested path (blue strip hovering 5 cm above the cell floors) and the start / goal flags. Every section is one batched mesh rebuilt only when its data changes — never per frame. Materials are gltfio ubershader instances (unlit, alpha-blended) obtained through flutter_filament's provider; no raw Filament entity work happens here.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `world` | `LuminaWorld? get world` | `world` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `meshActorCount` | `int get meshActorCount` | `meshActorCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `overlay` | `LuminaProceduralMeshComponent? get overlay` | `overlay` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `overlaySectionCount` | `int get overlaySectionCount` | Number of live overlay sections (walkable / blocked / path / flags). |
| `hasWalkableSection` | `bool get hasWalkableSection` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasPathSection` | `bool get hasPathSection` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `walkableQuadCount` | `int get walkableQuadCount` | `walkableQuadCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `blockedQuadCount` | `int get blockedQuadCount` | `blockedQuadCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `detach` | `void detach()` | Releases every reference; the viewport owns the world's cleanup. Overlay sections and material instances are freed here because the sections keep native buffers alive. |

## `lib/ui/features/sub_editors/models/navigation_editor_state.dart`

### `class NavMeshBoundsVolume`

`NavMeshBoundsVolume` is a plain level actor: a unit 1 m box whose `scale` *is* its extent in metres, centred on `location`. That way the outliner, undo, save and the viewport transform gizmos work on it with no special plumbing.

**Yapıcı Metotlar (Constructors):**
- `NavMeshBoundsVolume._()`: `NavMeshBoundsVolume._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isVolume` | `static bool isVolume(EditorActorNode actor)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `extentOf` | `static List<double> extentOf(EditorActorNode actor) => List<double>.from...` | Extent in metres along x / y / z. |
| `centreOf` | `static Vector3 centreOf(EditorActorNode actor)` | Centre in metres. |
| `aabbMetres` | `static Aabb3 aabbMetres(EditorActorNode actor)` | Axis-aligned bounds in metres. |
| `unionBounds` | `static Aabb3? unionBounds(Iterable<EditorActorNode> volumes)` | Union of all volumes' bounds (metres), or null without volumes. |

### `class NavigationEditorConfig`

`NavigationEditorConfig`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `NavigationEditorConfig.defaults()`: The engine's own defaults (`NavGridConfig()`), auto-rebuild off.
- `NavigationEditorConfig.fromSection(Map<String, dynamic> section)`: `NavigationEditorConfig.fromSection(Map<String, dynamic> section)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cellSize` | `double cellSize` | `cellSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `agentRadius` | `double agentRadius` | `agentRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `agentHeight` | `double agentHeight` | `agentHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxStepHeight` | `double maxStepHeight` | `maxStepHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `walkableLayerMask` | `int walkableLayerMask` | `walkableLayerMask` alanını (field/property) ve ilişkili veriyi saklar. |
| `autoRebuild` | `bool autoRebuild` | `autoRebuild` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNavGridConfig` | `NavGridConfig toNavGridConfig()` | `toNavGridConfig` işlemini gerçekleştirir. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class NavGridSnapshot`

Per-cell occupancy captured from a built `LuminaNavigationSystem` through its public `isWalkable` / `projectPointToNavigation` queries — the engine has no cell-enumeration accessor yet, so the overlay walks the grid by cell centre, which is exact for a uniform grid.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cols` | `int cols` | `cols` alanını (field/property) ve ilişkili veriyi saklar. |
| `rows` | `int rows` | `rows` alanını (field/property) ve ilişkili veriyi saklar. |
| `cellSize` | `double cellSize` | `cellSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `originX` | `double originX` | `originX` alanını (field/property) ve ilişkili veriyi saklar. |
| `originZ` | `double originZ` | `originZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `floorY` | `double floorY` | `floorY` alanını (field/property) ve ilişkili veriyi saklar. |
| `walkableCount` | `int walkableCount` | `walkableCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `cellCount` | `int get cellCount` | `cellCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `blockedCount` | `int get blockedCount` | `blockedCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isWalkableCell` | `bool isWalkableCell(int col, int row)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `floorHeightAt` | `double floorHeightAt(int col, int row)` | `floorHeightAt` işlemini gerçekleştirir. |
| `cellCenterX` | `double cellCenterX(int col)` | `cellCenterX` işlemini gerçekleştirir. |
| `cellCenterZ` | `double cellCenterZ(int row)` | `cellCenterZ` işlemini gerçekleştirir. |
| `capture` | `static NavGridSnapshot capture(LuminaNavigationSystem nav, Aabb3 bounds)` | Enumerates the grid exactly as the engine laid it out (`cols = ceil(width / cellSize)`, cell centre = `min + (i + 0.5) * cellSize`). |

### `class NavBuildResult`

`NavBuildResult`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `finishedAt` | `DateTime finishedAt` | `finishedAt` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `Duration duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `walkableCells` | `int walkableCells` | `walkableCells` alanını (field/property) ve ilişkili veriyi saklar. |
| `cols` | `int cols` | `cols` alanını (field/property) ve ilişkili veriyi saklar. |
| `rows` | `int rows` | `rows` alanını (field/property) ve ilişkili veriyi saklar. |
| `cellSize` | `double cellSize` | `cellSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `bounds` | `Aabb3 bounds` | `bounds` alanını (field/property) ve ilişkili veriyi saklar. |
| `obstacleCount` | `int obstacleCount` | `obstacleCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `volumeCount` | `int volumeCount` | `volumeCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `cellCount` | `int get cellCount` | `cellCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `durationMs` | `double get durationMs` | `durationMs` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `enum NavPathState`

`NavPathState`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class NavPathResult`

`NavPathResult`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `start` | `Vector3 start` | `start` alanını (field/property) ve ilişkili veriyi saklar. |
| `goal` | `Vector3 goal` | `goal` alanını (field/property) ve ilişkili veriyi saklar. |
| `path` | `NavPath? path` | `path` alanını (field/property) ve ilişkili veriyi saklar. |
| `queryTimeMs` | `double queryTimeMs` | `queryTimeMs` alanını (field/property) ve ilişkili veriyi saklar. |
| `state` | `NavPathState state` | `state` alanını (field/property) ve ilişkili veriyi saklar. |
| `pointCount` | `int get pointCount` | `pointCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lengthMetres` | `double get lengthMetres` | `lengthMetres` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class NavObstacleBox`

`NavObstacleBox`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actorId` | `String actorId` | `actorId` alanını (field/property) ve ilişkili veriyi saklar. |
| `actorName` | `String actorName` | `actorName` alanını (field/property) ve ilişkili veriyi saklar. |
| `center` | `Vector3 center` | `center` alanını (field/property) ve ilişkili veriyi saklar. |
| `halfExtent` | `Vector3 halfExtent` | `halfExtent` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotation` | `Quaternion rotation` | `rotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `top` | `double get top` | `top` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `bottom` | `double get bottom` | `bottom` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class NavigationWorldBuilder`

Turns the open level's actors into the collision world the nav bake reads.

**Yapıcı Metotlar (Constructors):**
- `NavigationWorldBuilder._()`: `NavigationWorldBuilder._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `obstaclesFrom` | `static List<NavObstacleBox> obstaclesFrom(Iterable<EditorActorNode> actors)` | Collision boxes of every actor that carries real geometry: mesh actors use their parsed mesh bounds × scale; capsule components use their authored radius / half height. Volumes, pawns, lights, folders and environment actors carry no collision. |
| `intersectsXZ` | `static bool intersectsXZ(NavObstacleBox box, Aabb3 bounds)` | `intersectsXZ` işlemini gerçekleştirir. |
| `buildWorld` | `static LuminaWorld buildWorld(Iterable<NavObstacleBox> obstacles)` | A pure-Dart `LuminaWorld` (no native context) holding one actor with a block-all `LuminaCollisionComponent` per obstacle — exactly what `LuminaNavigationSystem.buildFromWorld` rasterizes. |
| `signature` | `static String signature(Iterable<EditorActorNode> actors)` | A stable fingerprint of everything the bake depends on (volumes and obstacle transforms) so the editor can tell real scene changes from unrelated notifications. |

## `lib/ui/features/sub_editors/services/build_pipeline_service/navigation_thumbnail_validation_steps.dart`

### `class NavBuildOutcome`

**Yapıcı Metotlar (Constructors):**

- `const NavBuildOutcome(this.status, this.message)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `status` | `final BuildStepStatus status` |  |
| `message` | `final String message` |  |

### `typedef NavigationBuilder`

Delegate seam for the navigation bake so the navigation editor can plug its own build path in; the default reads the level file.

### `class NavigationBuildStep`

**Yapıcı Metotlar (Constructors):**

- `NavigationBuildStep({NavigationBuilder? builder})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `levelFileNavigationBuilder` | `static Future<NavBuildOutcome> levelFileNavigationBuilder(BuildStepContext ctx) async` | Reads `NavMeshBoundsVolume` actors (and the level's `navigation` section) from the active level `.lmas`, then runs the engine's real grid bake ([LuminaNavigationSystem.buildFromWorld]) on a headless world. |

### `class ThumbnailRegenStep`

**Yapıcı Metotlar (Constructors):**

- `ThumbnailRegenStep({ThumbnailService? thumbnailService})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isStale` | `static bool isStale(AssetIndexEntry entry)` | Stale when the asset has no embedded thumbnail, no thumbnail stamp (`metadata.thumbnail_asset_modified`), or its `.lmas` was modified after that stamp (there is no `.thumbnails/` sidecar to compare with). |

### `class AssetValidationStep`

---

[Önceki: Materyal editörü](material.md) | [Üst: Alt editörler](index.md) | [Sonraki: Parçacık editörü](particle.md)
