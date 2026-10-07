[English](../../en/lumina/utilities.md)

# Yardımcılar, matematik ve test

Engine yardımcıları: gameplay statics, gameplay volume'ları (trigger, blocking, kill-Z), timer manager, viewport picking, mesh decimation servisi, engine'in asset okuyucuları (`lib/src/assets/`: kodlanmış görüntü çözücü, engine'in Draco ve görüntü çözücüleriyle GLB yükleyici, level asset manifestosu ve level mesh materyal araması) ve engine'in `SmokeArtifacts` sınıfı. Dosya yolları `lumina/` paket dizinine görelidir. Matematik kuralları (birimler, eksenler, Euler, transform anlık görüntüleri) `lumina_core`'dadır: bkz. [Matematik](../lumina_core/math.md).

**Bu sayfada:**

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
- [`lib/src/utility/lumina_platform.dart`](#libsrcutilitylumina_platformdart)
- [`lib/src/media/video_playback.dart`](#libsrcmediavideo_playbackdart)
- [`lib/src/assets/encoded_image_decoder.dart`](#libsrcassetsencoded_image_decoderdart)
- [`lib/src/assets/glb_loader.dart`](#libsrcassetsglb_loaderdart)
- [`lib/src/assets/level_asset_manifest.dart`](#libsrcassetslevel_asset_manifestdart)

## `lib/src/services/mesh_decimation_service.dart`

### `class DecimatedMeshData`

`DecimatedMeshData`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `positions` | `Float32List positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `Uint32List indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `triangleCount` | `int triangleCount` | `triangleCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int vertexCount` | `vertexCount` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MeshDecimationService`

`MeshDecimationService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

## `lib/src/utility/gameplay_statics.dart`

### `class LuminaGameplayStatics`

Stateless static facade providing one-line accessors for actor spawning, player lookup, queries, and damage.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `destroyActor` | `static void destroyActor(LuminaWorld world, LuminaActor actor)` | Schedules an actor for destruction in Phase 5 of the next tick. |
| `getTimeSeconds` | `static double getTimeSeconds(LuminaWorld world)` | Returns total accumulated game-time in seconds elapsed on [world]. |
| `getTimerManager` | `static LuminaTimerManager? getTimerManager(LuminaWorld world)` | Retrieves the [LuminaTimerManager] world subsystem on [world] if registered. |

## `lib/src/utility/gameplay_volumes.dart`

### `class LuminaVolume`

Base volume actor providing oriented bounding box tests and standardized collision component root.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `volumeShape` | `LuminaCollisionComponent get volumeShape` | Typed accessor to the underlying collision component root shape. |

### `class LuminaTriggerVolume`

Volume actor that fires scriptable begin/end overlap events when other actors intersect its shape.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `triggerOnceOnly` | `bool triggerOnceOnly` | `triggerOnceOnly` alanını (field/property) ve ilişkili veriyi saklar. |
| `overlappingActors` | `List<LuminaActor> get overlappingActors` | Live unmodifiable view of all actors currently intersecting this trigger volume. |
| `onBeginPlay` | `void onBeginPlay()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

### `class LuminaBlockingVolume`

Static invisible blocking collision volume acting as world boundary or barrier.

### `class LuminaKillZVolume`

Lethal hazard volume that damages and destroys actors entering its bounds.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `onBeginPlay` | `void onBeginPlay()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/utility/timer_manager.dart`

### `class LuminaTimerHandle`

Opaque identifier for an active or expired timer managed by [LuminaTimerManager].

**Yapıcı Metotlar (Constructors):**
- `LuminaTimerHandle._(this.id)`: `LuminaTimerHandle._(this.id)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `int id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `isValid` | `bool get isValid` | Whether this handle currently references a valid registered timer. |
| `invalidate` | `void invalidate()` | Clears the validity of this local handle reference. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class _TimerEntry`

`_TimerEntry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `handle` | `LuminaTimerHandle handle` | `handle` alanını (field/property) ve ilişkili veriyi saklar. |
| `rate` | `double rate` | `rate` alanını (field/property) ve ilişkili veriyi saklar. |
| `looping` | `bool looping` | `looping` alanını (field/property) ve ilişkili veriyi saklar. |
| `remainingTime` | `double remainingTime` | `remainingTime` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaTimerManager`

Central world subsystem managing game-time timers and delayed invocations driven exclusively by world ticks.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onWorldShutdown` | `void onWorldShutdown()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/utility/viewport_statics.dart`

### `class LuminaPickResult`

Result descriptor from a GPU pixel-exact picking query.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hasHit` | `bool hasHit` | `hasHit` alanını (field/property) ve ilişkili veriyi saklar. |
| `entity` | `int entity` | `entity` alanını (field/property) ve ilişkili veriyi saklar. |
| `actor` | `LuminaActor? actor` | `actor` alanını (field/property) ve ilişkili veriyi saklar. |
| `component` | `LuminaSceneComponent? component` | `component` alanını (field/property) ve ilişkili veriyi saklar. |
| `depth` | `double depth` | `depth` alanını (field/property) ve ilişkili veriyi saklar. |
| `worldLocation` | `Vector3? worldLocation` | `worldLocation` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class LuminaViewportStatics`

Stateless static utility facade for GPU viewport operations (pixel picking, ray unprojection, and screenshot capture).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cancelAllPending` | `static void cancelAllPending(String reason)` | Cancels and fails all currently pending pick and screenshot operations. |
| `flipRowsVertically` | `static Uint8List flipRowsVertically(Uint8List source, int width, int hei...` | Vertically flips RGBA pixel buffer rows (from bottom-left to top-down convention). |

## `lib/src/testing/asset_project_fixture.dart`

### `class AssetProjectFixture`

A generated project with many real `.lmas` files of every kind the editor scans (for the derived-data tests and smoke): static meshes carrying the barrels of `test-assets/Props/Barrels/` (half with an `.entity.glb` companion), textures, materials, Blueprint classes, enum / interface / save-game / montage documents, particle systems, widgets and levels — every third file written in the older key order (base64 fields before `metadata`), as older editor builds left them.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `barrels` | `static const List<String> barrels` |  |
| `png` | `static Uint8List png(int seed, {int size = 32})` | A small opaque PNG tinted by [seed] (a thumbnail / texture image). |
| `legacyBytes` | `static Uint8List legacyBytes(LuminaAsset asset)` | [asset] as an older build wrote it: `thumbnail_png` and `raw_payload` before `raw_mat_source`, `references` and `metadata`. |
| `write` | `static String write(Directory parent, {String name = 'IndexedGame', int count = 300, bool withSidecars = false...` | Writes `<parent>/<name>` with [count] assets and returns its path. With [withSidecars] every thumbnail is also left as an older build wrote it — a `.thumbnails/<name>.png` beside the asset, stamped not older than the `.lmas`, and every tenth asset with the sidecar only — plus `contents/.thumbnails/cover.png`. Without [writeManifest] only `contents/` is written (into an existing project). |

## `lib/src/testing/import_folder_fixture.dart`

### `class ImportFolderFixture`

A real nested source folder for the folder importer, built from `test-assets/Props` in a temp directory (test-assets is never written to):

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `renderRealAssetMedia` | `static Future<void> renderRealAssetMedia({required String testTitle, required List<String> usedAssets, double...` | Renders real 3D assets from [usedAssets] (paths under [SmokeArtifacts.testAssetsDir]; a missing or unloadable one throws a [StateError], never a blank scene) via Filament C++/Vulkan engine over a headless simulation of [durationSeconds] (at least [SmokeVideo.minimumSeconds]) at [fps] (at least [SmokeVideo.minimumFps]), capturing a real rendered screenshot PNG and a WebM video of every simulated frame, [width] × [height] (at least [SmokeVideo.minimumWidth] × [SmokeVideo.minimumHeight]). |

## `lib/src/utility/lumina_assets.dart`

### `typedef LuminaAssetProvider`

Loads an asset's bytes by path (a mesh GLB, a compiled material, an IBL).

### `abstract final class LuminaAssets`

Where the runtime reads assets that a component was not handed a provider for. The editor and tests read project files from disk; a generated game sets [defaultProvider] to its Flutter asset bundle, which is the only store a web build has.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `defaultProvider` | `static LuminaAssetProvider? defaultProvider` | Used by the mesh cache, the material cache and the sky whenever their own `assetProvider` is null. Null reads the file system. |
| `bundleProvider` | `static LuminaAssetProvider? bundleProvider` | Uygulamayla paketlenmiş bir asset'i bundle anahtarıyla okur (bir paketin kendi asset'i: `packages/lumina/assets/sky/…`). Motorun asset bundle'ı yoktur: `LuminaWidgets.ensureInitialized` (`lumina_widgets`) bunu Flutter'ın `rootBundle`'ına ayarlar. Null: bileşenler [resolve]'a döner. |
| `projectDir` | `static String? projectDir` | Editörün açık projenin klasörüne ayarladığı yol: diskten okunan projeye göreli bir yol (`contents/…`, Blueprint'lerin sakladığı biçim) buna göre çözülür. Null ise her yol olduğu gibi okunur. |
| `resolve` | `static LuminaAssetProvider resolve(LuminaAssetProvider? explicit)` | Resolves the provider for a load: [explicit], else [defaultProvider], else a disk read. Paths a level preload pinned ([pinResident]) are served from memory first. |
| `pinResident` | `static void pinResident(Object owner, Map<String, Uint8List> bytes, [Map<String, Object> misses = const {}])` | Serves [bytes] (and fails [misses] with their error) by path from [resolve] until [unpinResident] with the same [owner]: what a level preload read, handed to the level's components. The maps are live — entries the owner adds later are served too. |
| `unpinResident` | `static void unpinResident(Object owner)` | Stops serving what [owner] pinned. |
| `isResident` | `static bool isResident(String path)` | Whether a preload serves [path] from memory. |
| `loadPayload` | `static Future<Uint8List?> loadPayload(String path, {LuminaAssetProvider? provider}) async` | What generated game code needs from a project asset: the payload of the `.lmas` at [path] (a texture's image bytes, …), or a plain file's bytes, loaded through [resolve]. Null when the `.lmas` carries no payload. |

## `lib/src/utility/lumina_platform.dart`

### `enum LuminaPlatform`

Bir oyunun çalıştığı işletim sistemi, motorun gördüğü biçimde (`Get Platform Name`'in bildirdiği), Flutter olmadan okunur: `android`, `fuchsia`, `iOS`, `linux`, `macOS`, `windows`, `web`.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isWeb` | `static const bool isWeb` | `bool.fromEnvironment('dart.library.js_interop')`: bunun bir web derlemesi olup olmadığı. |
| `override` | `static LuminaPlatform? override` | Host ayarlar: `lumina_widgets` açılışta Flutter'ın hedef platformunu ayarlar; bir test kendi değerini verebilir. |
| `current` | `static LuminaPlatform get current` | [override], yoksa web derlemesinde `web`, yoksa `dart:io`'nun bildirdiği işletim sistemi. |
| `displayName` | `static String get displayName` | `Windows`, `Linux`, `MacOS`, `IOS`, `Android`, `Fuchsia`; web derlemesinde `Web`. |

## `lib/src/media/video_playback.dart`

### `abstract interface class LuminaVideoPlayback`

Motorun nasıl olduğunu bilmeden oynattığı bir video: `Open Video`'nun döndürdüğü ve diğer Blueprint video node'larının sürdüğü nesne. Motor hiçbir medya oynatıcısı tutmaz; `lumina_widgets` açılışta [factory]'yi kaydeder (kendi `LuminaVideoController`'ı, media_kit). Üyeler: `initialize`, `play`, `pause`, `stop`, `seekToSeconds`, `setVolume`, `setPlaybackSpeed`, `setLooping`, `isPlaying`, `position`, `duration`.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `factory` | `static LuminaVideoPlayback Function({required String source, bool autoPlay, bool loop, double initialVolume})? factory` | Bir oynatma oluşturur; host'un oynatıcısı yoksa (başsız bir dünya, bir test) null'dır ve o zaman `Open Video` hiçbir şey döndürmez. |

## `lib/src/assets/encoded_image_decoder.dart`

### `class DecodedRgbaImage`

Decoded pixels: `width * height` RGBA8 texels, row-major, alpha premultiplied (what `dart:ui`'s `ImageByteFormat.rawRgba` hands back).

**Yapıcı Metotlar (Constructors):**

- `const DecodedRgbaImage(this.width, this.height, this.rgba)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `width` | `final int width` |  |
| `height` | `final int height` |  |
| `rgba` | `final Uint8List rgba` |  |

### `abstract final class EncodedImageDecoder`

Decodes an encoded image with the decoder for its [EncodedImageFormat], the same way on every isolate.

`dart:ui`'s image codec only exists on a root isolate (the editor's UI isolate, a test's main isolate, the web's only isolate). There it decodes PNG, JPEG, WebP, GIF and BMP; on any other isolate — an `Isolate.run` worker, a save or streaming worker — `package:image` decodes the same formats. TGA always goes through [TgaDecoderService]. KTX2 (Basis) and unrecognised bytes are not decoded to pixels here.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `platformCodecAvailable` | `static bool get platformCodecAvailable` | Whether this isolate can use `dart:ui`'s image codec. |
| `platformCodecProxy` | `static Future<DecodedRgbaImage> Function(Uint8List bytes)? platformCodecProxy` | Decodes with the UI isolate's platform codec on behalf of an isolate that has none: the import worker sets this to a round trip to the UI isolate, so what it decodes — the texels a mesh thumbnail samples — matches a UI-isolate decode bit for bit (JPEG decoders disagree in the last bits). Used only where [platformCodecAvailable] is false. |
| `decodeRgba` | `static Future<DecodedRgbaImage?> decodeRgba(Uint8List bytes) async` | [bytes] decoded to premultiplied RGBA8, or `null` when its format is not one this decoder turns into pixels (KTX2, unknown). Throws a [FormatException] for bytes that carry a recognised signature but do not decode. |

## `lib/src/assets/glb_loader.dart`

### `abstract final class LuminaGlbLoader`

GLB mesh verisini çalışma zamanında okur: lumina_core'un saf `GlbReader`'ı ve yalnızca engine'de olan çözücüler. Draco ile sıkıştırılmış primitive'ler Filament'in native çözücüsüyle (flutter_filament), base colour dokuları `EncodedImageDecoder` ile çözülür ve vertex renklerine örneklenir. Landscape'in foliage mesh'leri ve editör proxy'si bununla okunur. Editörün `GlbParserService.parseGlb`'si (lumina_editor_data) içe aktarma temizleyicisini `GlbDecoders.prepare` olarak ekler.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `decoders` | `static const GlbDecoders decoders` | `GlbReader.parse` için engine'in Draco ve görüntü çözücüleri. |
| `parse` | `static Future<GlbMeshData?> parse(Uint8List bytes)` | Bir `.glb`'nin ya da onu saran `.lmas`'ın mesh verisi; okunabilir bir GLB değilse null. |

## `lib/src/assets/level_asset_manifest.dart`

### `abstract final class LuminaLevelAssetManifest`

What a level loads: the assets its placed actors name — meshes, landscapes, sky environments, textures, materials, sounds, animation assets and the Blueprint classes placed in it with the assets their components name. The level code generator emits it as the level class's `assetManifest`; Play-In-Editor builds it from the level `.lmas` found through the project's asset index. Either way a [LuminaLevelPreloader] preloads it. Yerleştirilmiş bir mesh'e atanmış materyal yalnızca çizilebiliyorsa listelenir ([LuminaLevelActorMaterial]).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fromActorMaps` | `static List<LuminaAssetRef> fromActorMaps(List<Map<String, dynamic>> actorMaps, {String? projectDir})` | The assets [actorMaps] (`metadata.actors`) name, in first-seen order and without duplicates, as bundle paths (`contents/…`). A placed Blueprint adds its class `.lmas` and — with [projectDir] to read the class from — the assets its components name. |
| `kindOf` | `static LuminaAssetKind kindOf(String path, {String? key})` | The kind of [path], from the key that named it (`staticMeshAsset`, `soundAsset`…) or its extension. |
| `bundlePath` | `static String bundlePath(String path)` | [path] as the game bundle names it: `contents/…` (a path through the project's `contents/` is cut there); any other path as it is. |
| `levelPath` | `static String? levelPath(LuminaAssetIndex index, String levelName)` | The project-relative `.lmas` of level [levelName] (`L_Arena`, `L_Arena.lmas` or `contents/…/L_Arena.lmas`), found through [index] (up to date): `contents/levels/<name>.lmas`, else the level asset of that name anywhere under `contents/`. Null when there is none. |
| `levelNames` | `static List<String> levelNames(LuminaAssetIndex index)` | The names of the project's levels, from [index] (up to date). |
| `forProjectLevel` | `static Future<List<LuminaAssetRef>?> forProjectLevel(String projectDir, String levelName) async` | Level [levelName] of [projectDir]'s asset list for Play-In-Editor: found and read through the asset index (refreshed first), paths absolute (the editor reads the disk). Null when there is no such level. |
| `toDartLiteral` | `static String toDartLiteral(List<LuminaAssetRef> refs, {String indent = ' '})` | [refs] as the `const` list literal a generated level's `assetManifest` holds. |

### `abstract final class LuminaLevelActorMaterial`

Seviyeye yerleştirilmiş bir mesh'in ya da temel şeklin kendi materyali yerine her bölümde çizdiği materyal: aktörün `materialPath` alanı (Details panelinin Material alanı, `set_actor_property material`). Seviye görünümü, Play-In-Editor ve seviye kod üreticisi (`materialOverrideAsset`) bunu buradan okur.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `actorTypes` | `static const Set<String> actorTypes` | `Mesh`, `StaticMesh`, `SkeletalMesh`, `Primitive`. |
| `pathOf` | `static String? pathOf(Map<String, dynamic> actor)` | Atanmış materyal, paket yolu olarak (`contents/…`); atama yoksa, yerleştirilmiş bir Blueprint için ya da `.lmas` / `.filamat` adı taşımayan bir değer için (eski editörlerin yazdığı yer tutucu adlar) null. |
| `problem` | `static String? problem(String path, {String? projectDir})` | Materyalin neden çizilemediği (bulunamadı, derlenmiş materyal yok) ya da null. Üretici o zaman argüman yerine bir yorum yazar, Play ve görünüm bunu günlüğe yazar, mesh kendi materyalini korur. |
| `revision` | `static String revision(String path, {String? projectDir, Iterable<String> textures = const []})` | Seviye görünümünün materyal için çizdiği: materyal dosyasının ve [textures]'ın (sampler'larının dokuları) her birinin değiştirilme zamanı ve boyutu. Değişince görünüm aktörün materyalini yeniden kurar: yeniden derlenince ya da bir doku kaydedilince, yeniden içe aktarılınca veya ayarı değişince. |

---

[Önceki: Animation Blueprint'ler](blueprint/animation.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: lumina_editor_data (editör veri katmanı)](../lumina_editor_data/index.md)
