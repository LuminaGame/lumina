[Türkçe](../../../tr/lumina_ui/sub-editors/landscape.md)

# Landscape and foliage

The Landscape and Foliage editor: sculpt brushes, foliage painting, the terrain sink that uploads edited vertex windows, heightmap asset import and the live terrain preview. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/landscape/brush_overlay.dart`](#libuifeaturessub_editorsviewslandscapebrush_overlaydart)
- [`lib/ui/features/sub_editors/views/landscape/foliage_sub_editor.dart`](#libuifeaturessub_editorsviewslandscapefoliage_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/landscape_editor_view_model.dart`](#libuifeaturessub_editorsview_modelslandscape_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/landscape_asset_service.dart`](#libuifeaturessub_editorsserviceslandscape_asset_servicedart)
- [`lib/ui/features/sub_editors/services/landscape_preview_scene.dart`](#libuifeaturessub_editorsserviceslandscape_preview_scenedart)
- [`lib/ui/features/sub_editors/models/landscape_brush.dart`](#libuifeaturessub_editorsmodelslandscape_brushdart)
- [`lib/ui/features/sub_editors/models/landscape_terrain_sink.dart`](#libuifeaturessub_editorsmodelslandscape_terrain_sinkdart)
- [`lib/ui/features/sub_editors/services/landscape_brush_preferences.dart`](#libuifeaturessub_editorsserviceslandscape_brush_preferencesdart)

## `lib/ui/features/sub_editors/views/landscape/brush_overlay.dart`

### `class LandscapeBrushOverlay`

Interactive terrain map drawn over the viewport.  The map is the heightmap itself (real samples, colour-ramped from the terrain's own min/max), with the tile seams, every foliage instance and the brush ring — inner circle = full strength, outer circle = falloff edge — under the cursor. Dragging on it sculpts or paints at the exact world position, so the brush works identically here, in tests and in the smoke run.  **Engine gap, stated not stubbed**: projecting the ring onto the rendered terrain in the 3D viewport needs a world→screen projection that `SubEditor3DViewport` does not expose yet (it only unprojects clicks onto a floor plane). Until it does, the ring lives on this terrain-space map and the viewport's floor-plane clicks drive the same brush.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `LandscapeEditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `size` | `double size` | Holds the `size` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _LandscapeMapPainter`

`_LandscapeMapPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `data` | `LandscapeData data` | Holds the `data` property or configuration state. |
| `sectionsPerSide` | `int sectionsPerSide` | Holds the `sectionsPerSide` property or configuration state. |
| `cursorX` | `double? cursorX` | Holds the `cursorX` property or configuration state. |
| `cursorZ` | `double? cursorZ` | Holds the `cursorZ` property or configuration state. |
| `radius` | `double radius` | Holds the `radius` property or configuration state. |
| `falloff` | `double falloff` | Holds the `falloff` property or configuration state. |
| `eraseMode` | `bool eraseMode` | Holds the `eraseMode` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _LandscapeMapPainter old)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/views/landscape/foliage_sub_editor.dart`

### `class LandscapeFoliageSubEditor`

Landscape / Foliage sub-editor.  Honest scope: the terrain is a real heightmap turned into tiled `LuminaProceduralMeshComponent` sections, sculpted by real brushes that upload only the touched vertex windows, and foliage is scattered into real `LuminaInstancedStaticMeshComponent` batches. A weight-blended texture `Paint` tab (Grass/Rock/Mud/Snow target layers) is **not** here: no multi-layer terrain material exists in lumina or flutter_filament yet, so shipping those controls would mean shipping dead buttons.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | Holds the `editorViewModel` property or configuration state. |
| `viewModel` | `LandscapeEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<LandscapeFoliageSubEditor> createState() => _LandscapeFoliageSubEd...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _LandscapeFoliageSubEditorState`

`_LandscapeFoliageSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModelForTest` | `LandscapeEditorViewModel get viewModelForTest` | Getter accessor returning the current value of `viewModelForTest`. |
| `previewSceneForTest` | `LandscapePreviewScene? get previewSceneForTest` | The live preview scene, so smoke tests can assert what actually reached the Filament scene rather than only what the model counted. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/landscape_editor_view_model.dart`

**Top-level Functions:**

- **`show AssetType, LandscapeData, LandscapeMeshBuilder, RealAssetInfo`**: Executes `RealAssetInfo` operation.

### `enum LandscapeEditorTab`

Which left/right panel the sub-editor shows.

### `enum FoliagePaintMode`

Paint or erase, for the foliage brush.

### `class LandscapeUndoEntry`

One undoable edit.  Height strokes snapshot **only the dirty rect** (the mesh is regenerable, so nothing else has to be stored); foliage operations snapshot the edited layer's transform array, which is the layer's entire state and still tiny next to the heightmap.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `rect` | `HeightRect? rect` | Holds the `rect` property or configuration state. |
| `heightsBefore` | `Float32List? heightsBefore` | Holds the `heightsBefore` property or configuration state. |
| `heightsAfter` | `Float32List? heightsAfter` | Holds the `heightsAfter` property or configuration state. |
| `layerIndex` | `int? layerIndex` | Holds the `layerIndex` property or configuration state. |
| `layerBefore` | `Float32List? layerBefore` | Holds the `layerBefore` property or configuration state. |
| `layerAfter` | `Float32List? layerAfter` | Holds the `layerAfter` property or configuration state. |
| `isHeightStroke` | `bool get isHeightStroke` | Checks current state or capability and returns a boolean value. |
| `snapshotCellCount` | `int get snapshotCellCount` | Cells stored by this entry's snapshot (a stroke stores its rect, never the whole map). |

### `class LandscapeEditorViewModel`

View model of the Landscape / Foliage sub-editor.  Owns a real [LandscapeData] (heightmap + foliage layers), applies the sculpt brushes as pure maths over `heights`, maps the dirty rect of every stamp onto the affected mesh tiles' row-contiguous vertex windows, scatters foliage instances with the layer's real placement rules, and persists everything into a `LANDSCAPE` `.lmas`. Everything that must reach the GPU goes through [LandscapeTerrainSink].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `editor` | `EditorViewModel? editor` | Holds the `editor` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `sink` | `LandscapeTerrainSink sink` | Holds the `sink` property or configuration state. |
| `data` | `LandscapeData get data` | Getter accessor returning the current value of `data`. |
| `sectionMap` | `LandscapeSectionMap get sectionMap` | Getter accessor returning the current value of `sectionMap`. |
| `engineOwnsTerrain` | `bool get engineOwnsTerrain` | True when the engine component owns tile mounting (residency-streamed) rather than the view model pushing every tile. |
| `residencyStats` | `LandscapeResidencyStats? get residencyStats` | What is really resident right now, or null when nothing streams. |
| `setPreviewCamera` | `void setPreviewCamera(double worldX, double worldZ)` | Moves the point residency is centred on. Terrain-space metres.  Does nothing until the engine owns tile mounting — a terrain small enough to be fully resident has nothing to stream. |
| `tool` | `LandscapeTool get tool` | Getter accessor returning the current value of `tool`. |
| `brushRadius` | `double get brushRadius` | Getter accessor returning the current value of `brushRadius`. |
| `brushStrength` | `double get brushStrength` | Getter accessor returning the current value of `brushStrength`. |
| `brushFalloff` | `double get brushFalloff` | Getter accessor returning the current value of `brushFalloff`. |
| `falloffType` | `LandscapeFalloffType get falloffType` | Getter accessor returning the current value of `falloffType`. |
| `tab` | `LandscapeEditorTab get tab` | Getter accessor returning the current value of `tab`. |
| `paintMode` | `FoliagePaintMode get paintMode` | Getter accessor returning the current value of `paintMode`. |
| `selectedFoliageLayer` | `int get selectedFoliageLayer` | Selects the target actor or asset. |
| `newTerrainResolution` | `int get newTerrainResolution` | Getter accessor returning the current value of `newTerrainResolution`. |
| `newTerrainWorldSize` | `double get newTerrainWorldSize` | Getter accessor returning the current value of `newTerrainWorldSize`. |
| `newTerrainMaxHeight` | `double get newTerrainMaxHeight` | Getter accessor returning the current value of `newTerrainMaxHeight`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `isOpened` | `bool get isOpened` | Checks current state or capability and returns a boolean value. |
| `statusMessage` | `String? get statusMessage` | Getter accessor returning the current value of `statusMessage`. |
| `flattenTarget` | `double? get flattenTarget` | Getter accessor returning the current value of `flattenTarget`. |
| `isStroking` | `bool get isStroking` | Checks current state or capability and returns a boolean value. |
| `cursorWorldX` | `double? get cursorWorldX` | Getter accessor returning the current value of `cursorWorldX`. |
| `cursorWorldZ` | `double? get cursorWorldZ` | Getter accessor returning the current value of `cursorWorldZ`. |
| `isPreviewAttached` | `bool get isPreviewAttached` | True when a live lumina world renders the terrain; false means the viewport shows the "engine preview unavailable" badge instead of a fake. |
| `heightMin` | `double get heightMin` | Getter accessor returning the current value of `heightMin`. |
| `heightMax` | `double get heightMax` | Getter accessor returning the current value of `heightMax`. |
| `sectionCount` | `int get sectionCount` | Getter accessor returning the current value of `sectionCount`. |
| `foliageInstanceCount` | `int get foliageInstanceCount` | Getter accessor returning the current value of `foliageInstanceCount`. |
| `canUndo` | `bool get canUndo` | Getter accessor returning the current value of `canUndo`. |
| `canRedo` | `bool get canRedo` | Getter accessor returning the current value of `canRedo`. |
| `undoDepth` | `int get undoDepth` | Reverts the last executed editor operation. |
| `lastSnapshotCellCount` | `int get lastSnapshotCellCount` | Getter accessor returning the current value of `lastSnapshotCellCount`. |
| `meshPalette` | `List<RealAssetInfo> get meshPalette` | Mesh assets available as foliage types — the project's real FILAMESH assets, never a hardcoded list. |
| `statsLabel` | `String get statsLabel` | Getter accessor returning the current value of `statsLabel`. |
| `hudLabel` | `String get hudLabel` | Getter accessor returning the current value of `hudLabel`. |
| `open` | `void open()` | Loads the asset (or starts from a flat terrain) and mounts it. |
| `createTerrainFromForm` | `void createTerrainFromForm()` | `New Terrain` form → real terrain. |
| `importProgress` | `double? get importProgress` | Progress of a running heightmap import, `0..1`, or null when idle. |
| `importHeightmapFileAsync` | `Future<bool> importHeightmapFileAsync(String path)` | Imports a heightmap without freezing the editor.  The PNG decode runs in a background isolate and [importProgress] ticks as each stage completes, so a large map shows a progress bar instead of a frozen window. Returns false and leaves the terrain untouched on any rejection — including a size that does not tile, which comes back naming the nearest sizes that would. |
| `importHeightmapFile` | `bool importHeightmapFile(String path)` | Imports a real grayscale heightmap PNG from disk, synchronously. |
| `setTool` | `void setTool(LandscapeTool tool)` | Updates the `Tool` parameter and applies changes to the system. |
| `setBrushRadius` | `void setBrushRadius(double metres)` | Updates the `BrushRadius` parameter and applies changes to the system. |
| `setBrushStrength` | `void setBrushStrength(double v)` | Updates the `BrushStrength` parameter and applies changes to the system. |
| `setBrushFalloff` | `void setBrushFalloff(double v)` | Updates the `BrushFalloff` parameter and applies changes to the system. |
| `setFalloffType` | `void setFalloffType(LandscapeFalloffType t)` | Updates the `FalloffType` parameter and applies changes to the system. |
| `setTab` | `void setTab(LandscapeEditorTab t)` | Updates the `Tab` parameter and applies changes to the system. |
| `setPaintMode` | `void setPaintMode(FoliagePaintMode mode)` | Updates the `PaintMode` parameter and applies changes to the system. |
| `setNewTerrainResolution` | `void setNewTerrainResolution(int r)` | Updates the `NewTerrainResolution` parameter and applies changes to the system. |
| `setNewTerrainWorldSize` | `void setNewTerrainWorldSize(double m)` | Updates the `NewTerrainWorldSize` parameter and applies changes to the system. |
| `setNewTerrainMaxHeight` | `void setNewTerrainMaxHeight(double m)` | Updates the `NewTerrainMaxHeight` parameter and applies changes to the system. |
| `setCursor` | `void setCursor(double? worldX, double? worldZ)` | Brush ring position under the cursor (metres), null when off-terrain. |
| `brushSettings` | `LandscapeBrushSettings get brushSettings` | Getter accessor returning the current value of `brushSettings`. |
| `strokeTo` | `void strokeTo(double worldX, double worldZ)` | Continues the stroke, stamping every ~¼ radius along the drag. |
| `endStroke` | `void endStroke()` | Ends the stroke and records it as a single undo transaction. |
| `undo` | `void undo()` | Reverts the last executed editor operation. |
| `redo` | `void redo()` | Re-applies the last undone editor operation. |
| `removeFoliageLayer` | `void removeFoliageLayer(int index)` | Releases and safely disposes the specified `FoliageLayer` resource. |
| `selectFoliageLayer` | `void selectFoliageLayer(int index)` | Selects the target actor or asset. |
| `setLayerRules` | `void setLayerRules(int index, FoliageRules rules)` | Updates the `LayerRules` parameter and applies changes to the system. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |
| `rebuildPreview` | `void rebuildPreview() => _rebuildAll()` | Rebuilds every terrain section and foliage batch on the sink. Call this once the preview world is up: [attach] gives the scene a fresh mesh component, so whatever was uploaded before it is gone. |

## `lib/ui/features/sub_editors/services/landscape_asset_service.dart`

### `class DecodedHeightmap`

A decoded heightmap image: normalised `[0, 1]` samples, one per pixel.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `samples` | `Float32List samples` | Holds the `samples` property or configuration state. |
| `bitDepth` | `int bitDepth` | Holds the `bitDepth` property or configuration state. |

### `class LandscapeAssetService`

Reads and writes `LANDSCAPE` `.lmas` assets and imports heightmap PNGs.  The heightmap and the foliage layers live in the asset's `raw_payload` (raw little-endian binary — see [LandscapeData.toBytes]); each foliage layer additionally emits an `AssetReference` in slot `foliage_<i>` so the reference graph, the cook and the content browser see the mesh dependency.

**Constructors:**
- `LandscapeAssetService._()`: Initializes `LandscapeAssetService._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `load` | `static LandscapeData? load(String path)` | Loads the landscape payload of a `.lmas`, or null when the file is missing / carries no landscape payload. |
| `decodeHeightmapSamples` | `static DecodedHeightmapSamples decodeHeightmapSamples(Uint8List bytes)` | Decodes a PNG straight into normalized `uint16` samples.  This is the import path for large maps: it never materialises a `Float32List` of the whole image (at 8129² that alone is 264 MB). |
| `decodeHeightmapPng` | `static DecodedHeightmap decodeHeightmapPng(Uint8List bytes)` | Decodes a non-interlaced PNG into normalised `[0, 1]` luminance samples.  Kept for callers that want floats; [decodeHeightmapSamples] is the one the importer uses. |

### `class DecodedHeightmapSamples`

A heightmap decoded straight into the payload's own `uint16` sample space.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `samples` | `Uint16List samples` | Holds the `samples` property or configuration state. |
| `bitDepth` | `int bitDepth` | Holds the `bitDepth` property or configuration state. |

### `class _RawPng`

Unfiltered PNG pixel bytes.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `bitDepth` | `int bitDepth` | Holds the `bitDepth` property or configuration state. |
| `bytesPerPixel` | `int bytesPerPixel` | Holds the `bytesPerPixel` property or configuration state. |
| `stride` | `int stride` | Holds the `stride` property or configuration state. |
| `pixels` | `Uint8List pixels` | Holds the `pixels` property or configuration state. |

## `lib/ui/features/sub_editors/services/landscape_preview_scene.dart`

### `class LandscapePreviewScene`

Mounts the engine's terrain component in the Landscape sub-editor's preview world.  There is exactly one implementation of terrain drawing in the stack and it lives in `package:lumina`: [LuminaLandscapeComponent] owns the procedural mesh tiles, the foliage instance batches, their chunking against `maxAutomaticInstances` and the MIKKTSPACE-split detection that decides whether a tile can take a windowed upload. This class is the adapter between the sub-editor's [LandscapeTerrainSink] seam and that component — it holds no geometry, no materials and no batching logic of its own.  Nothing here fabricates terrain: without an attached world [isAvailable] is false and the editor shows an honest "preview unavailable" badge; when a foliage batch cannot be created, [foliageError] says why.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `landscape` | `LuminaLandscapeComponent? get landscape` | The engine component drawing the terrain, once attached. |
| `foliageError` | `String? get foliageError` | Getter accessor returning the current value of `foliageError`. |
| `terrain` | `LuminaProceduralMeshComponent? get terrain` | Getter accessor returning the current value of `terrain`. |
| `world` | `LuminaWorld? get world` | Getter accessor returning the current value of `world`. |
| `terrainSectionCount` | `int get terrainSectionCount` | Getter accessor returning the current value of `terrainSectionCount`. |
| `batchCount` | `int get batchCount` | Foliage layers with a mounted (or mounting) instance batch. |
| `foliageInstanceCount` | `int foliageInstanceCount(int layerIndex)` | Executes `foliageInstanceCount` operation. |
| `totalFoliageInstances` | `int get totalFoliageInstances` | Getter accessor returning the current value of `totalFoliageInstances`. |
| `foliageChunkCount` | `int get foliageChunkCount` | Renderables currently drawing foliage (one per chunk). |
| `isAvailable` | `bool get isAvailable` | Checks current state or capability and returns a boolean value. |
| `mountPayload` | `bool mountPayload(LandscapeData data)` | Executes `mountPayload` operation. |
| `updateResidency` | `void updateResidency(double worldX, double worldZ)` | Updates the current state or data values. |
| `isSectionResident` | `bool isSectionResident(int sectionIndex)` | Checks current state or capability and returns a boolean value. |
| `rebuildSection` | `bool rebuildSection(int sectionIndex)` | Executes `rebuildSection` operation. |
| `residencyStats` | `LandscapeResidencyStats? get residencyStats` | Getter accessor returning the current value of `residencyStats`. |
| `attach` | `void attach(LuminaWorld world)` | Binds a world handed over by the viewport and mounts lighting + terrain. |
| `detach` | `void detach()` | Executes `detach` operation. |
| `supportsPartialUpdate` | `bool supportsPartialUpdate(int sectionIndex)` | Executes `supportsPartialUpdate` operation. |
| `clearTerrain` | `void clearTerrain()` | Clears all elements from the collection or buffer. |
| `addFoliageInstance` | `int addFoliageInstance(int layerIndex, Matrix4 transform)` | Appends a new item to the collection or scene. |
| `removeFoliageInstance` | `void removeFoliageInstance(int layerIndex, int instanceIndex)` | Releases and safely disposes the specified `FoliageInstance` resource. |

## `lib/ui/features/sub_editors/models/landscape_brush.dart`

**Top-level Functions:**

- **`SectionUpdateWindow`**: Executes `SectionUpdateWindow` operation.

### `enum LandscapeTool`

The sculpt tools the engine can honestly back today.  Ramp / Erosion / Hydro and weight-blended texture layer painting are **not** here: they need a multi-layer terrain material and simulation passes that neither lumina nor flutter_filament define yet.

### `enum LandscapeFalloffType`

Brush falloff curves, matching the editor's `Falloff Type` select.

### `class LandscapeBrushSettings`

One brush stamp's parameters.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `tool` | `LandscapeTool tool` | Holds the `tool` property or configuration state. |
| `radius` | `double radius` | Brush radius in metres. |
| `strength` | `double strength` | Metres of height change at full weight (sculpt/noise), or the pull fraction for flatten/smooth. |
| `falloff` | `double falloff` | Fraction of [radius] that fades out; `0` is a hard-edged cylinder, `1` fades from the very centre. |
| `falloffType` | `LandscapeFalloffType falloffType` | Holds the `falloffType` property or configuration state. |
| `invert` | `bool invert` | Shift-held: sculpt lowers instead of raising. |

### `class LandscapeBrush`

Pure heightmap maths: every brush is a function over `LandscapeData.heights` returning the dirty rect it touched. No GPU, no engine types — the editor, the tests and the smoke run all exercise the identical code.

**Constructors:**
- `LandscapeBrush._()`: Initializes `LandscapeBrush._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `weightAt` | `static double weightAt(double t, double falloff, LandscapeFalloffType type)` | Brush weight at normalised distance [t] (`0` centre → `1` edge). |

### `class _SmoothSource`

A rectangular read-only snapshot of the heightmap, used by the Smooth brush so its 3×3 kernel never reads cells it has already written.  Rect-sized rather than grid-sized: the sculpt path must never touch every sample, and at 8129² a full copy is 264 MB.

**Constructors:**
- `_SmoothSource._(this.minCol, this.minRow, this.cols, this.rows, this.values)`: Initializes `_SmoothSource._(this.minCol, this.minRow, this.cols, this.rows, this.values)`.
- `_SmoothSource.of(LandscapeData data, int minCol, int minRow, int maxCol, int maxRow)`: Initializes `_SmoothSource.of(LandscapeData data, int minCol, int minRow, int maxCol, int maxRow)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `minCol` | `int minCol` | Holds the `minCol` property or configuration state. |
| `minRow` | `int minRow` | Holds the `minRow` property or configuration state. |
| `cols` | `int cols` | Holds the `cols` property or configuration state. |
| `rows` | `int rows` | Holds the `rows` property or configuration state. |
| `values` | `Float32List values` | Holds the `values` property or configuration state. |
| `at` | `double at(int col, int row)` | Height at a grid cell, clamped to the snapshot's own edge (the kernel only ever asks for cells inside the grown rect). |

### `class LandscapeFoliagePainter`

Foliage scattering and erasing over a real heightmap.

**Constructors:**
- `LandscapeFoliagePainter._()`: Initializes `LandscapeFoliagePainter._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `instancesInCircle` | `static List<int> instancesInCircle(FoliageLayer layer, double centerX, d...` | Indices of [layer]'s instances inside a circle, ascending. |

## `lib/ui/features/sub_editors/models/landscape_terrain_sink.dart`

### `class LandscapeTerrainSink`

The engine seam of the Landscape editor.  The view model owns the heightmap and the foliage transforms; everything that has to reach the GPU goes through this sink. The real implementation is `LandscapePreviewScene` (lumina `LuminaProceduralMeshComponent` tiles + one `LuminaInstancedStaticMeshComponent` per foliage layer); tests use a recording fake, so the upload windows and instance batches are asserted without a renderer.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAvailable` | `bool get isAvailable` | True when a live world is attached and the calls below really render. |
| `mountPayload` | `bool mountPayload(LandscapeData data)` | Hands the whole payload to the engine and lets it decide what to mount.  Returns true when the sink took ownership — the engine component then streams tiles against its residency budget, which is the only way an 8129² terrain is renderable at all. Sinks that cannot do that return false and the view model pushes every tile itself, as before. |
| `updateResidency` | `void updateResidency(double worldX, double worldZ)` | Re-solves residency for a camera at a terrain-space position (metres). |
| `isSectionResident` | `bool isSectionResident(int sectionIndex)` | True when [sectionIndex] is currently mounted. A tile the residency budget left out must not be uploaded into by a sculpt stroke. |
| `rebuildSection` | `bool rebuildSection(int sectionIndex)` | Asks the sink to rebuild one whole tile itself, at whatever LOD it currently holds. Returns false when the caller must build it instead. |
| `residencyStats` | `LandscapeResidencyStats? get residencyStats` | Measured residency numbers for the HUD, or null when the sink does not stream (everything mounted). |
| `supportsPartialUpdate` | `bool supportsPartialUpdate(int sectionIndex)` | False when a tile cannot take windowed uploads — the tangent generator may split vertices (MIKKTSPACE remesh), which invalidates vertex offsets. The view model then rebuilds that whole tile instead of writing garbage. |
| `addFoliageInstance` | `int addFoliageInstance(int layerIndex, Matrix4 transform)` | Adds one instance; returns its index in the batch. |
| `removeFoliageInstance` | `void removeFoliageInstance(int layerIndex, int instanceIndex)` | Swap-removes an instance (the batch's last instance relocates into the hole, mirroring the view model's own array). |
| `clearTerrain` | `void clearTerrain()` | Drops every section and batch (new terrain / reopen). |

### `class NullTerrainSink`

A sink that renders nothing — used when the sub-editor runs without a native viewport (unit tests, headless shells). Every call is a no-op and [isAvailable] is false so the UI can show an honest "preview unavailable" badge instead of faking terrain.

**Constructors:**
- `NullTerrainSink()`: Initializes `NullTerrainSink()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAvailable` | `bool get isAvailable` | Checks current state or capability and returns a boolean value. |
| `mountPayload` | `bool mountPayload(LandscapeData data)` | Executes `mountPayload` operation. |
| `updateResidency` | `void updateResidency(double worldX, double worldZ)` | Updates the current state or data values. |
| `isSectionResident` | `bool isSectionResident(int sectionIndex)` | Checks current state or capability and returns a boolean value. |
| `rebuildSection` | `bool rebuildSection(int sectionIndex)` | Executes `rebuildSection` operation. |
| `residencyStats` | `LandscapeResidencyStats? get residencyStats` | Getter accessor returning the current value of `residencyStats`. |
| `supportsPartialUpdate` | `bool supportsPartialUpdate(int sectionIndex)` | Executes `supportsPartialUpdate` operation. |
| `addFoliageInstance` | `int addFoliageInstance(int layerIndex, Matrix4 transform)` | Appends a new item to the collection or scene. |
| `removeFoliageInstance` | `void removeFoliageInstance(int layerIndex, int instanceIndex)` | Releases and safely disposes the specified `FoliageInstance` resource. |
| `clearTerrain` | `void clearTerrain()` | Clears all elements from the collection or buffer. |

### `class LandscapeResidencyStats`

What a streaming landscape really has mounted right now.  Every field is read back from the engine — sections and triangles from the geometry actually uploaded, vertices from the mesh component after any tangent-generator split, bytes from each section's real vertex stride. Nothing here is an estimate.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `residentSections` | `int residentSections` | Holds the `residentSections` property or configuration state. |
| `totalSections` | `int totalSections` | Holds the `totalSections` property or configuration state. |
| `triangles` | `int triangles` | Holds the `triangles` property or configuration state. |
| `vertices` | `int vertices` | Holds the `vertices` property or configuration state. |
| `gpuBytes` | `int gpuBytes` | Holds the `gpuBytes` property or configuration state. |
| `droppedForBudget` | `int droppedForBudget` | Holds the `droppedForBudget` property or configuration state. |
| `foliageInstances` | `int foliageInstances` | Holds the `foliageInstances` property or configuration state. |
| `foliageRenderables` | `int foliageRenderables` | Holds the `foliageRenderables` property or configuration state. |
| `isStreaming` | `bool get isStreaming` | Checks current state or capability and returns a boolean value. |
| `gpuMegabytes` | `double get gpuMegabytes` | Getter accessor returning the current value of `gpuMegabytes`. |
| `label` | `String get label` | One line for the viewport HUD. |

## `lib/ui/features/sub_editors/services/landscape_brush_preferences.dart`

### `class LandscapeBrushPreferences`

The Landscape editor's brush settings — the sculpt brush and the foliage brush — as this user left them in this project.

Stored per project in `<project>/.lumina/landscape_brush.json`, next to the editor's `editor_layout.json`: per-project user settings for the Landscape and Foliage modes (Brush Size / Falloff / Paint Density). They describe how the user likes to paint, not the terrain, so they never enter the `.lmas`. Lengths are written in **centimetres** (the editor's authoring unit) and read back into the view model's terrain metres.

**Constructors:**

- `const LandscapeBrushPreferences({this.tool = LandscapeTool.sculpt, this.sculptRadius = 45.0, this.sculptStrength = 0.5, this.sculptFalloff = 0.5, this.falloffTy...`
- `factory LandscapeBrushPreferences.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `tool` | `final LandscapeTool tool` |  |
| `sculptRadius` | `final double sculptRadius` | Sculpt brush radius, terrain metres. |
| `sculptStrength` | `final double sculptStrength` |  |
| `sculptFalloff` | `final double sculptFalloff` |  |
| `falloffType` | `final LandscapeFalloffType falloffType` |  |
| `foliageRadius` | `final double foliageRadius` | Foliage brush radius, terrain metres. |
| `foliageFalloff` | `final double foliageFalloff` |  |
| `paintDensity` | `final double paintDensity` |  |
| `eraseDensity` | `final double eraseDensity` |  |
| `fileName` | `static const String fileName` |  |
| `fileFor` | `static File fileFor(String projectDir)` | The file for the project at [projectDir]. |
| `projectDirOf` | `static String? projectDirOf(String? assetPath)` | The project a landscape asset belongs to: the folder above its `contents/`, or null when the path is not inside a project. |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `load` | `static LandscapeBrushPreferences? load(String projectDir)` | The saved settings of the project at [projectDir], or null when there are none (or the file cannot be read — the defaults then apply). |
| `save` | `void save(String projectDir)` | Writes the settings for the project at [projectDir]. |

---

[Previous: Environment lighting](environment-lighting.md) | [Up: Sub-editors](index.md) | [Next: Material editor](material.md)
