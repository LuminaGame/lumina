[Türkçe](../../tr/lumina/world.md)

# World, levels and streaming

The world that owns every actor: the world and its subsystems, levels and the level script actor, the entity registry, frame pacing, world partition cells, level streaming (manager, volumes and streaming sources), hierarchical LOD proxies and data layers. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/world/data_layer.dart`](#libsrcworlddata_layerdart)
- [`lib/src/world/entity_registry.dart`](#libsrcworldentity_registrydart)
- [`lib/src/world/frame_pacing.dart`](#libsrcworldframe_pacingdart)
- [`lib/src/world/hlod_subsystem.dart`](#libsrcworldhlod_subsystemdart)
- [`lib/src/world/level.dart`](#libsrcworldleveldart)
- [`lib/src/world/level_script_actor.dart`](#libsrcworldlevel_script_actordart)
- [`lib/src/world/level_streaming.dart`](#libsrcworldlevel_streamingdart)
- [`lib/src/world/level_streaming_manager.dart`](#libsrcworldlevel_streaming_managerdart)
- [`lib/src/world/level_streaming_volume.dart`](#libsrcworldlevel_streaming_volumedart)
- [`lib/src/world/streaming_source.dart`](#libsrcworldstreaming_sourcedart)
- [`lib/src/world/world.dart`](#libsrcworldworlddart)
- [`lib/src/world/world_partition.dart`](#libsrcworldworld_partitiondart)
- [`lib/src/world/world_partition_cell.dart`](#libsrcworldworld_partition_celldart)
- [`lib/src/world/world_type.dart`](#libsrcworldworld_typedart)
- [`lib/src/world/subsystem/physics_world_subsystem.dart`](#libsrcworldsubsystemphysics_world_subsystemdart)
- [`lib/src/world/subsystem/subsystem_collection.dart`](#libsrcworldsubsystemsubsystem_collectiondart)
- [`lib/src/world/subsystem/world_subsystem.dart`](#libsrcworldsubsystemworld_subsystemdart)
- [`lib/src/world/debug_shapes.dart`](#libsrcworlddebug_shapesdart)
- [`lib/src/world/level_preloader.dart`](#libsrcworldlevel_preloaderdart)
- [`lib/src/world/subsystem/widget_subsystem.dart`](#libsrcworldsubsystemwidget_subsystemdart)
- [`lib/src/world/subsystem/user_settings_subsystem.dart`](#libsrcworldsubsystemuser_settings_subsystemdart)

## `lib/src/world/data_layer.dart`

### `enum DataLayerState`

3-state runtime lifecycle for World Partition Data Layers.

### `class LuminaDataLayer`

Logical Data Layer used to group actors independently of spatial location.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `bIsRuntime` | `bool bIsRuntime` | Holds the `bIsRuntime` property or configuration state. |
| `state` | `DataLayerState get state` | Current runtime state of this data layer. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class LuminaDataLayerManager`

Manages logical data layer registrations, runtime state mutations, and change notifications.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `findLayer` | `LuminaDataLayer? findLayer(String name)` | Finds a data layer by name if registered. |
| `getDataLayerState` | `DataLayerState? getDataLayerState(String name)` | Gets the current state of a registered data layer. |
| `setDataLayerState` | `void setDataLayerState(String name, DataLayerState newState)` | Sets the runtime state of a data layer and notifies subscribers if changed. |
| `snapshotStates` | `Map<String, DataLayerState> snapshotStates()` | Snapshots the states of all registered data layers for game saving. |
| `restoreStates` | `void restoreStates(Map<String, DataLayerState> states)` | Restores data layer states from a saved game snapshot. |
| `dispose` | `void dispose()` | Disposes stream controller. |

## `lib/src/world/entity_registry.dart`

### `class LuminaEntityRegistry`

Central world registry mapping native Filament renderable entity IDs to owning components and actors.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `registerEntities` | `void registerEntities(Iterable<int> entities, LuminaSceneComponent owner)` | Registers [entities] as belonging to [owner]. |
| `unregisterEntities` | `void unregisterEntities(Iterable<int> entities)` | Unregisters [entities] from this registry. |
| `componentForEntity` | `LuminaSceneComponent? componentForEntity(int entity)` | Returns the component mapped to [entity], or null if not registered. |
| `actorForEntity` | `LuminaActor? actorForEntity(int entity)` | Returns the actor owning the component mapped to [entity], or null if not registered. |
| `count` | `int get count` | Number of registered entity mappings. |
| `clear` | `void clear() => _registry.clear()` | Clears all entity mappings. |

## `lib/src/world/frame_pacing.dart`

### `class LuminaFrameStats`

Immutable telemetry snapshot for a single rendered or processed frame.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `frameId` | `int frameId` | Holds the `frameId` property or configuration state. |
| `cpuFrameMs` | `double cpuFrameMs` | Holds the `cpuFrameMs` property or configuration state. |
| `gpuFrameMs` | `double? gpuFrameMs` | Holds the `gpuFrameMs` property or configuration state. |
| `frameIntervalMs` | `double frameIntervalMs` | Holds the `frameIntervalMs` property or configuration state. |
| `fps` | `double fps` | Holds the `fps` property or configuration state. |
| `missedFrames` | `int missedFrames` | Holds the `missedFrames` property or configuration state. |
| `gpuBehind` | `bool gpuBehind` | Holds the `gpuBehind` property or configuration state. |

### `class LuminaFrameDriver`

The core game loop driver managing vsync timing, FramePacer integration, frame skipping, and stat streaming.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `world` | `LuminaWorld world` | Holds the `world` property or configuration state. |
| `renderer` | `FilamentRenderer renderer` | Holds the `renderer` property or configuration state. |
| `swapChain` | `FilamentSwapChain swapChain` | Holds the `swapChain` property or configuration state. |
| `view` | `FilamentView view` | Holds the `view` property or configuration state. |
| `useFramePacer` | `bool useFramePacer` | Holds the `useFramePacer` property or configuration state. |
| `framePacer` | `FilamentFramePacer? framePacer` | Holds the `framePacer` property or configuration state. |
| `maxDeltaTime` | `double maxDeltaTime` | Holds the `maxDeltaTime` property or configuration state. |
| `frameStats` | `Stream<LuminaFrameStats> get frameStats` | Broadcast stream of per-frame performance statistics. |
| `paused` | `bool get paused` | Whether the game loop is paused (skips simulation and rendering, keeps message queues pumping).  This is the "window minimized" knob. The PIE pause is [LuminaWorld.isPaused]: while the world is paused the driver keeps pumping message queues and presenting frames (so the viewport shows the frozen state) but skips [LuminaWorld.tick], and resets its delta-time baseline so the first tick after resume is not clamped as a hitch. |
| `paused` | `paused(bool value)` | Executes `paused` operation. |
| `targetFrameRate` | `double get targetFrameRate` | Target frame rate in FPS (0.0 means follow display refresh rate). |
| `targetFrameRate` | `targetFrameRate(double fps)` | Executes `targetFrameRate` operation. |
| `setDisplayRefreshRate` | `void setDisplayRefreshRate(double hz)` | Updates the display refresh rate on [renderer], called on display config change. |
| `hitchCount` | `int get hitchCount` | Cumulative count of frame time hitches clamped to [maxDeltaTime]. |
| `onVsync` | `void onVsync(int vsyncSteadyClockNanos)` | Per-frame entry point called on vsync with the engine's steady-clock timestamp in nanoseconds. |
| `dispose` | `void dispose()` | Disposes resources, closes streams, and destroys the frame pacer. |

## `lib/src/world/hlod_subsystem.dart`

### `enum HlodProxyState`

Runtime visibility and cross-fade states for HLOD proxy meshes.

### `class LuminaHlodProxyDescriptor`

Authored or baked metadata associating a spatial grid cell with a merged proxy mesh.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cellX` | `int cellX` | Holds the `cellX` property or configuration state. |
| `cellY` | `int cellY` | Holds the `cellY` property or configuration state. |
| `proxyMeshAsset` | `String proxyMeshAsset` | Holds the `proxyMeshAsset` property or configuration state. |
| `bounds` | `Aabb3? bounds` | Holds the `bounds` property or configuration state. |

### `class LuminaHlodProxy`

Runtime instance wrapping an HLOD proxy mesh with continuous opacity for cross-fading.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `descriptor` | `LuminaHlodProxyDescriptor descriptor` | Holds the `descriptor` property or configuration state. |
| `state` | `HlodProxyState get state` | Current proxy visibility state. |
| `opacity` | `double get opacity` | Current normalized opacity [0.0, 1.0] driving the material fade parameter. |

### `class LuminaHlodSubsystem`

Manages distant proxy meshes (HLOD) and handles cross-fading between proxy and real actors.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `crossFadeDuration` | `Duration crossFadeDuration` | Holds the `crossFadeDuration` property or configuration state. |
| `proxyPoolSize` | `int proxyPoolSize` | Holds the `proxyPoolSize` property or configuration state. |
| `liveProxyCount` | `int get liveProxyCount` | Total number of proxies actively rendering (not hidden). |
| `availablePoolCount` | `int get availablePoolCount` | Available entity slots remaining in the fixed proxy pool. |
| `registerProxyDescriptor` | `void registerProxyDescriptor(LuminaHlodProxyDescriptor d)` | Registers an authored/baked HLOD proxy mesh descriptor for a grid cell. |
| `proxyForCell` | `LuminaHlodProxy? proxyForCell(int x, int y)` | Returns the runtime proxy instance for a cell, if present. |
| `onCellStateChanged` | `void onCellStateChanged(int x, int y, CellState oldState, CellState newS...` | Reacts to cell state changes from World Partition. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/world/level.dart`

### `enum LevelState`

7-state asynchronous streaming and lifecycle state for a [LuminaLevel].

### `class LuminaLevel`

Container holding actors, script actors, and scene graph state for a level.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String? name` | Holds the `name` property or configuration state. |
| `scriptActor` | `LuminaLevelScriptActor? scriptActor` | Holds the `scriptActor` property or configuration state. |
| `state` | `LevelState state` | Holds the `state` property or configuration state. |
| `owningWorld` | `LuminaWorld? owningWorld` | Holds the `owningWorld` property or configuration state. |
| `effectiveName` | `String get effectiveName` | Effective name for level identification in save games and streaming. |
| `isVisible` | `bool get isVisible` | Whether the level is currently visible and active in the world. |
| `actors` | `List<LuminaActor> get actors` | Unmodifiable view of registered actors in this level. |
| `registerActor` | `void registerActor(LuminaActor actor)` | Registers an actor into this level, establishing ownership. |
| `unregisterActor` | `void unregisterActor(LuminaActor actor)` | Unregisters an actor from this level, firing [onUnregister] and clearing ownership. |
| `notifyLevelLoaded` | `void notifyLevelLoaded()` | Notifies the script actor that the level has finished loading. |
| `unloadActors` | `void unloadActors()` | Unloads all actors in reverse registration order, unregisters scriptActor, and resets state. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/src/world/level_script_actor.dart`

### `class LuminaLevelScriptActor`

Special actor attached to a level for executing level-specific scenarios and events.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `level` | `LuminaLevel? get level` | The owning level for this script actor. |
| `hasLevelLoaded` | `bool get hasLevelLoaded` | Whether [onLevelLoaded] has already been called. |
| `hasLevelUnloaded` | `bool get hasLevelUnloaded` | Whether [onLevelUnloaded] has already been called. |
| `onLevelLoaded` | `void onLevelLoaded()` | Called exactly once when the owning level finishes loading, before any actor in the level receives `onBeginPlay`. |
| `onLevelUnloaded` | `void onLevelUnloaded()` | Called exactly once when the level begins teardown/unload, after all other actors in the level have been unregistered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/world/level_streaming.dart`

### `class LuminaLevelStreaming`

Handles asynchronous level streaming, 7-state lifecycle management, and visibility transitions per sub-level.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `levelPath` | `String levelPath` | Holds the `levelPath` property or configuration state. |
| `levelInstance` | `LuminaLevel levelInstance` | Holds the `levelInstance` property or configuration state. |
| `bShouldBeLoaded` | `bool bShouldBeLoaded` | Holds the `bShouldBeLoaded` property or configuration state. |
| `bShouldBeVisible` | `bool bShouldBeVisible` | Holds the `bShouldBeVisible` property or configuration state. |
| `bDisableDistanceStreaming` | `bool bDisableDistanceStreaming` | Holds the `bDisableDistanceStreaming` property or configuration state. |
| `state` | `LevelState get state` | The current lifecycle state of this streaming level. |
| `onStateChanged` | `Stream<LevelState> get onStateChanged` | Broadcast stream of state changes. |
| `isTransitioning` | `bool get isTransitioning` | Whether the level is currently in an asynchronous transitional state. |
| `loadLevelAsync` | `Future<LuminaLevel> loadLevelAsync()` | Asynchronously loads the level, transitioning through `unloaded -> loading -> loaded` (and `visible` if [bShouldBeVisible] is true). |
| `setVisibleAsync` | `Future<void> setVisibleAsync(bool visible)` | Asynchronously transitions visibility between `loaded <-> makingVisible <-> visible` and `visible <-> makingInvisible <-> loaded`. |
| `unloadLevelAsync` | `Future<void> unloadLevelAsync()` | Asynchronously unloads the level, hiding it first if visible, unregistering all actors, and transitioning to `unloaded`. |
| `dispose` | `void dispose()` | Closes the state broadcast stream controller and releases resources. |

## `lib/src/world/level_streaming_manager.dart`

### `class LuminaLevelPayload`

Lightweight pure-data payload describing level actor descriptors parsed off the main thread.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `levelPath` | `String levelPath` | Holds the `levelPath` property or configuration state. |
| `actorDescriptors` | `List<Map<String, dynamic>> actorDescriptors` | Holds the `actorDescriptors` property or configuration state. |

### `class LuminaTimeSlicedWorkQueue`

A time-sliced task queue that limits per-frame execution to a configured duration budget.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `pendingCount` | `int get pendingCount` | Number of pending work items. |
| `enqueue` | `void enqueue(Iterable<void Function()> steps)` | Enqueues tasks to be processed within per-frame time budgets. |
| `pump` | `void pump(Duration budget)` | Processes queued tasks until [budget] is exhausted. |

### `class _RegisteredStreamingLevel`

`_RegisteredStreamingLevel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `streaming` | `LuminaLevelStreaming streaming` | Holds the `streaming` property or configuration state. |
| `origin` | `Vector3 origin` | Holds the `origin` property or configuration state. |

### `class LuminaLevelStreamingManager`

Subsystem managing sub-level streaming, spatial volume evaluation, distance policies, double-buffered request dispatch, and time-sliced workload execution.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `streamingDistance` | `double streamingDistance` | Holds the `streamingDistance` property or configuration state. |
| `frameBudget` | `Duration frameBudget` | Holds the `frameBudget` property or configuration state. |
| `viewerPosition` | `Vector3 get viewerPosition` | The active viewer position (e.g. camera / player pawn location). |
| `setViewerPosition` | `void setViewerPosition(Vector3 position)` | Sets the primary viewer location for distance-based streaming evaluations. |
| `unregisterStreamingLevel` | `void unregisterStreamingLevel(String levelPath)` | Unregisters a sub-level streaming handle. |
| `findByName` | `LuminaLevelStreaming? findByName(String levelPath)` | Finds a registered streaming level handle by its path/name. |
| `addVolume` | `void addVolume(LuminaLevelStreamingVolume volume)` | Adds a streaming trigger volume. |
| `removeVolume` | `void removeVolume(LuminaLevelStreamingVolume volume)` | Removes a streaming trigger volume. |
| `enqueueRequest` | `void enqueueRequest(void Function() request)` | Enqueues a streaming request into the current double-buffer. |
| `processPendingRequests` | `void processPendingRequests()` | Swaps double buffers and dispatches requests collected from the previous tick. |
| `parseLevelInIsolate` | `static Future<LuminaLevelPayload> parseLevelInIsolate(String levelPath)` | Decodes level data in a background Dart isolate. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/world/level_streaming_volume.dart`

### `enum LuminaStreamingVolumeShape`

The geometric shape type of a [LuminaLevelStreamingVolume].

### `class _PawnVolumeState`

`_PawnVolumeState`: `class` representing the data model or functionality of the module.

### `class LuminaLevelStreamingVolume`

Volume trigger used to automatically request level streaming loads/unloads when player pawns enter or exit specified spatial bounds.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `volumeName` | `String volumeName` | Holds the `volumeName` property or configuration state. |
| `targetLevelNames` | `List<String> targetLevelNames` | Holds the `targetLevelNames` property or configuration state. |
| `shape` | `LuminaStreamingVolumeShape shape` | Holds the `shape` property or configuration state. |
| `minX` | `double minX` | Holds the `minX` property or configuration state. |
| `minY` | `double minY` | Holds the `minY` property or configuration state. |
| `minZ` | `double minZ` | Holds the `minZ` property or configuration state. |
| `maxX` | `double maxX` | Holds the `maxX` property or configuration state. |
| `maxY` | `double maxY` | Holds the `maxY` property or configuration state. |
| `maxZ` | `double maxZ` | Holds the `maxZ` property or configuration state. |
| `centerX` | `double centerX` | Holds the `centerX` property or configuration state. |
| `centerY` | `double centerY` | Holds the `centerY` property or configuration state. |
| `centerZ` | `double centerZ` | Holds the `centerZ` property or configuration state. |
| `sphereRadius` | `double sphereRadius` | Holds the `sphereRadius` property or configuration state. |
| `bufferMargin` | `double bufferMargin` | Holds the `bufferMargin` property or configuration state. |
| `exitDelay` | `Duration exitDelay` | Holds the `exitDelay` property or configuration state. |
| `bEditorPreVisOnly` | `bool bEditorPreVisOnly` | Holds the `bEditorPreVisOnly` property or configuration state. |
| `bDisabled` | `bool bDisabled` | Holds the `bDisabled` property or configuration state. |
| `isAnyPawnInside` | `bool get isAnyPawnInside` | Whether any tracked pawn is currently considered inside the volume. |
| `requestedLevels` | `Iterable<String> get requestedLevels` | Target levels requested by this volume when active and occupied by at least one pawn. |
| `evaluatePawnPosition` | `bool evaluatePawnPosition(Object pawnId, Vector3 pawnPosition, double de...` | Evaluates the position of a specific pawn against this volume's bounds with asymmetric hysteresis.  - If the pawn was outside: enters when strictly inside tight bounds. - If the pawn was inside: stays inside as long as within bounds + [bufferMargin]. Once past the margin, exit is committed only after [exitDelay] has accumulated. |
| `removePawn` | `void removePawn(Object pawnId)` | Removes a pawn from tracking (e.g. on despawn) without firing exit callbacks. |

## `lib/src/world/streaming_source.dart`

### `enum LuminaStreamingSourceState`

Operational state of a streaming source.

### `enum LuminaStreamingSourceTargetState`

Target residency state requested by a streaming source for its covered cells.

### `class LuminaStreamingSourceComponent`

Streaming Source Component attached to Player Pawns, Controllers, or Cinematic Cameras.  Drives spatial cell loading and activation across World Partition.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `loadingRadius` | `double loadingRadius` | Radial boundary within which this source requests cell residency. |
| `priority` | `int priority` | Priority weighting used to order cell transitions under constrained frame budgets. |
| `bShapesCellLoading` | `bool bShapesCellLoading` | Whether this source contributes to the cell loading union. |
| `targetState` | `LuminaStreamingSourceTargetState targetState` | Desired state cap for cells covered by this source (`loaded` or `activated`). |
| `bEnabled` | `bool bEnabled` | Whether this streaming source is currently active. |
| `overrideLocation` | `Vector3? overrideLocation` | Optional manual coordinate override for detached or cinematic camera sources. |
| `location` | `Vector3 get location` | Current 3D world position of this streaming source. |
| `location` | `location(Vector3 v)` | Executes `location` operation. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onInitialize` | `void onInitialize()` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/world/world.dart`

### `class _PendingSpawnItem`

`_PendingSpawnItem`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_PendingSpawnItem(this.actor, this.targetLevel)`: Initializes `_PendingSpawnItem(this.actor, this.targetLevel)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actor` | `LuminaActor actor` | Holds the `actor` property or configuration state. |
| `targetLevel` | `LuminaLevel targetLevel` | Holds the `targetLevel` property or configuration state. |

### `class LuminaWorld`

Orchestrates levels, actors, Filament scene bindings, and the 5-phase deterministic tick pipeline.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `worldType` | `LuminaWorldType worldType` | Holds the `worldType` property or configuration state. |
| `persistentLevel` | `LuminaLevel persistentLevel` | Holds the `persistentLevel` property or configuration state. |
| `levels` | `List<LuminaLevel> get levels` | All levels associated with this world (persistent and streaming sub-levels). |
| `currentLevel` | `LuminaLevel? get currentLevel` | The active primary level for this world. |
| `gameMode` | `LuminaGameMode? gameMode` | The game mode defining the rules for this world. |
| `gameState` | `LuminaGameState? get gameState` | The game state for this world, managed by the game mode. |
| `timeSeconds` | `double get timeSeconds` | Accumulated game time in seconds (does not advance while [isPaused]). |
| `tickCount` | `int get tickCount` | Number of ticks actually executed by [tick] / [step]; paused no-op ticks are not counted. |
| `isPaused` | `bool get isPaused` | Whether the world is paused. While paused, [tick] is a silent no-op — no phases run, so subsystems (timers, audio), actors and [timeSeconds] all freeze together. Only [step] advances a paused world. Subsystems are notified via [LuminaWorldSubsystem.onWorldPauseChanged] on every actual change. |
| `isPaused` | `isPaused(bool value)` | Checks current state or capability and returns a boolean value. |
| `killZ` | `double? killZ` | Optional vertical threshold (Y coordinate) below which actors are automatically destroyed. |
| `buildOwner` | `LuminaBuildOwner? buildOwner` | Optional attached build owner for flushing declarative rebuilds during pre-physics phase. |
| `hasNativeContext` | `bool get hasNativeContext` | Whether a native Filament engine and scene context are currently bound. |
| `isCleanedUp` | `bool get isCleanedUp` | Whether this world has been cleaned up and is no longer usable. |
| `filamentEngine` | `FilamentEngine get filamentEngine` | The bound native Filament engine. Throws [StateError] if unbound. |
| `filamentScene` | `FilamentScene get filamentScene` | The bound native Filament scene. Throws [StateError] if unbound. |
| `filamentEngineOrNull` | `FilamentEngine? get filamentEngineOrNull` | The bound native Filament engine, or null if unbound. |
| `nativeEngine` | `FilamentEngine? get nativeEngine` | Alias for bound native Filament engine, or null if unbound. |
| `filamentSceneOrNull` | `FilamentScene? get filamentSceneOrNull` | The bound native Filament scene, or null if unbound. |
| `meshAssetCache` | `LuminaMeshAssetCache get meshAssetCache` | Refcounted mesh asset cache for this world's native Filament context. |
| `materialCache` | `LuminaMaterialCache get materialCache` | Refcounted material cache for this world's native Filament context. |
| `hasBegunPlay` | `bool get hasBegunPlay` | Whether [beginPlay] has already been called on this world. |
| `actors` | `List<LuminaActor> get actors` | All active registered actors across persistent and visible streaming levels. |
| `debugActiveSpawnBuffer` | `List<dynamic> get debugActiveSpawnBuffer` | Getter accessor returning the current value of `debugActiveSpawnBuffer`. |
| `debugSecondarySpawnBuffer` | `List<dynamic> get debugSecondarySpawnBuffer` | Getter accessor returning the current value of `debugSecondarySpawnBuffer`. |
| `debugActiveDestroyBuffer` | `List<LuminaActor> get debugActiveDestroyBuffer` | Getter accessor returning the current value of `debugActiveDestroyBuffer`. |
| `debugSecondaryDestroyBuffer` | `List<LuminaActor> get debugSecondaryDestroyBuffer` | Getter accessor returning the current value of `debugSecondaryDestroyBuffer`. |
| `debugAllocatedBufferCount` | `int get debugAllocatedBufferCount` | Getter accessor returning the current value of `debugAllocatedBufferCount`. |
| `filamentViewOrNull` | `FilamentView? get filamentViewOrNull` | The bound native Filament view, or null if unbound. |
| `postProcess` | `LuminaPostProcessController get postProcess` | The post-process controller for this world. Throws [StateError] if no FilamentView is bound. |
| `bindView` | `void bindView(FilamentView view)` | Binds a native [FilamentView] to this world and initializes the post-process controller. |
| `activeCamera` | `LuminaCameraComponent? get activeCamera` | The active primary camera component in this world, if one exists. |
| `appliedScalability` | `LuminaScalabilityProfile? get appliedScalability` | The currently applied engine scalability profile, or null if unconfigured. |
| `stagedSunShadowOptions` | `ShadowOptions? get stagedSunShadowOptions` | The staged sun shadow options computed from scalability/shadow settings. |
| `updateDirectionalLightShadows` | `void updateDirectionalLightShadows(ShadowOptions shadowOpts)` | Pushes updated [shadowOpts] to all shadow-casting directional sun lights in this world. |
| `applyScalability` | `void applyScalability(LuminaScalabilityProfile profile)` | Applies a full engine scalability profile across post-processing and lighting. |
| `destroyActor` | `void destroyActor(LuminaActor actor)` | Schedules an actor for destruction, deferred to Phase 5. |
| `beginPlay` | `void beginPlay()` | Initializes gameplay state and triggers [beginPlay] across subsystems and actors. |
| `tick` | `void tick(double deltaTime)` | Executes the 5-phase Deterministic Tick Pipeline for each frame update.  Returns immediately (no phases, no [onPreTick], no [tickCount] increment) while [isPaused]. |
| `step` | `void step(double deltaTime)` | Executes exactly one full 5-phase tick regardless of [isPaused] (the pause flag is untouched). |
| `cleanup` | `void cleanup()` | Releases resources and cleans up native scene bindings.  The world detaches its references but does NOT destroy the native Filament engine/scene. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/src/world/world_partition.dart`

### `class LuminaWorldPartitionSubsystem`

Spatially partitioned world subsystem managing 2D grid cells, data layers, and seamless streaming.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cellSize` | `double cellSize` | Holds the `cellSize` property or configuration state. |
| `maxCellTransitionsPerTick` | `int maxCellTransitionsPerTick` | Holds the `maxCellTransitionsPerTick` property or configuration state. |
| `dataLayers` | `Map<String, LuminaDataLayer> get dataLayers` | Backward-compatible alias for dataLayers. |
| `streamingSources` | `List<LuminaStreamingSourceComponent> get streamingSources` | All registered streaming sources. |
| `cellCount` | `int get cellCount` | Total number of instantiated cells in the sparse spatial map. |
| `registerSource` | `void registerSource(LuminaStreamingSourceComponent source)` | Registers a streaming source with this World Partition subsystem. |
| `unregisterSource` | `void unregisterSource(LuminaStreamingSourceComponent source)` | Unregisters a streaming source from this World Partition subsystem. |
| `assignActorToLayer` | `void assignActorToLayer(LuminaActor actor, String layerName)` | Assigns an actor to a logical data layer. |
| `removeActorFromLayer` | `void removeActorFromLayer(LuminaActor actor, String layerName)` | Removes an actor from a logical data layer. |
| `getActorLayers` | `Set<String> getActorLayers(LuminaActor actor)` | Returns the set of data layer names assigned to this actor. |
| `cellKey` | `static int cellKey(int x, int y)` | Fast 64-bit integer spatial hash combining two 32-bit integers. |
| `cellAt` | `LuminaWorldPartitionCell cellAt(Vector3 worldPos)` | Retrieves or creates the grid cell at the given 3D world position. The grid is a partition of the **ground plane**: axis 1 is world X and axis 2 is world Z, because Y is the up axis everywhere in lumina. Using Y here would make cells vertical slabs. |
| `cellByCoords` | `LuminaWorldPartitionCell? cellByCoords(int x, int y)` | Retrieves a cell by discrete grid coordinates if already instantiated. |
| `addActor` | `void addActor(LuminaActor actor, Vector3 location)` | Adds an actor to the appropriate spatial grid cell based on world position. |
| `moveActor` | `void moveActor(LuminaActor actor, Vector3 newLocation)` | Updates actor cell assignment when moving across cell boundaries. |
| `removeActor` | `void removeActor(LuminaActor actor)` | Removes an actor from its assigned cell in O(1) time. |
| `queryCellsInRadius` | `Iterable<LuminaWorldPartitionCell> queryCellsInRadius(Vector3 center, do...` | Queries all cells whose centers fall within the given radius from center. Bounded window scan only (never a full-map scan). |
| `computeActorEffectiveState` | `DataLayerState computeActorEffectiveState(CellState cellState, LuminaAct...` | Pure helper computing the effective DataLayerState for an actor in a cell.  Evaluates `min(cellDesiredState, max(actorLayers))` with `unloaded < loaded < activated`. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `onWorldShutdown` | `void onWorldShutdown()` | Callback invoked when the corresponding event is triggered. |

### `class _CellIntent`

`_CellIntent`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `maxPriority` | `int maxPriority` | Holds the `maxPriority` property or configuration state. |
| `minDistance` | `double minDistance` | Holds the `minDistance` property or configuration state. |
| `targetState` | `LuminaStreamingSourceTargetState targetState` | Holds the `targetState` property or configuration state. |

## `lib/src/world/world_partition_cell.dart`

### `enum CellState`

6-state lifecycle for World Partition cells.

### `class LuminaWorldPartitionCell`

A spatial grid cell within World Partition holding regional actors.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cellX` | `int cellX` | Holds the `cellX` property or configuration state. |
| `cellY` | `int cellY` | Holds the `cellY` property or configuration state. |
| `cellSize` | `double cellSize` | Holds the `cellSize` property or configuration state. |
| `state` | `CellState get state` | Getter accessor returning the current value of `state`. |
| `isTicking` | `bool get isTicking` | Whether actors in this cell should be actively ticked. |
| `center` | `Vector2 get center` | 2D ground plane centre of this cell: `(world X, world Z)`. |
| `bounds` | `Aabb3 get bounds` | 3D Axis-Aligned Bounding Box enclosing this cell: bounded on the X/Z ground plane and effectively unbounded in height, because Y is up. |
| `loadAsync` | `Future<void> loadAsync()` | Transitions cell from unloaded -> loading -> loaded. |
| `activate` | `void activate()` | Transitions cell from (loaded | deactivated) -> activated. |
| `deactivate` | `void deactivate()` | Transitions cell from activated -> deactivated. |
| `unloadAsync` | `Future<void> unloadAsync()` | Transitions cell from (loaded | deactivated) -> unloading -> unloaded. |
| `transitionTo` | `void transitionTo(CellState newState)` | Direct guarded state transition. |

## `lib/src/world/world_type.dart`

### `enum LuminaWorldType`

Operating mode of a [LuminaWorld].

### `extension LuminaWorldTypeX`

Behavioral capabilities and semantics for [LuminaWorldType].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `runsGameplay` | `bool get runsGameplay` | Whether gameplay lifecycle (e.g. `onBeginPlay`, `onTick` for actors) executes. |
| `ticksSubsystems` | `bool get ticksSubsystems` | Whether world subsystems receive tick notifications during frame updates. |
| `runsRenderPrep` | `bool get runsRenderPrep` | Whether the post-physics render prep phase is active for scene updates. |
| `isEditorWorld` | `bool get isEditorWorld` | Whether the world is running inside an editor environment (editor or PIE). |

## `lib/src/world/subsystem/physics_world_subsystem.dart`

### `class LuminaPhysicsWorldSubsystem`

Reference physics world subsystem providing simulation stepping and collision integration.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `onWorldShutdown` | `void onWorldShutdown()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/world/subsystem/subsystem_collection.dart`

### `class LuminaSubsystemCollection`

Collection manager for [LuminaWorldSubsystem] instances. Provides O(1) dual-indexed generic lookup and deterministic registration-order execution.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `length` | `int get length` | Number of registered subsystems. |
| `notifyBeginPlay` | `void notifyBeginPlay()` | Notifies all registered subsystems of [beginPlay] in registration order. |
| `notifyTick` | `void notifyTick(double deltaTime)` | Notifies all registered subsystems of frame tick in registration order. |
| `notifyPauseChanged` | `void notifyPauseChanged(bool paused)` | Notifies all registered subsystems of a world pause/resume in registration order. |
| `shutdown` | `void shutdown()` | Shuts down all registered subsystems in reverse registration order and clears the collection. |

## `lib/src/world/subsystem/world_subsystem.dart`

### `class LuminaWorldSubsystem`

Base class for global, lifetime-bound services attached to a [LuminaWorld].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `world` | `LuminaWorld? get world` | The world instance this subsystem is bound to. |
| `isInitialized` | `bool get isInitialized` | Whether this subsystem has been initialized. |
| `onWorldInitialize` | `void onWorldInitialize(LuminaWorld world)` | Called when the subsystem is registered with the world. |
| `onWorldBeginPlay` | `void onWorldBeginPlay()` | Called when gameplay begins in the world. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Called on each frame during Phase 2 of the world tick pipeline. |
| `onWorldPauseChanged` | `void onWorldPauseChanged(bool paused)` | Called when [LuminaWorld.isPaused] changes (`true` = paused, `false` = resumed). |
| `onWorldShutdown` | `void onWorldShutdown()` | Called when the world is shutting down or cleaned up. |

## `lib/src/world/debug_shapes.dart`

### `enum LuminaDebugShapeKind`

What kind of debug shape a Blueprint drew.

**Values:**

- `line`
- `sphere`
- `box`
- `point`
- `arrow`
- `string`
- `capsule`

### `class LuminaDebugShape`

One debug shape recorded in `LuminaWorld.debugShapes` for the editor's Play-In-Editor viewport to draw. Points are **runtime** coordinates (Y up, cm); [color] is linear RGBA 0–1; [expiresAt] is the world's real time the shape disappears at.

**Constructors:**

- `const LuminaDebugShape({required this.kind, required this.points, required this.color, required this.expiresAt, this.thickness = 1.0, this.duration = 0.0, this....`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `final LuminaDebugShapeKind kind` |  |
| `points` | `final List<Vector3> points` | Line / arrow: start and end. Sphere / point / string / capsule: the centre. Box: the centre. |
| `color` | `final List<double> color` |  |
| `thickness` | `final double thickness` |  |
| `duration` | `final double duration` |  |
| `expiresAt` | `final double expiresAt` |  |
| `radius` | `final double radius` | Sphere / point / capsule radius; arrow head size. |
| `extent` | `final Vector3? extent` | Box half extents; capsule: `(0, halfHeight, 0)`. |
| `rotation` | `final Quaternion? rotation` | Box / capsule orientation. |
| `text` | `final String? text` | The text of a string shape. |
| `nodeId` | `final String? nodeId` | The Blueprint node that drew it (for the editor's debug-draw hover). |

### `class LuminaScreenMessage`

One line of `Print String` with Print to Screen, keyed so a node with the same key replaces its previous line.

**Constructors:**

- `const LuminaScreenMessage(this.key, this.text, this.color, this.expiresAt)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `key` | `final String key` |  |
| `text` | `final String text` |  |
| `color` | `final List<double> color` |  |
| `expiresAt` | `final double expiresAt` |  |

## `lib/src/world/level_preloader.dart`

### `abstract final class LuminaProjectLevels`

The levels of the open project, by name (`L_Arena`): what the Blueprint validator checks a Load Level / Change Level node's Level Name against. Empty — nothing registered — checks nothing. Play-In-Editor and the editor register them from the project's asset index.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `names` | `static Set<String> get names` |  |
| `register` | `static void register(Iterable<String> levelNames)` |  |
| `clear` | `static void clear()` |  |
| `nameOf` | `static String nameOf(String level)` | `L_Arena` for `L_Arena`, `L_Arena.lmas` or `contents/levels/L_Arena.lmas`. |
| `isKnown` | `static bool isKnown(String level)` | Whether [level] is a registered project level (always, when none is). |

### `enum LuminaAssetKind`

What kind of content a level asset is: it decides how the [LuminaLevelPreloader] makes it resident.

**Values:**

- `mesh`
- `texture`
- `material`
- `animation`
- `sound`
- `blueprint`
- `landscape`
- `environment`
- `other`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fromName` | `static LuminaAssetKind fromName(String? name)` | The kind named [name] (`mesh`, `texture`…), [other] when unknown. |

### `class LuminaAssetRef`

One asset a level loads: the path its components read (a bundle path such as `contents/meshes/SM_Rock.lmas` in a built game, an absolute path in the editor) and its [kind]. The level code generator emits a level's list as `static const List<LuminaAssetRef> assetManifest`.

**Constructors:**

- `const LuminaAssetRef(this.path, [this.kind = LuminaAssetKind.other])`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `kind` | `final LuminaAssetKind kind` |  |
| `name` | `String get name` | `SM_Rock`: the file name without its extension, what progress reports as the content being loaded. |
| `toJson` | `Map<String, Object?> toJson()` |  |
| `fromJson` | `static LuminaAssetRef fromJson(Map<String, Object?> json)` |  |

### `class LuminaLevelLoadProgress`

One update of a level preload: after each asset ([loaded] of [total], [current] is the asset that just finished), then either the final [done] update (Success) or one carrying [error] and [stackTrace].

**Constructors:**

- `const LuminaLevelLoadProgress({required this.levelName, required this.total, required this.loaded, this.current = '', this.error, this.stackTrace, this.done = f...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `levelName` | `final String levelName` |  |
| `total` | `final int total` |  |
| `loaded` | `final int loaded` |  |
| `current` | `final String current` | The asset this update is about ([LuminaAssetRef.name]); empty on the final update. |
| `error` | `final Object? error` |  |
| `stackTrace` | `final StackTrace? stackTrace` |  |
| `done` | `final bool done` | Every asset is resident: the level can be switched to at once. |
| `percent` | `double get percent` | Loaded of total, 0–100 (a level with nothing to load is 100). |
| `hasError` | `bool get hasError` |  |

### `typedef LuminaLevelManifestResolver`

The asset list of the level [levelName], or null when there is no such level. A built game answers from the generated levels' `assetManifest`s, the editor from the level `.lmas` through the asset index.

### `typedef LuminaAssetPreloadStep`

Makes one asset resident: reads it through [provider] (a recording provider: whatever it returns stays pinned) and returns anything else to keep alive until the level is switched to or released (a GPU handle, a compiled class). Throws when the asset cannot be loaded.

### `class LuminaLevelPreloader`

Preloads persistent levels in the background — the loading-screen flow (async loading with progress, then Open Level).

[preload] resolves the level's asset list ([manifestResolver]) and loads every asset through the engine's loaders — bytes through [LuminaAssets.resolve] ([assetProvider], else the game's `LuminaAssets.defaultProvider`, else the disk), meshes into the engine's [LuminaMeshAssetCache] when an [engine] is set, anything a [kindLoaders] step adds — at most [maxConcurrent] at a time, yielding between items, and reports one [LuminaLevelLoadProgress] per asset, then Success (or the first error). What it loaded stays pinned — its bytes are served to the level's components through [LuminaAssets.resolve], its mesh handles keep the GPU assets — until [changeLevel] hands them to the new level or [release] / [cancel] drops them.

**Constructors:**

- `LuminaLevelPreloader({this.manifestResolver, this.assetProvider, this.engine, this.maxConcurrent = 4})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `instance` | `static LuminaLevelPreloader instance` | The game's preloader: what the Load Level / Change Level nodes and the game hosts use. The generated `main()` sets its [manifestResolver], Play-In-Editor its resolver and engine. |
| `manifestResolver` | `LuminaLevelManifestResolver? manifestResolver` |  |
| `assetProvider` | `LuminaAssetProvider? assetProvider` |  |
| `engine` | `FilamentEngine? engine` | The engine whose mesh cache preloaded meshes are uploaded to (the engine the next level renders with). Null: meshes are only read. |
| `maxConcurrent` | `int maxConcurrent` |  |
| `betweenItems` | `Future<void> Function()? betweenItems` | What the preloader awaits after each asset before the next (default: one turn of the event loop). A host can wait for its next frame here to spread a load over frames. |
| `kindLoaders` | `final Map<LuminaAssetKind, LuminaAssetPreloadStep> kindLoaders` | Extra steps by kind (Play-In-Editor compiles Blueprint classes). |
| `isLoaded` | `bool isLoaded(String levelName)` | Whether [levelName] is fully preloaded (Success reached, not released). |
| `isLoading` | `bool isLoading(String levelName)` | Whether [levelName] is being preloaded. |
| `levels` | `Iterable<String> get levels` | The levels preloaded or loading. |
| `pinnedPaths` | `Set<String> pinnedPaths(String levelName)` | The paths [levelName]'s preload pinned (bytes read), for diagnostics. |
| `preload` | `Stream<LuminaLevelLoadProgress> preload(String levelName)` | Starts (or joins) preloading [levelName]. The stream replays the updates so far to a late listener, then continues: one per asset, then the final `done` update, or an update with an error; it closes after either, or silently when the load is cancelled. |
| `ensureLoaded` | `Future<void> ensureLoaded(String levelName)` | Preloads [levelName] to the end; throws its error (or a cancellation). |
| `cancel` | `void cancel([String? levelName])` | Stops preloading [levelName] (every level when null) and drops what it pinned. A cancelled stream sends nothing more. |
| `release` | `void release(String levelName)` | Drops [levelName]'s preload (bytes, GPU handles): an abandoned load, or a level switched to already. |
| `reset` | `void reset()` | Cancels everything, releases every preload and forgets the resolver, provider and engine (a Play session ending). |
| `changeLevel` | `Future<void> changeLevel(String levelName, Future<void> Function() swap) async` | Switches to [levelName] with [swap] — the host's own level change, which completes once the new level has begun play — after preloading it when it is not preloaded yet; then hands the pinned assets over (the new level's components have taken their own references) and releases the preload. Throws what the preload or [swap] throws. |

## `lib/src/world/subsystem/widget_subsystem.dart`

### `class LuminaWidgetSubsystem`

Manages active UMG widgets added to the viewport in a [LuminaWorld].

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `activeWidgets` | `final ObservableValue<List<Map<String, Object?>>> activeWidgets` | The active widgets list (`lumina_core`'s `ObservableValue`), replaced whenever widgets are added, removed, reordered, or their visibility changes; the widget layer of `lumina_widgets` listens to it. |
| `widgets` | `List<Map<String, Object?>> get widgets` | Read-only snapshot of current active widgets sorted by zOrder ascending. |
| `addWidget` | `void addWidget(Map<String, Object?> widget)` | Adds a widget to the viewport. |
| `removeWidget` | `void removeWidget(Map<String, Object?> widget)` | Removes a widget from the viewport. |
| `notifyChanged` | `void notifyChanged()` | Notifies listeners that widget properties (e.g. visibility, zOrder, text) changed. |

## `lib/src/world/subsystem/user_settings_subsystem.dart`

### `class LuminaUserSettingsSubsystem`

World subsystem managing game scalability, camera view distance, and user display settings.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `overallScalabilityLevel` | `String get overallScalabilityLevel` | Current overall preset (`low`, `medium`, `high`, `epic`, `cinematic`, or `custom`). |
| `viewDistanceQuality` | `String get viewDistanceQuality` | Current view distance tier (`low`, `medium`, `high`, `epic`, `cinematic`). |
| `viewDistance` | `double get viewDistance` | Current camera far clip plane distance in centimeters. |
| `shadowQuality` | `String get shadowQuality` | Current shadow quality tier. |
| `antiAliasingQuality` | `String get antiAliasingQuality` | Current anti-aliasing mode (`none`, `fxaa`, `msaa`, `taa`). |
| `postProcessingQuality` | `String get postProcessingQuality` | Current post-processing tier. |
| `textureQuality` | `String get textureQuality` | Current texture quality tier. |
| `shadingQuality` | `String get shadingQuality` | Current shading quality tier. |
| `resolutionScale` | `double get resolutionScale` | Current render resolution scaling percentage. |
| `targetFps` | `int get targetFps` | Target FPS cap (0 for unlimited). |
| `vsyncEnabled` | `bool get vsyncEnabled` | Whether vertical synchronization is enabled. |
| `setOverallScalabilityLevel` | `void setOverallScalabilityLevel(String preset)` | Sets all scalability tiers to match the specified preset. |
| `setViewDistanceQuality` | `void setViewDistanceQuality(String tier)` | Sets view distance quality tier and updates far clip distance. |
| `setViewDistance` | `void setViewDistance(double cm)` | Sets explicit camera far clip plane in centimeters. |
| `applySettings` | `void applySettings()` | Applies the configured settings to the world, dynamic resolution, post-process controller, directional light shadows, and camera far clip planes. |

---

[Previous: Declarative tree](declarative.md) | [Up: lumina (engine core)](index.md) | [Next: Actors, pawns and characters](object.md)
