[Türkçe](../../tr/lumina_ui/main-editor-state.md)

# Main editor: view model and services

The state behind the main editor: `EditorViewModel`, the central view model, and the services around it: editor quality settings, the gizmo controller, the Play-In-Editor controller, snapping, viewport picking, keyboard shortcuts and quick open, fuzzy matching, the command registry, undo/redo transactions and the actor catalog. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

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

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `notifier` | `Listenable notifier` | Holds the `notifier` property or configuration state. |
| `onChanged` | `VoidCallback onChanged` | Holds the `onChanged` property or configuration state. |

### `class EditorTabInfo`

`EditorTabInfo`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `category` | `String category` | Holds the `category` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `isDirty` | `bool isDirty` | Holds the `isDirty` property or configuration state. |

### `class EditorActorNode`

`EditorActorNode`: 3D scene entity possessing spatial transform and lifecycle (`tick`/`beginPlay`).

**Constructors:**
- `EditorActorNode.fromMap(Map<String, dynamic> map)`: Initializes `EditorActorNode.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `type` | `String type` | Holds the `type` property or configuration state. |
| `parentId` | `String? parentId` | Holds the `parentId` property or configuration state. |
| `location` | `List<double> location` | Holds the `location` property or configuration state. |
| `rotation` | `List<double> rotation` | Holds the `rotation` property or configuration state. |
| `scale` | `List<double> scale` | Holds the `scale` property or configuration state. |
| `isVisible` | `bool isVisible` | Holds the `isVisible` property or configuration state. |
| `isLocked` | `bool isLocked` | Holds the `isLocked` property or configuration state. |
| `mobility` | `String mobility` | Holds the `mobility` property or configuration state. |
| `lightIntensity` | `double lightIntensity` | Holds the `lightIntensity` property or configuration state. |
| `castShadows` | `bool castShadows` | Holds the `castShadows` property or configuration state. |
| `lightColorHex` | `String lightColorHex` | Holds the `lightColorHex` property or configuration state. |
| `materialPath` | `String? materialPath` | Holds the `materialPath` property or configuration state. |
| `thumbnailBytes` | `Uint8List? thumbnailBytes` | Holds the `thumbnailBytes` property or configuration state. |
| `meshData` | `GlbMeshData? meshData` | Holds the `meshData` property or configuration state. |
| `meshAssetPath` | `String? meshAssetPath` | Absolute path of the mesh file (.lmas/.glb/.obj) this actor renders, resolved from the project's contents/ tree. Null for non-mesh actors. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class EditorViewModel`

`EditorViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Constructors:**
- `EditorViewModel._categoryNameFromAssetType(type)`: Initializes `EditorViewModel._categoryNameFromAssetType(type)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `collections` | `List<Collection> get collections` | Getter accessor returning the current value of `collections`. |
| `searchQuery` | `String get searchQuery` | Getter accessor returning the current value of `searchQuery`. |
| `searchQuery` | `searchQuery(String value)` | Executes `searchQuery` operation. |
| `activeTypeFilters` | `Set<AssetType> get activeTypeFilters` | Getter accessor returning the current value of `activeTypeFilters`. |
| `activeTypeFilters` | `activeTypeFilters(Set<AssetType> value)` | Executes `activeTypeFilters` operation. |
| `sortMode` | `String get sortMode` | Getter accessor returning the current value of `sortMode`. |
| `sortMode` | `sortMode(String value)` | Executes `sortMode` operation. |
| `selectedFolder` | `String? get selectedFolder` | Selects the target actor or asset. |
| `selectedFolder` | `selectedFolder(String? value)` | Selects the target actor or asset. |
| `favoriteFolders` | `Set<String> get favoriteFolders` | Getter accessor returning the current value of `favoriteFolders`. |
| `toggleFavoriteFolder` | `void toggleFavoriteFolder(String folder)` | Toggles the target feature or visibility on/off. |
| `activeCollection` | `String? get activeCollection` | Getter accessor returning the current value of `activeCollection`. |
| `activeCollection` | `activeCollection(String? value)` | Executes `activeCollection` operation. |
| `showRecentlyModified` | `bool get showRecentlyModified` | Getter accessor returning the current value of `showRecentlyModified`. |
| `showRecentlyModified` | `showRecentlyModified(bool value)` | Executes `showRecentlyModified` operation. |
| `sourceFolders` | `List<String> get sourceFolders` | Getter accessor returning the current value of `sourceFolders`. |
| `loadCollections` | `Future<void> loadCollections()` | Loads data from disk or memory buffer into the engine. |
| `createCollection` | `void createCollection(String name)` | Creates, configures, and returns a new `Collection` instance or associated GPU resource. |
| `deleteCollection` | `void deleteCollection(String name)` | Releases and safely disposes the specified `Collection` resource. |
| `addToCollection` | `void addToCollection(String collectionName, String assetId)` | Appends a new item to the collection or scene. |
| `removeFromCollection` | `void removeFromCollection(String collectionName, String assetId)` | Releases and safely disposes the specified `FromCollection` resource. |
| `recentlyModified` | `List<RealAssetInfo> recentlyModified(int n)` | Executes `recentlyModified` operation. |
| `visibleAssets` | `List<RealAssetInfo> get visibleAssets` | Getter accessor returning the current value of `visibleAssets`. |
| `referenceGraph` | `AssetReferenceGraph get referenceGraph` | Getter accessor returning the current value of `referenceGraph`. |
| `renameAsset` | `void renameAsset(String absolutePath, String newName)` | Executes `renameAsset` operation. |
| `moveAsset` | `void moveAsset(String absolutePath, String targetFolder)` | Executes `moveAsset` operation. |
| `duplicateAsset` | `void duplicateAsset(String absolutePath)` | Executes `duplicateAsset` operation. |
| `sizeInfo` | `Map<String, int> sizeInfo(String absolutePath)` | Executes `sizeInfo` operation. |
| `referencersOf` | `List<RealAssetInfo> referencersOf(String assetId)` | Executes `referencersOf` operation. |
| `dependenciesOf` | `List<RealAssetInfo> dependenciesOf(String assetId)` | Executes `dependenciesOf` operation. |
| `thumbnailQueueLength` | `int get thumbnailQueueLength` | Getter accessor returning the current value of `thumbnailQueueLength`. |
| `currentThumbnailJob` | `String? get currentThumbnailJob` | Getter accessor returning the current value of `currentThumbnailJob`. |
| `thumbnailQueueProgress` | `double? get thumbnailQueueProgress` | Getter accessor returning the current value of `thumbnailQueueProgress`. |
| `enqueueThumbnail` | `void enqueueThumbnail(String lmasPath)` | Executes `enqueueThumbnail` operation. |
| `regenerateThumbnail` | `void regenerateThumbnail(String lmasPath)` | Executes `regenerateThumbnail` operation. |
| `logger` | `EngineLoggerService get logger` | Getter accessor returning the current value of `logger`. |
| `extensionRegistry` | `final PluginExtensionRegistry extensionRegistry` | Holds the `extensionRegistry` property or configuration state. |
| `sourceControl` | `final SourceControlViewModel sourceControl` | Git status/commit/history over the real `git` CLI. |
| `cameraMode` | `String get cameraMode` | Getter accessor returning the current value of `cameraMode`. |
| `viewMode` | `String get viewMode` | Getter accessor returning the current value of `viewMode`. |
| `bufferVisualization` | `String get bufferVisualization` | Getter accessor returning the current value of `bufferVisualization`. |
| `showFlags` | `Map<String, bool> get showFlags` | Getter accessor returning the current value of `showFlags`. |
| `setCameraMode` | `void setCameraMode(String mode)` | Updates the `CameraMode` parameter and applies changes to the system. |
| `setViewMode` | `void setViewMode(String mode)` | Updates the `ViewMode` parameter and applies changes to the system. |
| `setBufferVisualization` | `void setBufferVisualization(String mode)` | Updates the `BufferVisualization` parameter and applies changes to the system. |
| `toggleShowFlag` | `void toggleShowFlag(String flag)` | Toggles the target feature or visibility on/off. |
| `reportFrameTime` | `void reportFrameTime(Duration cpu, Duration frame)` | Executes `reportFrameTime` operation. |
| `totalTriangles` | `int get totalTriangles` | Getter accessor returning the current value of `totalTriangles`. |
| `translateSnapEnabled` | `bool get translateSnapEnabled` | Getter accessor returning the current value of `translateSnapEnabled`. |
| `rotateSnapEnabled` | `bool get rotateSnapEnabled` | Getter accessor returning the current value of `rotateSnapEnabled`. |
| `scaleSnapEnabled` | `bool get scaleSnapEnabled` | Getter accessor returning the current value of `scaleSnapEnabled`. |
| `surfaceSnapEnabled` | `bool get surfaceSnapEnabled` | Getter accessor returning the current value of `surfaceSnapEnabled`. |
| `gridVisible` | `bool get gridVisible` | Getter accessor returning the current value of `gridVisible`. |
| `translateSnapStep` | `double get translateSnapStep` | Getter accessor returning the current value of `translateSnapStep`. |
| `rotateSnapStep` | `double get rotateSnapStep` | Getter accessor returning the current value of `rotateSnapStep`. |
| `scaleSnapStep` | `double get scaleSnapStep` | Getter accessor returning the current value of `scaleSnapStep`. |
| `editorGridStep` | `double get editorGridStep` | The editor snap grid step as stored in the project. This is what the toolbar's grid-step menu picks; it is unrelated to the world partition. |
| `gridStep` | `double get gridStep` | Spacing the viewport draws its editor grid at. When the level authors an enabled World Partition the viewport draws the partition's `cellSize` so the authored cell boundaries — not an unrelated snap grid — are what you see; otherwise it is the project's own grid step.  **Unit caveat, deliberately not papered over**: `cellSize` is authored in METRES (that is what `LuminaWorldPartitionSubsystem` divides by), while `FilamentEditorGrid` takes CENTIMETRES (`editorSnap.gridStep` defaults to 50 cm over a 2000 cm extent). The number is passed through unconverted, exactly as the template-seeded geometry is, so the viewport shows the authored cell *grid* faithfully — change `cellSize` and the spacing changes — but the drawn cells are not a metre-accurate footprint. Do NOT "fix" this with a ×100 here: the metre/centimetre split runs through the whole editor (imported meshes and the snap grid are centimetre-scale, templates and the runtime are metre-scale) and is an open decision. |
| `gridExtent` | `double get gridExtent` | Extent the viewport draws its grid over. An enabled partition widens it to at least 8 cells across so more than one cell boundary is visible. Same unit caveat as [gridStep]. |
| `updateTranslateSnapEnabled` | `void updateTranslateSnapEnabled(bool v)` | Updates the current state or data values. |
| `updateRotateSnapEnabled` | `void updateRotateSnapEnabled(bool v)` | Updates the current state or data values. |
| `updateScaleSnapEnabled` | `void updateScaleSnapEnabled(bool v)` | Updates the current state or data values. |
| `updateSurfaceSnapEnabled` | `void updateSurfaceSnapEnabled(bool v)` | Updates the current state or data values. |
| `updateGridVisible` | `void updateGridVisible(bool v)` | Updates the current state or data values. |
| `updateTranslateSnapStep` | `void updateTranslateSnapStep(double v)` | Updates the current state or data values. |
| `updateRotateSnapStep` | `void updateRotateSnapStep(double v)` | Updates the current state or data values. |
| `updateScaleSnapStep` | `void updateScaleSnapStep(double v)` | Updates the current state or data values. |
| `updateGridStep` | `void updateGridStep(double v)` | Updates the current state or data values. |
| `updateGridExtent` | `void updateGridExtent(double v)` | Updates the current state or data values. |
| `commands` | `final EditorCommandRegistry commands` | Holds the `commands` property or configuration state. |
| `layoutState` | `EditorLayoutState layoutState` | Holds the `layoutState` property or configuration state. |
| `isImporting` | `bool get isImporting` | Checks current state or capability and returns a boolean value. |
| `importStatusMessage` | `String get importStatusMessage` | Getter accessor returning the current value of `importStatusMessage`. |
| `importProgress` | `double? get importProgress` | Getter accessor returning the current value of `importProgress`. |
| `cameraSpeedMultiplier` | `double get cameraSpeedMultiplier` | Getter accessor returning the current value of `cameraSpeedMultiplier`. |
| `cameraSpeedScalar` | `int get cameraSpeedScalar` | Getter accessor returning the current value of `cameraSpeedScalar`. |
| `cameraPanZ` | `double get cameraPanZ` | Getter accessor returning the current value of `cameraPanZ`. |
| `setCameraSpeed` | `void setCameraSpeed(int level)` | Updates the `CameraSpeed` parameter and applies changes to the system. |
| `adjustCameraSpeed` | `void adjustCameraSpeed(int delta)` | Executes `adjustCameraSpeed` operation. |
| `rotateCamera` | `void rotateCamera(double dx, double dy)` | Executes `rotateCamera` operation. |
| `walkMove` | `void walkMove(double dx, double dy)` | Executes `walkMove` operation. |
| `panCamera` | `void panCamera(double dx, double dy)` | Executes `panCamera` operation. |
| `panPedestal` | `void panPedestal(double dx, double dy)` | Executes `panPedestal` operation. |
| `orbitCamera` | `void orbitCamera(double dx, double dy)` | Executes `orbitCamera` operation. |
| `dollyCamera` | `void dollyCamera(double delta)` | Executes `dollyCamera` operation. |
| `zoomCamera` | `void zoomCamera(double delta)` | Executes `zoomCamera` operation. |
| `resetCamera` | `void resetCamera()` | Resets values or state back to defaults. |
| `gizmoSpace` | `String get gizmoSpace` | Getter accessor returning the current value of `gizmoSpace`. |
| `toggleGizmoSpace` | `void toggleGizmoSpace()` | Toggles the target feature or visibility on/off. |
| `openTabs` | `List<EditorTabInfo> get openTabs` | Getter accessor returning the current value of `openTabs`. |
| `activeTabIndex` | `int get activeTabIndex` | Getter accessor returning the current value of `activeTabIndex`. |
| `currentTab` | `EditorTabInfo get currentTab` | Getter accessor returning the current value of `currentTab`. |
| `selectTab` | `void selectTab(int index)` | Selects the target actor or asset. |
| `unbindTabSession` | `void unbindTabSession(String tabId)` | Executes `unbindTabSession` operation. |
| `hasTabSession` | `bool hasTabSession(String tabId) => _tabSessions.containsKey(tabId)` | Checks current state or capability and returns a boolean value. |
| `isTabDirty` | `bool isTabDirty(int index)` | Whether the tab at [index] has unsaved changes, consulting the bound sub-editor session when there is one. |
| `saveTab` | `Future<bool> saveTab(int index)` | Saves the tab at [index] through its bound sub-editor (or the level save path for the main tab). Returns false when nothing could save it or the save failed. |
| `closeTab` | `void closeTab(int index)` | Executes `closeTab` operation. |
| `project` | `LuminaProject get project` | Getter accessor returning the current value of `project`. |
| `engineVersion` | `String get engineVersion` | Getter accessor returning the current value of `engineVersion`. |
| `activeLevelName` | `String get activeLevelName` | Getter accessor returning the current value of `activeLevelName`. |
| `activeTool` | `String get activeTool` | Getter accessor returning the current value of `activeTool`. |
| `viewportMode` | `String get viewportMode` | Getter accessor returning the current value of `viewportMode`. |
| `isPlaying` | `bool get isPlaying` | Checks current state or capability and returns a boolean value. |
| `isPaused` | `bool get isPaused` | Checks current state or capability and returns a boolean value. |
| `selectedActor` | `EditorActorNode? get selectedActor` | Selects the target actor or asset. |
| `primarySelectedActor` | `EditorActorNode? get primarySelectedActor` | Getter accessor returning the current value of `primarySelectedActor`. |
| `selectedActorIds` | `Set<String> get selectedActorIds` | Selects the target actor or asset. |
| `selectedActors` | `List<EditorActorNode> get selectedActors` | Selects the target actor or asset. |
| `selectedActorId` | `String? get selectedActorId` | Selects the target actor or asset. |
| `actors` | `List<EditorActorNode> get actors` | Getter accessor returning the current value of `actors`. |
| `addActorNodeForTest` | `void addActorNodeForTest(EditorActorNode node)` | Appends a new item to the collection or scene. |
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
| `setWorldPartitionLoadingRange` | `void setWorldPartitionLoadingRange(double v)` | Updates the `WorldPartitionLoadingRange` parameter and applies changes to the system. |
| `setWorldPartitionMaxCellTransitionsPerTick` | `void setWorldPartitionMaxCellTransitionsPerTick(int v)` | Updates the `WorldPartitionMaxCellTransitionsPerTick` parameter and applies changes to the system. |
| `addWorldPartitionDataLayer` | `void addWorldPartitionDataLayer([String name = 'DataLayer'])` | Appends a data layer the generated code really registers with `LuminaDataLayerManager.registerLayer`. |
| `removeWorldPartitionDataLayer` | `void removeWorldPartitionDataLayer(int index)` | Releases and safely disposes the specified `WorldPartitionDataLayer` resource. |
| `setWorldPartitionDataLayerName` | `void setWorldPartitionDataLayerName(int index, String name)` | Updates the `WorldPartitionDataLayerName` parameter and applies changes to the system. |
| `setWorldPartitionDataLayerState` | `void setWorldPartitionDataLayerState(int index, String state)` | [state] is one of `unloaded`, `loaded`, `activated` — the three `DataLayerState` values the runtime has. |
| `worldPartitionCellLabel` | `String? worldPartitionCellLabel(EditorActorNode actor)` | `"x, y"` for the outliner's cell column, or null when the level authors no enabled partition. |
| `navigationBuildRequests` | `int get navigationBuildRequests` | Monotonic counter bumped by `Build → Build Navigation`; the open Navigation sub-editor runs the real grid bake when it changes. |
| `requestNavigationBuild` | `void requestNavigationBuild()` | `Build → Build Navigation`: opens (or focuses) the Navigation workspace tab and asks it to run the same bake as its own Build button. |
| `realAssets` | `List<RealAssetInfo> get realAssets` | Getter accessor returning the current value of `realAssets`. |
| `logs` | `List<EngineLogEntry> get logs` | Getter accessor returning the current value of `logs`. |
| `clearLogs` | `void clearLogs()` | Clears all elements from the collection or buffer. |
| `cameraYaw` | `double get cameraYaw` | Getter accessor returning the current value of `cameraYaw`. |
| `cameraPitch` | `double get cameraPitch` | Getter accessor returning the current value of `cameraPitch`. |
| `cameraDistance` | `double get cameraDistance` | Getter accessor returning the current value of `cameraDistance`. |
| `cameraPanX` | `double get cameraPanX` | Getter accessor returning the current value of `cameraPanX`. |
| `cameraPanY` | `double get cameraPanY` | Getter accessor returning the current value of `cameraPanY`. |
| `fps` | `double get fps` | Getter accessor returning the current value of `fps`. |
| `cpuMs` | `double get cpuMs` | Getter accessor returning the current value of `cpuMs`. |
| `formatTriangleCount` | `static String formatTriangleCount(int count)` | Formats a triangle count as 1.2K / 3.4M for the viewport stats strip. |
| `viewportStatsLabel` | `String get viewportStatsLabel` | Real stats for the viewport HUD: triangles summed from loaded mesh data, FPS and CPU time measured via [reportFrameTime] (`--` until a frame has been reported). |
| `gpuMs` | `double get gpuMs` | Getter accessor returning the current value of `gpuMs`. |
| `quality` | `EditorQualitySettings get quality` | How the editor viewport renders. Per-user, not part of the project — the project's shipped quality lives in the manifest and Project Settings. |
| `qualityRevision` | `int get qualityRevision` | Bumped whenever [quality] changes, so the viewport knows to re-apply it to its live Filament view. |
| `qualityPreset` | `String get qualityPreset` | Getter accessor returning the current value of `qualityPreset`. |
| `resolutionScale` | `double get resolutionScale` | Getter accessor returning the current value of `resolutionScale`. |
| `ssaoEnabled` | `bool get ssaoEnabled` | Getter accessor returning the current value of `ssaoEnabled`. |
| `bloomEnabled` | `bool get bloomEnabled` | Getter accessor returning the current value of `bloomEnabled`. |
| `screenSpaceReflectionsEnabled` | `bool get screenSpaceReflectionsEnabled` | Getter accessor returning the current value of `screenSpaceReflectionsEnabled`. |
| `vsyncEnabled` | `bool get vsyncEnabled` | Getter accessor returning the current value of `vsyncEnabled`. |
| `projectDirPath` | `String get projectDirPath` | Getter accessor returning the current value of `projectDirPath`. |
| `setProject` | `void setProject(LuminaProject proj)` | Updates the `Project` parameter and applies changes to the system. |
| `ensureDefaultLevelAssets` | `Future<void> ensureDefaultLevelAssets() => _ensureDefaultLevelAssets()` | Executes `ensureDefaultLevelAssets` operation. |
| `refreshAssets` | `void refreshAssets() => _refreshAssets()` | Executes `refreshAssets` operation. |
| `starterLevelActors` | `static List<EditorActorNode> starterLevelActors()` | The actors a brand-new level starts with. This is the on-disk starter template written into a level's `.lmas` the first time it is created (or the first time a legacy level file without an `actors` list is opened); it is never injected into a session from memory.  The list itself lives in the shared [GameTemplateCatalog] as the Blank 3D template's actor set, so the launcher's scaffolder and the editor's lazy seeding cannot drift apart. |
| `deleteAsset` | `Future<void> deleteAsset(RealAssetInfo asset)` | Releases and safely disposes the specified `Asset` resource. |
| `spawnRefusalFor` | `String? spawnRefusalFor(String type)` | Why [type] cannot be spawned right now, or null when it can. |
| `ensureActorMeshDataForTest` | `Future<void> ensureActorMeshDataForTest(EditorActorNode actor)` | Executes `ensureActorMeshDataForTest` operation. |
| `updateActorMaterial` | `void updateActorMaterial(String materialPath)` | Updates the current state or data values. |
| `replaceActorsForTest` | `void replaceActorsForTest(List<EditorActorNode> actors)` | Executes `replaceActorsForTest` operation. |
| `frameLevelBounds` | `void frameLevelBounds()` | Points the viewport camera at the whole level and pulls back far enough to hold it.  Levels do not all share a scale: imported props are authored in centimetres, while the game templates lay out rooms in metres. Framing what is actually in the level means either opens visible, instead of a distant speck or a wall of geometry. |
| `focusCameraOnActor` | `void focusCameraOnActor(EditorActorNode actor)` | Executes `focusCameraOnActor` operation. |
| `actorTypeNameForAssetType` | `static String actorTypeNameForAssetType(AssetType type)` | The outliner actor type an asset dropped into the level becomes.  Public so the landscape placement tests can assert it directly: a `LANDSCAPE` `.lmas` must become a `Landscape` actor, not an untyped `Mesh` with no geometry. |
| `cancelActiveOperation` | `void cancelActiveOperation()` | Executes `cancelActiveOperation` operation. |
| `childrenOf` | `List<EditorActorNode> childrenOf(String parentId)` | Executes `childrenOf` operation. |
| `rootActors` | `List<EditorActorNode> get rootActors` | Getter accessor returning the current value of `rootActors`. |
| `canReparent` | `bool canReparent(String parentId, String? newParentId)` | Executes `canReparent` operation. |
| `reparentActor` | `void reparentActor(String id, String? newParentId)` | Executes `reparentActor` operation. |
| `renameActor` | `void renameActor(String id, String newName)` | Executes `renameActor` operation. |
| `duplicateActorSubtree` | `void duplicateActorSubtree(String id)` | Executes `duplicateActorSubtree` operation. |
| `outlinerSearchQuery` | `String get outlinerSearchQuery` | Getter accessor returning the current value of `outlinerSearchQuery`. |
| `setOutlinerSearchQuery` | `void setOutlinerSearchQuery(String query)` | Updates the `OutlinerSearchQuery` parameter and applies changes to the system. |
| `outlinerTypeFilter` | `String? get outlinerTypeFilter` | Getter accessor returning the current value of `outlinerTypeFilter`. |
| `setOutlinerTypeFilter` | `void setOutlinerTypeFilter(String? type)` | Updates the `OutlinerTypeFilter` parameter and applies changes to the system. |
| `actorCount` | `int get actorCount` | Getter accessor returning the current value of `actorCount`. |
| `hiddenActorCount` | `int get hiddenActorCount` | Getter accessor returning the current value of `hiddenActorCount`. |
| `selectedCount` | `int get selectedCount` | Selects the target actor or asset. |
| `isEffectivelyVisible` | `bool isEffectivelyVisible(String id)` | Checks current state or capability and returns a boolean value. |
| `isEffectivelyLocked` | `bool isEffectivelyLocked(String id)` | Checks current state or capability and returns a boolean value. |
| `setActorLockedWithTransaction` | `void setActorLockedWithTransaction(String id, bool locked)` | Updates the `ActorLockedWithTransaction` parameter and applies changes to the system. |
| `toggleSoloWithTransaction` | `void toggleSoloWithTransaction(String id)` | Toggles the target feature or visibility on/off. |
| `addComponentWithTransaction` | `void addComponentWithTransaction(String actorId, String type)` | Appends a new item to the collection or scene. |
| `reparentActorWithTransaction` | `void reparentActorWithTransaction(String id, String? newParentId)` | Executes `reparentActorWithTransaction` operation. |
| `renameActorWithTransaction` | `void renameActorWithTransaction(String id, String newName)` | Executes `renameActorWithTransaction` operation. |
| `deleteSelectedActor` | `void deleteSelectedActor()` | Releases and safely disposes the specified `SelectedActor` resource. |
| `setActiveTool` | `void setActiveTool(String tool)` | Updates the `ActiveTool` parameter and applies changes to the system. |
| `setViewportMode` | `void setViewportMode(String mode)` | Updates the `ViewportMode` parameter and applies changes to the system. |
| `selectActor` | `void selectActor(EditorActorNode? actor)` | Selects the target actor or asset. |
| `selectActors` | `void selectActors(Iterable<String> ids)` | Selects the target actor or asset. |
| `toggleActorSelection` | `void toggleActorSelection(String id)` | Toggles the target feature or visibility on/off. |
| `clearSelection` | `void clearSelection()` | Clears all elements from the collection or buffer. |
| `selectActorById` | `void selectActorById(String? id)` | Selects the target actor or asset. |
| `updateActorMobility` | `void updateActorMobility(String val)` | Updates the current state or data values. |
| `updateActorLightIntensity` | `void updateActorLightIntensity(double val)` | Updates the current state or data values. |
| `updateActorCastShadows` | `void updateActorCastShadows(bool val)` | Updates the current state or data values. |
| `updateActorLightColor` | `void updateActorLightColor(String val)` | Updates the current state or data values. |
| `startSimulation` | `void startSimulation()` | Executes `startSimulation` operation. |
| `togglePauseSimulation` | `void togglePauseSimulation()` | Toggles the target feature or visibility on/off. |
| `setSimulationPaused` | `void setSimulationPaused(bool paused)` | Mirrors the runtime pause state into the editor flags (toolbar, menu). |
| `stepSimulation` | `void stepSimulation()` | Frame-steps the paused runtime world by one tick. |
| `stopSimulation` | `void stopSimulation()` | Executes `stopSimulation` operation. |
| `togglePlaySimulation` | `void togglePlaySimulation()` | Toggles the target feature or visibility on/off. |
| `saveLevelAndGenerateCode` | `Future<void> saveLevelAndGenerateCode()` | Serializes and writes the current state or asset to disk. |
| `applyProjectSettings` | `void applyProjectSettings(LuminaProject saved)` | Adopts a manifest saved by the Project Settings editor so the toolbar scalability state, VSync and every other section share the same truth. |
| `updateQualityPreset` | `void updateQualityPreset(String preset)` | Updates the current state or data values. |
| `toggleVSync` | `void toggleVSync()` | Toggles the target feature or visibility on/off. |
| `flushQualitySettings` | `Future<void> flushQualitySettings()` | Awaits the in-flight settings write. Tests and shutdown use this; normal UI interaction does not have to. |
| `loadQualitySettings` | `Future<void> loadQualitySettings()` | Restores this project's saved editor quality, if any. |
| `toggleSsao` | `void toggleSsao()` | Toggles the target feature or visibility on/off. |
| `toggleBloom` | `void toggleBloom()` | Toggles the target feature or visibility on/off. |
| `toggleScreenSpaceReflections` | `void toggleScreenSpaceReflections()` | Toggles the target feature or visibility on/off. |
| `updateResolutionScale` | `void updateResolutionScale(double scale)` | Updates the current state or data values. |
| `saveAsset` | `Future<void> saveAsset(LuminaAsset asset)` | Serializes and writes the current state or asset to disk. |
| `saveLayoutState` | `void saveLayoutState()` | Serializes and writes the current state or asset to disk. |
| `switchLevel` | `void switchLevel(String levelRelativePath)` | Executes `switchLevel` operation. |
| `importLevelData` | `void importLevelData(String content)` | Executes `importLevelData` operation. |
| `importLevelDataFromJson` | `void importLevelDataFromJson(dynamic map)` | Executes `importLevelDataFromJson` operation. |
| `duplicateSelectedActor` | `void duplicateSelectedActor()` | Executes `duplicateSelectedActor` operation. |
| `clearDirtyFlag` | `void clearDirtyFlag()` | Clears all elements from the collection or buffer. |
| `notifyListeners` | `void notifyListeners()` | Executes `notifyListeners` operation. |
| `buildManagerViewModel` | `buildManagerViewModel` | Holds the `buildManagerViewModel` property or configuration state. |
| `revealAssetInContentBrowser` | `void revealAssetInContentBrowser(String relativeAssetPath)` | Focuses the Content Browser on [relativeAssetPath]'s folder and filters the grid to its name (Build Manager's "Reveal in Content Browser"). |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `restoreSnapshot` | `void restoreSnapshot(List<EditorActorNode> snapshot)` | Executes `restoreSnapshot` operation. |
| `restoreCameraSnapshot` | `void restoreCameraSnapshot(List<double> cam)` | Executes `restoreCameraSnapshot` operation. |
| `beginTransformDrag` | `void beginTransformDrag()` | Executes `beginTransformDrag` operation. |
| `cancelTransformDrag` | `void cancelTransformDrag()` | Executes `cancelTransformDrag` operation. |
| `endTransformDrag` | `void endTransformDrag()` | Executes `endTransformDrag` operation. |
| `removeComponentWithTransaction` | `void removeComponentWithTransaction(String actorId, String compId)` | Releases and safely disposes the specified `ComponentWithTransaction` resource. |
| `pluginRegistry` | `final PluginRegistryService pluginRegistry` | Holds the `pluginRegistry` property or configuration state. |
| `pluginPatcher` | `final PluginHostPatcherService pluginPatcher` | Holds the `pluginPatcher` property or configuration state. |
| `pluginRestartRequired` | `bool get pluginRestartRequired` | Getter accessor returning the current value of `pluginRestartRequired`. |
| `dismissPluginRestart` | `void dismissPluginRestart()` | Executes `dismissPluginRestart` operation. |

## `lib/ui/features/main_editor/services/editor_quality_settings.dart`

### `class EditorQualitySettings`

How the **editor viewport** renders — an editor scalability setting, which is a per-user preference rather than a project property.  The project's own shipped quality lives in the `.lmproject` manifest and is edited in Project Settings; this only governs what the user looks at while editing, so it is stored per user, keyed by project directory, and is never written into the project.  Every field maps onto something Filament really does: the preset expands to a [LuminaScalabilityProfile] (shadow type/size/cascades, HDR buffer quality, TAA, MSAA, FXAA), the resolution scale pins Filament's dynamic-resolution scaler, and the three feature flags switch real post-process passes.

**Constructors:**
- `EditorQualitySettings.fromMap(Map<String, dynamic> map)`: Initializes `EditorQualitySettings.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `preset` | `String preset` | One of `kQualityPresets` (`Low`, `Medium`, `High`, `Epic`, `Cinematic`). Lower-case, matching `ProjectScalabilitySettings.qualityPreset` in the manifest. The UI capitalises for display; nothing compares display text. |
| `resolutionScale` | `double resolutionScale` | Internal render resolution, as a percentage of the view. 100 means native. |
| `ssao` | `bool ssao` | Screen-space ambient occlusion. |
| `bloom` | `bool bloom` | Bloom. |
| `screenSpaceReflections` | `bool screenSpaceReflections` | Screen-space reflections. |
| `profile` | `LuminaScalabilityProfile get profile` | The engine profile this preset and resolution scale describe. |
| `applyFeatures` | `LuminaPostProcessSettings applyFeatures(LuminaPostProcessSettings base)` | [base] with this settings object's feature flags applied. Used for the post-process passes, which live on the settings rather than the profile. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class EditorQualityStore`

Per-user store for [EditorQualitySettings], one entry per project directory, in `~/.config/lumina/editor_quality.json` — the same place the launcher keeps its recent-project list and the plugin wizard its defaults.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `configDir` | `Directory configDir` | Holds the `configDir` property or configuration state. |
| `file` | `File get file` | Getter accessor returning the current value of `file`. |
| `load` | `Future<EditorQualitySettings> load(String projectDirPath)` | The settings saved for [projectDirPath], or the defaults. |
| `save` | `Future<void> save(String projectDirPath, EditorQualitySettings settings)` | Serializes and writes the current state or asset to disk. |

## `lib/ui/features/main_editor/services/gizmo_controller.dart`

### `enum GizmoMode`

`GizmoMode`: Enumeration listing system options and state constants.

### `enum GizmoSpace`

`GizmoSpace`: Enumeration listing system options and state constants.

### `class GizmoController`

`GizmoController`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `getAxisDirection` | `static Vector3 getAxisDirection(String axis, GizmoSpace space, [Quaterni...` | Queries and returns the `AxisDirection` value or child object. |
| `getPlaneNormal` | `static Vector3 getPlaneNormal(String planeId, GizmoSpace space, [Quatern...` | Queries and returns the `PlaneNormal` value or child object. |

## `lib/ui/features/main_editor/services/pie_controller.dart`

### `class EditorPieGame`

Declarative game built from the editor's level actors for Play-In-Editor.  Every editor actor is mapped to a real Lumina runtime object via [mapEditorActor]; the resulting tree is mounted into a [LuminaWorld] on the live Filament engine/scene so the simulated world contains the same meshes, lights and pawn the editor shows.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `editorActors` | `List<EditorActorNode> editorActors` | Holds the `editorActors` property or configuration state. |
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
| `tickGame` | `void tickGame(double deltaTime)` | Executes `tickGame` operation. |
| `step` | `void step(double deltaTime)` | Executes `step` operation. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |
| `mapEditorActor` | `static LuminaObject? mapEditorActor(EditorActorNode actor)` | Maps an editor actor to its runtime counterpart, or null for organisational nodes such as folders. |

### `class PieController`

`PieController`: `class` representing the data model or functionality of the module.

**Constructors:**
- `PieController(this.viewModel)`: Initializes `PieController(this.viewModel)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `lastError` | `String? lastError` | Last error raised while mounting or ticking the runtime world, or null. |
| `game` | `EditorPieGame? get game` | The mounted runtime game while playing, or null. |
| `playerPawn` | `LuminaTemplateCharacter? get playerPawn` | The possessed character while playing, or null. |
| `templateKindForProject` | `GameTemplateKind templateKindForProject()` | Which pawn this project's template scaffolds, read from the manifest. |
| `boundInputForProject` | `BoundProjectInput boundInputForProject()` | The project's input actions and key bindings, bound to the runtime.  A project created before the template work has no input section; it falls back to its template's defaults so Play still moves, and the user can then edit them in Project Settings. |
| `startPie` | `void startPie(FilamentEngine engine, FilamentScene scene)` | Executes `startPie` operation. |
| `stopPie` | `void stopPie(FilamentEngine engine, FilamentScene scene)` | Executes `stopPie` operation. |
| `pause` | `void pause()` | Pauses the runtime world (timers, subsystems and audio freeze) and the editor tick. No-op unless playing. |
| `resume` | `void resume()` | Executes `resume` operation. |
| `step` | `void step([double dt = 1 / 60])` | Advances the paused world by exactly one tick of [dt] seconds (frame stepping). No-op unless playing and paused. |
| `restart` | `void restart()` | Restarts the running session: the runtime world is rebuilt from the same editor snapshot on the same engine/scene, resuming play. |
| `acceptsGameInput` | `bool get acceptsGameInput` | Whether the running world should receive keyboard and mouse events. An ejected user drives the editor flycam instead of the pawn. |
| `injectKeyDown` | `void injectKeyDown(LuminaKey key)` | Executes `injectKeyDown` operation. |
| `injectKeyUp` | `void injectKeyUp(LuminaKey key)` | Executes `injectKeyUp` operation. |
| `injectMouseDelta` | `void injectMouseDelta(double dx, double dy)` | Executes `injectMouseDelta` operation. |
| `eject` | `void eject()` | Executes `eject` operation. |
| `possess` | `void possess()` | Executes `possess` operation. |
| `tick` | `void tick(double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |

## `lib/ui/features/main_editor/services/snap_service.dart`

### `class SnapService`

`SnapService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `snapValue` | `static double snapValue(double value, double step)` | Executes `snapValue` operation. |
| `snapVector` | `static List<double> snapVector(List<double> vector, double step)` | Executes `snapVector` operation. |
| `snapAngle` | `static double snapAngle(double angle, double step)` | Executes `snapAngle` operation. |

## `lib/ui/features/main_editor/services/viewport_picker.dart`

### `class PickHit`

`PickHit`: `class` representing the data model or functionality of the module.

**Constructors:**
- `PickHit(this.actor, this.distance)`: Initializes `PickHit(this.actor, this.distance)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actor` | `EditorActorNode actor` | Holds the `actor` property or configuration state. |
| `distance` | `double distance` | Holds the `distance` property or configuration state. |

### `class ViewportPicker`

`ViewportPicker`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `pickActors` | `List<PickHit> pickActors(List<EditorActorNode> actors, Ray ray, Matrix4?...` | Executes `pickActors` operation. |

## `lib/ui/features/main_editor/shortcuts/editor_shortcuts_scope.dart`

### `class ConditionalActivator`

`ConditionalActivator`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ConditionalActivator(this.key, this.viewModel)`: Initializes `ConditionalActivator(this.key, this.viewModel)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `key` | `LogicalKeyboardKey key` | Holds the `key` property or configuration state. |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `accepts` | `bool accepts(KeyEvent event, HardwareKeyboard state)` | Executes `accepts` operation. |
| `triggers` | `Iterable<LogicalKeyboardKey>? get triggers` | Getter accessor returning the current value of `triggers`. |
| `debugDescribeKeys` | `String debugDescribeKeys()` | Executes `debugDescribeKeys` operation. |

### `class DispatchCommandIntent`

`DispatchCommandIntent`: `class` representing the data model or functionality of the module.

**Constructors:**
- `DispatchCommandIntent(this.commandId)`: Initializes `DispatchCommandIntent(this.commandId)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `commandId` | `String commandId` | Holds the `commandId` property or configuration state. |

### `class EditorShortcutsScope`

`EditorShortcutsScope`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `child` | `Widget child` | Holds the `child` property or configuration state. |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<EditorShortcutsScope> createState() => _EditorShortcutsScopeState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _EditorShortcutsScopeState`

`_EditorShortcutsScopeState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/shortcuts/quick_open_palette.dart`

**Top-level Functions:**

- **`void showQuickOpenPalette(BuildContext context, EditorViewModel viewModel, FocusNode returnFocus)`**: Executes `showQuickOpenPalette` operation.

### `class QuickOpenPaletteWidget`

`QuickOpenPaletteWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<QuickOpenPaletteWidget> createState() => _QuickOpenPaletteWidgetSt...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _QuickOpenPaletteWidgetState`

`_QuickOpenPaletteWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/utils/fuzzy_match.dart`

**Top-level Functions:**

- **`List<QuickOpenMatch> fuzzyMatchAssets(String query, List<RealAssetInfo> assets)`**: Executes `fuzzyMatchAssets` operation.

### `class QuickOpenMatch`

`QuickOpenMatch`: `class` representing the data model or functionality of the module.

**Constructors:**
- `QuickOpenMatch(this.asset, this.matchIndices, this.score)`: Initializes `QuickOpenMatch(this.asset, this.matchIndices, this.score)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `asset` | `RealAssetInfo asset` | Holds the `asset` property or configuration state. |
| `matchIndices` | `List<int> matchIndices` | Holds the `matchIndices` property or configuration state. |
| `score` | `int score` | Holds the `score` property or configuration state. |

## `lib/ui/features/main_editor/commands/editor_command.dart`

### `class EditorCommandRegistry`

`EditorCommandRegistry`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `register` | `void register(EditorCommand command)` | Registers the plugin with the editor context (`LuminaEditorContext`) and exposes its features. |
| `registerAll` | `void registerAll(List<EditorCommand> commands)` | Executes `registerAll` operation. |
| `byId` | `EditorCommand? byId(String id)` | Executes `byId` operation. |
| `all` | `List<EditorCommand> get all` | Getter accessor returning the current value of `all`. |
| `execute` | `bool execute(String id, [BuildContext? context])` | Executes the command or action logic. |

## `lib/ui/features/main_editor/commands/editor_transaction.dart`

### `class EditorTransaction`

`EditorTransaction`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `coalesceKey` | `String? coalesceKey` | Holds the `coalesceKey` property or configuration state. |

### `class TransactionManager`

`TransactionManager`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isApplying` | `bool get isApplying` | Checks current state or capability and returns a boolean value. |
| `canUndo` | `bool get canUndo` | Getter accessor returning the current value of `canUndo`. |
| `canRedo` | `bool get canRedo` | Getter accessor returning the current value of `canRedo`. |
| `undoLabel` | `String get undoLabel` | Reverts the last executed editor operation. |
| `redoLabel` | `String get redoLabel` | Re-applies the last undone editor operation. |
| `endTransaction` | `void endTransaction()` | Executes `endTransaction` operation. |
| `record` | `void record(EditorTransaction transaction)` | Executes `record` operation. |
| `undo` | `void undo()` | Reverts the last executed editor operation. |
| `redo` | `void redo()` | Re-applies the last undone editor operation. |
| `clear` | `void clear()` | Clears all elements from the collection or buffer. |

## `lib/ui/features/main_editor/models/editor_actor_catalog.dart`

### `class EditorActorType`

One actor type the editor can place in a level.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | The string stored in `metadata.actors[].type` and switched on by the code generator, the viewport painter and the PIE mapper. |
| `label` | `String label` | What the user sees in the spawn menu. |
| `description` | `String description` | One short line saying what placing it does. |
| `category` | `String category` | Menu grouping, e.g. `Lights`. |
| `icon` | `IconData icon` | Holds the `icon` property or configuration state. |
| `color` | `Color color` | Holds the `color` property or configuration state. |
| `unique` | `bool unique` | True when a level may hold at most one (the sky/atmosphere). |
| `lightIntensity` | `double lightIntensity` | Default light intensity for light types, 0 for everything else. |

### `class EditorActorCatalog`

The single answer to "what can this editor place in a level".  The spawn dialog, the outliner's icons and the details panel all read this, so they cannot drift apart the way they did when each kept its own list (the dialog once offered five of ten supported types, so a sky, a spot light and a skeletal mesh could not be placed at all).

**Constructors:**
- `EditorActorCatalog._()`: Initializes `EditorActorCatalog._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `categories` | `static List<String> get categories` | Categories in menu order. |
| `inCategory` | `static List<EditorActorType> inCategory(String category)` | Executes `inCategory` operation. |
| `byId` | `static EditorActorType? byId(String id)` | Executes `byId` operation. |
| `iconFor` | `static IconData iconFor(String type)` | Icon for any type string, including ones no longer in the catalog (old levels can hold anything). |
| `colorFor` | `static Color colorFor(String type)` | Executes `colorFor` operation. |

---

[Previous: Main editor: views (continued)](main-editor-views-continued.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Main editor: view model and services (continued)](main-editor-state-continued.md)
