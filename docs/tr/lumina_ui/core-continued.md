[English](../../en/lumina_ui/core-continued.md)

# Uygulama kabuğu ve ortak UI (devamı, bölüm 1)

Uygulama kabuğu ve ortak UI sayfasının devamı: `lib/`, `lib/testing/`, `lib/ui/core/`, `lib/ui/core/host/`, `lib/ui/core/property_editors/`, `lib/ui/core/services/`, `lib/ui/core/theme/`, `lib/ui/core/widgets/` altındaki diğer public dosyalar. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/editor_entry.dart`](#libeditor_entrydart)
- [`lib/testing/smoke_artifacts.dart`](#libtestingsmoke_artifactsdart)
- [`lib/ui/core/editor_level_access.dart`](#libuicoreeditor_level_accessdart)
- [`lib/ui/core/host/editor_host.dart`](#libuicorehosteditor_hostdart)
- [`lib/ui/core/property_editors/asset_picker_select.dart`](#libuicoreproperty_editorsasset_picker_selectdart)
- [`lib/ui/core/property_editors/collision_section_editor.dart`](#libuicoreproperty_editorscollision_section_editordart)
- [`lib/ui/core/property_editors/physics_section_editor.dart`](#libuicoreproperty_editorsphysics_section_editordart)
- [`lib/ui/core/property_editors/synced_text_field.dart`](#libuicoreproperty_editorssynced_text_fielddart)
- [`lib/ui/core/services/asset_picker_catalog.dart`](#libuicoreservicesasset_picker_catalogdart)
- [`lib/ui/core/services/content_folders.dart`](#libuicoreservicescontent_foldersdart)
- [`lib/ui/core/services/file_reveal.dart`](#libuicoreservicesfile_revealdart)
- [`lib/ui/core/services/editor_mesh_budget.dart`](#libuicoreserviceseditor_mesh_budgetdart)
- [`lib/ui/core/services/rgba_png_encoder.dart`](#libuicoreservicesrgba_png_encoderdart)
- [`lib/ui/core/services/user_plugin_dir.dart`](#libuicoreservicesuser_plugin_dirdart)
- [`lib/ui/core/theme/asset_type_style.dart`](#libuicorethemeasset_type_styledart)
- [`lib/ui/core/theme/editor_theme_access.dart`](#libuicorethemeeditor_theme_accessdart)
- [`lib/ui/core/theme/editor_theme_data.dart`](#libuicorethemeeditor_theme_datadart)
- [`lib/ui/core/theme/editor_theme_store.dart`](#libuicorethemeeditor_theme_storedart)
- [`lib/ui/core/widgets/editor_context_menu.dart`](#libuicorewidgetseditor_context_menudart)

## `lib/editor_entry.dart`

### `class LuminaStudioApp`

**Yapıcı Metotlar (Constructors):**

- `const LuminaStudioApp({super.key})`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `appThemeModeNotifier` | `final ValueNotifier<ThemeMode> appThemeModeNotifier` |  |
| `runLuminaEditor` | `Future<void> runLuminaEditor(List<String> args, {List<LuminaEditorPlugin> plugins = const [], EditorHostInfo?...` |  |

## `lib/testing/smoke_artifacts.dart`

### `abstract final class SmokeArtifacts`

The smoke-test artifact API of Lumina Studio's tests: lumina_smoke's `SmokeArtifacts` (every member forwards to it, so both share one state: the artifact directory, the recorded assets) plus the widget and integration-test captures of lumina_smoke's `SmokeCapture`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `captureWidgetPng` | `static Future<Uint8List> captureWidgetPng(WidgetTester tester, Finder repaintBoundary)` | A widget wrapped in a `RepaintBoundary`, captured as PNG in a widget test. |
| `captureIntegrationPng` | `static Future<Uint8List> captureIntegrationPng(IntegrationTestWidgetsFlutterBinding binding, WidgetTester test...` | A frame of an integration test: [boundary] (or the first `RepaintBoundary`), else the binding's own screenshot. |
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

## `lib/ui/core/editor_level_access.dart`

### `class EditorViewModelLevelAccess`

The open level as plugins see it: a thin adapter over [EditorViewModel] that hands out immutable snapshots and routes every edit through the view model's transaction / dirty-flag path, so a plugin's Generate is one undo entry like a hand-placed actor.

**Yapıcı Metotlar (Constructors):**

- `EditorViewModelLevelAccess(this.viewModel)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `runTransaction` | `Future<T> runTransaction<T>(String label, Future<T> Function() body)` | Every level edit [body] makes is one undo step. |
| `snapshotOf` | `static EditorActorSnapshot snapshotOf(EditorActorNode node)` | The immutable view of [node] a plugin gets. |

## `lib/ui/core/host/editor_host.dart`

### `class EditorHostInfo`

Which editor binary is running. A project editor host (`<project>/.lumina/editor/`, generated by `EditorHostGeneratorService`) passes one to `runLuminaEditor`; the stock editor — the launcher — has none.

**Yapıcı Metotlar (Constructors):**

- `const EditorHostInfo({required this.packageName, required this.engineRoot})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `packageName` | `final String packageName` | The host package's name, also its binary's name. |
| `engineRoot` | `final String engineRoot` | The workspace root the host was generated against (holds `lumina_ui/`). |

### `class EditorLaunchArgs`

Editörün komut satırı: `--project <path>`, `--rebuild`, `--no-plugins`, `--launcher-exe <path>`, `--update-editor`.

**Yapıcı Metotlar (Constructors):**

- `const EditorLaunchArgs({this.project, this.rebuild = false, this.noPlugins = false, this.launcherExe, this.updateEditor = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `project` | `final String? project` |  |
| `rebuild` | `final bool rebuild` |  |
| `noPlugins` | `final bool noPlugins` |  |
| `launcherExe` | `final String? launcherExe` |  |
| `updateEditor` | `final bool updateEditor` | Kullanıcı projenin editörünü bu Studio'nun motoruna güncellemeyi zaten seçti (proje editörü devretti): yeniden sormadan günceller. |
| `parse` | `static EditorLaunchArgs parse(List<String> args)` |  |

### `class LuminaEditorHost`

Process-wide state of the running editor: its host, arguments and the code plugins compiled into it. Set once by `runLuminaEditor`; tests set [plugins] to boot an editor with a plugin.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `info` | `static EditorHostInfo? info` |  |
| `args` | `static EditorLaunchArgs args` |  |
| `plugins` | `static List<LuminaEditorPlugin> plugins` | The code plugins compiled into this binary (the host's registrar). |
| `compiledFingerprint` | `static const String compiledFingerprint` | The fingerprint this project editor was built with (`--dart-define=LUMINA_EDITOR_FINGERPRINT=…` from the build service). |
| `isProjectEditor` | `static bool get isProjectEditor` | Whether this is a project editor rather than the stock editor. |
| `engineRoot` | `static String get engineRoot` | The workspace root: the host's, else the resolved workspace — never the working directory, which a project editor does not share with the engine. |
| `uiRoot` | `static String get uiRoot` | `<engineRoot>/lumina_ui`. |
| `launcherExecutable` | `static String? launcherExecutable()` | The stock editor's executable, the launcher a project editor hands off to: `--launcher-exe`, else this binary when it is the stock editor, else the newest build under `<engineRoot>/lumina_ui/build`. |
| `findStockEditor` | `static String? findStockEditor(String engineRoot, {String? operatingSystem})` |  |

### `class EditorAssets`

lumina_ui's own assets, wherever it runs: as the app its keys are `assets/…` and `skills/…`; as a project editor host's dependency Flutter bundles them as `packages/lumina_ui/assets/…`. The editor keeps writing the unprefixed key, and this bundle — installed as the app's [DefaultAssetBundle] and used for direct loads — maps it.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `packagePrefix` | `static const String packagePrefix` |  |
| `packaged` | `static bool packaged` | Whether keys need [packagePrefix]; set by [configure]. |
| `bundle` | `static final AssetBundle bundle` |  |
| `ownFolders` | `static const List<String> ownFolders` | The top folders of lumina_ui's own assets (pubspec `flutter: assets:`). |
| `key` | `static String key(String path)` | The bundle key of lumina_ui asset [path] (`assets/…`, `skills/…`). |
| `load` | `static Future<ByteData> load(String path)` |  |
| `configure` | `static Future<void> configure() async` | Detects the packaged layout from the asset manifest and, when packaged, registers lumina_ui's bundled fonts under their unqualified family names (a dependency's fonts are otherwise `packages/lumina_ui/<Family>`). |

### `class EditorHandOff`

Starts another editor binary and quits this one: the launcher execs a project editor, a project editor hands back to the launcher. Tests replace [instance] to observe the hand-off instead of exiting.

**Yapıcı Metotlar (Constructors):**

- `const EditorHandOff({required this.startDetached, required this.exitApp})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `startDetached` | `final Future<void> Function(String executable, List<String> arguments) startDetached` |  |
| `exitApp` | `final void Function(int code) exitApp` |  |
| `instance` | `static EditorHandOff instance` |  |
| `restartExitCode` | `static const int restartExitCode` | The exit code the dev launcher script / `flutter run` wrapper treats as "rebuild and restart" when there is no launcher to hand off to. |
| `beforeExit` | `static final List<Future<void> Function()> beforeExit` | Run before this process exits through a hand-off (the editor's plugins shut down: `onEditorShutdown`, child processes). |
| `execProjectEditor` | `Future<void> execProjectEditor(String executable, String projectDir) async` | Execs the project editor [executable] for [projectDir] and quits. |
| `restartThroughLauncher` | `Future<bool> restartThroughLauncher(String projectDir, {bool rebuild = false, bool updateEditor = false, String? launcher}) async` | Launcher'ı ([launcher], yoksa [LuminaEditorHost.launcherExecutable]) [projectDir] ile yeniden başlatır (çözümler, eskiyse derler ve açar) ve çıkar; launcher yoksa [restartExitCode] ile çıkar. [updateEditor] `--update-editor` geçirir: launcher projenin editörünü sormadan kendi motoruna günceller. Launcher başlatıldıysa true döner. |
| `returnToLauncher` | `Future<bool> returnToLauncher({String? launcher}) async` | Launcher'ı ([launcher], yoksa [LuminaEditorHost.launcherExecutable]) proje listesiyle başlatır ve çıkar; yoksa yalnızca çıkar. Launcher başlatıldıysa true döner. |

## `lib/ui/core/property_editors/asset_picker_select.dart`

### `class AssetPickerScope`

What the editor lends every [AssetPickerSelect] below it: the asset list's change notifications and freshest copy (thumbnails land in the background), on-demand thumbnail generation, and "Browse to asset" in the Content Browser. The main editor provides it; a picker outside it still searches and shows the thumbnails its assets carry.

**Yapıcı Metotlar (Constructors):**

- `const AssetPickerScope({super.key, required super.child, this.changes, this.latest, this.requestThumbnail, this.browse,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `changes` | `final Listenable? changes` | Fires when assets (and their thumbnails) change. |
| `latest` | `final RealAssetInfo Function(RealAssetInfo asset)? latest` | The current copy of an asset (with a thumbnail rendered since the list was built); the asset itself when unknown. |
| `requestThumbnail` | `final void Function(RealAssetInfo asset)? requestThumbnail` | Queues a thumbnail for an asset that has none. |
| `browse` | `final void Function(RealAssetInfo asset)? browse` | Selects an asset in the Content Browser. |
| `maybeOf` | `static AssetPickerScope? maybeOf(BuildContext context)` |  |

### `class AssetPickerOption`

A fixed choice a picker lists above its assets ("Auto" / "None" entries), e.g. the import dialog's "Auto (match bone names)".

**Yapıcı Metotlar (Constructors):**

- `const AssetPickerOption({required this.id, required this.label, this.icon = LucideIcons.circleDot})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `label` | `final String label` |  |
| `icon` | `final IconData icon` |  |

### `class AssetThumbnail`

An asset's thumbnail, rounded: its PNG when it has one, otherwise its type icon (also while a thumbnail is being generated). Like a Content Browser tile it carries its asset type's strip along the bottom edge; an empty slot has none.

**Yapıcı Metotlar (Constructors):**

- `const AssetThumbnail({super.key, required this.asset, this.size = 24})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `asset` | `final RealAssetInfo? asset` |  |
| `size` | `final double size` |  |
| `stripHeight` | `double get stripHeight` | The type strip's height at this size. |
| `bytes` | `Uint8List? get bytes` | The PNG shown, or null for the icon. |

### `class AssetPickerSelect`

The shared asset picker: the closed control shows the selected asset's thumbnail and name (or [placeholder]); a click opens a popup with a search field (name, folder and type, as you type, matches highlighted), `Recently used`, then every asset as a thumbnail row with its folder, in a lazy list. Up/Down move, Enter picks the highlighted (first) match, Escape closes. [onCleared] adds the `— clear —` row; "Browse to asset" (row context menu and the icon beside the control) selects the asset in the Content Browser.

[selectedPath] may be an absolute `.lmas` path, a project-relative path or a stored path that no longer exists (shown in red as missing).

**Yapıcı Metotlar (Constructors):**

- `const AssetPickerSelect({super.key, required this.assets, required this.selectedPath, required this.onSelected, this.onCleared, this.placeholder = 'None', this....`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `assets` | `final List<RealAssetInfo> assets` | The assets offered (narrowed by [typeFilter] when given). |
| `selectedPath` | `final String? selectedPath` | The picked asset's stored path, or null. |
| `onSelected` | `final void Function(RealAssetInfo asset) onSelected` |  |
| `onCleared` | `final VoidCallback? onCleared` | Clears the value; the `— clear —` row shows when this is set and [allowClear] is on. |
| `placeholder` | `final String placeholder` | Shown in the closed control when nothing is picked. |
| `typeFilter` | `final Set<AssetType>? typeFilter` |  |
| `labelOf` | `final String Function(RealAssetInfo asset)? labelOf` | How an asset is named; its file name without `.lmas` by default. |
| `thumbnailSize` | `final double thumbnailSize` | Row thumbnail size in the popup. |
| `valueThumbnailSize` | `final double? valueThumbnailSize` | Thumbnail size in the closed control (defaults to [thumbnailSize]). |
| `allowClear` | `final bool allowClear` |  |
| `clearLabel` | `final String clearLabel` |  |
| `onBrowse` | `final void Function(RealAssetInfo asset)? onBrowse` | "Browse to asset"; defaults to the [AssetPickerScope]'s. |
| `keyPrefix` | `final String keyPrefix` | Prefix of the popup's keys: `<prefix>_search`, `<prefix>_clear`, `<prefix>_item_<file name>`, `<prefix>_recent_<file name>`, `<prefix>_browse`, `<prefix>_value`. |
| `recents` | `final AssetPickerRecents? recents` | Where `Recently used` is kept; the editor preferences file by default. |
| `enabled` | `final bool enabled` |  |
| `expand` | `final bool expand` | Whether the closed control fills the available width. |
| `options` | `final List<AssetPickerOption> options` | Fixed choices listed above the assets (keys `<prefix>_option_<id>`). |
| `selectedOption` | `final String? selectedOption` | The [options] entry currently chosen (shown in the closed control), if the value is not an asset. |
| `onOption` | `final void Function(String id)? onOption` |  |

### `class AssetPickerPopup`

The popup of [AssetPickerSelect]: search row, `— clear —`, `Recently used`, and the lazy list of matches.

**Yapıcı Metotlar (Constructors):**

- `const AssetPickerPopup({super.key, required this.assets, required this.selectedPath, required this.onSelected, required this.recents, this.typeFilter, this.onCl...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `assets` | `final List<RealAssetInfo> assets` |  |
| `typeFilter` | `final Set<AssetType>? typeFilter` |  |
| `selectedPath` | `final String? selectedPath` |  |
| `onSelected` | `final void Function(RealAssetInfo asset) onSelected` |  |
| `onCleared` | `final VoidCallback? onCleared` |  |
| `onBrowse` | `final void Function(RealAssetInfo asset)? onBrowse` |  |
| `labelOf` | `final String Function(RealAssetInfo asset)? labelOf` |  |
| `thumbnailSize` | `final double thumbnailSize` |  |
| `width` | `final double width` |  |
| `keyPrefix` | `final String keyPrefix` |  |
| `clearLabel` | `final String clearLabel` |  |
| `recents` | `final AssetPickerRecents recents` |  |
| `scope` | `final AssetPickerScope? scope` |  |
| `options` | `final List<AssetPickerOption> options` |  |
| `selectedOption` | `final String? selectedOption` |  |
| `onOption` | `final void Function(String id)? onOption` |  |
| `onClose` | `final VoidCallback? onClose` | Closes the popup (Escape). |
| `rowExtent` | `static const double rowExtent` | Height of one asset row. |
| `maxListHeight` | `static const double maxListHeight` | Height of the list before it scrolls. |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kRenderedThumbnailTypes` | `const Set<AssetType> kRenderedThumbnailTypes` | The asset types whose thumbnail is a render or the image itself; the rest (animations, Blueprints, levels…) show their type icon. |
| `assetTypeIcon` | `IconData assetTypeIcon(AssetType type)` | The icon an asset type is drawn with when it has no thumbnail ([AssetTypeStyle]). |

## `lib/ui/core/property_editors/collision_section_editor.dart`

### `abstract final class CollisionJson`

The editor's reading and writing of lumina's collision JSON: `{'preset', 'objectType', 'responses': {'worldStatic': 'block', …}, 'generateOverlapEvents', 'collisionEnabled'}` — the keys a collision component carries in a Blueprint document or a placed actor's component properties.

The rules: picking a preset fills object type and the grid from its table; only **Custom** lets the user edit object type, Collision Enabled and the grid, and an edit made there keeps `preset: custom` even when the grid happens to match a table. Generate Overlap Events is independent of the preset.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `keys` | `static const List<String> keys` | The keys this editor writes. |
| `of` | `static Map<String, dynamic> of(Map<String, dynamic> properties)` | The collision keys of [properties] (anything else dropped). |
| `profile` | `static LuminaCollisionProfile profile(Map<String, dynamic> json, {LuminaCollisionProfile? base})` | The profile [json] describes, on top of [base] (the component's built-in setup: a Character's capsule is Pawn, anything else lumina's default Block All Dynamic). |
| `preset` | `static LuminaCollisionPreset preset(Map<String, dynamic> json, {LuminaCollisionProfile? base})` | The preset the section shows: a stored `preset` wins (so Custom sticks), otherwise the table the profile matches. |
| `withPreset` | `static Map<String, dynamic> withPreset(Map<String, dynamic> json, LuminaCollisionPreset preset, {LuminaCollisi...` | [json] with [preset] chosen: its table, keeping Generate Overlap Events (Trigger's table turns it on). Custom keeps the current profile and marks it custom. |
| `withResponse` | `static Map<String, dynamic> withResponse(Map<String, dynamic> json, CollisionObjectType channel, CollisionResp...` | [json] with [channel] answered by [response]; the result is Custom. |
| `withObjectType` | `static Map<String, dynamic> withObjectType(Map<String, dynamic> json, CollisionObjectType type, {LuminaCollisi...` | [json] with object type [type]; the result is Custom. |
| `withCollisionEnabled` | `static Map<String, dynamic> withCollisionEnabled(Map<String, dynamic> json, bool enabled, {LuminaCollisionProf...` | [json] with Collision Enabled [enabled]; the result is Custom. |
| `withGenerateOverlapEvents` | `static Map<String, dynamic> withGenerateOverlapEvents(Map<String, dynamic> json, bool value, {LuminaCollisionP...` | [json] with Generate Overlap Events [value]; the preset stays. |
| `presetLabel` | `static String presetLabel(LuminaCollisionPreset p)` | The preset's display label. |
| `channelLabel` | `static String channelLabel(CollisionObjectType t)` |  |
| `responseLabel` | `static String responseLabel(CollisionResponse r)` |  |
| `parseObjectType` | `static CollisionObjectType? parseObjectType(String? s)` | Parses an object type name as the engine does. |

### `class CollisionSectionEditor`

The Details **Collision** section, shared by the Blueprint editor's component Details and the level Details of a placed actor's collision components: Collision Presets, Collision Enabled, Object Type, the World Static / World Dynamic / Pawn × Ignore / Overlap / Block response grid and Generate Overlap Events.

Stateless over [value] (the component's collision JSON, possibly empty); every edit hands [onChanged] the whole new collision JSON, which the host stores as one undo step. Widget keys start with [keyPrefix].

**Yapıcı Metotlar (Constructors):**

- `const CollisionSectionEditor({super.key, required this.value, required this.onChanged, this.keyPrefix = 'collision', this.base,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `value` | `final Map<String, dynamic> value` |  |
| `onChanged` | `final ValueChanged<Map<String, dynamic>> onChanged` |  |
| `keyPrefix` | `final String keyPrefix` |  |
| `base` | `final LuminaCollisionProfile? base` | The component's setup when [value] lacks a key (a Character's capsule is Pawn). |
| `gridTooltip` | `static const String gridTooltip` |  |

## `lib/ui/core/property_editors/physics_section_editor.dart`

### `abstract final class PhysicsJson`

The editor's reading and writing of a component's `physics` JSON: `{simulate, massKg, overrideMass, centerOfMassOffset, linearDamping, angularDamping, enableGravity, friction, restitution, locks: {position: [x, y, z], rotation: [x, y, z]}}`, vectors and lock axes in authoring space (cm, Z up). `meshPhysics` carries the static mesh's values the component inherits, baked for the generated game.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `key` | `static const String key` | The component property the JSON lives under. |
| `defaultLinearDamping` | `static const double defaultLinearDamping` |  |
| `defaultAngularDamping` | `static const double defaultAngularDamping` |  |
| `of` | `static Map<String, dynamic> of(Map<String, dynamic> props)` | A deep copy of [props]' physics map (empty when it has none). |
| `simulate` | `static bool simulate(Map<String, dynamic> json)` |  |
| `overrideMass` | `static bool overrideMass(Map<String, dynamic> json)` |  |
| `enableGravity` | `static bool enableGravity(Map<String, dynamic> json)` |  |
| `overridesCenterOfMass` | `static bool overridesCenterOfMass(Map<String, dynamic> json)` |  |
| `number` | `static double number(Map<String, dynamic> json, String k, double fallback)` |  |
| `friction` | `static double friction(Map<String, dynamic> json)` |  |
| `restitution` | `static double restitution(Map<String, dynamic> json)` |  |
| `linearDamping` | `static double linearDamping(Map<String, dynamic> json)` |  |
| `angularDamping` | `static double angularDamping(Map<String, dynamic> json)` |  |
| `centerOfMass` | `static List<double> centerOfMass(Map<String, dynamic> json, LuminaMeshPhysics? inherited)` | The authored centre-of-mass offset, else [inherited]'s, else zero. |
| `lock` | `static bool lock(Map<String, dynamic> json, String kind, int axis)` | Lock [kind] (`position` / `rotation`) on authoring [axis] 0–2. |
| `withValue` | `static Map<String, dynamic> withValue(Map<String, dynamic> json, String k, Object? value)` | [json] with [k] set to [value] (null removes it). |
| `withLock` | `static Map<String, dynamic> withLock(Map<String, dynamic> json, String kind, int axis, bool locked)` |  |
| `effectiveMass` | `static double effectiveMass(Map<String, dynamic> json, LuminaMeshPhysics? inherited, double computedMassKg)` | The mass the body gets: the override, the mesh's, else [computedMassKg]. |

### `class PhysicsSectionEditor`

The Details **Physics** section, shared by the Blueprint editor's component Details and the level Details of a placed Blueprint's components: Simulate Physics, Mass (kg) — greyed with the inherited value until Override Mass — Center of Mass, Linear / Angular Damping, Enable Gravity, Friction, Restitution and the position / rotation locks.

Stateless over [value] (the component's physics JSON, possibly empty); every edit hands [onChanged] the whole new JSON, one undo step for the host. [inherited] is the static mesh's physics ([inheritedFrom] names it); [computedMassKg] is the density × volume mass used without either.

**Yapıcı Metotlar (Constructors):**

- `const PhysicsSectionEditor({super.key, required this.value, required this.onChanged, this.keyPrefix = 'physics', this.inherited, this.inheritedFrom, this.comput...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `value` | `final Map<String, dynamic> value` |  |
| `onChanged` | `final ValueChanged<Map<String, dynamic>> onChanged` |  |
| `keyPrefix` | `final String keyPrefix` |  |
| `inherited` | `final LuminaMeshPhysics? inherited` |  |
| `inheritedFrom` | `final String? inheritedFrom` |  |
| `computedMassKg` | `final double computedMassKg` |  |

## `lib/ui/core/property_editors/synced_text_field.dart`

### `class SyncedTextField`

A text field that follows its value when it changes elsewhere (MCP tools, undo, a reload) and keeps what the user is typing while it has focus. Use it instead of `TextField(initialValue: …)` for a field that shows view-model state: `initialValue` is read once.

**Yapıcı Metotlar (Constructors):**

- `const SyncedTextField({super.key, required this.text, this.onChanged, this.onSubmitted, this.placeholder, this.enabled = true})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `text` | `final String text` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onSubmitted` | `final ValueChanged<String>? onSubmitted` |  |
| `placeholder` | `final Widget? placeholder` |  |
| `enabled` | `final bool enabled` |  |

## `lib/ui/core/services/asset_picker_catalog.dart`

### `abstract final class AssetPickerCatalog`

The pure half of the shared asset picker: how an asset is named and where it lives, which assets a query matches and in what order, and which parts of a name to highlight.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `defaultLabel` | `static String defaultLabel(RealAssetInfo asset)` | An asset's display name: its file name without `.lmas`. |
| `folderOf` | `static String folderOf(RealAssetInfo asset)` | The folder an asset sits in (`contents/materials/a.lmas` → `contents/materials`). |
| `matchesPath` | `static bool matchesPath(RealAssetInfo asset, String? path)` | Whether [asset] is the one a picker's stored [path] names: stores keep the absolute `.lmas` path, the project-relative path, or just the name. |
| `find` | `static RealAssetInfo? find(Iterable<RealAssetInfo> assets, String? path)` | The asset [path] names among [assets], or null. |
| `filter` | `static List<RealAssetInfo> filter(Iterable<RealAssetInfo> assets, String query, {String Function(RealAssetInfo...` | [assets] matching [query] (case-insensitive), best first: a name that starts with the query, then a name that contains it, then the folder, then the asset type; a several-word query matches when every word is found in the name, folder or type. Ties keep name order. An empty query keeps every asset, sorted by name. |
| `rank` | `static int? rank(String name, String folder, String type, String q)` | The rank of one asset for lower-case query [q] (0 is best), or null when it does not match. |
| `matchRanges` | `static List<(int, int)> matchRanges(String text, String query)` | The `[start, end)` ranges of [text] that match [query]'s words, case-insensitive and merged, for highlighting a row's name. |

### `class AssetPickerRecents`

The picker's "Recently used" group: the last [limit] assets picked per asset type, kept in the editor preferences file (`editor_preferences.json` in [LuminaConfigDir], next to the flight-camera setting) so they survive a restart.

**Yapıcı Metotlar (Constructors):**

- `AssetPickerRecents({File? file})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fileName` | `static const String fileName` | The editor preferences file (`EditorPreferences.fileName`). |
| `key` | `static const String key` | The key the recents live under in [file]. |
| `limit` | `static const int limit` | How many assets each type remembers. |
| `file` | `final File file` |  |
| `recentPaths` | `List<String> recentPaths(Iterable<AssetType> types)` | The project-relative paths picked last for [types], most recent first (types in the order given), at most [limit]. |
| `record` | `void record(RealAssetInfo asset)` | Remembers [asset] as the most recent pick of its type. |

## `lib/ui/core/services/content_folders.dart`

### `class ContentFolders`

Content folders on disk: the standard folders a new project arrives with, and the keep-marker that lets an empty folder survive git and project copies.

The content browser never lists the marker: assets are `.lmas` files only.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `markerFileName` | `static const String markerFileName` | Marker that keeps an otherwise empty content folder in version control. |
| `projectFolders` | `static const List<String> projectFolders` | Folders every new project gets beyond the ones its template's assets already live in: Widget Blueprints go to `contents/widgets/`, Input Actions and Mapping Contexts to `contents/input/`. |
| `ensureProjectFolders` | `static List<String> ensureProjectFolders(String projectDir)` | Creates [projectFolders] (with markers) under [projectDir]; existing folders and their files are left alone. Returns the folders it created. |
| `writeMarker` | `static void writeMarker(String dirPath)` | Writes the keep-marker into [dirPath] unless it is already there. |
| `parentOf` | `static String parentOf(String relativePath)` | The folder an asset at [relativePath] sits in (`contents/a/b.lmas` → `contents/a`), with separators normalised to `/`. |

## `lib/ui/core/services/file_reveal.dart`

### `abstract final class FileReveal`

"Show in Explorer" (Windows) / "Reveal in Finder" (macOS) / "Show in File Manager" (Linux): platformun dosya yöneticisini bir dosyada (seçili) ya da bir klasörde (açık) açar. Content Browser'ın klasör menüsü (Sources ağacı ve klasör kutucukları), varlık menüsü (varlığın `.lmas` dosyası), varlık seçicinin satır menüsü ve World Outliner'ın aktör menüsü ("Show Asset in Explorer": aktörün mesh ya da Blueprint sınıf dosyası, diskteyse) bunu kullanır.

| Platform | Dosya | Klasör |
| :--- | :--- | :--- |
| Windows | `explorer.exe /select, <dosya>` | `explorer.exe <klasör>` |
| macOS | `open -R <dosya>` | `open <klasör>` |
| Linux | `xdg-open <üst klasör>` | `xdg-open <klasör>` |

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `runner` | `static FileRevealRunner runner` | Komutu başlatır (varsayılan: bağımsız süreç); testler çağrıyı kaydetmek için değiştirir. |
| `menuLabel` | `static String menuLabel({String? subject, String? os})` | Platformun menü etiketi; [subject] gösterileni adlandırır ("Show Asset in Explorer"). |
| `commandFor` | `static FileRevealCommand commandFor(String path, {required bool isDirectory, String? os})` | [os] üzerinde [path] için komut satırı (yukarıdaki tablo). |
| `resolve` | `static String resolve(String projectDir, String path)` | Projeye göreli bir yol (`contents/props`) [projectDir]'e göre çözülür; mutlak yol olduğu gibi kalır. |
| `reveal` | `static Future<bool> reveal(String path, {String? os})` | [path]'i gösterir; diskte yoksa ya da dosya yöneticisi başlatılamazsa false döner. |

## `lib/ui/core/services/editor_mesh_budget.dart`

### `abstract final class EditorMeshBudget`

The editor's texture budget on every mesh the shared engine loads by path — Blueprint previews, PIE, preview worlds — not only on the level viewport's and sub-editors' payloads.

It routes lumina's `LuminaMeshAssetCache.sourceFilter` through `AssetRepository.sanitizedGlbFor`, the same memo and derived-data cache `AssetRepository.loadMeshFromDisk` uses, with the same memo tag. So an 8K-textured `.entity.glb` left by an import from an older build is drawn budgeted everywhere, and a preview world's path-based load gets the very bytes the level viewport holds: one GPU upload for both.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ensureInstalled` | `static void ensureInstalled()` | Installs the filter (idempotent). Called by the editor's viewports before they load anything. |
| `isInstalled` | `static bool get isInstalled` | Whether the editor's filter is the one installed. |

## `lib/ui/core/services/rgba_png_encoder.dart`

### `abstract final class RgbaPngEncoder`

A dependency-free RGBA8/BGRA8 → PNG encoder. The editor's own code uses it (the texture editor's thumbnails), so it lives outside `lib/testing/`, whose flutter_test / integration_test imports a project editor host (where lumina_ui is a dependency) cannot compile.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `encode` | `static Uint8List encode(int w, int h, Uint8List rgba, {bool flipY = false, bool bgra = false,})` | Encodes raw RGBA8/BGRA8 pixel buffer into a valid PNG byte stream. |

## `lib/ui/core/services/user_plugin_dir.dart`

### `abstract final class UserPluginDir`

The per-user plugin install directory the editor scans with the [PluginOrigin.user] origin and the Marketplace installs plugin listings into: `~/.local/share/lumina/plugins`.

Resolved in this order: 1. [override], the in-process redirect a test sets to a temp directory; 2. the `LUMINA_USER_PLUGIN_DIR` environment variable; 3. `$HOME/.local/share/lumina/plugins`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `environmentVariable` | `static const String environmentVariable` |  |
| `override` | `static Directory? override` | In-process redirect, ahead of [environmentVariable]. |
| `resolve` | `static Directory resolve({Map<String, String>? environment})` |  |

### `abstract final class PluginDataDir`

Where plugins keep their per-user data, one folder per plugin: [override], else `LUMINA_PLUGIN_DATA_DIR`, else `$HOME/.local/share/lumina/plugin_data` (beside the user plugin dir).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `environmentVariable` | `static const String environmentVariable` |  |
| `override` | `static Directory? override` | In-process redirect, ahead of [environmentVariable]. |
| `resolve` | `static Directory resolve({Map<String, String>? environment})` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `editorPluginScanRoots` | `List<PluginScanRoot> editorPluginScanRoots(String projectDir)` | Where the editor looks for plugins: the built-ins, the plugin packages the engine workspace resolved (`LuminaWorkspace.pluginPackageDirs(<engineRoot>)`, a `PluginScanRoot.packages` root), plus an engine `plugins/` folder when there is one (`LUMINA_ENGINE_ROOT`, else `<engineRoot>/plugins` — never relative to the working directory, which a project editor does not share with the engine); the project's `plugins/`; and the per-user [UserPluginDir]. The launcher's project editor resolver scans the same roots as the editor. |

## `lib/ui/core/theme/asset_type_style.dart`

### `class AssetTypeStyle`

How the editor shows an asset kind: its colour (an [EditorColors] token, so a theme slot), the human-readable type name the Content Browser writes under a tile's name, the short label of its filter chip, and the icon drawn when there is no thumbnail.

Every place that shows an asset type reads it from here: the grid tile's strip and label, the tile tooltip, the filter chips, the delete / new-asset dialogs and the asset pickers' thumbnails.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `color` | `final Color color` | The type colour: an [EditorColors] token that resolves through the active theme (compare with `toARGB32()`, not `==`). |
| `displayName` | `final String displayName` | The asset-class name: "Animation Sequence", "Skeletal Mesh", …. |
| `filterLabel` | `final String filterLabel` | The filter chip's label. |
| `icon` | `final IconData icon` |  |
| `of` | `static AssetTypeStyle of(AssetType type)` |  |

### `class AssetTypeStrip`

The thin line in an asset type's colour along the bottom edge of a thumbnail. Folders have none.

**Yapıcı Metotlar (Constructors):**

- `const AssetTypeStrip({super.key, required this.type, this.height = 3})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `type` | `final AssetType type` |  |
| `height` | `final double height` |  |

### `class AssetTypeSwatch`

A small rounded square in an asset type's colour (tooltips, filter chips).

**Yapıcı Metotlar (Constructors):**

- `const AssetTypeSwatch({super.key, required this.type, this.size = 8})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `type` | `final AssetType type` |  |
| `size` | `final double size` |  |

## `lib/ui/core/theme/editor_theme_access.dart`

### `class HostEditorThemeAccess`

The host's side of `EditorThemeAccess`: plugins read the active editor theme through it and are notified when it changes. Read-only — a plugin cannot switch or edit the theme.

**Yapıcı Metotlar (Constructors):**

- `const HostEditorThemeAccess()`

## `lib/ui/core/theme/editor_theme_data.dart`

### `class EditorThemeToken`

One colour slot of the editor theme: its JSON key, the group the Appearance page files it under, and a line saying what it paints.

**Yapıcı Metotlar (Constructors):**

- `const EditorThemeToken(this.key, this.group, this.description)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `key` | `final String key` |  |
| `group` | `final String group` |  |
| `description` | `final String description` |  |

### `class EditorThemeData`

An editor theme — every colour the editor paints, plus its corner radius, density and fonts — as a JSON document the user can switch, edit, import and export:

Colours are CSS hex, `#RRGGBB` or `#RRGGBBAA`. A token that is missing takes the default theme's value; one that does not parse does too, and is reported in [warnings] so the Appearance page can say which.

**Yapıcı Metotlar (Constructors):**

- `const EditorThemeData({required this.name, required this.brightness, required this.colors, this.radius = defaultRadius, this.density = 1.0, this.sansFamily = de...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `static const int version` |  |
| `defaultRadius` | `static const double defaultRadius` |  |
| `defaultSans` | `static const String defaultSans` |  |
| `defaultMono` | `static const String defaultMono` |  |
| `sansFamilies` | `static const List<String> sansFamilies` | The fonts the editor bundles (shadcn_flutter's Geist family and JetBrains Mono under `assets/fonts/`); a theme may pick among these. |
| `monoFamilies` | `static const List<String> monoFamilies` |  |
| `minDensity` | `static const double minDensity` | Density is shadcn_flutter's `ThemeData.scaling`: < 1 is compact. |
| `maxDensity` | `static const double maxDensity` |  |
| `minRadius` | `static const double minRadius` |  |
| `maxRadius` | `static const double maxRadius` |  |
| `name` | `final String name` |  |
| `brightness` | `final Brightness brightness` |  |
| `colors` | `final Map<String, Color> colors` | Every token in [tokens], always complete. |
| `radius` | `final double radius` |  |
| `density` | `final double density` |  |
| `sansFamily` | `final String sansFamily` |  |
| `monoFamily` | `final String monoFamily` |  |
| `warnings` | `final List<String> warnings` | What was wrong with the JSON this came from (a colour that did not parse, an out-of-range radius, …) and which default replaced it. |
| `color` | `Color color(String token)` |  |
| `surfaces` | `static const String surfaces` |  |
| `text` | `static const String text` |  |
| `accents` | `static const String accents` |  |
| `status` | `static const String status` |  |
| `graph` | `static const String graph` |  |
| `charts` | `static const String charts` |  |
| `assetTypes` | `static const String assetTypes` |  |
| `groups` | `static const List<String> groups` |  |
| `tokens` | `static const List<EditorThemeToken> tokens` | The theme's colour slots, in the order they are written. |
| `tokenKeys` | `static final Set<String> tokenKeys` |  |
| `luminaDark` | `static final EditorThemeData luminaDark` | The lifted grey ramp — the default. |
| `luminaClassic` | `static final EditorThemeData luminaClassic` | The Figma Make prototype's near-black palette, as the editor looked before the lifted grey ramp. |
| `luminaLight` | `static final EditorThemeData luminaLight` | A light counterpart: the same accents on a hueless light ramp. |
| `builtIns` | `static final List<EditorThemeData> builtIns` |  |
| `isBuiltInName` | `static bool isBuiltInName(String name)` |  |
| `formatColor` | `static String formatColor(Color c)` |  |
| `parseColor` | `static Color? parseColor(Object? value)` | `#RRGGBB` / `#RRGGBBAA` (CSS order), or null. |
| `toJson` | `Map<String, Object> toJson()` |  |
| `encode` | `String encode()` | The canonical text of this theme: two-space indent, tokens in [tokens] order, a trailing newline. Parsing it and encoding again gives the same bytes. |
| `fromJson` | `static EditorThemeData fromJson(Object? json, {EditorThemeData? fallback, String? fallbackName})` | Reads a theme; every invalid or missing value falls back to [fallback] (Lumina Dark by default), invalid ones with a warning. |
| `decode` | `static EditorThemeData decode(String source, {EditorThemeData? fallback, String? fallbackName})` | Parses [source]; text that is not JSON gives the fallback with a warning. |
| `copyWith` | `EditorThemeData copyWith({String? name, Brightness? brightness, Map<String, Color>? colors, double? radius, do...` |  |
| `withColor` | `EditorThemeData withColor(String token, Color value)` | This theme with [token] set to [value]. |

## `lib/ui/core/theme/editor_theme_store.dart`

### `abstract final class EditorTheme`

The theme every [EditorThemeColor] — so every `EditorColors` token — resolves through. [apply] swaps it and refreshes the whole running editor without a restart.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `listenable` | `static ValueListenable<EditorThemeData> get listenable` | The active theme; notifies when [apply] swaps it. |
| `current` | `static EditorThemeData get current` |  |
| `apply` | `static void apply(EditorThemeData theme)` | Makes [theme] the active one. Every `EditorColors` token reads it from the next paint on; widgets that baked a colour into a const subtree or a laid-out paragraph are rebuilt, repainted and re-laid out here. |
| `refreshAll` | `static void refreshAll()` | Rebuilds every element, repaints every render object and re-lays out all text (a paragraph keeps the colours it was built with, so the same "fonts changed" broadcast the engine sends is replayed to discard them). |
| `resetForTest` | `static void resetForTest()` | Back to Lumina Dark without touching any file (tests). |

### `class EditorThemeColor`

A `const` colour whose value is the active theme's [token]. The `int` is the default theme's value, used only if the active theme somehow lacks the token.

`dart:ui` reads a colour through its `a`/`r`/`g`/`b`/`colorSpace` getters (painting, text styles, `withValues`), so overriding them makes every `EditorColors` token — including the ones inside `const` widgets — follow the theme from the next paint on.

**Yapıcı Metotlar (Constructors):**

- `const EditorThemeColor(this.token, super.value)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `token` | `final String token` |  |

### `class EditorThemeStore`

Where themes live: the three built-ins in code, the user's own as `<name>.json` files in `themes/` under [LuminaConfigDir], and the active theme's name in `editor_preferences.json` (`"theme"`).

**Yapıcı Metotlar (Constructors):**

- `EditorThemeStore({Directory? configDir})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `configDir` | `final Directory configDir` |  |
| `preferencesFile` | `static const String preferencesFile` |  |
| `preferenceKey` | `static const String preferenceKey` |  |
| `themesDir` | `Directory get themesDir` |  |
| `fileFor` | `File fileFor(String name)` | The file a user theme called [name] is kept in. |
| `slug` | `static String slug(String name)` |  |
| `loadUserThemes` | `List<EditorThemeData> loadUserThemes()` | The user's themes on disk, by name (a file that does not parse still loads, with the defaults and a warning). |
| `writeUserTheme` | `void writeUserTheme(EditorThemeData theme)` |  |
| `deleteUserTheme` | `void deleteUserTheme(String name)` |  |
| `readActiveName` | `String? readActiveName()` |  |
| `writeActiveName` | `void writeActiveName(String name)` |  |

### `class EditorThemeController`

The Appearance page's model: the theme list, the active theme, and the operations on user themes. Activating a theme applies it at once ([EditorTheme.apply]) and remembers it for the next start.

**Yapıcı Metotlar (Constructors):**

- `EditorThemeController({EditorThemeStore? store})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `instance` | `static EditorThemeController get instance` | The app's controller (config dir from [LuminaConfigDir]). |
| `instance` | `static set instance(EditorThemeController value)` |  |
| `store` | `final EditorThemeStore store` |  |
| `themes` | `List<EditorThemeData> get themes` |  |
| `userThemes` | `List<EditorThemeData> get userThemes` |  |
| `activeName` | `String get activeName` |  |
| `active` | `EditorThemeData get active` |  |
| `byName` | `EditorThemeData? byName(String name)` |  |
| `isBuiltIn` | `bool isBuiltIn(String name)` |  |
| `reload` | `void reload()` | Re-reads the config dir and applies the remembered theme. |
| `activate` | `void activate(String name)` |  |
| `uniqueName` | `String uniqueName(String base)` | A name no theme has yet: [base], then "[base] 2", "[base] 3", … |
| `duplicate` | `EditorThemeData duplicate(String name, {String? newName})` | A user copy of [name], saved to disk. |
| `save` | `void save(EditorThemeData theme)` | Saves a user theme; if it is the active one, applies it again. |
| `rename` | `bool rename(String name, String newName)` |  |
| `delete` | `bool delete(String name)` |  |
| `importFile` | `EditorThemeData importFile(File file)` | Imports a `.json` theme: it joins the list under its own name (made unique), with any warnings its tokens raised. |
| `exportTo` | `void exportTo(String name, File file)` | Writes [name]'s canonical JSON to [file]. |

### `class EditorThemeScope`

Puts the [EditorThemeController] above `ShadcnApp`: what builds the app depends on it, so activating a theme rebuilds the shadcn theme too; the Appearance page finds its controller here.

**Yapıcı Metotlar (Constructors):**

- `const EditorThemeScope({super.key, required EditorThemeController controller, required super.child})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `of` | `static EditorThemeController of(BuildContext context)` | The controller in scope, or the app's [EditorThemeController.instance]. |

## `lib/ui/core/widgets/editor_context_menu.dart`

### `class EditorContextMenu`

A right-click menu over [child], used instead of shadcn's `ContextMenu`.

shadcn's `ContextMenu` opens on `onSecondaryTapDown`, which Flutter calls for every tap recognizer under the pointer once the press timeout passes, before the gesture arena picks a winner — so nested menus (an asset tile inside the content browser's background) opened both menus stacked on top of each other.

This widget listens to raw pointer events instead, outside the gesture arena: pointer events reach the innermost listener first, and the first [EditorContextMenu] to see a right-button press claims that pointer, so outer menus ignore it. The claiming menu opens on release, at the release point. Gesture detectors inside [child] (a tile's own `onSecondaryTap` selecting it) keep working, because nothing here enters the arena.

**Yapıcı Metotlar (Constructors):**

- `const EditorContextMenu({super.key, required this.child, required this.items, this.enabled = true, this.behavior = HitTestBehavior.translucent,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `child` | `final Widget child` |  |
| `items` | `final List<MenuItem> items` |  |
| `enabled` | `final bool enabled` |  |
| `behavior` | `final HitTestBehavior behavior` |  |
| `show` | `static void show(BuildContext context, Offset globalPosition, List<MenuItem> items)` | Opens [items] with the menu's top-left corner at [globalPosition]. |

---

[Önceki: Uygulama kabuğu ve ortak UI](core.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Uygulama kabuğu ve ortak UI (devamı, bölüm 2)](core-continued-2.md)
