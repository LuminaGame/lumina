[English](../../../en/lumina_ui/sub-editors/landscape.md)

# Landscape ve foliage

Landscape ve Foliage editörü: şekillendirme fırçaları, foliage boyama, düzenlenen vertex pencerelerini yükleyen terrain sink, heightmap asset içe aktarma ve canlı arazi önizlemesi. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `LandscapeEditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `size` | `double size` | `size` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _LandscapeMapPainter`

`_LandscapeMapPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `data` | `LandscapeData data` | `data` alanını (field/property) ve ilişkili veriyi saklar. |
| `sectionsPerSide` | `int sectionsPerSide` | `sectionsPerSide` alanını (field/property) ve ilişkili veriyi saklar. |
| `cursorX` | `double? cursorX` | `cursorX` alanını (field/property) ve ilişkili veriyi saklar. |
| `cursorZ` | `double? cursorZ` | `cursorZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `radius` | `double radius` | `radius` alanını (field/property) ve ilişkili veriyi saklar. |
| `falloff` | `double falloff` | `falloff` alanını (field/property) ve ilişkili veriyi saklar. |
| `eraseMode` | `bool eraseMode` | `eraseMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _LandscapeMapPainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/views/landscape/foliage_sub_editor.dart`

### `class LandscapeFoliageSubEditor`

Landscape / Foliage sub-editor.  Honest scope: the terrain is a real heightmap turned into tiled `LuminaProceduralMeshComponent` sections, sculpted by real brushes that upload only the touched vertex windows, and foliage is scattered into real `LuminaInstancedStaticMeshComponent` batches. A weight-blended texture `Paint` tab (Grass/Rock/Mud/Snow target layers) is **not** here: no multi-layer terrain material exists in lumina or flutter_filament yet, so shipping those controls would mean shipping dead buttons.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | `editorViewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `LandscapeEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<LandscapeFoliageSubEditor> createState() => _LandscapeFoliageSubEd...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _LandscapeFoliageSubEditorState`

`_LandscapeFoliageSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModelForTest` | `LandscapeEditorViewModel get viewModelForTest` | `viewModelForTest` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `previewSceneForTest` | `LandscapePreviewScene? get previewSceneForTest` | The live preview scene, so smoke tests can assert what actually reached the Filament scene rather than only what the model counted. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/landscape_editor_view_model.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`show AssetType, LandscapeData, LandscapeMeshBuilder, RealAssetInfo`**: `RealAssetInfo` işlemini gerçekleştirir.

### `enum LandscapeEditorTab`

Which left/right panel the sub-editor shows.

### `enum FoliagePaintMode`

Paint or erase, for the foliage brush.

### `class LandscapeUndoEntry`

One undoable edit.  Height strokes snapshot **only the dirty rect** (the mesh is regenerable, so nothing else has to be stored); foliage operations snapshot the edited layer's transform array, which is the layer's entire state and still tiny next to the heightmap.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `rect` | `HeightRect? rect` | `rect` alanını (field/property) ve ilişkili veriyi saklar. |
| `heightsBefore` | `Float32List? heightsBefore` | `heightsBefore` alanını (field/property) ve ilişkili veriyi saklar. |
| `heightsAfter` | `Float32List? heightsAfter` | `heightsAfter` alanını (field/property) ve ilişkili veriyi saklar. |
| `layerIndex` | `int? layerIndex` | `layerIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `layerBefore` | `Float32List? layerBefore` | `layerBefore` alanını (field/property) ve ilişkili veriyi saklar. |
| `layerAfter` | `Float32List? layerAfter` | `layerAfter` alanını (field/property) ve ilişkili veriyi saklar. |
| `isHeightStroke` | `bool get isHeightStroke` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `snapshotCellCount` | `int get snapshotCellCount` | Cells stored by this entry's snapshot (a stroke stores its rect, never the whole map). |

### `class LandscapeEditorViewModel`

View model of the Landscape / Foliage sub-editor.  Owns a real [LandscapeData] (heightmap + foliage layers), applies the sculpt brushes as pure maths over `heights`, maps the dirty rect of every stamp onto the affected mesh tiles' row-contiguous vertex windows, scatters foliage instances with the layer's real placement rules, and persists everything into a `LANDSCAPE` `.lmas`. Everything that must reach the GPU goes through [LandscapeTerrainSink].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `editor` | `EditorViewModel? editor` | `editor` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `sink` | `LandscapeTerrainSink sink` | `sink` alanını (field/property) ve ilişkili veriyi saklar. |
| `data` | `LandscapeData get data` | `data` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sectionMap` | `LandscapeSectionMap get sectionMap` | `sectionMap` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `engineOwnsTerrain` | `bool get engineOwnsTerrain` | True when the engine component owns tile mounting (residency-streamed) rather than the view model pushing every tile. |
| `residencyStats` | `LandscapeResidencyStats? get residencyStats` | What is really resident right now, or null when nothing streams. |
| `setPreviewCamera` | `void setPreviewCamera(double worldX, double worldZ)` | Moves the point residency is centred on. Terrain-space metres.  Does nothing until the engine owns tile mounting — a terrain small enough to be fully resident has nothing to stream. |
| `tool` | `LandscapeTool get tool` | `tool` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `brushRadius` | `double get brushRadius` | `brushRadius` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `brushStrength` | `double get brushStrength` | `brushStrength` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `brushFalloff` | `double get brushFalloff` | `brushFalloff` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `falloffType` | `LandscapeFalloffType get falloffType` | `falloffType` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `tab` | `LandscapeEditorTab get tab` | `tab` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `paintMode` | `FoliagePaintMode get paintMode` | `paintMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedFoliageLayer` | `int get selectedFoliageLayer` | İlgili aktör veya varlığı seçili duruma getirir. |
| `newTerrainResolution` | `int get newTerrainResolution` | `newTerrainResolution` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `newTerrainWorldSize` | `double get newTerrainWorldSize` | `newTerrainWorldSize` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `newTerrainMaxHeight` | `double get newTerrainMaxHeight` | `newTerrainMaxHeight` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isOpened` | `bool get isOpened` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `statusMessage` | `String? get statusMessage` | `statusMessage` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `flattenTarget` | `double? get flattenTarget` | `flattenTarget` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isStroking` | `bool get isStroking` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `cursorWorldX` | `double? get cursorWorldX` | `cursorWorldX` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cursorWorldZ` | `double? get cursorWorldZ` | `cursorWorldZ` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isPreviewAttached` | `bool get isPreviewAttached` | True when a live lumina world renders the terrain; false means the viewport shows the "engine preview unavailable" badge instead of a fake. |
| `heightMin` | `double get heightMin` | `heightMin` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `heightMax` | `double get heightMax` | `heightMax` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sectionCount` | `int get sectionCount` | `sectionCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `foliageInstanceCount` | `int get foliageInstanceCount` | `foliageInstanceCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `canUndo` | `bool get canUndo` | `canUndo` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `canRedo` | `bool get canRedo` | `canRedo` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `undoDepth` | `int get undoDepth` | Yapılan son işlemi geri alır. |
| `lastSnapshotCellCount` | `int get lastSnapshotCellCount` | `lastSnapshotCellCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `meshPalette` | `List<RealAssetInfo> get meshPalette` | Mesh assets available as foliage types — the project's real FILAMESH assets, never a hardcoded list. |
| `statsLabel` | `String get statsLabel` | `statsLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hudLabel` | `String get hudLabel` | `hudLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `open` | `void open()` | Loads the asset (or starts from a flat terrain) and mounts it. |
| `createTerrainFromForm` | `void createTerrainFromForm()` | `New Terrain` form → real terrain. |
| `importProgress` | `double? get importProgress` | Progress of a running heightmap import, `0..1`, or null when idle. |
| `importHeightmapFileAsync` | `Future<bool> importHeightmapFileAsync(String path)` | Imports a heightmap without freezing the editor.  The PNG decode runs in a background isolate and [importProgress] ticks as each stage completes, so a large map shows a progress bar instead of a frozen window. Returns false and leaves the terrain untouched on any rejection — including a size that does not tile, which comes back naming the nearest sizes that would. |
| `importHeightmapFile` | `bool importHeightmapFile(String path)` | Imports a real grayscale heightmap PNG from disk, synchronously. |
| `setTool` | `void setTool(LandscapeTool tool)` | `Tool` parametresini günceller ve sisteme uygular. |
| `setBrushRadius` | `void setBrushRadius(double metres)` | `BrushRadius` parametresini günceller ve sisteme uygular. |
| `setBrushStrength` | `void setBrushStrength(double v)` | `BrushStrength` parametresini günceller ve sisteme uygular. |
| `setBrushFalloff` | `void setBrushFalloff(double v)` | `BrushFalloff` parametresini günceller ve sisteme uygular. |
| `setFalloffType` | `void setFalloffType(LandscapeFalloffType t)` | `FalloffType` parametresini günceller ve sisteme uygular. |
| `setTab` | `void setTab(LandscapeEditorTab t)` | `Tab` parametresini günceller ve sisteme uygular. |
| `setPaintMode` | `void setPaintMode(FoliagePaintMode mode)` | `PaintMode` parametresini günceller ve sisteme uygular. |
| `setNewTerrainResolution` | `void setNewTerrainResolution(int r)` | `NewTerrainResolution` parametresini günceller ve sisteme uygular. |
| `setNewTerrainWorldSize` | `void setNewTerrainWorldSize(double m)` | `NewTerrainWorldSize` parametresini günceller ve sisteme uygular. |
| `setNewTerrainMaxHeight` | `void setNewTerrainMaxHeight(double m)` | `NewTerrainMaxHeight` parametresini günceller ve sisteme uygular. |
| `setCursor` | `void setCursor(double? worldX, double? worldZ)` | Brush ring position under the cursor (metres), null when off-terrain. |
| `brushSettings` | `LandscapeBrushSettings get brushSettings` | `brushSettings` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `strokeTo` | `void strokeTo(double worldX, double worldZ)` | Continues the stroke, stamping every ~¼ radius along the drag. |
| `endStroke` | `void endStroke()` | Ends the stroke and records it as a single undo transaction. |
| `undo` | `void undo()` | Yapılan son işlemi geri alır. |
| `redo` | `void redo()` | Geri alınan son işlemi yineler. |
| `removeFoliageLayer` | `void removeFoliageLayer(int index)` | Belirtilen `FoliageLayer` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `selectFoliageLayer` | `void selectFoliageLayer(int index)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `setLayerRules` | `void setLayerRules(int index, FoliageRules rules)` | `LayerRules` parametresini günceller ve sisteme uygular. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `rebuildPreview` | `void rebuildPreview() => _rebuildAll()` | Rebuilds every terrain section and foliage batch on the sink. Call this once the preview world is up: [attach] gives the scene a fresh mesh component, so whatever was uploaded before it is gone. |

## `lib/ui/features/sub_editors/services/landscape_asset_service.dart`

### `class DecodedHeightmap`

A decoded heightmap image: normalised `[0, 1]` samples, one per pixel.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `samples` | `Float32List samples` | `samples` alanını (field/property) ve ilişkili veriyi saklar. |
| `bitDepth` | `int bitDepth` | `bitDepth` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LandscapeAssetService`

Reads and writes `LANDSCAPE` `.lmas` assets and imports heightmap PNGs.  The heightmap and the foliage layers live in the asset's `raw_payload` (raw little-endian binary — see [LandscapeData.toBytes]); each foliage layer additionally emits an `AssetReference` in slot `foliage_<i>` so the reference graph, the cook and the content browser see the mesh dependency.

**Yapıcı Metotlar (Constructors):**
- `LandscapeAssetService._()`: `LandscapeAssetService._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `load` | `static LandscapeData? load(String path)` | Loads the landscape payload of a `.lmas`, or null when the file is missing / carries no landscape payload. |
| `decodeHeightmapSamples` | `static DecodedHeightmapSamples decodeHeightmapSamples(Uint8List bytes)` | Decodes a PNG straight into normalized `uint16` samples.  This is the import path for large maps: it never materialises a `Float32List` of the whole image (at 8129² that alone is 264 MB). |
| `decodeHeightmapPng` | `static DecodedHeightmap decodeHeightmapPng(Uint8List bytes)` | Decodes a non-interlaced PNG into normalised `[0, 1]` luminance samples.  Kept for callers that want floats; [decodeHeightmapSamples] is the one the importer uses. |

### `class DecodedHeightmapSamples`

A heightmap decoded straight into the payload's own `uint16` sample space.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `samples` | `Uint16List samples` | `samples` alanını (field/property) ve ilişkili veriyi saklar. |
| `bitDepth` | `int bitDepth` | `bitDepth` alanını (field/property) ve ilişkili veriyi saklar. |

### `class _RawPng`

Unfiltered PNG pixel bytes.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `bitDepth` | `int bitDepth` | `bitDepth` alanını (field/property) ve ilişkili veriyi saklar. |
| `bytesPerPixel` | `int bytesPerPixel` | `bytesPerPixel` alanını (field/property) ve ilişkili veriyi saklar. |
| `stride` | `int stride` | `stride` alanını (field/property) ve ilişkili veriyi saklar. |
| `pixels` | `Uint8List pixels` | `pixels` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/ui/features/sub_editors/services/landscape_preview_scene.dart`

### `class LandscapePreviewScene`

Mounts the engine's terrain component in the Landscape sub-editor's preview world.  There is exactly one implementation of terrain drawing in the stack and it lives in `package:lumina`: [LuminaLandscapeComponent] owns the procedural mesh tiles, the foliage instance batches, their chunking against `maxAutomaticInstances` and the MIKKTSPACE-split detection that decides whether a tile can take a windowed upload. This class is the adapter between the sub-editor's [LandscapeTerrainSink] seam and that component — it holds no geometry, no materials and no batching logic of its own.  Nothing here fabricates terrain: without an attached world [isAvailable] is false and the editor shows an honest "preview unavailable" badge; when a foliage batch cannot be created, [foliageError] says why.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `landscape` | `LuminaLandscapeComponent? get landscape` | The engine component drawing the terrain, once attached. |
| `foliageError` | `String? get foliageError` | `foliageError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `terrain` | `LuminaProceduralMeshComponent? get terrain` | `terrain` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `world` | `LuminaWorld? get world` | `world` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `terrainSectionCount` | `int get terrainSectionCount` | `terrainSectionCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `batchCount` | `int get batchCount` | Foliage layers with a mounted (or mounting) instance batch. |
| `foliageInstanceCount` | `int foliageInstanceCount(int layerIndex)` | `foliageInstanceCount` işlemini gerçekleştirir. |
| `totalFoliageInstances` | `int get totalFoliageInstances` | `totalFoliageInstances` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `foliageChunkCount` | `int get foliageChunkCount` | Renderables currently drawing foliage (one per chunk). |
| `isAvailable` | `bool get isAvailable` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `mountPayload` | `bool mountPayload(LandscapeData data)` | `mountPayload` işlemini gerçekleştirir. |
| `updateResidency` | `void updateResidency(double worldX, double worldZ)` | Mevcut verileri veya durumu günceller. |
| `isSectionResident` | `bool isSectionResident(int sectionIndex)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `rebuildSection` | `bool rebuildSection(int sectionIndex)` | `rebuildSection` işlemini gerçekleştirir. |
| `residencyStats` | `LandscapeResidencyStats? get residencyStats` | `residencyStats` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `attach` | `void attach(LuminaWorld world)` | Binds a world handed over by the viewport and mounts lighting + terrain. |
| `detach` | `void detach()` | `detach` işlemini gerçekleştirir. |
| `supportsPartialUpdate` | `bool supportsPartialUpdate(int sectionIndex)` | `supportsPartialUpdate` işlemini gerçekleştirir. |
| `clearTerrain` | `void clearTerrain()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `addFoliageInstance` | `int addFoliageInstance(int layerIndex, Matrix4 transform)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeFoliageInstance` | `void removeFoliageInstance(int layerIndex, int instanceIndex)` | Belirtilen `FoliageInstance` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |

## `lib/ui/features/sub_editors/models/landscape_brush.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`SectionUpdateWindow`**: `SectionUpdateWindow` işlemini gerçekleştirir.

### `enum LandscapeTool`

The sculpt tools the engine can honestly back today.  Ramp / Erosion / Hydro and weight-blended texture layer painting are **not** here: they need a multi-layer terrain material and simulation passes that neither lumina nor flutter_filament define yet.

### `enum LandscapeFalloffType`

Brush falloff curves, matching the editor's `Falloff Type` select.

### `class LandscapeBrushSettings`

One brush stamp's parameters.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `tool` | `LandscapeTool tool` | `tool` alanını (field/property) ve ilişkili veriyi saklar. |
| `radius` | `double radius` | Brush radius in metres. |
| `strength` | `double strength` | Metres of height change at full weight (sculpt/noise), or the pull fraction for flatten/smooth. |
| `falloff` | `double falloff` | Fraction of [radius] that fades out; `0` is a hard-edged cylinder, `1` fades from the very centre. |
| `falloffType` | `LandscapeFalloffType falloffType` | `falloffType` alanını (field/property) ve ilişkili veriyi saklar. |
| `invert` | `bool invert` | Shift-held: sculpt lowers instead of raising. |

### `class LandscapeBrush`

Pure heightmap maths: every brush is a function over `LandscapeData.heights` returning the dirty rect it touched. No GPU, no engine types — the editor, the tests and the smoke run all exercise the identical code.

**Yapıcı Metotlar (Constructors):**
- `LandscapeBrush._()`: `LandscapeBrush._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `weightAt` | `static double weightAt(double t, double falloff, LandscapeFalloffType type)` | Brush weight at normalised distance [t] (`0` centre → `1` edge). |

### `class _SmoothSource`

A rectangular read-only snapshot of the heightmap, used by the Smooth brush so its 3×3 kernel never reads cells it has already written.  Rect-sized rather than grid-sized: the sculpt path must never touch every sample, and at 8129² a full copy is 264 MB.

**Yapıcı Metotlar (Constructors):**
- `_SmoothSource._(this.minCol, this.minRow, this.cols, this.rows, this.values)`: `_SmoothSource._(this.minCol, this.minRow, this.cols, this.rows, this.values)` nesnesini ilklendirir.
- `_SmoothSource.of(LandscapeData data, int minCol, int minRow, int maxCol, int maxRow)`: `_SmoothSource.of(LandscapeData data, int minCol, int minRow, int maxCol, int maxRow)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `minCol` | `int minCol` | `minCol` alanını (field/property) ve ilişkili veriyi saklar. |
| `minRow` | `int minRow` | `minRow` alanını (field/property) ve ilişkili veriyi saklar. |
| `cols` | `int cols` | `cols` alanını (field/property) ve ilişkili veriyi saklar. |
| `rows` | `int rows` | `rows` alanını (field/property) ve ilişkili veriyi saklar. |
| `values` | `Float32List values` | `values` alanını (field/property) ve ilişkili veriyi saklar. |
| `at` | `double at(int col, int row)` | Height at a grid cell, clamped to the snapshot's own edge (the kernel only ever asks for cells inside the grown rect). |

### `class LandscapeFoliagePainter`

Foliage scattering and erasing over a real heightmap.

**Yapıcı Metotlar (Constructors):**
- `LandscapeFoliagePainter._()`: `LandscapeFoliagePainter._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `instancesInCircle` | `static List<int> instancesInCircle(FoliageLayer layer, double centerX, d...` | Indices of [layer]'s instances inside a circle, ascending. |

## `lib/ui/features/sub_editors/models/landscape_terrain_sink.dart`

### `class LandscapeTerrainSink`

The engine seam of the Landscape editor.  The view model owns the heightmap and the foliage transforms; everything that has to reach the GPU goes through this sink. The real implementation is `LandscapePreviewScene` (lumina `LuminaProceduralMeshComponent` tiles + one `LuminaInstancedStaticMeshComponent` per foliage layer); tests use a recording fake, so the upload windows and instance batches are asserted without a renderer.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Yapıcı Metotlar (Constructors):**
- `NullTerrainSink()`: `NullTerrainSink()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isAvailable` | `bool get isAvailable` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `mountPayload` | `bool mountPayload(LandscapeData data)` | `mountPayload` işlemini gerçekleştirir. |
| `updateResidency` | `void updateResidency(double worldX, double worldZ)` | Mevcut verileri veya durumu günceller. |
| `isSectionResident` | `bool isSectionResident(int sectionIndex)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `rebuildSection` | `bool rebuildSection(int sectionIndex)` | `rebuildSection` işlemini gerçekleştirir. |
| `residencyStats` | `LandscapeResidencyStats? get residencyStats` | `residencyStats` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `supportsPartialUpdate` | `bool supportsPartialUpdate(int sectionIndex)` | `supportsPartialUpdate` işlemini gerçekleştirir. |
| `addFoliageInstance` | `int addFoliageInstance(int layerIndex, Matrix4 transform)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeFoliageInstance` | `void removeFoliageInstance(int layerIndex, int instanceIndex)` | Belirtilen `FoliageInstance` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `clearTerrain` | `void clearTerrain()` | Koleksiyon veya tampon içeriğini tamamen temizler. |

### `class LandscapeResidencyStats`

What a streaming landscape really has mounted right now.  Every field is read back from the engine — sections and triangles from the geometry actually uploaded, vertices from the mesh component after any tangent-generator split, bytes from each section's real vertex stride. Nothing here is an estimate.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `residentSections` | `int residentSections` | `residentSections` alanını (field/property) ve ilişkili veriyi saklar. |
| `totalSections` | `int totalSections` | `totalSections` alanını (field/property) ve ilişkili veriyi saklar. |
| `triangles` | `int triangles` | `triangles` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertices` | `int vertices` | `vertices` alanını (field/property) ve ilişkili veriyi saklar. |
| `gpuBytes` | `int gpuBytes` | `gpuBytes` alanını (field/property) ve ilişkili veriyi saklar. |
| `droppedForBudget` | `int droppedForBudget` | `droppedForBudget` alanını (field/property) ve ilişkili veriyi saklar. |
| `foliageInstances` | `int foliageInstances` | `foliageInstances` alanını (field/property) ve ilişkili veriyi saklar. |
| `foliageRenderables` | `int foliageRenderables` | `foliageRenderables` alanını (field/property) ve ilişkili veriyi saklar. |
| `isStreaming` | `bool get isStreaming` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `gpuMegabytes` | `double get gpuMegabytes` | `gpuMegabytes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `label` | `String get label` | One line for the viewport HUD. |

## `lib/ui/features/sub_editors/services/landscape_brush_preferences.dart`

### `class LandscapeBrushPreferences`

The Landscape editor's brush settings — the sculpt brush and the foliage brush — as this user left them in this project.

Stored per project in `<project>/.lumina/landscape_brush.json`, next to the editor's `editor_layout.json`: per-project user settings for the Landscape and Foliage modes (Brush Size / Falloff / Paint Density). They describe how the user likes to paint, not the terrain, so they never enter the `.lmas`. Lengths are written in **centimetres** (the editor's authoring unit) and read back into the view model's terrain metres.

**Yapıcı Metotlar (Constructors):**

- `const LandscapeBrushPreferences({this.tool = LandscapeTool.sculpt, this.sculptRadius = 45.0, this.sculptStrength = 0.5, this.sculptFalloff = 0.5, this.falloffTy...`
- `factory LandscapeBrushPreferences.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
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

[Önceki: Çevre ışıklandırması](environment-lighting.md) | [Üst: Alt editörler](index.md) | [Sonraki: Materyal editörü](material.md)
