[Türkçe](../../tr/lumina/utilities.md)

# Utilities, math and testing

Engine utilities: gameplay statics, gameplay volumes (trigger, blocking, kill-Z), the timer manager, viewport picking, the mesh decimation service and the engine's `SmokeArtifacts`. File paths are relative to the `lumina/` package directory. The math rules (units, axes, Euler, transform snapshots) live in `lumina_core`: see [Math](../lumina_core/math.md).

**On this page:**

- [`lib/src/services/mesh_decimation_service.dart`](#libsrcservicesmesh_decimation_servicedart)
- [`lib/src/utility/gameplay_statics.dart`](#libsrcutilitygameplay_staticsdart)
- [`lib/src/utility/gameplay_volumes.dart`](#libsrcutilitygameplay_volumesdart)
- [`lib/src/utility/timer_manager.dart`](#libsrcutilitytimer_managerdart)
- [`lib/src/utility/viewport_statics.dart`](#libsrcutilityviewport_staticsdart)
- [`lib/src/testing/asset_project_fixture.dart`](#libsrctestingasset_project_fixturedart)
- [`lib/src/testing/import_folder_fixture.dart`](#libsrctestingimport_folder_fixturedart)
- [`lib/src/testing/smoke_artifacts.dart`](#libsrctestingsmoke_artifactsdart)
- [`lib/src/testing/smoke_render.dart`](#libsrctestingsmoke_renderdart)
- [`lib/src/utility/lumina_assets.dart`](#libsrcutilitylumina_assetsdart)
- [`lib/src/utility/web_loading.dart`](#libsrcutilityweb_loadingdart)
- [`lib/src/utility/web_loading_hook_stub.dart`](#libsrcutilityweb_loading_hook_stubdart)
- [`lib/src/utility/web_loading_hook_web.dart`](#libsrcutilityweb_loading_hook_webdart)

## `lib/src/services/mesh_decimation_service.dart`

### `class DecimatedMeshData`

`DecimatedMeshData`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `positions` | `Float32List positions` | Holds the `positions` property or configuration state. |
| `indices` | `Uint32List indices` | Holds the `indices` property or configuration state. |
| `triangleCount` | `int triangleCount` | Holds the `triangleCount` property or configuration state. |
| `vertexCount` | `int vertexCount` | Holds the `vertexCount` property or configuration state. |

### `class MeshDecimationService`

`MeshDecimationService`: Service class encapsulating business logic, file I/O, or engine processing.

## `lib/src/utility/gameplay_statics.dart`

### `class LuminaGameplayStatics`

Stateless static facade providing one-line accessors for actor spawning, player lookup, queries, and damage.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `destroyActor` | `static void destroyActor(LuminaWorld world, LuminaActor actor)` | Schedules an actor for destruction in Phase 5 of the next tick. |
| `getTimeSeconds` | `static double getTimeSeconds(LuminaWorld world)` | Returns total accumulated game-time in seconds elapsed on [world]. |
| `getTimerManager` | `static LuminaTimerManager? getTimerManager(LuminaWorld world)` | Retrieves the [LuminaTimerManager] world subsystem on [world] if registered. |

## `lib/src/utility/gameplay_volumes.dart`

### `class LuminaVolume`

Base volume actor providing oriented bounding box tests and standardized collision component root.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `volumeShape` | `LuminaCollisionComponent get volumeShape` | Typed accessor to the underlying collision component root shape. |

### `class LuminaTriggerVolume`

Volume actor that fires scriptable begin/end overlap events when other actors intersect its shape.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `triggerOnceOnly` | `bool triggerOnceOnly` | Holds the `triggerOnceOnly` property or configuration state. |
| `overlappingActors` | `List<LuminaActor> get overlappingActors` | Live unmodifiable view of all actors currently intersecting this trigger volume. |
| `onBeginPlay` | `void onBeginPlay()` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

### `class LuminaBlockingVolume`

Static invisible blocking collision volume acting as world boundary or barrier.

### `class LuminaKillZVolume`

Lethal hazard volume that damages and destroys actors entering its bounds.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `onBeginPlay` | `void onBeginPlay()` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/utility/timer_manager.dart`

### `class LuminaTimerHandle`

Opaque identifier for an active or expired timer managed by [LuminaTimerManager].

**Constructors:**
- `LuminaTimerHandle._(this.id)`: Initializes `LuminaTimerHandle._(this.id)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `int id` | Holds the `id` property or configuration state. |
| `isValid` | `bool get isValid` | Whether this handle currently references a valid registered timer. |
| `invalidate` | `void invalidate()` | Clears the validity of this local handle reference. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class _TimerEntry`

`_TimerEntry`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `handle` | `LuminaTimerHandle handle` | Returns the underlying native FFI pointer handle. |
| `rate` | `double rate` | Holds the `rate` property or configuration state. |
| `looping` | `bool looping` | Holds the `looping` property or configuration state. |
| `remainingTime` | `double remainingTime` | Holds the `remainingTime` property or configuration state. |

### `class LuminaTimerManager`

Central world subsystem managing game-time timers and delayed invocations driven exclusively by world ticks.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `setTimerForNextTick` | `LuminaTimerHandle setTimerForNextTick(void Function() callback)` | Schedules [callback] to execute on the immediately following world tick. |
| `clearTimer` | `void clearTimer(LuminaTimerHandle handle)` | Cancels the timer referenced by [handle]. |
| `clearAllTimers` | `void clearAllTimers()` | Cancels all active, paused, and pending timers. |
| `pauseTimer` | `void pauseTimer(LuminaTimerHandle handle)` | Pauses the timer referenced by [handle], freezing its remaining time. |
| `unpauseTimer` | `void unpauseTimer(LuminaTimerHandle handle)` | Resumes a paused timer referenced by [handle]. |
| `isTimerActive` | `bool isTimerActive(LuminaTimerHandle handle)` | Checks if [handle] is currently active and not paused. |
| `isTimerPaused` | `bool isTimerPaused(LuminaTimerHandle handle)` | Checks if [handle] is currently paused. |
| `getTimerRemaining` | `double getTimerRemaining(LuminaTimerHandle handle)` | Returns the remaining time in seconds for [handle], or -1.0 if not found. |
| `getTimerElapsed` | `double getTimerElapsed(LuminaTimerHandle handle)` | Returns the elapsed time in seconds into the current interval for [handle], or -1.0 if not found. |
| `getTimerRate` | `double getTimerRate(LuminaTimerHandle handle)` | Returns the configured interval rate in seconds for [handle], or -1.0 if not found. |
| `activeTimerCount` | `int get activeTimerCount` | Total count of active timers currently tracked. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `onWorldShutdown` | `void onWorldShutdown()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/utility/viewport_statics.dart`

### `class LuminaPickResult`

Result descriptor from a GPU pixel-exact picking query.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hasHit` | `bool hasHit` | Holds the `hasHit` property or configuration state. |
| `entity` | `int entity` | Holds the `entity` property or configuration state. |
| `actor` | `LuminaActor? actor` | Holds the `actor` property or configuration state. |
| `component` | `LuminaSceneComponent? component` | Holds the `component` property or configuration state. |
| `depth` | `double depth` | Holds the `depth` property or configuration state. |
| `worldLocation` | `Vector3? worldLocation` | Holds the `worldLocation` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class LuminaViewportStatics`

Stateless static utility facade for GPU viewport operations (pixel picking, ray unprojection, and screenshot capture).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cancelAllPending` | `static void cancelAllPending(String reason)` | Cancels and fails all currently pending pick and screenshot operations. |
| `flipRowsVertically` | `static Uint8List flipRowsVertically(Uint8List source, int width, int hei...` | Vertically flips RGBA pixel buffer rows (from bottom-left to top-down convention). |

## `lib/src/testing/asset_project_fixture.dart`

### `class AssetProjectFixture`

A generated project with many real `.lmas` files of every kind the editor scans (for the derived-data tests and smoke): static meshes carrying the barrels of `test-assets/Props/Barrels/` (half with an `.entity.glb` companion), textures, materials, Blueprint classes, enum / interface / save-game / montage documents, particle systems, widgets and levels — every third file written in the older key order (base64 fields before `metadata`), as older editor builds left them.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `barrels` | `static const List<String> barrels` |  |
| `png` | `static Uint8List png(int seed, {int size = 32})` | A small opaque PNG tinted by [seed] (a thumbnail / texture image). |
| `legacyBytes` | `static Uint8List legacyBytes(LuminaAsset asset)` | [asset] as an older build wrote it: `thumbnail_png` and `raw_payload` before `raw_mat_source`, `references` and `metadata`. |
| `write` | `static String write(Directory parent, {String name = 'IndexedGame', int count = 300, bool withSidecars = false...` | Writes `<parent>/<name>` with [count] assets and returns its path. With [withSidecars] every thumbnail is also left as an older build wrote it — a `.thumbnails/<name>.png` beside the asset, stamped not older than the `.lmas`, and every tenth asset with the sidecar only — plus `contents/.thumbnails/cover.png`. Without [writeManifest] only `contents/` is written (into an existing project). |

## `lib/src/testing/import_folder_fixture.dart`

### `class ImportFolderFixture`

A real nested source folder for the folder importer, built from `test-assets/Props` in a temp directory (test-assets is never written to):

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `root` | `final String root` | `<dest>/Source`, the folder to pick. |
| `copied` | `static const Map<String, List<String>> copied` |  |
| `splitSource` | `static const String splitSource` | The GLB unpacked into the `.gltf` + `.bin` pair. |
| `hiddenSource` | `static const String hiddenSource` | The GLB copied into the hidden folder (which the importer ignores). |
| `usedAssets` | `static List<String> get usedAssets` | test-assets paths the fixture copies from (for smoke badges). |
| `expectedPrimaries` | `static List<String> get expectedPrimaries` | Primary files the importer should find, relative to [root]. |
| `available` | `static bool get available` | Whether test-assets has every file the fixture needs. |
| `build` | `static ImportFolderFixture build(Directory dest)` |  |
| `unpackGlb` | `static ({String name, Uint8List bytes})? unpackGlb(Uint8List glb, String dir, String name)` | Writes [glb] as `<dir>/<name>.gltf` + `<name>.bin`, its first embedded image moved to `textures/<image name>` (referenced by uri). Returns that image (its file name and bytes), or null when it has none. |

## `lib/src/testing/smoke_artifacts.dart`

### `abstract final class SmokeArtifacts`

The smoke-test artifact API of lumina's tests: lumina_smoke's `SmokeArtifacts` (every member forwards to it, so both share one state: the artifact directory, the recorded assets) plus [renderRealAssetMedia], which films real test assets with Filament.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `renderRealAssetMedia` | `static Future<void> renderRealAssetMedia({required String testTitle, required List<String> usedAssets, double...` | See [SmokeRender.renderRealAssetMedia]. |
| `outputDirOverride` | `static String? get outputDirOverride` |  |
| `outputDirOverride` | `static set outputDirOverride(String? value)` |  |
| `testAssetsDirOverride` | `static String? get testAssetsDirOverride` |  |
| `testAssetsDirOverride` | `static set testAssetsDirOverride(String? value)` |  |
| `overrideDirForTesting` | `static void overrideDirForTesting(Directory? d)` |  |
| `packageRoot` | `static Directory get packageRoot` |  |
| `dir` | `static Directory get dir` |  |
| `testAssetsDir` | `static Directory get testAssetsDir` |  |
| `sanitizeTestName` | `static String sanitizeTestName(String testName)` |  |
| `recordAsset` | `static void recordAsset(String path)` |  |
| `recordedAssets` | `static List<String> get recordedAssets` |  |
| `resetRecordedAssets` | `static void resetRecordedAssets()` |  |
| `minimumVideoSeconds` | `static const double minimumVideoSeconds` |  |
| `maximumFrameHoldSeconds` | `static const double maximumFrameHoldSeconds` |  |
| `minimumVideoFps` | `static const double minimumVideoFps` |  |
| `minimumVideoWidth` | `static const int minimumVideoWidth` |  |
| `minimumVideoHeight` | `static const int minimumVideoHeight` |  |
| `framesDurationSeconds` | `static double framesDurationSeconds(int frameCount, double fps)` |  |
| `framesForSeconds` | `static int framesForSeconds(double fps, {double seconds = minimumVideoSeconds})` |  |
| `checkVideoDuration` | `static void checkVideoDuration(String testName, int frameCount, double fps)` |  |
| `checkVideoFps` | `static void checkVideoFps(String testName, double fps)` |  |
| `checkVideoSize` | `static void checkVideoSize(String testName, int width, int height)` |  |
| `checkFramesMove` | `static void checkFramesMove(String testName, List<Uint8List> pngFrames, double fps)` |  |
| `encodePng` | `static Uint8List encodePng(int w, int h, Uint8List rgba, {bool flipY = false, bool bgra = false})` |  |
| `encodeRgbaToPng` | `static Uint8List encodeRgbaToPng(Uint8List rawPixels, int width, int height, {bool flipY = false, bool bgra =...` |  |
| `pngSize` | `static (int, int)? pngSize(Uint8List png)` |  |
| `vp8QualitySettings` | `static const List<String> vp8QualitySettings` |  |
| `ffmpegVp8QualitySettings` | `static const List<String> ffmpegVp8QualitySettings` |  |
| `videoEncoderAvailable` | `static bool get videoEncoderAvailable` |  |
| `gstreamerEncoderAvailable` | `static bool get gstreamerEncoderAvailable` |  |
| `ffmpegPath` | `static String? get ffmpegPath` |  |
| `ffprobePath` | `static String? get ffprobePath` |  |
| `encodeWebmFromPngFrames` | `static Uint8List encodeWebmFromPngFrames(List<Uint8List> pngFrames, {double fps = minimumVideoFps})` |  |
| `encodeRawRgbaToWebm` | `static ProcessResult encodeRawRgbaToWebm({required String rawFrames, required String out, required int width,...` |  |
| `encodeWebmFromRawFile` | `static Uint8List encodeWebmFromRawFile(File rawFrames, {required int width, required int height, required int...` |  |
| `encodeWebmFromRgbaFrames` | `static Uint8List encodeWebmFromRgbaFrames({required int width, required int height, required List<Uint8List> f...` |  |
| `probeVideo` | `static ({double? seconds, int? width, int? height, double? fps})? probeVideo(String path)` |  |
| `probeVideoSeconds` | `static double? probeVideoSeconds(String path)` |  |
| `videoDurationSeconds` | `static double? videoDurationSeconds(File video)` |  |
| `videoFramesPerSecond` | `static double? videoFramesPerSecond(File video)` |  |
| `videoFrameSize` | `static (int, int)? videoFrameSize(File video)` |  |
| `saveScreenshot` | `static File saveScreenshot(String testName, Uint8List pngBytes, {List<String>? usedAssets, Map<String, Object?...` |  |
| `saveScreenshotToDir` | `static File saveScreenshotToDir(String testName, Uint8List pngBytes, Directory targetDir, {List<String>? usedA...` |  |
| `saveVideoFromPngFrames` | `static File saveVideoFromPngFrames(String testName, List<Uint8List> pngFrames, {double fps = minimumVideoFps,...` |  |
| `saveVideo` | `static File saveVideo(String testName, Uint8List videoBytes, {String extension = 'webm', List<String>? usedAss...` |  |
| `saveEncodedVideo` | `static File saveEncodedVideo(String testName, Uint8List videoBytes, {String extension = 'webm', List<String>?...` |  |
| `saveVideoToDir` | `static File saveVideoToDir(String testName, Uint8List videoBytes, Directory targetDir, {String extension = 'we...` |  |
| `annotate` | `static void annotate(String testName, Map<String, Object?> fields, {Directory? targetDir})` |  |
| `clear` | `static void clear()` |  |
| `clearDir` | `static void clearDir(Directory targetDir)` |  |

## `lib/src/testing/smoke_render.dart`

### `typedef SmokeRenderFrame`

Called for every frame [SmokeRender.renderRealAssetMedia] films, before it is rendered.

### `typedef SmokeRenderSetup`

Called once the scene of [SmokeRender.renderRealAssetMedia] and its assets are ready, before the first frame.

### `abstract final class SmokeRender`

Smoke evidence rendered by Filament itself: a headless scene of real test assets filmed frame by frame into a screenshot and a smoke video.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `renderRealAssetMedia` | `static Future<void> renderRealAssetMedia({required String testTitle, required List<String> usedAssets, double...` | Renders real 3D assets from [usedAssets] (paths under [SmokeArtifacts.testAssetsDir]; a missing or unloadable one throws a [StateError], never a blank scene) via Filament C++/Vulkan engine over a headless simulation of [durationSeconds] (at least [SmokeVideo.minimumSeconds]) at [fps] (at least [SmokeVideo.minimumFps]), capturing a real rendered screenshot PNG and a WebM video of every simulated frame, [width] × [height] (at least [SmokeVideo.minimumWidth] × [SmokeVideo.minimumHeight]). |

## `lib/src/utility/lumina_assets.dart`

### `typedef LuminaAssetProvider`

Loads an asset's bytes by path (a mesh GLB, a compiled material, an IBL).

### `abstract final class LuminaAssets`

Where the runtime reads assets that a component was not handed a provider for. The editor and tests read project files from disk; a generated game sets [defaultProvider] to its Flutter asset bundle, which is the only store a web build has.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `defaultProvider` | `static LuminaAssetProvider? defaultProvider` | Used by the mesh cache, the material cache and the sky whenever their own `assetProvider` is null. Null reads the file system. |
| `projectDir` | `static String? projectDir` | The open project's folder, set by the editor: a disk read of a project-relative path (`contents/…`, what Blueprints store) resolves against it. Null reads every path as given. |
| `resolve` | `static LuminaAssetProvider resolve(LuminaAssetProvider? explicit)` | Resolves the provider for a load: [explicit], else [defaultProvider], else a disk read. Paths a level preload pinned ([pinResident]) are served from memory first. |
| `pinResident` | `static void pinResident(Object owner, Map<String, Uint8List> bytes, [Map<String, Object> misses = const {}])` | Serves [bytes] (and fails [misses] with their error) by path from [resolve] until [unpinResident] with the same [owner]: what a level preload read, handed to the level's components. The maps are live — entries the owner adds later are served too. |
| `unpinResident` | `static void unpinResident(Object owner)` | Stops serving what [owner] pinned. |
| `isResident` | `static bool isResident(String path)` | Whether a preload serves [path] from memory. |
| `loadPayload` | `static Future<Uint8List?> loadPayload(String path, {LuminaAssetProvider? provider}) async` | What generated game code needs from a project asset: the payload of the `.lmas` at [path] (a texture's image bytes, …), or a plain file's bytes, loaded through [resolve]. Null when the `.lmas` carries no payload. |

## `lib/src/utility/web_loading.dart`

### `abstract final class LuminaWebLoading`

The generated game's side of the web loading screen.

A web build's `index.html` shows a plain HTML/CSS screen from the first byte; its `loading.js` tracks the Flutter engine's download itself and exposes `window.luminaLoading.progress(fraction, label)`. Once Dart runs, the generated `main()` calls [prepareGame], which loads the renderer's WebAssembly module and preloads the game's bundled assets, reporting each step there, before `runApp`. The screen fades out on Flutter's first frame, so it covers the whole download.

Native builds skip all of it: [prepareGame] returns at once and nothing here imports `dart:js_interop` outside the web (conditional import).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `engineEnd` | `static const double engineEnd` | The loading bar's phases: the Flutter engine fills it up to [engineEnd] (tracked by `loading.js` alone), the renderer's wasm from [rendererStart] to [rendererEnd] (its bytes mapped by `loading.js`, which holds the same numbers), the asset preload the rest. |
| `rendererStart` | `static const double rendererStart` |  |
| `rendererEnd` | `static const double rendererEnd` |  |
| `isWeb` | `static bool get isWeb` | Whether this is a web build. |
| `progress` | `static void progress(double fraction, String label)` | Moves the page's loading screen to [fraction] (0–1, never backwards) with [label] under it. A no-op on native builds and on pages without the loading screen. |
| `preloadedCount` | `static int get preloadedCount` | Preloaded assets not handed out yet. |
| `prepareGame` | `static Future<void> prepareGame({AssetBundle? bundle, String contentsPrefix = 'contents/'}) async` | Web builds: loads the renderer, then every asset under [contentsPrefix] in [bundle]'s manifest, reporting progress to the loading screen. Call after `LuminaAssets.defaultProvider` is set and before `runApp`. |
| `preloadAssets` | `static Future<int> preloadAssets(AssetBundle bundle, {String prefix = 'contents/', int concurrency = 4, void F...` | Loads every asset of [bundle]'s manifest whose key starts with [prefix], [concurrency] at a time, calling [onProgress] with the count done (from 0 to the total). The bytes are kept until the runtime first asks for that path: [LuminaAssets.defaultProvider] is wrapped to hand each one out once, so the level's meshes and textures do not download twice. Whatever is not asked for within [keepFor] is dropped (null: kept until [releasePreloaded]). Returns the number of assets loaded. |
| `releasePreloaded` | `static void releasePreloaded()` | Drops every preloaded asset not handed out yet. |

## `lib/src/utility/web_loading_hook_stub.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isWeb` | `const bool isWeb` |  |
| `progress` | `void progress(double fraction, String label)` |  |
| `loadRenderer` | `Future<void> loadRenderer() async` |  |

## `lib/src/utility/web_loading_hook_web.dart`

### `extension type _LuminaLoadingJs._(JSObject _)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `progress` | `external void progress(JSNumber fraction, JSString label)` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isWeb` | `const bool isWeb` |  |
| `progress` | `void progress(double fraction, String label)` | Reports to `window.luminaLoading.progress`; a page without the loading screen (a hand-written index.html) is left alone. |
| `loadRenderer` | `Future<void> loadRenderer()` | Downloads and instantiates the renderer's WebAssembly module. |

---

[Previous: Animation Blueprints](blueprint/animation.md) | [Up: lumina (engine core)](index.md) | [Next: Data layer: use cases and services](data-services.md)
