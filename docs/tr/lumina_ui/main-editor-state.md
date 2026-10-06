[English](../../en/lumina_ui/main-editor-state.md)

# Ana editör: view model ve servisler

Ana editörün arkasındaki durum: merkezi view model olan `EditorViewModel` ve etrafındaki servisler: editör kalite ayarları, gizmo controller, Play-In-Editor controller, snapping, viewport picking, klavye kısayolları ve hızlı açma, bulanık eşleştirme, komut registry'si, undo/redo transaction'ları ve actor kataloğu. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/main_editor/view_models/editor_view_model.dart`](#libuifeaturesmain_editorview_modelseditor_view_modeldart)
- [`lib/ui/features/main_editor/services/editor_quality_settings.dart`](#libuifeaturesmain_editorserviceseditor_quality_settingsdart)
- [`lib/ui/features/main_editor/services/gizmo_controller.dart`](#libuifeaturesmain_editorservicesgizmo_controllerdart)
- [`lib/ui/features/main_editor/services/pie_controller.dart`](#libuifeaturesmain_editorservicespie_controllerdart)
- [`lib/ui/features/main_editor/services/snap_service.dart`](#libuifeaturesmain_editorservicessnap_servicedart)
- [`lib/ui/features/main_editor/services/viewport_picker.dart`](#libuifeaturesmain_editorservicesviewport_pickerdart)
- [`lib/ui/features/main_editor/shortcuts/editor_shortcuts_scope.dart`](#libuifeaturesmain_editorshortcutseditor_shortcuts_scopedart)
- [`lib/ui/features/main_editor/shortcuts/quick_open_palette.dart`](#libuifeaturesmain_editorshortcutsquick_open_palettedart)
- [`lib/ui/features/main_editor/utils/fuzzy_match.dart`](#libuifeaturesmain_editorutilsfuzzy_matchdart)
- [`lib/ui/features/main_editor/commands/editor_command.dart`](#libuifeaturesmain_editorcommandseditor_commanddart)
- [`lib/ui/features/main_editor/commands/editor_transaction.dart`](#libuifeaturesmain_editorcommandseditor_transactiondart)
- [`lib/ui/features/main_editor/models/editor_actor_catalog.dart`](#libuifeaturesmain_editormodelseditor_actor_catalogdart)

## `lib/ui/features/main_editor/view_models/editor_view_model.dart`

### `class EditorTabSession`

A live binding between an open sub-editor tab and its view model.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `notifier` | `Listenable notifier` | `notifier` alanını (field/property) ve ilişkili veriyi saklar. |
| `onChanged` | `VoidCallback onChanged` | `onChanged` alanını (field/property) ve ilişkili veriyi saklar. |

### `class EditorTabInfo`

`EditorTabInfo`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `category` | `String category` | `category` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `isDirty` | `bool isDirty` | `isDirty` alanını (field/property) ve ilişkili veriyi saklar. |

### `class EditorActorNode`

`EditorActorNode`: Seviyede (Level) var olan, konuma sahip, yaşam döngüsü (tick/beginPlay) bulunan 3B nesnedir.

**Yapıcı Metotlar (Constructors):**
- `EditorActorNode.fromMap(Map<String, dynamic> map)`: `EditorActorNode.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `String type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `parentId` | `String? parentId` | `parentId` alanını (field/property) ve ilişkili veriyi saklar. |
| `location` | `List<double> location` | `location` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotation` | `List<double> rotation` | `rotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `List<double> scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |
| `isVisible` | `bool isVisible` | `isVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLocked` | `bool isLocked` | `isLocked` alanını (field/property) ve ilişkili veriyi saklar. |
| `mobility` | `String mobility` | `mobility` alanını (field/property) ve ilişkili veriyi saklar. |
| `lightIntensity` | `double lightIntensity` | `lightIntensity` alanını (field/property) ve ilişkili veriyi saklar. |
| `castShadows` | `bool castShadows` | `castShadows` alanını (field/property) ve ilişkili veriyi saklar. |
| `lightColorHex` | `String lightColorHex` | `lightColorHex` alanını (field/property) ve ilişkili veriyi saklar. |
| `materialPath` | `String? materialPath` | `materialPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `thumbnailBytes` | `Uint8List? thumbnailBytes` | `thumbnailBytes` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshData` | `GlbMeshData? meshData` | `meshData` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshAssetPath` | `String? meshAssetPath` | Absolute path of the mesh file (.lmas/.glb/.obj) this actor renders, resolved from the project's contents/ tree. Null for non-mesh actors. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class EditorViewModel`

`EditorViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Yapıcı Metotlar (Constructors):**
- `EditorViewModel._categoryNameFromAssetType(type)`: `EditorViewModel._categoryNameFromAssetType(type)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `collections` | `List<Collection> get collections` | `collections` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `searchQuery` | `String get searchQuery` | `searchQuery` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `searchQuery` | `searchQuery(String value)` | `searchQuery` işlemini gerçekleştirir. |
| `activeTypeFilters` | `Set<AssetType> get activeTypeFilters` | `activeTypeFilters` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeTypeFilters` | `activeTypeFilters(Set<AssetType> value)` | `activeTypeFilters` işlemini gerçekleştirir. |
| `sortMode` | `String get sortMode` | `sortMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sortMode` | `sortMode(String value)` | `sortMode` işlemini gerçekleştirir. |
| `selectedFolder` | `String? get selectedFolder` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedFolder` | `selectedFolder(String? value)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `favoriteFolders` | `Set<String> get favoriteFolders` | `favoriteFolders` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `toggleFavoriteFolder` | `void toggleFavoriteFolder(String folder)` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `activeCollection` | `String? get activeCollection` | `activeCollection` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeCollection` | `activeCollection(String? value)` | `activeCollection` işlemini gerçekleştirir. |
| `showRecentlyModified` | `bool get showRecentlyModified` | `showRecentlyModified` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `showRecentlyModified` | `showRecentlyModified(bool value)` | `showRecentlyModified` işlemini gerçekleştirir. |
| `sourceFolders` | `List<String> get sourceFolders` | `sourceFolders` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `loadCollections` | `Future<void> loadCollections()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `createCollection` | `void createCollection(String name)` | Yeni bir `Collection` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |
| `deleteCollection` | `void deleteCollection(String name)` | Belirtilen `Collection` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `addToCollection` | `void addToCollection(String collectionName, String assetId)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeFromCollection` | `void removeFromCollection(String collectionName, String assetId)` | Belirtilen `FromCollection` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `recentlyModified` | `List<RealAssetInfo> recentlyModified(int n)` | `recentlyModified` işlemini gerçekleştirir. |
| `visibleAssets` | `List<RealAssetInfo> get visibleAssets` | `visibleAssets` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `referenceGraph` | `AssetReferenceGraph get referenceGraph` | `referenceGraph` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `renameAsset` | `void renameAsset(String absolutePath, String newName)` | `renameAsset` işlemini gerçekleştirir. |
| `moveAsset` | `void moveAsset(String absolutePath, String targetFolder)` | `moveAsset` işlemini gerçekleştirir. |
| `duplicateAsset` | `void duplicateAsset(String absolutePath)` | `duplicateAsset` işlemini gerçekleştirir. |
| `sizeInfo` | `Map<String, int> sizeInfo(String absolutePath)` | `sizeInfo` işlemini gerçekleştirir. |
| `referencersOf` | `List<RealAssetInfo> referencersOf(String assetId)` | `referencersOf` işlemini gerçekleştirir. |
| `dependenciesOf` | `List<RealAssetInfo> dependenciesOf(String assetId)` | `dependenciesOf` işlemini gerçekleştirir. |
| `thumbnailQueueLength` | `int get thumbnailQueueLength` | `thumbnailQueueLength` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentThumbnailJob` | `String? get currentThumbnailJob` | `currentThumbnailJob` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `thumbnailQueueProgress` | `double? get thumbnailQueueProgress` | `thumbnailQueueProgress` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `enqueueThumbnail` | `void enqueueThumbnail(String lmasPath)` | `enqueueThumbnail` işlemini gerçekleştirir. |
| `regenerateThumbnail` | `void regenerateThumbnail(String lmasPath)` | `regenerateThumbnail` işlemini gerçekleştirir. |
| `logger` | `EngineLoggerService get logger` | `logger` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `extensionRegistry` | `final PluginExtensionRegistry extensionRegistry` | `extensionRegistry` alanını (field/property) ve ilişkili veriyi saklar. |
| `sourceControl` | `final SourceControlViewModel sourceControl` | Git status/commit/history over the real `git` CLI. |
| `cameraMode` | `String get cameraMode` | `cameraMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `viewMode` | `String get viewMode` | `viewMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `bufferVisualization` | `String get bufferVisualization` | `bufferVisualization` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `showFlags` | `Map<String, bool> get showFlags` | `showFlags` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setCameraMode` | `void setCameraMode(String mode)` | `CameraMode` parametresini günceller ve sisteme uygular. |
| `setViewMode` | `void setViewMode(String mode)` | `ViewMode` parametresini günceller ve sisteme uygular. |
| `setBufferVisualization` | `void setBufferVisualization(String mode)` | `BufferVisualization` parametresini günceller ve sisteme uygular. |
| `toggleShowFlag` | `void toggleShowFlag(String flag)` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `reportFrameTime` | `void reportFrameTime(Duration cpu, Duration frame)` | `reportFrameTime` işlemini gerçekleştirir. |
| `totalTriangles` | `int get totalTriangles` | `totalTriangles` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `translateSnapEnabled` | `bool get translateSnapEnabled` | `translateSnapEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rotateSnapEnabled` | `bool get rotateSnapEnabled` | `rotateSnapEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `scaleSnapEnabled` | `bool get scaleSnapEnabled` | `scaleSnapEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `surfaceSnapEnabled` | `bool get surfaceSnapEnabled` | `surfaceSnapEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `gridVisible` | `bool get gridVisible` | `gridVisible` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `translateSnapStep` | `double get translateSnapStep` | `translateSnapStep` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rotateSnapStep` | `double get rotateSnapStep` | `rotateSnapStep` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `scaleSnapStep` | `double get scaleSnapStep` | `scaleSnapStep` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `editorGridStep` | `double get editorGridStep` | The editor snap grid step as stored in the project. This is what the toolbar's grid-step menu picks; it is unrelated to the world partition. |
| `gridStep` | `double get gridStep` | Spacing the viewport draws its editor grid at. When the level authors an enabled World Partition the viewport draws the partition's `cellSize` so the authored cell boundaries — not an unrelated snap grid — are what you see; otherwise it is the project's own grid step.  **Unit caveat, deliberately not papered over**: `cellSize` is authored in METRES (that is what `LuminaWorldPartitionSubsystem` divides by), while `FilamentEditorGrid` takes CENTIMETRES (`editorSnap.gridStep` defaults to 50 cm over a 2000 cm extent). The number is passed through unconverted, exactly as the template-seeded geometry is, so the viewport shows the authored cell *grid* faithfully — change `cellSize` and the spacing changes — but the drawn cells are not a metre-accurate footprint. Do NOT "fix" this with a ×100 here: the metre/centimetre split runs through the whole editor (imported meshes and the snap grid are centimetre-scale, templates and the runtime are metre-scale) and is an open decision. |
| `gridExtent` | `double get gridExtent` | Extent the viewport draws its grid over. An enabled partition widens it to at least 8 cells across so more than one cell boundary is visible. Same unit caveat as [gridStep]. |
| `updateTranslateSnapEnabled` | `void updateTranslateSnapEnabled(bool v)` | Mevcut verileri veya durumu günceller. |
| `updateRotateSnapEnabled` | `void updateRotateSnapEnabled(bool v)` | Mevcut verileri veya durumu günceller. |
| `updateScaleSnapEnabled` | `void updateScaleSnapEnabled(bool v)` | Mevcut verileri veya durumu günceller. |
| `updateSurfaceSnapEnabled` | `void updateSurfaceSnapEnabled(bool v)` | Mevcut verileri veya durumu günceller. |
| `updateGridVisible` | `void updateGridVisible(bool v)` | Mevcut verileri veya durumu günceller. |
| `updateTranslateSnapStep` | `void updateTranslateSnapStep(double v)` | Mevcut verileri veya durumu günceller. |
| `updateRotateSnapStep` | `void updateRotateSnapStep(double v)` | Mevcut verileri veya durumu günceller. |
| `updateScaleSnapStep` | `void updateScaleSnapStep(double v)` | Mevcut verileri veya durumu günceller. |
| `updateGridStep` | `void updateGridStep(double v)` | Mevcut verileri veya durumu günceller. |
| `updateGridExtent` | `void updateGridExtent(double v)` | Mevcut verileri veya durumu günceller. |
| `commands` | `final EditorCommandRegistry commands` | `commands` alanını (field/property) ve ilişkili veriyi saklar. |
| `layoutState` | `EditorLayoutState layoutState` | `layoutState` alanını (field/property) ve ilişkili veriyi saklar. |
| `isImporting` | `bool get isImporting` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `importStatusMessage` | `String get importStatusMessage` | `importStatusMessage` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `importProgress` | `double? get importProgress` | `importProgress` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cameraSpeedMultiplier` | `double get cameraSpeedMultiplier` | `cameraSpeedMultiplier` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cameraSpeedScalar` | `int get cameraSpeedScalar` | `cameraSpeedScalar` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cameraPanZ` | `double get cameraPanZ` | `cameraPanZ` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setCameraSpeed` | `void setCameraSpeed(int level)` | `CameraSpeed` parametresini günceller ve sisteme uygular. |
| `adjustCameraSpeed` | `void adjustCameraSpeed(int delta)` | `adjustCameraSpeed` işlemini gerçekleştirir. |
| `rotateCamera` | `void rotateCamera(double dx, double dy)` | `rotateCamera` işlemini gerçekleştirir. |
| `walkMove` | `void walkMove(double dx, double dy)` | `walkMove` işlemini gerçekleştirir. |
| `panCamera` | `void panCamera(double dx, double dy)` | `panCamera` işlemini gerçekleştirir. |
| `panPedestal` | `void panPedestal(double dx, double dy)` | `panPedestal` işlemini gerçekleştirir. |
| `orbitCamera` | `void orbitCamera(double dx, double dy)` | `orbitCamera` işlemini gerçekleştirir. |
| `dollyCamera` | `void dollyCamera(double delta)` | `dollyCamera` işlemini gerçekleştirir. |
| `zoomCamera` | `void zoomCamera(double delta)` | `zoomCamera` işlemini gerçekleştirir. |
| `resetCamera` | `void resetCamera()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |
| `gizmoSpace` | `String get gizmoSpace` | `gizmoSpace` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `toggleGizmoSpace` | `void toggleGizmoSpace()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `openTabs` | `List<EditorTabInfo> get openTabs` | `openTabs` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeTabIndex` | `int get activeTabIndex` | `activeTabIndex` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentTab` | `EditorTabInfo get currentTab` | `currentTab` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectTab` | `void selectTab(int index)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `unbindTabSession` | `void unbindTabSession(String tabId)` | `unbindTabSession` işlemini gerçekleştirir. |
| `hasTabSession` | `bool hasTabSession(String tabId) => _tabSessions.containsKey(tabId)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isTabDirty` | `bool isTabDirty(int index)` | Whether the tab at [index] has unsaved changes, consulting the bound sub-editor session when there is one. |
| `saveTab` | `Future<bool> saveTab(int index)` | Saves the tab at [index] through its bound sub-editor (or the level save path for the main tab). Returns false when nothing could save it or the save failed. |
| `closeTab` | `void closeTab(int index)` | `closeTab` işlemini gerçekleştirir. |
| `project` | `LuminaProject get project` | `project` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `engineVersion` | `String get engineVersion` | `engineVersion` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeLevelName` | `String get activeLevelName` | `activeLevelName` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeTool` | `String get activeTool` | `activeTool` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `viewportMode` | `String get viewportMode` | `viewportMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isPlaying` | `bool get isPlaying` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isPaused` | `bool get isPaused` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `selectedActor` | `EditorActorNode? get selectedActor` | İlgili aktör veya varlığı seçili duruma getirir. |
| `primarySelectedActor` | `EditorActorNode? get primarySelectedActor` | `primarySelectedActor` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedActorIds` | `Set<String> get selectedActorIds` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedActors` | `List<EditorActorNode> get selectedActors` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedActorId` | `String? get selectedActorId` | İlgili aktör veya varlığı seçili duruma getirir. |
| `actors` | `List<EditorActorNode> get actors` | `actors` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `addActorNodeForTest` | `void addActorNodeForTest(EditorActorNode node)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `levelEnvironment` | `Map<String, dynamic> get levelEnvironment` | The active level's `environment` payload section as last loaded/edited (see `EnvironmentLightingViewModel`); empty for levels without one. |
| `setLevelEnvironment` | `void setLevelEnvironment(Map<String, dynamic> section)` | Replaces the level's `environment` section and marks the level dirty so auto-save / Save Level persist it with the actors. |
| `levelNavigation` | `Map<String, dynamic> get levelNavigation` | The active level's `navigation` payload section as last loaded/edited (see `NavigationEditorViewModel`); empty for levels without one. |
| `setLevelNavigation` | `void setLevelNavigation(Map<String, dynamic> section)` | Replaces the level's `navigation` section and marks the level dirty so auto-save / Save Level persist it with the actors. |
| `levelWorldPartition` | `Map<String, dynamic> get levelWorldPartition` | The active level's `worldPartition` payload section as last loaded or edited; empty for levels that do not author one. |
| `setLevelWorldPartition` | `void setLevelWorldPartition(Map<String, dynamic> section)` | Replaces the level's `worldPartition` section and marks the level dirty. |
| `worldPartitionEnabled` | `bool get worldPartitionEnabled` | Whether the active level authors an enabled world partition. |
| `worldPartitionCellSize` | `double get worldPartitionCellSize` | Grid cell edge length in metres (`LuminaWorldPartitionSubsystem.cellSize`). |
| `worldPartitionLoadingRange` | `double get worldPartitionLoadingRange` | Streaming radius in metres applied to sources that author none (`LuminaStreamingSourceComponent.loadingRadius`). |
| `worldPartitionMaxCellTransitionsPerTick` | `int get worldPartitionMaxCellTransitionsPerTick` | Cell state transitions the subsystem may run per tick. |
| `worldPartitionDataLayers` | `List<Map<String, dynamic>> get worldPartitionDataLayers` | The authored data layers (`name`, `initialState`, `isRuntime`). |
| `setWorldPartitionEnabled` | `void setWorldPartitionEnabled(bool v)` | Turns the section on (seeding the runtime's own defaults) or off. Disabling keeps the authored values so toggling back does not lose them. |
| `setWorldPartitionCellSize` | `void setWorldPartitionCellSize(double v)` | Cell edge length in metres; clamped to a positive value because the runtime divides by it. |
| `setWorldPartitionLoadingRange` | `void setWorldPartitionLoadingRange(double v)` | `WorldPartitionLoadingRange` parametresini günceller ve sisteme uygular. |
| `setWorldPartitionMaxCellTransitionsPerTick` | `void setWorldPartitionMaxCellTransitionsPerTick(int v)` | `WorldPartitionMaxCellTransitionsPerTick` parametresini günceller ve sisteme uygular. |
| `addWorldPartitionDataLayer` | `void addWorldPartitionDataLayer([String name = 'DataLayer'])` | Appends a data layer the generated code really registers with `LuminaDataLayerManager.registerLayer`. |
| `removeWorldPartitionDataLayer` | `void removeWorldPartitionDataLayer(int index)` | Belirtilen `WorldPartitionDataLayer` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setWorldPartitionDataLayerName` | `void setWorldPartitionDataLayerName(int index, String name)` | `WorldPartitionDataLayerName` parametresini günceller ve sisteme uygular. |
| `setWorldPartitionDataLayerState` | `void setWorldPartitionDataLayerState(int index, String state)` | [state] is one of `unloaded`, `loaded`, `activated` — the three `DataLayerState` values the runtime has. |
| `worldPartitionCellLabel` | `String? worldPartitionCellLabel(EditorActorNode actor)` | `"x, y"` for the outliner's cell column, or null when the level authors no enabled partition. |
| `navigationBuildRequests` | `int get navigationBuildRequests` | Monotonic counter bumped by `Build → Build Navigation`; the open Navigation sub-editor runs the real grid bake when it changes. |
| `requestNavigationBuild` | `void requestNavigationBuild()` | `Build → Build Navigation`: opens (or focuses) the Navigation workspace tab and asks it to run the same bake as its own Build button. |
| `realAssets` | `List<RealAssetInfo> get realAssets` | `realAssets` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `logs` | `List<EngineLogEntry> get logs` | `logs` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `clearLogs` | `void clearLogs()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `cameraYaw` | `double get cameraYaw` | `cameraYaw` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cameraPitch` | `double get cameraPitch` | `cameraPitch` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cameraDistance` | `double get cameraDistance` | `cameraDistance` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cameraPanX` | `double get cameraPanX` | `cameraPanX` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cameraPanY` | `double get cameraPanY` | `cameraPanY` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fps` | `double get fps` | `fps` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cpuMs` | `double get cpuMs` | `cpuMs` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `formatTriangleCount` | `static String formatTriangleCount(int count)` | Formats a triangle count as 1.2K / 3.4M for the viewport stats strip. |
| `viewportStatsLabel` | `String get viewportStatsLabel` | Real stats for the viewport HUD: triangles summed from loaded mesh data, FPS and CPU time measured via [reportFrameTime] (`--` until a frame has been reported). |
| `gpuMs` | `double get gpuMs` | `gpuMs` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `quality` | `EditorQualitySettings get quality` | How the editor viewport renders. Per-user, not part of the project — the project's shipped quality lives in the manifest and Project Settings. |
| `qualityRevision` | `int get qualityRevision` | Bumped whenever [quality] changes, so the viewport knows to re-apply it to its live Filament view. |
| `qualityPreset` | `String get qualityPreset` | `qualityPreset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `resolutionScale` | `double get resolutionScale` | `resolutionScale` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `ssaoEnabled` | `bool get ssaoEnabled` | `ssaoEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `bloomEnabled` | `bool get bloomEnabled` | `bloomEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `screenSpaceReflectionsEnabled` | `bool get screenSpaceReflectionsEnabled` | `screenSpaceReflectionsEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `vsyncEnabled` | `bool get vsyncEnabled` | `vsyncEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `projectDirPath` | `String get projectDirPath` | `projectDirPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setProject` | `void setProject(LuminaProject proj)` | `Project` parametresini günceller ve sisteme uygular. |
| `ensureDefaultLevelAssets` | `Future<void> ensureDefaultLevelAssets() => _ensureDefaultLevelAssets()` | `ensureDefaultLevelAssets` işlemini gerçekleştirir. |
| `refreshAssets` | `void refreshAssets() => _refreshAssets()` | `refreshAssets` işlemini gerçekleştirir. |
| `starterLevelActors` | `static List<EditorActorNode> starterLevelActors()` | The actors a brand-new level starts with. This is the on-disk starter template written into a level's `.lmas` the first time it is created (or the first time a legacy level file without an `actors` list is opened); it is never injected into a session from memory.  The list itself lives in the shared [GameTemplateCatalog] as the Blank 3D template's actor set, so the launcher's scaffolder and the editor's lazy seeding cannot drift apart. |
| `deleteAsset` | `Future<void> deleteAsset(RealAssetInfo asset)` | Belirtilen `Asset` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `spawnRefusalFor` | `String? spawnRefusalFor(String type)` | Why [type] cannot be spawned right now, or null when it can. |
| `ensureActorMeshDataForTest` | `Future<void> ensureActorMeshDataForTest(EditorActorNode actor)` | `ensureActorMeshDataForTest` işlemini gerçekleştirir. |
| `updateActorMaterial` | `void updateActorMaterial(String materialPath)` | Mevcut verileri veya durumu günceller. |
| `replaceActorsForTest` | `void replaceActorsForTest(List<EditorActorNode> actors)` | `replaceActorsForTest` işlemini gerçekleştirir. |
| `frameLevelBounds` | `void frameLevelBounds()` | Mesh sınırları olan aktörleri çerçeveler (geometriden uzaktaki ışıklar, gökyüzü ve oyuncu başlangıçları kamerayı dışarı itmez). Points the viewport camera at the whole level and pulls back far enough to hold it.  Levels do not all share a scale: imported props are authored in centimetres, while the game templates lay out rooms in metres. Framing what is actually in the level means either opens visible, instead of a distant speck or a wall of geometry. |
| `restoreSavedCamera` | `Future<bool> restoreSavedCamera()` | Kamerayı bu projenin en son düzenlendiği yere koyar (`EditorCameraStore`); proje bu makinede hiç açılmadıysa false. Proje açma yolu bunu çağırır ve yalnızca false dönerse seviyeyi çerçeveler. |
| `loadLevelMeshes`, `meshesToLoad`, `meshesLoaded`, `meshesLoading`, `meshLoadOrder` | `Future<void> loadLevelMeshes({bool reframeWhenDone})`, `int`, `int`, `bool`, `List<String>` | Seviyenin aktörlerinde hâlâ eksik olan mesh'leri akıtır: kamera pivotuna en yakın olandan başlayarak, aynı anda `meshLoadConcurrency` (4) tane, GLB ayrıştırma isolate'lerde; sayaçlar stat şeridini besler (`Meshes: a/b`), akış sürerken bildirimler saniyede yaklaşık 20'ye kısılır ve ilk açılış, kamera oynamadıysa her mesh'in sınırları gelince seviyeyi yeniden çerçeveler. Proje açma yolu, `_refreshAssets` ve seviye değiştirme artık mesh'leri tek tek yüklemek yerine akıtır. |
| `cameraState`, `flushCameraState` | `EditorCameraState get cameraState`, `Future<void> flushCameraState()` | Kamera, deponun tuttuğu haliyle; her kamera değişikliği hareket durduktan 400 ms sonra kaydedilir, `flushCameraState` bekleyen kaydı bekler. |
| `focusCameraOnActor` | `void focusCameraOnActor(EditorActorNode actor)` | `focusCameraOnActor` işlemini gerçekleştirir. |
| `actorTypeNameForAssetType` | `static String actorTypeNameForAssetType(AssetType type)` | The outliner actor type an asset dropped into the level becomes.  Public so the landscape placement tests can assert it directly: a `LANDSCAPE` `.lmas` must become a `Landscape` actor, not an untyped `Mesh` with no geometry. |
| `cancelActiveOperation` | `void cancelActiveOperation()` | `cancelActiveOperation` işlemini gerçekleştirir. |
| `childrenOf` | `List<EditorActorNode> childrenOf(String parentId)` | `childrenOf` işlemini gerçekleştirir. |
| `rootActors` | `List<EditorActorNode> get rootActors` | `rootActors` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `canReparent` | `bool canReparent(String parentId, String? newParentId)` | `canReparent` işlemini gerçekleştirir. |
| `reparentActor` | `void reparentActor(String id, String? newParentId)` | `reparentActor` işlemini gerçekleştirir. |
| `renameActor` | `void renameActor(String id, String newName)` | `renameActor` işlemini gerçekleştirir. |
| `duplicateActorSubtree` | `void duplicateActorSubtree(String id)` | `duplicateActorSubtree` işlemini gerçekleştirir. |
| `outlinerSearchQuery` | `String get outlinerSearchQuery` | `outlinerSearchQuery` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setOutlinerSearchQuery` | `void setOutlinerSearchQuery(String query)` | `OutlinerSearchQuery` parametresini günceller ve sisteme uygular. |
| `outlinerTypeFilter` | `String? get outlinerTypeFilter` | `outlinerTypeFilter` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setOutlinerTypeFilter` | `void setOutlinerTypeFilter(String? type)` | `OutlinerTypeFilter` parametresini günceller ve sisteme uygular. |
| `actorCount` | `int get actorCount` | `actorCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hiddenActorCount` | `int get hiddenActorCount` | `hiddenActorCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedCount` | `int get selectedCount` | İlgili aktör veya varlığı seçili duruma getirir. |
| `isEffectivelyVisible` | `bool isEffectivelyVisible(String id)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| | | Outliner'ın gizlediğini Play göstermez: `PieController` doğurduğu aktörlere klasör zincirini işler ve gizli olan her birinde `hiddenInGame` ayarlar; editörün kendi aktör başına bayrakları olduğu gibi kalır. |
| `isEffectivelyLocked` | `bool isEffectivelyLocked(String id)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `setActorLockedWithTransaction` | `void setActorLockedWithTransaction(String id, bool locked)` | `ActorLockedWithTransaction` parametresini günceller ve sisteme uygular. |
| `toggleSoloWithTransaction` | `void toggleSoloWithTransaction(String id)` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `addComponentWithTransaction` | `void addComponentWithTransaction(String actorId, String type)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `reparentActorWithTransaction` | `void reparentActorWithTransaction(String id, String? newParentId)` | `reparentActorWithTransaction` işlemini gerçekleştirir. |
| `renameActorWithTransaction` | `void renameActorWithTransaction(String id, String newName)` | `renameActorWithTransaction` işlemini gerçekleştirir. |
| `deleteSelectedActor` | `void deleteSelectedActor()` | Belirtilen `SelectedActor` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setActiveTool` | `void setActiveTool(String tool)` | `ActiveTool` parametresini günceller ve sisteme uygular. |
| `setViewportMode` | `void setViewportMode(String mode)` | `ViewportMode` parametresini günceller ve sisteme uygular. |
| `selectActor` | `void selectActor(EditorActorNode? actor)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectActors` | `void selectActors(Iterable<String> ids)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `toggleActorSelection` | `void toggleActorSelection(String id)` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `clearSelection` | `void clearSelection()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `selectActorById` | `void selectActorById(String? id)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `updateActorMobility` | `void updateActorMobility(String val)` | Mevcut verileri veya durumu günceller. |
| `updateActorLightIntensity` | `void updateActorLightIntensity(double val)` | Mevcut verileri veya durumu günceller. |
| `updateActorCastShadows` | `void updateActorCastShadows(bool val)` | Mevcut verileri veya durumu günceller. |
| `updateActorLightColor` | `void updateActorLightColor(String val)` | Mevcut verileri veya durumu günceller. |
| `startSimulation` | `void startSimulation()` | `startSimulation` işlemini gerçekleştirir. |
| `togglePauseSimulation` | `void togglePauseSimulation()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `setSimulationPaused` | `void setSimulationPaused(bool paused)` | Mirrors the runtime pause state into the editor flags (toolbar, menu). |
| `stepSimulation` | `void stepSimulation()` | Frame-steps the paused runtime world by one tick. |
| `stopSimulation` | `void stopSimulation()` | `stopSimulation` işlemini gerçekleştirir. |
| `togglePlaySimulation` | `void togglePlaySimulation()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `saveLevelAndGenerateCode` | `Future<void> saveLevelAndGenerateCode()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `applyProjectSettings` | `void applyProjectSettings(LuminaProject saved)` | Adopts a manifest saved by the Project Settings editor so the toolbar scalability state, VSync and every other section share the same truth. |
| `updateQualityPreset` | `void updateQualityPreset(String preset)` | Mevcut verileri veya durumu günceller. |
| `toggleVSync` | `void toggleVSync()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `flushQualitySettings` | `Future<void> flushQualitySettings()` | Awaits the in-flight settings write. Tests and shutdown use this; normal UI interaction does not have to. |
| `loadQualitySettings` | `Future<void> loadQualitySettings()` | Restores this project's saved editor quality, if any. |
| `toggleSsao` | `void toggleSsao()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `toggleBloom` | `void toggleBloom()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `toggleScreenSpaceReflections` | `void toggleScreenSpaceReflections()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `updateResolutionScale` | `void updateResolutionScale(double scale)` | Mevcut verileri veya durumu günceller. |
| `saveAsset` | `Future<void> saveAsset(LuminaAsset asset)` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `saveLayoutState` | `void saveLayoutState()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `switchLevel` | `void switchLevel(String levelRelativePath)` | `switchLevel` işlemini gerçekleştirir. |
| `importLevelData` | `void importLevelData(String content)` | `importLevelData` işlemini gerçekleştirir. |
| `importLevelDataFromJson` | `void importLevelDataFromJson(dynamic map)` | `importLevelDataFromJson` işlemini gerçekleştirir. |
| `duplicateSelectedActor` | `void duplicateSelectedActor()` | `duplicateSelectedActor` işlemini gerçekleştirir. |
| `clearDirtyFlag` | `void clearDirtyFlag()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `notifyListeners` | `void notifyListeners()` | `notifyListeners` işlemini gerçekleştirir. |
| `buildManagerViewModel` | `buildManagerViewModel` | `buildManagerViewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `revealAssetInContentBrowser` | `void revealAssetInContentBrowser(String relativeAssetPath)` | Focuses the Content Browser on [relativeAssetPath]'s folder and filters the grid to its name (Build Manager's "Reveal in Content Browser"). |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `restoreSnapshot` | `void restoreSnapshot(List<EditorActorNode> snapshot)` | `restoreSnapshot` işlemini gerçekleştirir. |
| `restoreCameraSnapshot` | `void restoreCameraSnapshot(List<double> cam)` | `restoreCameraSnapshot` işlemini gerçekleştirir. |
| `beginTransformDrag` | `void beginTransformDrag()` | `beginTransformDrag` işlemini gerçekleştirir. |
| `cancelTransformDrag` | `void cancelTransformDrag()` | `cancelTransformDrag` işlemini gerçekleştirir. |
| `endTransformDrag` | `void endTransformDrag()` | Bir dönüşüm sürüklemesini tek geri alma adımıyla bitirir. Açık bir Sequencer'ın `actorTransformEditHandler` üzerinden aldığı aktörler orada key'lenir (level adımı ve kirli işareti yok); `applyPropertyToSelection` da `location` / `rotation` / `scale` için aynısını yapar. |
| `actorTransformEditHandler` | `Set<String> Function(List<({EditorActorNode actor, List<double> location, List<double> rotation, List<double> scale})> edits)? actorTransformEditHandler` | Açık bir Sequencer tarafından kurulur: her işlenen aktör dönüşüm düzenlemesini önceki değerleriyle alır; key'lediği id'leri döndürür. |
| `removeComponentWithTransaction` | `void removeComponentWithTransaction(String actorId, String compId)` | Belirtilen `ComponentWithTransaction` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `pluginRegistry` | `final PluginRegistryService pluginRegistry` | `pluginRegistry` alanını (field/property) ve ilişkili veriyi saklar. |
| `pluginPatcher` | `final PluginHostPatcherService pluginPatcher` | `pluginPatcher` alanını (field/property) ve ilişkili veriyi saklar. |
| `pluginRestartRequired` | `bool get pluginRestartRequired` | `pluginRestartRequired` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dismissPluginRestart` | `void dismissPluginRestart()` | `dismissPluginRestart` işlemini gerçekleştirir. |

## `lib/ui/features/main_editor/services/editor_quality_settings.dart`

### `class EditorQualitySettings`

How the **editor viewport** renders — an editor scalability setting, which is a per-user preference rather than a project property.  The project's own shipped quality lives in the `.lmproject` manifest and is edited in Project Settings; this only governs what the user looks at while editing, so it is stored per user, keyed by project directory, and is never written into the project.  Every field maps onto something Filament really does: the preset expands to a [LuminaScalabilityProfile] (shadow type/size/cascades, HDR buffer quality, TAA, MSAA, FXAA), the resolution scale pins Filament's dynamic-resolution scaler, and the three feature flags switch real post-process passes.

**Yapıcı Metotlar (Constructors):**
- `EditorQualitySettings.fromMap(Map<String, dynamic> map)`: `EditorQualitySettings.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `preset` | `String preset` | One of `kQualityPresets` (`Low`, `Medium`, `High`, `Epic`, `Cinematic`). Lower-case, matching `ProjectScalabilitySettings.qualityPreset` in the manifest. The UI capitalises for display; nothing compares display text. |
| `resolutionScale` | `double resolutionScale` | Internal render resolution, as a percentage of the view. 100 means native. |
| `ssao` | `bool ssao` | Screen-space ambient occlusion. |
| `bloom` | `bool bloom` | Bloom. |
| `screenSpaceReflections` | `bool screenSpaceReflections` | Screen-space reflections. |
| `profile` | `LuminaScalabilityProfile get profile` | The engine profile this preset and resolution scale describe. |
| `applyFeatures` | `LuminaPostProcessSettings applyFeatures(LuminaPostProcessSettings base)` | [base] with this settings object's feature flags applied. Used for the post-process passes, which live on the settings rather than the profile. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class EditorCameraState`

Bir projenin viewport kamerası, `EditorCameraStore`'un tuttuğu haliyle: `yaw` ve `pitch` (derece), yörünge `distance`'ı, pivot `panX`/`panY`/`panZ` ve kamera `mode`'u; `toMap` / `fromMap` (eksik bir harita için null).

### `class EditorCameraStore`

Editörün yapılandırma dizinindeki (`LuminaConfigDir`) `editor_camera.json`, proje dizinine göre anahtarlı: `load(projectDirPath)` (ilk açılışta null) ve `save(projectDirPath, camera)`. Bir projeyi yeniden açmak, tüm seviyeyi çerçevelemek yerine kamerayı olduğu yere geri koyar.

### `class EditorQualityStore`

Per-user store for [EditorQualitySettings], one entry per project directory, in `~/.config/lumina/editor_quality.json` — the same place the launcher keeps its recent-project list and the plugin wizard its defaults.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `configDir` | `Directory configDir` | `configDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `file` | `File get file` | `file` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `load` | `Future<EditorQualitySettings> load(String projectDirPath)` | The settings saved for [projectDirPath], or the defaults. |
| `save` | `Future<void> save(String projectDirPath, EditorQualitySettings settings)` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |

## `lib/ui/features/main_editor/services/gizmo_controller.dart`

### `enum GizmoMode`

`GizmoMode`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `enum GizmoSpace`

`GizmoSpace`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class GizmoController`

`GizmoController`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `getAxisDirection` | `static Vector3 getAxisDirection(String axis, GizmoSpace space, [Quaterni...` | `AxisDirection` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getPlaneNormal` | `static Vector3 getPlaneNormal(String planeId, GizmoSpace space, [Quatern...` | `PlaneNormal` bilgisini veya alt nesnesini sorgulayıp döndürür. |

## `lib/ui/features/main_editor/services/pie_controller.dart`

### `class EditorPieGame`

Declarative game built from the editor's level actors for Play-In-Editor.  Every editor actor is mapped to a real Lumina runtime object via [mapEditorActor]; the resulting tree is mounted into a [LuminaWorld] on the live Filament engine/scene so the simulated world contains the same meshes, lights and pawn the editor shows.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `editorActors` | `List<EditorActorNode> editorActors` | `editorActors` alanını (field/property) ve ilişkili veriyi saklar. |
| `templateKind` | `GameTemplateKind templateKind` | Which pawn the project's template scaffolds. `blank` plays the level with no player at all, which is what Simulate means for a level that has no game framework in it. |
| `input` | `BoundProjectInput input` | The project's own input actions and mapping contexts, bound to the runtime. Rebinding a key in Project Settings changes what Play does. |
| `playerController` | `LuminaPlayerController? playerController` | The local player's controller once [startPlayerSession] has run. |
| `playerPawn` | `LuminaTemplateCharacter? get playerPawn` | The possessed character, or null while no pawn is possessed. |
| `hasPlayerSession` | `bool get hasPlayerSession` | Whether this project carries a game mode that spawns a player. |
| `installSubsystems` | `void installSubsystems(LuminaWorld world)` | Registers the subsystems a playing world needs but a mounted tree does not create for itself.  Without the collision subsystem the character movement component has nothing to sweep against: the character neither falls onto the floor nor is stopped by a wall, and simply floats through the level. The generated game registers the same subsystem from its level script actor. |
| `installGameMode` | `void installGameMode(LuminaWorld world)` | Installs the game mode on [world] **before** `beginPlay`, because `LuminaWorld.beginPlay` is what calls `initGame` and creates the game state that `login` adds the player to. |
| `startPlayerSession` | `void startPlayerSession()` | Logs the local player in **after** `beginPlay`: `findPlayerStart` walks the world's levels, which are only populated once the tree has mounted. |
| `mountIntoWorldForTest` | `void mountIntoWorldForTest(LuminaWorld world)` | Mounts the actor tree into [world] and runs the whole play sequence. Used by tests, which have no Filament engine to mount into. |
| `injectKeyDown` | `void injectKeyDown(LuminaKey key)` | Forwards a key press from the editor viewport into the running world. |
| `injectKeyUp` | `void injectKeyUp(LuminaKey key) => _inputSubsystem?.injectKeyUp(key)` | Forwards a key release from the editor viewport into the running world. |
| `injectMouseDelta` | `void injectMouseDelta(double dx, double dy)` | Forwards a mouse movement, in pixels, into the running world. |
| `tickGame` | `void tickGame(double deltaTime)` | `tickGame` işlemini gerçekleştirir. |
| `step` | `void step(double deltaTime)` | `step` işlemini gerçekleştirir. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |
| `mapEditorActor` | `static LuminaObject? mapEditorActor(EditorActorNode actor)` | Maps an editor actor to its runtime counterpart, or null for organisational nodes such as folders. |

### `class PieController`

`PieController`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PieController(this.viewModel)`: `PieController(this.viewModel)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `lastError` | `String? lastError` | Last error raised while mounting or ticking the runtime world, or null. |
| `game` | `EditorPieGame? get game` | The mounted runtime game while playing, or null. |
| `playerPawn` | `LuminaTemplateCharacter? get playerPawn` | The possessed character while playing, or null. |
| `templateKindForProject` | `GameTemplateKind templateKindForProject()` | Which pawn this project's template scaffolds, read from the manifest. |
| `boundInputForProject` | `BoundProjectInput boundInputForProject()` | The project's input actions and key bindings, bound to the runtime.  A project created before the template work has no input section; it falls back to its template's defaults so Play still moves, and the user can then edit them in Project Settings. |
| `startPie` | `void startPie(FilamentEngine engine, FilamentScene scene)` | `startPie` işlemini gerçekleştirir. |
| `stopPie` | `void stopPie(FilamentEngine engine, FilamentScene scene)` | `stopPie` işlemini gerçekleştirir. |
| `pause` | `void pause()` | Pauses the runtime world (timers, subsystems and audio freeze) and the editor tick. No-op unless playing. |
| `resume` | `void resume()` | `resume` işlemini gerçekleştirir. |
| `step` | `void step([double dt = 1 / 60])` | Advances the paused world by exactly one tick of [dt] seconds (frame stepping). No-op unless playing and paused. |
| `restart` | `void restart()` | Restarts the running session: the runtime world is rebuilt from the same editor snapshot on the same engine/scene, resuming play. |
| `acceptsGameInput` | `bool get acceptsGameInput` | Whether the running world should receive keyboard and mouse events. An ejected user drives the editor flycam instead of the pawn. |
| `injectKeyDown` | `void injectKeyDown(LuminaKey key)` | `injectKeyDown` işlemini gerçekleştirir. |
| `injectKeyUp` | `void injectKeyUp(LuminaKey key)` | `injectKeyUp` işlemini gerçekleştirir. |
| `injectMouseDelta` | `void injectMouseDelta(double dx, double dy)` | `injectMouseDelta` işlemini gerçekleştirir. |
| `eject` | `void eject()` | `eject` işlemini gerçekleştirir. |
| `possess` | `void possess()` | `possess` işlemini gerçekleştirir. |
| `tick` | `void tick(double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |

## `lib/ui/features/main_editor/services/snap_service.dart`

### `class SnapService`

`SnapService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `snapValue` | `static double snapValue(double value, double step)` | `snapValue` işlemini gerçekleştirir. |
| `snapVector` | `static List<double> snapVector(List<double> vector, double step)` | `snapVector` işlemini gerçekleştirir. |
| `snapAngle` | `static double snapAngle(double angle, double step)` | `snapAngle` işlemini gerçekleştirir. |

## `lib/ui/features/main_editor/services/viewport_picker.dart`

### `class PickHit`

`PickHit`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PickHit(this.actor, this.distance)`: `PickHit(this.actor, this.distance)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actor` | `EditorActorNode actor` | `actor` alanını (field/property) ve ilişkili veriyi saklar. |
| `distance` | `double distance` | `distance` alanını (field/property) ve ilişkili veriyi saklar. |

### `class ViewportPicker`

`ViewportPicker`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `pickActors` | `List<PickHit> pickActors(List<EditorActorNode> actors, Ray ray, Matrix4?...` | `pickActors` işlemini gerçekleştirir. |

## `lib/ui/features/main_editor/shortcuts/editor_shortcuts_scope.dart`

### `class ConditionalActivator`

`ConditionalActivator`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ConditionalActivator(this.key, this.viewModel)`: `ConditionalActivator(this.key, this.viewModel)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `key` | `LogicalKeyboardKey key` | `key` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `accepts` | `bool accepts(KeyEvent event, HardwareKeyboard state)` | `accepts` işlemini gerçekleştirir. |
| `triggers` | `Iterable<LogicalKeyboardKey>? get triggers` | `triggers` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `debugDescribeKeys` | `String debugDescribeKeys()` | `debugDescribeKeys` işlemini gerçekleştirir. |

### `class DispatchCommandIntent`

`DispatchCommandIntent`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `DispatchCommandIntent(this.commandId)`: `DispatchCommandIntent(this.commandId)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `commandId` | `String commandId` | `commandId` alanını (field/property) ve ilişkili veriyi saklar. |

### `class EditorShortcutsScope`

`EditorShortcutsScope`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `child` | `Widget child` | `child` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<EditorShortcutsScope> createState() => _EditorShortcutsScopeState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _EditorShortcutsScopeState`

`_EditorShortcutsScopeState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/shortcuts/quick_open_palette.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`void showQuickOpenPalette(BuildContext context, EditorViewModel viewModel, FocusNode returnFocus)`**: `showQuickOpenPalette` işlemini gerçekleştirir.

### `class QuickOpenPaletteWidget`

`QuickOpenPaletteWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<QuickOpenPaletteWidget> createState() => _QuickOpenPaletteWidgetSt...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _QuickOpenPaletteWidgetState`

`_QuickOpenPaletteWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/utils/fuzzy_match.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`List<QuickOpenMatch> fuzzyMatchAssets(String query, List<RealAssetInfo> assets)`**: `fuzzyMatchAssets` işlemini gerçekleştirir.

### `class QuickOpenMatch`

`QuickOpenMatch`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `QuickOpenMatch(this.asset, this.matchIndices, this.score)`: `QuickOpenMatch(this.asset, this.matchIndices, this.score)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `asset` | `RealAssetInfo asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `matchIndices` | `List<int> matchIndices` | `matchIndices` alanını (field/property) ve ilişkili veriyi saklar. |
| `score` | `int score` | `score` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/ui/features/main_editor/commands/editor_command.dart`

### `class EditorCommandRegistry`

`EditorCommandRegistry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `register` | `void register(EditorCommand command)` | Eklentiyi editör bağlamına (`LuminaEditorContext`) kaydeder ve yeteneklerini tanıtır. |
| `registerAll` | `void registerAll(List<EditorCommand> commands)` | `registerAll` işlemini gerçekleştirir. |
| `byId` | `EditorCommand? byId(String id)` | `byId` işlemini gerçekleştirir. |
| `all` | `List<EditorCommand> get all` | `all` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `execute` | `bool execute(String id, [BuildContext? context])` | İlgili komutun veya eylemin mantığını çalıştırır. |

## `lib/ui/features/main_editor/commands/editor_transaction.dart`

### `class EditorTransaction`

`EditorTransaction`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `coalesceKey` | `String? coalesceKey` | `coalesceKey` alanını (field/property) ve ilişkili veriyi saklar. |

### `class TransactionManager`

`TransactionManager`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isApplying` | `bool get isApplying` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `canUndo` | `bool get canUndo` | `canUndo` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `canRedo` | `bool get canRedo` | `canRedo` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `undoLabel` | `String get undoLabel` | Yapılan son işlemi geri alır. |
| `redoLabel` | `String get redoLabel` | Geri alınan son işlemi yineler. |
| `endTransaction` | `void endTransaction()` | `endTransaction` işlemini gerçekleştirir. |
| `record` | `void record(EditorTransaction transaction)` | `record` işlemini gerçekleştirir. |
| `undo` | `void undo()` | Yapılan son işlemi geri alır. |
| `redo` | `void redo()` | Geri alınan son işlemi yineler. |
| `clear` | `void clear()` | Koleksiyon veya tampon içeriğini tamamen temizler. |

## `lib/ui/features/main_editor/models/editor_actor_catalog.dart`

### `class EditorActorType`

One actor type the editor can place in a level.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | The string stored in `metadata.actors[].type` and switched on by the code generator, the viewport painter and the PIE mapper. |
| `label` | `String label` | What the user sees in the spawn menu. |
| `description` | `String description` | One short line saying what placing it does. |
| `category` | `String category` | Menu grouping, e.g. `Lights`. |
| `icon` | `IconData icon` | `icon` alanını (field/property) ve ilişkili veriyi saklar. |
| `color` | `Color color` | `color` alanını (field/property) ve ilişkili veriyi saklar. |
| `unique` | `bool unique` | True when a level may hold at most one (the sky/atmosphere). |
| `lightIntensity` | `double lightIntensity` | Default light intensity for light types, 0 for everything else. |

### `class EditorActorCatalog`

The single answer to "what can this editor place in a level".  The spawn dialog, the outliner's icons and the details panel all read this, so they cannot drift apart the way they did when each kept its own list (the dialog once offered five of ten supported types, so a sky, a spot light and a skeletal mesh could not be placed at all).

**Yapıcı Metotlar (Constructors):**
- `EditorActorCatalog._()`: `EditorActorCatalog._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `categories` | `static List<String> get categories` | Categories in menu order. |
| `inCategory` | `static List<EditorActorType> inCategory(String category)` | `inCategory` işlemini gerçekleştirir. |
| `byId` | `static EditorActorType? byId(String id)` | `byId` işlemini gerçekleştirir. |
| `iconFor` | `static IconData iconFor(String type)` | Icon for any type string, including ones no longer in the catalog (old levels can hold anything). |
| `colorFor` | `static Color colorFor(String type)` | `colorFor` işlemini gerçekleştirir. |

---

[Önceki: Ana editör: view'ler (devamı)](main-editor-views-continued.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Ana editör: view model ve servisler (devamı)](main-editor-state-continued.md)
