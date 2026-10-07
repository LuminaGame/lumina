[English](../../en/lumina/world.md)

# Dünya, level'lar ve streaming

Tüm actor'lerin sahibi olan dünya: world ve subsystem'leri, level'lar ve level script actor, entity registry, frame pacing, world partition hücreleri, level streaming (manager, volume'lar ve streaming source'lar), hiyerarşik LOD proxy'leri ve data layer'lar. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `bIsRuntime` | `bool bIsRuntime` | `bIsRuntime` alanını (field/property) ve ilişkili veriyi saklar. |
| `state` | `DataLayerState get state` | Current runtime state of this data layer. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class LuminaDataLayerManager`

Manages logical data layer registrations, runtime state mutations, and change notifications.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `frameId` | `int frameId` | `frameId` alanını (field/property) ve ilişkili veriyi saklar. |
| `cpuFrameMs` | `double cpuFrameMs` | `cpuFrameMs` alanını (field/property) ve ilişkili veriyi saklar. |
| `gpuFrameMs` | `double? gpuFrameMs` | `gpuFrameMs` alanını (field/property) ve ilişkili veriyi saklar. |
| `frameIntervalMs` | `double frameIntervalMs` | `frameIntervalMs` alanını (field/property) ve ilişkili veriyi saklar. |
| `fps` | `double fps` | `fps` alanını (field/property) ve ilişkili veriyi saklar. |
| `missedFrames` | `int missedFrames` | `missedFrames` alanını (field/property) ve ilişkili veriyi saklar. |
| `gpuBehind` | `bool gpuBehind` | `gpuBehind` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaFrameDriver`

The core game loop driver managing vsync timing, FramePacer integration, frame skipping, and stat streaming.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `world` | `LuminaWorld world` | `world` alanını (field/property) ve ilişkili veriyi saklar. |
| `renderer` | `FilamentRenderer renderer` | `renderer` alanını (field/property) ve ilişkili veriyi saklar. |
| `swapChain` | `FilamentSwapChain swapChain` | `swapChain` alanını (field/property) ve ilişkili veriyi saklar. |
| `view` | `FilamentView view` | `view` alanını (field/property) ve ilişkili veriyi saklar. |
| `useFramePacer` | `bool useFramePacer` | `useFramePacer` alanını (field/property) ve ilişkili veriyi saklar. |
| `framePacer` | `FilamentFramePacer? framePacer` | `framePacer` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxDeltaTime` | `double maxDeltaTime` | `maxDeltaTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `frameStats` | `Stream<LuminaFrameStats> get frameStats` | Broadcast stream of per-frame performance statistics. |
| `paused` | `bool get paused` | Whether the game loop is paused (skips simulation and rendering, keeps message queues pumping).  This is the "window minimized" knob. The PIE pause is [LuminaWorld.isPaused]: while the world is paused the driver keeps pumping message queues and presenting frames (so the viewport shows the frozen state) but skips [LuminaWorld.tick], and resets its delta-time baseline so the first tick after resume is not clamped as a hitch. |
| `paused` | `paused(bool value)` | `paused` işlemini gerçekleştirir. |
| `targetFrameRate` | `double get targetFrameRate` | Target frame rate in FPS (0.0 means follow display refresh rate). |
| `targetFrameRate` | `targetFrameRate(double fps)` | `targetFrameRate` işlemini gerçekleştirir. |
| `setDisplayRefreshRate` | `void setDisplayRefreshRate(double hz)` | Updates the display refresh rate on [renderer], called on display config change. |
| `hitchCount` | `int get hitchCount` | Cumulative count of frame time hitches clamped to [maxDeltaTime]. |
| `onVsync` | `void onVsync(int vsyncSteadyClockNanos)` | Per-frame entry point called on vsync with the engine's steady-clock timestamp in nanoseconds. |
| `dispose` | `void dispose()` | Disposes resources, closes streams, and destroys the frame pacer. |

## `lib/src/world/hlod_subsystem.dart`

### `enum HlodProxyState`

Runtime visibility and cross-fade states for HLOD proxy meshes.

### `class LuminaHlodProxyDescriptor`

Authored or baked metadata associating a spatial grid cell with a merged proxy mesh.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cellX` | `int cellX` | `cellX` alanını (field/property) ve ilişkili veriyi saklar. |
| `cellY` | `int cellY` | `cellY` alanını (field/property) ve ilişkili veriyi saklar. |
| `proxyMeshAsset` | `String proxyMeshAsset` | `proxyMeshAsset` alanını (field/property) ve ilişkili veriyi saklar. |
| `bounds` | `Aabb3? bounds` | `bounds` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaHlodProxy`

Runtime instance wrapping an HLOD proxy mesh with continuous opacity for cross-fading.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `descriptor` | `LuminaHlodProxyDescriptor descriptor` | `descriptor` alanını (field/property) ve ilişkili veriyi saklar. |
| `state` | `HlodProxyState get state` | Current proxy visibility state. |
| `opacity` | `double get opacity` | Current normalized opacity [0.0, 1.0] driving the material fade parameter. |

### `class LuminaHlodSubsystem`

Manages distant proxy meshes (HLOD) and handles cross-fading between proxy and real actors.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `crossFadeDuration` | `Duration crossFadeDuration` | `crossFadeDuration` alanını (field/property) ve ilişkili veriyi saklar. |
| `proxyPoolSize` | `int proxyPoolSize` | `proxyPoolSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `liveProxyCount` | `int get liveProxyCount` | Total number of proxies actively rendering (not hidden). |
| `availablePoolCount` | `int get availablePoolCount` | Available entity slots remaining in the fixed proxy pool. |
| `registerProxyDescriptor` | `void registerProxyDescriptor(LuminaHlodProxyDescriptor d)` | Registers an authored/baked HLOD proxy mesh descriptor for a grid cell. |
| `proxyForCell` | `LuminaHlodProxy? proxyForCell(int x, int y)` | Returns the runtime proxy instance for a cell, if present. |
| `onCellStateChanged` | `void onCellStateChanged(int x, int y, CellState oldState, CellState newS...` | Reacts to cell state changes from World Partition. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/world/level.dart`

### `enum LevelState`

7-state asynchronous streaming and lifecycle state for a [LuminaLevel].

### `class LuminaLevel`

Container holding actors, script actors, and scene graph state for a level.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String? name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `scriptActor` | `LuminaLevelScriptActor? scriptActor` | `scriptActor` alanını (field/property) ve ilişkili veriyi saklar. |
| `state` | `LevelState state` | `state` alanını (field/property) ve ilişkili veriyi saklar. |
| `owningWorld` | `LuminaWorld? owningWorld` | `owningWorld` alanını (field/property) ve ilişkili veriyi saklar. |
| `effectiveName` | `String get effectiveName` | Effective name for level identification in save games and streaming. |
| `isVisible` | `bool get isVisible` | Whether the level is currently visible and active in the world. |
| `actors` | `List<LuminaActor> get actors` | Unmodifiable view of registered actors in this level. |
| `registerActor` | `void registerActor(LuminaActor actor)` | Registers an actor into this level, establishing ownership. |
| `unregisterActor` | `void unregisterActor(LuminaActor actor)` | Unregisters an actor from this level, firing [onUnregister] and clearing ownership. |
| `notifyLevelLoaded` | `void notifyLevelLoaded()` | Notifies the script actor that the level has finished loading. |
| `unloadActors` | `void unloadActors()` | Unloads all actors in reverse registration order, unregisters scriptActor, and resets state. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/src/world/level_script_actor.dart`

### `class LuminaLevelScriptActor`

Special actor attached to a level for executing level-specific scenarios and events.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `level` | `LuminaLevel? get level` | The owning level for this script actor. |
| `hasLevelLoaded` | `bool get hasLevelLoaded` | Whether [onLevelLoaded] has already been called. |
| `hasLevelUnloaded` | `bool get hasLevelUnloaded` | Whether [onLevelUnloaded] has already been called. |
| `onLevelLoaded` | `void onLevelLoaded()` | Called exactly once when the owning level finishes loading, before any actor in the level receives `onBeginPlay`. |
| `onLevelUnloaded` | `void onLevelUnloaded()` | Called exactly once when the level begins teardown/unload, after all other actors in the level have been unregistered. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/world/level_streaming.dart`

### `class LuminaLevelStreaming`

Handles asynchronous level streaming, 7-state lifecycle management, and visibility transitions per sub-level.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `levelPath` | `String levelPath` | `levelPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `levelInstance` | `LuminaLevel levelInstance` | `levelInstance` alanını (field/property) ve ilişkili veriyi saklar. |
| `bShouldBeLoaded` | `bool bShouldBeLoaded` | `bShouldBeLoaded` alanını (field/property) ve ilişkili veriyi saklar. |
| `bShouldBeVisible` | `bool bShouldBeVisible` | `bShouldBeVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `bDisableDistanceStreaming` | `bool bDisableDistanceStreaming` | `bDisableDistanceStreaming` alanını (field/property) ve ilişkili veriyi saklar. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `levelPath` | `String levelPath` | `levelPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `actorDescriptors` | `List<Map<String, dynamic>> actorDescriptors` | `actorDescriptors` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaTimeSlicedWorkQueue`

A time-sliced task queue that limits per-frame execution to a configured duration budget.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `pendingCount` | `int get pendingCount` | Number of pending work items. |
| `enqueue` | `void enqueue(Iterable<void Function()> steps)` | Enqueues tasks to be processed within per-frame time budgets. |
| `pump` | `void pump(Duration budget)` | Processes queued tasks until [budget] is exhausted. |

### `class _RegisteredStreamingLevel`

`_RegisteredStreamingLevel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `streaming` | `LuminaLevelStreaming streaming` | `streaming` alanını (field/property) ve ilişkili veriyi saklar. |
| `origin` | `Vector3 origin` | `origin` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaLevelStreamingManager`

Subsystem managing sub-level streaming, spatial volume evaluation, distance policies, double-buffered request dispatch, and time-sliced workload execution.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `streamingDistance` | `double streamingDistance` | `streamingDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `frameBudget` | `Duration frameBudget` | `frameBudget` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewerPosition` | `Vector3 get viewerPosition` | The active viewer position (e.g. camera / player pawn location). |
| `setViewerPosition` | `void setViewerPosition(Vector3 position)` | Sets the primary viewer location for distance-based streaming evaluations. |
| `unregisterStreamingLevel` | `void unregisterStreamingLevel(String levelPath)` | Unregisters a sub-level streaming handle. |
| `findByName` | `LuminaLevelStreaming? findByName(String levelPath)` | Finds a registered streaming level handle by its path/name. |
| `addVolume` | `void addVolume(LuminaLevelStreamingVolume volume)` | Adds a streaming trigger volume. |
| `removeVolume` | `void removeVolume(LuminaLevelStreamingVolume volume)` | Removes a streaming trigger volume. |
| `enqueueRequest` | `void enqueueRequest(void Function() request)` | Enqueues a streaming request into the current double-buffer. |
| `processPendingRequests` | `void processPendingRequests()` | Swaps double buffers and dispatches requests collected from the previous tick. |
| `parseLevelInIsolate` | `static Future<LuminaLevelPayload> parseLevelInIsolate(String levelPath)` | Decodes level data in a background Dart isolate. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/world/level_streaming_volume.dart`

### `enum LuminaStreamingVolumeShape`

The geometric shape type of a [LuminaLevelStreamingVolume].

### `class _PawnVolumeState`

`_PawnVolumeState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

### `class LuminaLevelStreamingVolume`

Volume trigger used to automatically request level streaming loads/unloads when player pawns enter or exit specified spatial bounds.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `volumeName` | `String volumeName` | `volumeName` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetLevelNames` | `List<String> targetLevelNames` | `targetLevelNames` alanını (field/property) ve ilişkili veriyi saklar. |
| `shape` | `LuminaStreamingVolumeShape shape` | `shape` alanını (field/property) ve ilişkili veriyi saklar. |
| `minX` | `double minX` | `minX` alanını (field/property) ve ilişkili veriyi saklar. |
| `minY` | `double minY` | `minY` alanını (field/property) ve ilişkili veriyi saklar. |
| `minZ` | `double minZ` | `minZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxX` | `double maxX` | `maxX` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxY` | `double maxY` | `maxY` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxZ` | `double maxZ` | `maxZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `centerX` | `double centerX` | `centerX` alanını (field/property) ve ilişkili veriyi saklar. |
| `centerY` | `double centerY` | `centerY` alanını (field/property) ve ilişkili veriyi saklar. |
| `centerZ` | `double centerZ` | `centerZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `sphereRadius` | `double sphereRadius` | `sphereRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `bufferMargin` | `double bufferMargin` | `bufferMargin` alanını (field/property) ve ilişkili veriyi saklar. |
| `exitDelay` | `Duration exitDelay` | `exitDelay` alanını (field/property) ve ilişkili veriyi saklar. |
| `bEditorPreVisOnly` | `bool bEditorPreVisOnly` | `bEditorPreVisOnly` alanını (field/property) ve ilişkili veriyi saklar. |
| `bDisabled` | `bool bDisabled` | `bDisabled` alanını (field/property) ve ilişkili veriyi saklar. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `loadingRadius` | `double loadingRadius` | Radial boundary within which this source requests cell residency. |
| `priority` | `int priority` | Priority weighting used to order cell transitions under constrained frame budgets. |
| `bShapesCellLoading` | `bool bShapesCellLoading` | Whether this source contributes to the cell loading union. |
| `targetState` | `LuminaStreamingSourceTargetState targetState` | Desired state cap for cells covered by this source (`loaded` or `activated`). |
| `bEnabled` | `bool bEnabled` | Whether this streaming source is currently active. |
| `overrideLocation` | `Vector3? overrideLocation` | Optional manual coordinate override for detached or cinematic camera sources. |
| `location` | `Vector3 get location` | Current 3D world position of this streaming source. |
| `location` | `location(Vector3 v)` | `location` işlemini gerçekleştirir. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onInitialize` | `void onInitialize()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/world/world.dart`

### `class _PendingSpawnItem`

`_PendingSpawnItem`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_PendingSpawnItem(this.actor, this.targetLevel)`: `_PendingSpawnItem(this.actor, this.targetLevel)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actor` | `LuminaActor actor` | `actor` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetLevel` | `LuminaLevel targetLevel` | `targetLevel` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaWorld`

Orchestrates levels, actors, Filament scene bindings, and the 5-phase deterministic tick pipeline.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `worldType` | `LuminaWorldType worldType` | `worldType` alanını (field/property) ve ilişkili veriyi saklar. |
| `persistentLevel` | `LuminaLevel persistentLevel` | `persistentLevel` alanını (field/property) ve ilişkili veriyi saklar. |
| `levels` | `List<LuminaLevel> get levels` | All levels associated with this world (persistent and streaming sub-levels). |
| `currentLevel` | `LuminaLevel? get currentLevel` | The active primary level for this world. |
| `gameMode` | `LuminaGameMode? gameMode` | The game mode defining the rules for this world. |
| `gameState` | `LuminaGameState? get gameState` | The game state for this world, managed by the game mode. |
| `timeSeconds` | `double get timeSeconds` | Accumulated game time in seconds (does not advance while [isPaused]). |
| `tickCount` | `int get tickCount` | Number of ticks actually executed by [tick] / [step]; paused no-op ticks are not counted. |
| `isPaused` | `bool get isPaused` | Whether the world is paused. While paused, [tick] is a silent no-op — no phases run, so subsystems (timers, audio), actors and [timeSeconds] all freeze together. Only [step] advances a paused world. Subsystems are notified via [LuminaWorldSubsystem.onWorldPauseChanged] on every actual change. |
| `isPaused` | `isPaused(bool value)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
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
| `debugActiveSpawnBuffer` | `List<dynamic> get debugActiveSpawnBuffer` | `debugActiveSpawnBuffer` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `debugSecondarySpawnBuffer` | `List<dynamic> get debugSecondarySpawnBuffer` | `debugSecondarySpawnBuffer` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `debugActiveDestroyBuffer` | `List<LuminaActor> get debugActiveDestroyBuffer` | `debugActiveDestroyBuffer` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `debugSecondaryDestroyBuffer` | `List<LuminaActor> get debugSecondaryDestroyBuffer` | `debugSecondaryDestroyBuffer` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `debugAllocatedBufferCount` | `int get debugAllocatedBufferCount` | `debugAllocatedBufferCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
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
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/src/world/world_partition.dart`

### `class LuminaWorldPartitionSubsystem`

Spatially partitioned world subsystem managing 2D grid cells, data layers, and seamless streaming.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cellSize` | `double cellSize` | `cellSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxCellTransitionsPerTick` | `int maxCellTransitionsPerTick` | `maxCellTransitionsPerTick` alanını (field/property) ve ilişkili veriyi saklar. |
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
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onWorldShutdown` | `void onWorldShutdown()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

### `class _CellIntent`

`_CellIntent`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `maxPriority` | `int maxPriority` | `maxPriority` alanını (field/property) ve ilişkili veriyi saklar. |
| `minDistance` | `double minDistance` | `minDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetState` | `LuminaStreamingSourceTargetState targetState` | `targetState` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/src/world/world_partition_cell.dart`

### `enum CellState`

6-state lifecycle for World Partition cells.

### `class LuminaWorldPartitionCell`

A spatial grid cell within World Partition holding regional actors.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cellX` | `int cellX` | `cellX` alanını (field/property) ve ilişkili veriyi saklar. |
| `cellY` | `int cellY` | `cellY` alanını (field/property) ve ilişkili veriyi saklar. |
| `cellSize` | `double cellSize` | `cellSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `state` | `CellState get state` | `state` özelliğinin anlık değerini okuyan getter erişimcisi. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `runsGameplay` | `bool get runsGameplay` | Whether gameplay lifecycle (e.g. `onBeginPlay`, `onTick` for actors) executes. |
| `ticksSubsystems` | `bool get ticksSubsystems` | Whether world subsystems receive tick notifications during frame updates. |
| `runsRenderPrep` | `bool get runsRenderPrep` | Whether the post-physics render prep phase is active for scene updates. |
| `isEditorWorld` | `bool get isEditorWorld` | Whether the world is running inside an editor environment (editor or PIE). |

## `lib/src/world/subsystem/physics_world_subsystem.dart`

### `class LuminaPhysicsWorldSubsystem`

Reference physics world subsystem providing simulation stepping and collision integration.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onWorldShutdown` | `void onWorldShutdown()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/world/subsystem/subsystem_collection.dart`

### `class LuminaSubsystemCollection`

Collection manager for [LuminaWorldSubsystem] instances. Provides O(1) dual-indexed generic lookup and deterministic registration-order execution.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `length` | `int get length` | Number of registered subsystems. |
| `notifyBeginPlay` | `void notifyBeginPlay()` | Notifies all registered subsystems of [beginPlay] in registration order. |
| `notifyTick` | `void notifyTick(double deltaTime)` | Notifies all registered subsystems of frame tick in registration order. |
| `notifyPauseChanged` | `void notifyPauseChanged(bool paused)` | Notifies all registered subsystems of a world pause/resume in registration order. |
| `shutdown` | `void shutdown()` | Shuts down all registered subsystems in reverse registration order and clears the collection. |

## `lib/src/world/subsystem/world_subsystem.dart`

### `class LuminaWorldSubsystem`

Base class for global, lifetime-bound services attached to a [LuminaWorld].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Değerler:**

- `line`
- `sphere`
- `box`
- `point`
- `arrow`
- `string`
- `capsule`

### `class LuminaDebugShape`

One debug shape recorded in `LuminaWorld.debugShapes` for the editor's Play-In-Editor viewport to draw. Points are **runtime** coordinates (Y up, cm); [color] is linear RGBA 0–1; [expiresAt] is the world's real time the shape disappears at.

**Yapıcı Metotlar (Constructors):**

- `const LuminaDebugShape({required this.kind, required this.points, required this.color, required this.expiresAt, this.thickness = 1.0, this.duration = 0.0, this....`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `const LuminaScreenMessage(this.key, this.text, this.color, this.expiresAt)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `key` | `final String key` |  |
| `text` | `final String text` |  |
| `color` | `final List<double> color` |  |
| `expiresAt` | `final double expiresAt` |  |

## `lib/src/world/level_preloader.dart`

### `abstract final class LuminaProjectLevels`

The levels of the open project, by name (`L_Arena`): what the Blueprint validator checks a Load Level / Change Level node's Level Name against. Empty — nothing registered — checks nothing. Play-In-Editor and the editor register them from the project's asset index.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `names` | `static Set<String> get names` |  |
| `register` | `static void register(Iterable<String> levelNames)` |  |
| `clear` | `static void clear()` |  |
| `nameOf` | `static String nameOf(String level)` | `L_Arena` for `L_Arena`, `L_Arena.lmas` or `contents/levels/L_Arena.lmas`. |
| `isKnown` | `static bool isKnown(String level)` | Whether [level] is a registered project level (always, when none is). |

### `enum LuminaAssetKind`

What kind of content a level asset is: it decides how the [LuminaLevelPreloader] makes it resident.

**Değerler:**

- `mesh`
- `texture`
- `material`
- `animation`
- `sound`
- `blueprint`
- `landscape`
- `environment`
- `other`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fromName` | `static LuminaAssetKind fromName(String? name)` | The kind named [name] (`mesh`, `texture`…), [other] when unknown. |

### `class LuminaAssetRef`

One asset a level loads: the path its components read (a bundle path such as `contents/meshes/SM_Rock.lmas` in a built game, an absolute path in the editor) and its [kind]. The level code generator emits a level's list as `static const List<LuminaAssetRef> assetManifest`.

**Yapıcı Metotlar (Constructors):**

- `const LuminaAssetRef(this.path, [this.kind = LuminaAssetKind.other])`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `kind` | `final LuminaAssetKind kind` |  |
| `name` | `String get name` | `SM_Rock`: the file name without its extension, what progress reports as the content being loaded. |
| `toJson` | `Map<String, Object?> toJson()` |  |
| `fromJson` | `static LuminaAssetRef fromJson(Map<String, Object?> json)` |  |

### `class LuminaLevelLoadProgress`

One update of a level preload: after each asset ([loaded] of [total], [current] is the asset that just finished), then either the final [done] update (Success) or one carrying [error] and [stackTrace].

**Yapıcı Metotlar (Constructors):**

- `const LuminaLevelLoadProgress({required this.levelName, required this.total, required this.loaded, this.current = '', this.error, this.stackTrace, this.done = f...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `LuminaLevelPreloader({this.manifestResolver, this.assetProvider, this.engine, this.maxConcurrent = 4})`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `activeWidgets` | `final ObservableValue<List<Map<String, Object?>>> activeWidgets` | Etkin widget listesi (`lumina_core`'un `ObservableValue`'su); widget eklenince, çıkarılınca, yeniden sıralanınca ya da görünürlüğü değişince yenilenir; `lumina_widgets`'ın widget katmanı onu dinler. |
| `widgets` | `List<Map<String, Object?>> get widgets` | Read-only snapshot of current active widgets sorted by zOrder ascending. |
| `addWidget` | `void addWidget(Map<String, Object?> widget)` | Adds a widget to the viewport. |
| `removeWidget` | `void removeWidget(Map<String, Object?> widget)` | Removes a widget from the viewport. |
| `notifyChanged` | `void notifyChanged()` | Notifies listeners that widget properties (e.g. visibility, zOrder, text) changed. |

## `lib/src/world/subsystem/user_settings_subsystem.dart`

### `class LuminaUserSettingsSubsystem`

Oyun ölçeklenebilirliğini, kamera görüş mesafesini ve kullanıcı ekran ayarlarını yöneten dünya alt sistemi (world subsystem).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `overallScalabilityLevel` | `String get overallScalabilityLevel` | Geçerli genel preset (`low`, `medium`, `high`, `epic`, `cinematic` veya `custom`). |
| `viewDistanceQuality` | `String get viewDistanceQuality` | Geçerli görüş mesafesi kademesi (`low`, `medium`, `high`, `epic`, `cinematic`). |
| `viewDistance` | `double get viewDistance` | Santimetre cinsinden geçerli kamera far clip düzlemi mesafesi. |
| `shadowQuality` | `String get shadowQuality` | Geçerli gölge kalitesi kademesi. |
| `antiAliasingQuality` | `String get antiAliasingQuality` | Geçerli kenar yumuşatma modu (`none`, `fxaa`, `msaa`, `taa`). |
| `postProcessingQuality` | `String get postProcessingQuality` | Geçerli post-processing kademesi. |
| `textureQuality` | `String get textureQuality` | Geçerli doku kalitesi kademesi. |
| `shadingQuality` | `String get shadingQuality` | Geçerli gölgelendirme kalitesi kademesi. |
| `resolutionScale` | `double get resolutionScale` | Geçerli dahili render çözünürlük ölçeği yüzdesi. |
| `targetFps` | `int get targetFps` | Hedef FPS sınırı (sınırsız için 0). |
| `vsyncEnabled` | `bool get vsyncEnabled` | Dikey senkronizasyonun (VSync) etkin olup olmadığı. |
| `setOverallScalabilityLevel` | `void setOverallScalabilityLevel(String preset)` | Tüm ölçeklenebilirlik kademelerini belirtilen presete göre senkronize eder. |
| `setViewDistanceQuality` | `void setViewDistanceQuality(String tier)` | Görüş mesafesi kademesini belirler ve far clip mesafesini günceller. |
| `setViewDistance` | `void setViewDistance(double cm)` | Santimetre cinsinden açık kamera far clip düzlemini belirler. |
| `applySettings` | `void applySettings()` | Yapılandırılan ayarları dünyadaki dinamik çözünürlüğe, post-process denetleyicisine, yönlü ışık gölgelerine ve kamera kırpma düzlemlerine uygular. |

---

[Önceki: Deklaratif ağaç](declarative.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Actor'ler, pawn'lar ve character'lar](object.md)
