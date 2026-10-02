[English](../../en/lumina/data-services-continued-2.md)

# Veri katmanı: use case'ler ve servisler (devamı, bölüm 2)

Veri katmanı: use case'ler ve servisler sayfasının devamı: `lib/data/services/` altındaki diğer public dosyalar. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/data/services/editor_build_service.dart`](#libdataserviceseditor_build_servicedart)
- [`lib/data/services/editor_host_generator_service.dart`](#libdataserviceseditor_host_generator_servicedart)
- [`lib/data/services/editor_source_vendor_service.dart`](#libdataserviceseditor_source_vendor_servicedart)
- [`lib/data/services/encoded_image_decoder.dart`](#libdataservicesencoded_image_decoderdart)
- [`lib/data/services/encoded_image_format.dart`](#libdataservicesencoded_image_formatdart)
- [`lib/data/services/engine_bootstrap.dart`](#libdataservicesengine_bootstrapdart)
- [`lib/data/services/engine_identity.dart`](#libdataservicesengine_identitydart)
- [`lib/data/services/fbx_import_service.dart`](#libdataservicesfbx_import_servicedart)
- [`lib/data/services/fbx_material_mapper.dart`](#libdataservicesfbx_material_mapperdart)
- [`lib/data/services/fbx_texture_locator.dart`](#libdataservicesfbx_texture_locatordart)
- [`lib/data/services/filament_thumbnail_renderer.dart`](#libdataservicesfilament_thumbnail_rendererdart)
- [`lib/data/services/generated_code_migration.dart`](#libdataservicesgenerated_code_migrationdart)

## `lib/data/services/editor_build_service.dart`

### `enum EditorBuildPhase`

The phases of a project editor build, with their share of the bar.

**Değerler:**

- `copyingSource`: The engine source into the project, once.
- `generatingHost`
- `resolvingPackages`
- `buildingNativeAssets`
- `compilingDart`
- `linking`
- `installing`

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildPhase(this.weight, this.label)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `weight` | `final int weight` | Percent of the whole build (the weights sum to 100). |
| `label` | `final String label` |  |
| `overall` | `double overall(double inPhase)` | The overall fraction when this phase is [inPhase] done. |

### `class EditorBuildProgress`

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildProgress(this.phase, this.fraction, this.message, {this.logLine})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `phase` | `final EditorBuildPhase phase` |  |
| `fraction` | `final double fraction` | Overall 0–1, monotonic non-decreasing over a build. |
| `message` | `final String message` |  |
| `logLine` | `final String? logLine` |  |

### `sealed class EditorBuildOutcome`

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildOutcome()`

### `class EditorBuildSucceeded`

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildSucceeded(this.entry, this.logPath, this.elapsed)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `entry` | `final EditorBuildEntry entry` |  |
| `logPath` | `final String? logPath` |  |
| `elapsed` | `final Duration elapsed` | The whole build, from generation to install (zero on a cache hit). |

### `class EditorBuildFailed`

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildFailed(this.message, this.lastLines, this.logPath)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `message` | `final String message` |  |
| `lastLines` | `final List<String> lastLines` | The last [EditorBuildService.failureTailLines] lines of the log. |
| `logPath` | `final String? logPath` |  |

### `class EditorBuildCancelled`

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildCancelled(this.logPath)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `logPath` | `final String? logPath` |  |

### `typedef EditorBuildProcessStarter`

Starts a child process; the same shape as the cook step's starter, so a test replays recorded output through it.

### `class EditorBuildJob`

One running build. [progress] is a broadcast stream; [result] completes once, with the outcome.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `progress` | `final Stream<EditorBuildProgress> progress` |  |
| `result` | `final Future<EditorBuildOutcome> result` |  |
| `cancel` | `void cancel()` |  |
| `logPath` | `String? get logPath` | `<cache>/<hash>.log`, once the hash is known (after `pub get`). |

### `class EditorBuildProgressParser`

Maps `flutter build <platform> -v` output to phases and in-phase fractions. Only counts the output carries move the bar: - native assets: completed build hooks (`output.json contents:` after a hook's "Running (cd package…" line) against [hookPackages]; - compiling: the flutter_assemble targets the tool reports complete (kernel snapshot, AOT snapshot, bundle assets); - linking: MSBuild's finished projects against the [linkTargets] of the generated solution, or CMake/ninja's `[n/m]` steps. A line without a count leaves the bar where it is.

The tool runs the hooks and the kernel compile in parallel; the bar stays in the native-assets phase until the last hook is done (a compile milestone seen meanwhile is applied when the phase is entered).

**Yapıcı Metotlar (Constructors):**

- `EditorBuildProgressParser({required this.hookPackages, this.linkTargets})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hookPackages` | `final int hookPackages` | How many packages in the host's package graph have a `hook/build.dart`. |
| `linkTargets` | `final int Function()? linkTargets` | How many projects MSBuild builds (the top-level `.sln`'s projects), read when linking starts; null or 0 when unknown (non-Windows). |
| `phase` | `EditorBuildPhase phase` |  |
| `inPhase` | `double inPhase` |  |
| `message` | `String message` |  |
| `feed` | `bool feed(String line)` | Feeds one line; returns true when the phase or fraction moved. |
| `overall` | `double get overall` |  |
| `msBuildProjects` | `static int msBuildProjects(String buildDir)` | Projects in the generated Visual Studio solution of [hostDir]'s build. |

### `class EditorBuildService`

Generates, resolves, builds and installs a project editor: **generate → pub get → flutter build → install**, as a stream of [EditorBuildProgress] and one [EditorBuildOutcome]. The full log goes to `<cache>/<hash>.log`.

**Yapıcı Metotlar (Constructors):**

- `EditorBuildService({required this.engineRoot, EditorBuildCache? cache, EditorHostGeneratorService? generator, EditorSourceVendorService? vendor, String? flutter...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` |  |
| `cache` | `final EditorBuildCache cache` |  |
| `generator` | `final EditorHostGeneratorService generator` |  |
| `vendor` | `final EditorSourceVendorService vendor` | Copies the engine source into the project before the first build. |
| `flutterExecutable` | `final String flutterExecutable` |  |
| `flutterInfo` | `final Future<FlutterToolInfo> Function() flutterInfo` |  |
| `mode` | `final String mode` | `release` (default) or `debug`. |
| `platform` | `final String platform` | `windows`, `linux` or `macos`. |
| `environment` | `final Map<String, String>? environment` | Extra environment for the child processes (the smoke run redirects the caches with it). |
| `cleanHostAfterInstall` | `final bool cleanHostAfterInstall` | Whether to delete the host's `.dart_tool/` and `build/` after install (only the bundle is cached). |
| `hostAliasRoot` | `final Directory? hostAliasRoot` | Windows: where the space-free build aliases of project hosts live Defaults to `%LOCALAPPDATA%\lumina\hosts`. |
| `failureTailLines` | `static const int failureTailLines` |  |
| `buildDirOf` | `String buildDirOf(String hostDir)` | [hostDir] için `pub get` ve `flutter build` komutlarının çalıştığı yer: host'un kendisi, Windows'ta ise boşluksuz bir kök altında ona giden bir junction (bkz. [SpaceFreeBuildDir]). Dosyalar projede kalır. |
| `bundleDirOf` | `String bundleDirOf(String hostDir)` | `build/<platform>/…` holding the runnable bundle, relative to the host. |
| `executableIn` | `String executableIn(String packageName)` | The executable inside the bundle. |
| `countHookPackages` | `static int countHookPackages(String hostDir)` | Packages in the host's package graph that have a `hook/build.dart` (from `.dart_tool/package_config.json`). |
| `start` | `EditorBuildJob start(String projectDir, List<LuminaPluginDescriptor> plugins, {String? projectName, bool syncSource = false, FutureOr<void> Function()? onSourceSynced})` | [projectDir] projesinin editörünü derler. [syncSource], kopya zaten varsa bile önce projenin motor kaynağı kopyasını değiştirir (çalışan motora güncelleme; kopyalama aşaması "Updating editor source" yazar); [onSourceSynced] yeni kopya yerine geçince çalışır. |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `defaultEditorBuildProcessStarter` | `Future<Process> defaultEditorBuildProcessStarter(String executable, List<String> arguments, {String? workingDi...` |  |
| `killProcessTree` | `Future<void> killProcessTree(int pid) async` | Kills [pid] and its children (`flutter` is a script that runs the tool, which runs MSBuild/CMake/ninja and the hooks). |

## `lib/data/services/space_free_build_dir.dart`

### `abstract final class SpaceFreeBuildDir`

Windows'ta bir klasör için `flutter pub get` / `flutter build` komutlarının çalıştığı yer: boşluksuz bir kök altında ona giden bir junction; böylece native-assets hook'ları hiçbir zaman boşluk içeren bir yol görmez. native_toolchain_c `cl.exe`'yi `cmd.exe` üzerinden çalıştırır ve `cl.exe` "C:\Program Files" altındadır; bu yüzden tırnaklı bir argüman daha ("…\Lumina Projects\…" altındaki bir çıktı klasörü, include ya da kütüphane) cmd'nin tırnak işlemesini bozar ("'C:\Program' is not recognized"). Takma ad ayrıca bütün yolları kısa tutar. Dosyalar yerinde kalır; yalnızca build'in gördüğü yol değişir. Proje editörü build'i ([EditorBuildService.buildDirOf]), Cook & Package ve Play Standalone tarafından kullanılır.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `of` | `static String of(String dir, {Directory? aliasRoot, String? platform})` | [dir] için build klasörü: Windows dışında (ya da [platform] `windows` değilse) [dir]'in kendisi, aksi halde [aliasRoot] (varsayılan [defaultAliasRoot]) altında ona giden, klasör başına bir tane olan kalıcı bir junction. Takma ad yolunda link olmayan bir şey varsa ona dokunulmaz: [dir] olduğu gibi kullanılır. |
| `defaultAliasRoot` | `static String defaultAliasRoot()` | `%LOCALAPPDATA%\lumina\hosts`; `%LOCALAPPDATA%`'nın kendisi boşluk içeriyorsa (boşluklu bir kullanıcı adı) `<SystemDrive>\lumina-hosts`. |

## `lib/data/services/editor_host_generator_service.dart`

### `enum EditorHostStatus`

What [EditorHostGeneratorService.generate] did.

**Değerler:**

- `generated`: `<project>/.lumina/editor/` holds the project's editor host.

### `class EditorHostResult`

**Yapıcı Metotlar (Constructors):**

- `factory EditorHostResult.generated(Directory hostDir, String packageName, {required bool changed})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `status` | `final EditorHostStatus status` |  |
| `hostDir` | `final Directory? hostDir` | `<project>/.lumina/editor`, when [status] is [EditorHostStatus.generated]. |
| `packageName` | `final String? packageName` | The host package's name (`<project_snake>_editor`), also its binary name. |
| `changed` | `final bool changed` | Whether any generated file differed from what was on disk. |

### `class EditorHostGeneratorService`

Writes a project's editor host package: a thin Flutter app in `<project>/.lumina/editor/` that depends on `lumina_ui` as a library plus the project's code plugins, and holds its own registrar and platform runner. Every engine package it depends on is the project's own copy beside it (`lumina_ui/`, `lumina/`, …, made by `EditorSourceVendorService`), referenced by relative paths. The engine checkout is never modified.

Output is deterministic (the same inputs give byte-identical files) and written in place: a regeneration that changes nothing leaves the folder — the source copy, `.dart_tool`, `pubspec.lock` and build stamp — untouched.

Host'un `pubspec.lock` dosyası engine lock'undaki her hosted paketle doldurulur ([engineLockOf]: projenin kopyasındaki anlık görüntü, yoksa engine workspace'inin `pubspec.lock` dosyası); böylece `pub get`, pub.dev'de sonradan yayımlanan en yeni sürümleri değil, engine'in derlendiği sürümleri korur. Yalnızca host'ta olan paketler (bir code plugin'in kendi bağımlılıkları) kayıtlarını korur, yeniler normal çözülür; path ve git paketlerini pubspec'in kendisi sabitler. Lock; host'ta hiç yoksa, pubspec'i değiştiyse ya da bir engine paketini başka bir sürümde tutuyorsa yeniden yazılır.

**Yapıcı Metotlar (Constructors):**

- `EditorHostGeneratorService({required this.engineRoot, String? platform, String? workspaceRoot})` — `workspaceRoot` (varsayılan `engineRoot`), git'ten çözülmüş eklentileri `pubspec.lock` dosyasında sabitleyen çalışma alanıdır: böyle bir eklenti host pubspec'ine asla pub önbelleğine giden bir path olarak değil, o git bağımlılığı olarak yazılır.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` | The workspace root holding `lumina_ui/`, `lumina/`, `flutter_filament/`, …. |
| `platform` | `final String platform` | The host OS whose runner folder is copied (`linux`, `windows`, `macos`). |
| `stampFileName` | `static const String stampFileName` | The stamp file the build service writes into the host after a build. |
| `hostDirOf` | `static String hostDirOf(String projectDir)` |  |
| `packageNameFor` | `static String packageNameFor(String projectName)` | `MyGame` → `my_game_editor`, always a valid Dart package name. |
| `editorCodePlugins` | `static List<LuminaPluginDescriptor> editorCodePlugins(List<LuminaPluginDescriptor> plugins)` | The plugins that contribute editor code (the ones a host must compile). |
| `projectNameIn` | `static String? projectNameIn(String projectDir)` | The project's name: the `.lmproject` file's base name. |
| `generate` | `Future<EditorHostResult> generate(String projectDir, List<LuminaPluginDescriptor> enabledCodePlugins, {String?...` |  |
| `engineLockOf` | `File engineLockOf(String hostDir)` | Host'un hosted paketlerinin sabitlendiği lock: kopyanın `EditorSourceVendorService.engineLockFileName` dosyası, yoksa `<workspaceRoot>/pubspec.lock`. |
| `movedFromEngineLock` | `List<String> movedFromEngineLock(String hostDir)` | Host lock'unun başka bir sürümde tuttuğu (bir code plugin'in kısıtının kaydırdığı) engine-locked hosted paketler, `name <engine> → <host>` biçiminde; build log'u her biri için uyarır. |
| `isOldLayout` | `static bool isOldLayout(String hostDir)` | Whether the host at [hostDir] depends on `lumina_ui` anywhere but the project's copy beside it (a host from before per-project source copies). |

## `lib/data/services/editor_source_vendor_service.dart`

### `class EditorEngineUpdate`

Projenin motor kaynağı kopyası çalışan motordan başka bir motordan geliyor (bkz. [EditorSourceVendorService.engineUpdate]). Launcher [fromLabel] ve [toLabel] ile "Update this project's editor?" diye sorar.

**Yapıcı Metotlar (Constructors):**

- `const EditorEngineUpdate({required this.copied, required this.current, this.projectEngineVersion, this.changedRepos = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `copied` | `final EngineIdentity? copied` | Kopyanın alındığı motor, damganın kaydettiği şekliyle; damgalar bunu kaydetmeden önce yapılmış kopyada null. |
| `projectEngineVersion` | `final String? projectEngineVersion` | Projenin `.lmproject` `engine_version` değeri, bir sürüm adlandırıyorsa. |
| `current` | `final EngineIdentity current` | Senkronizasyonun kopyalayacağı motor. |
| `changedRepos` | `final List<String> changedRepos` | Kopyadan beri motor kaynağı değişen kopyalanmış depolar. |
| `fromLabel` | `String get fromLabel` | Kopyanın motoru kullanıcı için: etiketi, yoksa projenin `engine_version` değeri, yoksa "an older engine". |
| `toLabel` | `String get toLabel` | Çalışan motor kullanıcı için; aynı sürüm ve commit'ten alınmış kopyada (kaynak checkout'unda düzenleme) değişen depolar da yazılır. |

### `class EditorSourceVendorService`

Copies the engine's Dart source, dependencies included, into a project's editor host: `<host>/lumina_ui/`, `<host>/lumina/`, `<host>/flutter_filament/`, … at the workspace's relative layout, so the copied pubspecs' `path: ../x` entries resolve among themselves. Packages from other repos (git dependencies: flutter_assimp, flutter_riglogic, flutter_gstreamer and lumina_smoke from `tools`, the marketplace's shared package) are copied from where the engine workspace resolved them (its package config: the pub cache, or a local checkout through `pubspec_overrides.yaml`) to `<host>/<name>/`; the host pubspec overrides every one of them to its copy. Filament's C++ tree is linked (`<host>/filament` → `<engine>/filament`), never copied.

The copy is made once and is the project's own afterwards: only [sync] replaces it.

**Yapıcı Metotlar (Constructors):**

- `EditorSourceVendorService({required this.engineRoot, this.rootPackage = 'lumina_ui', this.linkPackages = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` | The workspace root holding `lumina_ui/`, `lumina/`, `filament/`, …. |
| `rootPackage` | `final String rootPackage` | The package whose path-dependency closure is copied. |
| `linkPackages` | `final bool linkPackages` | Links each package to the engine instead of copying it: for engine development and tests, where a ~650 MB copy per build is pointless. Projects never use it. |
| `stampFileName` | `static const String stampFileName` |  |
| `engineLockFileName` | `static const String engineLockFileName` | `.lumina_engine_pubspec.lock`: kopya alındığı andaki engine workspace `pubspec.lock` dosyası (kopyalanan kaynağın derlenip test edildiği sürümler); [vendor] yazar, host generator host'un hosted paketlerini buna sabitler. |
| `filamentDir` | `static const String filamentDir` | Filament's C++ tree, linked beside the copied packages because the native-assets hooks resolve `../filament/…` from their package root. |
| `packageExcludes` | `static const Set<String> packageExcludes` | Skipped directly under each package root: build outputs, tests and backlog docs, none of which the editor build reads. |
| `anywhereExcludes` | `static const Set<String> anywhereExcludes` | Skipped at any depth. |
| `readStamp` | `static Map<String, dynamic>? readStamp(String hostDir)` |  |
| `copiedRepos` | `static List<String> copiedRepos(String hostDir)` | The packages copied into [hostDir] (relative, `/`), from its stamp; empty when it holds no copy. |
| `packageClosure` | `List<String> packageClosure()` | The package dirs (relative to the host, `/`-separated) reachable from [rootPackage] through `path:` and `git:` dependencies and overrides, in discovery order: see [packageSources]. |
| `packageSources` | `Map<String, String> packageSources()` | Each [packageClosure] entry and the directory it is copied from. A `path:` dependency inside [engineRoot] keeps its relative place; one leaving it is a [StateError]. A `git:` dependency (a package of another repo) is copied from where the engine workspace resolved it (see [LuminaWorkspace.resolvedPackageDir]) to `<name>`; one the engine has not resolved is a [StateError]. Path dependencies of such a package are copied by name too. |
| `copyRoots` | `List<String> copyRoots()` | [packageClosure] without packages nested in another one (they travel inside their parent). |
| `isVendored` | `bool isVendored(String hostDir)` | Whether [hostDir] holds a complete copy: the stamp, every package in it and the Filament link. |
| `vendorIfMissing` | `Future<bool> vendorIfMissing(String hostDir, {void Function(double fraction, String file)? onProgress}) async` | Copies the source unless [hostDir] already holds it; true when it copied. |
| `sync` | `Future<void> sync(String hostDir, {void Function(double fraction, String file)? onProgress})` | Replaces the copy with the engine's current source; edits made in the project's copy are lost. |
| `vendor` | `Future<void> vendor(String hostDir, {void Function(double fraction, String file)? onProgress}) async` | Her [copyRoots] paketini [hostDir] içine kopyalar (oradakinin yerine), Filament'i bağlar ve damgayı yazar; damga kopyanın alındığı motoru kaydeder (`engine`: [EngineIdentity]). Paketler önce `<host>/.source.tmp/` içine kopyalanır, hepsi bitince yerine taşınır; yarıda kalan kopya eski durumu bırakır. |
| `copiedEngine` | `static EngineIdentity? copiedEngine(String hostDir)` | [hostDir] kopyasının alındığı motor, damgasından; damga bu kayıttan eskiyse (ya da kopya yoksa) null. |
| `engineChangedSince` | `Future<List<String>> engineChangedSince(String hostDir) async` | The engine repos (top-level dirs) whose state changed since [hostDir]'s copy was made. |
| `engineUpdate` | `Future<EditorEngineUpdate?> engineUpdate(String hostDir, {required EngineIdentity current, String? projectEngineVersion}) async` | [hostDir] kopyası [current] dışında bir motordan mı geliyor: kopya yoksa ya da günselse null. Motorunu kaydeden damga, o motor [current] değilse ya da motor kaynağı o zamandan beri değiştiyse ([engineChangedSince]; kaynak checkout'unda düzenlemeler de sayılır) farklıdır. Eski damga, kaynak değiştiyse ya da projenin [projectEngineVersion] değeri başka bir sürüm adlandırıyorsa farklıdır; oluşturucuların yer tutucusu `kLuminaEngineVersion` sürüm sayılmaz. |

## `lib/data/services/encoded_image_decoder.dart`

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

## `lib/data/services/encoded_image_format.dart`

### `enum EncodedImageFormat`

The container an encoded image is stored in, told from its bytes.

Every format with a signature is recognised by it. TGA has none, so it is only reported when no signature matched and the header passes [TgaDecoderService.isTga]. A glTF `mimeType` or a file extension never decides: exporters label images wrongly and texture folders hold PNGs saved under `.tga` names, and a PNG read as a TGA header is an 18505x21060 image.

**Değerler:**

- `png`
- `jpeg`
- `webp`
- `gif`
- `bmp`
- `ktx2`
- `tga`
- `unknown`: No signature matched and the bytes are not a TGA header either.

**Yapıcı Metotlar (Constructors):**

- `const EncodedImageFormat(this.mimeType)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `mimeType` | `final String? mimeType` |  |
| `sniff` | `static EncodedImageFormat sniff(Uint8List bytes)` | The format of [bytes]; [unknown] when nothing matches. |

## `lib/data/services/engine_bootstrap.dart`

### `abstract final class LuminaRelease`

What the release workflow compiles into a Lumina Studio build (`--dart-define`): the release tag, its commit and the engine repo. All empty in a dev build.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `static const String version` | The release tag, e.g. `v0.1.0`; empty in dev builds. |
| `commit` | `static const String commit` | The full commit SHA the release was built from. |
| `repo` | `static String get repo` | The engine repo the release fetches its source from. |
| `isRelease` | `static bool get isRelease` | Whether this is a release build. |

### `typedef FilamentProvider`

Downloads (or finds) the prebuilt Filament build [version] and returns its directory, usable as the hooks' `filament_dir`: from the `filament-<version>` release, else from the [releaseTag] release (the editor's own, for releases that attached Filament themselves). The signature of `FilamentPrebuilt.ensure`.

### `enum EngineBootstrapStep`

The steps of [EngineBootstrap.ensure], in order.

**Değerler:**

- `prerequisites`
- `source`
- `filament`
- `packages`

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapStep(this.label)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `label` | `final String label` |  |

### `sealed class EngineBootstrapEvent`

An event of [EngineBootstrap.run] / [EngineBootstrap.ensure].

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapEvent()`

### `final class EngineBootstrapProgress`

[step] started or advanced; [fraction] is null while unknown.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapProgress(this.step, this.message, {this.fraction})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `fraction` | `final double? fraction` |  |
| `message` | `final String message` |  |

### `final class EngineBootstrapLog`

A line of tool output (git, flutter) during [step].

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapLog(this.step, this.line)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `line` | `final String line` |  |

### `final class EngineBootstrapStepDone`

[step] finished; [skipped] when there was nothing to do.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapStepDone(this.step, {this.skipped = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `skipped` | `final bool skipped` |  |

### `final class EngineBootstrapPrerequisites`

The prerequisite check's findings (sent whether or not any is missing).

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapPrerequisites(this.prerequisites)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `prerequisites` | `final List<EnginePrerequisite> prerequisites` |  |

### `final class EngineBootstrapCompleted`

The checkout is ready and active.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapCompleted(this.checkout)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `checkout` | `final EngineCheckout checkout` |  |

### `final class EngineBootstrapFailed`

The bootstrap stopped; running it again resumes.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapFailed(this.error)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `error` | `final EngineBootstrapException error` |  |

### `class EnginePrerequisite`

A tool the engine source needs on this machine.

**Yapıcı Metotlar (Constructors):**

- `const EnginePrerequisite({required this.name, required this.location, required this.required, required this.hint})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` | Display name, e.g. `Git`. |
| `location` | `final String? location` | Where it was found (a path, a version), or null when missing. |
| `required` | `final bool required` | Missing required prerequisites stop the bootstrap; the others (the C++ toolchain, needed only to build games and project editors) are reported. |
| `hint` | `final String hint` | How to install it. |
| `found` | `bool get found` |  |

### `class EngineBootstrapException`

Why [EngineBootstrap.ensure] stopped.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapException(this.message, {required this.step, this.missing = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `message` | `final String message` |  |
| `step` | `final EngineBootstrapStep step` | The step that failed. |
| `missing` | `final List<EnginePrerequisite> missing` | The required prerequisites that are missing (step [EngineBootstrapStep.prerequisites]). |

### `class EngineCheckout`

A complete engine checkout, as recorded in its marker file.

**Yapıcı Metotlar (Constructors):**

- `const EngineCheckout({required this.dir, required this.version, required this.commit, required this.repo, required this.filamentVersion, required this.filamentD...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `dir` | `final String dir` | The checkout directory (`<data>/engine/<version>`). |
| `version` | `final String version` | The release tag it belongs to. |
| `commit` | `final String commit` | The commit it is checked out at (detached). |
| `repo` | `final String repo` | The git URL it was cloned from. |
| `filamentVersion` | `final String filamentVersion` | The prebuilt Filament version (`tool/filament/VERSION`) and directory its `filament` link points at. |
| `filamentDir` | `final String filamentDir` |  |
| `completedAt` | `final DateTime completedAt` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |
| `fromJson` | `static EngineCheckout? fromJson(String dir, Object? json)` |  |

### `class EngineBootstrap`

Fetches the engine source of a release build: the installed Lumina Studio is a prebuilt binary, but generating games, project editors and plugins needs the engine's source, at exactly the commit the binary was built from.

[ensure] makes `<engineRoot>/<version>` a partial git clone of [repo] checked out (detached) at [commit], links the prebuilt Filament for the checkout's `tool/filament/VERSION` as its `filament` folder (the root pubspec's hook settings name `filament`), runs `flutter pub get` there (the pinned `ref:`s and the committed lock resolve the other repos), writes a marker file and points [LuminaWorkspace.root] at the checkout.

Every step is idempotent: a complete checkout starts without the network, an interrupted one resumes (a clone whose objects arrived is checked out, a broken one is cloned again). Checkouts of older versions are kept.

**Yapıcı Metotlar (Constructors):**

- `EngineBootstrap({required this.version, this.commit = '', this.repo = kLuminaGitUrl, Directory? engineRoot, Directory? filamentRoot, Map<String, String>? enviro...`
- `factory EngineBootstrap.release({FilamentProvider? filament})`: The bootstrap of this release build ([LuminaRelease]).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `final String version` | The release tag, e.g. `v0.1.0`: the checkout's folder name, and the commit to check out when [commit] is empty. |
| `commit` | `final String commit` | The commit to check out; empty: the tag [version]. |
| `repo` | `final String repo` | The engine repo (any git URL, `file://` included). |
| `engineRoot` | `final Directory engineRoot` | Where checkouts live (`<data>/engine`). |
| `filamentRoot` | `final Directory filamentRoot` | Where prebuilt Filament builds live (`<data>/filament`). |
| `environment` | `final Map<String, String> environment` | The environment tools are looked up in and run with. |
| `filament` | `final FilamentProvider? filament` | Supplies the prebuilt Filament; defaults to [defaultFilamentProvider]. |
| `checkToolchain` | `final bool checkToolchain` | Whether to look for the C++ toolchain (reported, never blocking). |
| `defaultFilamentProvider` | `static FilamentProvider? defaultFilamentProvider` | The Filament provider bootstraps use unless given one. |
| `markerName` | `static const String markerName` | The marker a complete checkout carries, inside its `.git` folder (so it never shows as a change and goes when the checkout goes). |
| `needed` | `static bool get needed` | Whether this process needs a bootstrap: a release build that does not run from a source workspace (`LUMINA_WORKSPACE`, or an ancestor checkout). |
| `checkoutDir` | `Directory get checkoutDir` | `<engineRoot>/<version>`. |
| `markerFile` | `File get markerFile` |  |
| `readyCheckout` | `EngineCheckout? readyCheckout()` | The checkout when it is complete — marker present and matching, `.git/HEAD` at the commit, Filament linked, packages resolved — else null. Reads files only (no git, no network). |
| `activate` | `static void activate(EngineCheckout checkout)` | Makes [LuminaWorkspace.root] resolve to [checkout] for this process. |
| `run` | `Stream<EngineBootstrapEvent> run({bool force = false, bool activate = true})` | [ensure] as a stream: its events, ending with [EngineBootstrapCompleted] or [EngineBootstrapFailed]. |
| `ensure` | `Future<EngineCheckout> ensure({void Function(EngineBootstrapEvent)? onEvent, bool force = false, bool activate...` | Makes the checkout complete (see the class comment) and returns it; with [activate], points [LuminaWorkspace.root] at it. [force] deletes the checkout first and downloads it again. Throws [EngineBootstrapException]. |
| `checkPrerequisites` | `Future<List<EnginePrerequisite>> checkPrerequisites() async` | Git and the Flutter SDK (required), and the C++ toolchain the engine's native code builds with (reported only), found through [environment]. |
| `findExecutable` | `String? findExecutable(String name)` | [name]'s full path on [environment]'s `PATH` (with `PATHEXT` on Windows), or null. |

## `lib/data/services/engine_identity.dart`

### `class EngineIdentity`

Bir Lumina Studio'nun hangi motorla çalıştığı ya da projenin motor kaynağı kopyasının hangi motordan alındığı: bir sürüm etiketi ve commit'i, ya da kaynak checkout'u için kaynak sürümü ve `HEAD`.

**Yapıcı Metotlar (Constructors):**

- `const EngineIdentity({required this.version, this.commit = '', this.release = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `final String version` | Etiketin `v` harfi olmadan sürüm: `0.0.1-dev.7`, kaynak checkout'unda `0.0.1-dev`. |
| `commit` | `final String commit` | Tam commit SHA'sı; bilinmiyorsa (git checkout'u olmayan kaynak ağacı) boş. |
| `release` | `final bool release` | İndirilmiş bir sürüm checkout'u mu (yalnızca etiketiyle adlandırılır). |
| `of` | `static Future<EngineIdentity> of(String engineRoot) async` | [engineRoot] konumundaki motor: indirilmiş sürüm checkout'u etiketini ve commit'ini (bootstrap işaretçisi) verir; sürüm tanımları taşımayan proje editörü de onu indiren Studio ile aynı kimliği okur. Başka her ağaç kaynak checkout'udur: [LuminaRelease.displayVersion] ve oradaki `git rev-parse HEAD` (yalnızca ağacın kendi checkout'u). |
| `stripTag` | `static String stripTag(String version)` | `v0.1.0` → `0.1.0`. |
| `label` | `String get label` | Kullanıcıya gösterilen ad: sürüm, ya da kaynak sürümü ve commit'i (`0.0.1-dev (08cb722)`). |
| `key` | `String get key` | `<version>@<commit>`: aynı motor için eşittir. |
| `toJson / fromJson` | `Map<String, Object?> toJson() · static EngineIdentity? fromJson(Object? json)` | Vendor damgasının ve Studio kaydının `engine` kaydı; sürüm yoksa `fromJson` null döner. |

## `lib/data/services/fbx_import_service.dart`

### `class FbxImportException`

Thrown when an FBX file cannot be turned into a GLB.

**Yapıcı Metotlar (Constructors):**

- `const FbxImportException(this.message)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `message` | `final String message` |  |

### `class FbxImportResult`

An FBX file converted for the import pipeline.

**Yapıcı Metotlar (Constructors):**

- `const FbxImportResult({required this.glb, required this.report, required this.clipNames, required this.collisionHulls,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `glb` | `final Uint8List glb` | Standard glTF: metres, +Y up, one animation per FBX take (named), node transforms as TRS, `UCX_`-style collision hulls removed. |
| `report` | `final Map<String, dynamic> report` | The bridge report without the hull points and triangles (see `AssimpImportConversion.report`). |
| `clipNames` | `final List<String> clipNames` | One name per take, in animation order. |
| `collisionHulls` | `final List<Map<String, dynamic>> collisionHulls` | The removed collision hulls: name, shape (convex/box/sphere/ capsule), vertex_count, face_count, min/max, points (x, y, z flattened; metres, Y up, in the asset's space) and triangles (indices into the points, 3 per face). `MeshCollisionService` turns them into collision. |
| `missingTextureDetails` | `List<Map<String, dynamic>> get missingTextureDetails` | Each texture the FBX referenced but that was found nowhere (see [FbxImportService.missingTextureDetailsKey]): `material` (the FBX material name), `slot`, `path` (as the FBX wrote it), `file`. |
| `materialTextures` | `List<Map<String, dynamic>> get materialTextures` | Each texture bound to a material (see [FbxImportService.materialTexturesKey]). |
| `toAssetMetadata` | `Map<String, String> toAssetMetadata({String? assetBaseName})` | What the import records on the emitted asset: the source format, how it was normalized, the takes and (when the source had any) the hulls. [assetBaseName] (the mesh asset's name) turns the FBX material names of the texture lists into the material assets' names. |

### `abstract final class FbxImportService`

FBX → GLB for the import pipeline.

flutter_assimp's bridge does the heavy lifting natively: it bakes the FBX unit scale and axis system into the scene (Unreal exports are centimetres, Z up) and strips `UCX_`/`UBX_`/`USP_`/`UCP_` collision hulls. What remains is fixing what Assimp's glTF exporter writes:

- one unnamed animation **per channel** (per bone); they are merged back into one animation per FBX take, named after the file (single take) or `<file>_<take>`; - samplers carry their interpolation under `path`; rewritten as `interpolation`; - node transforms as `matrix`; rewritten as TRS, which animated nodes must use (glTF 2.0 ) and the CPU mesh parser reads.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isFbx` | `static bool isFbx(String path)` |  |
| `convert` | `static Future<FbxImportResult> convert(String fbxPath, {List<String> textureSearchDirs = const []})` | [convertSync] in a background isolate (Assimp takes seconds on a skeletal mesh; the editor's UI thread must not wait on it). |
| `convertSync` | `static FbxImportResult convertSync(String fbxPath, {List<String> textureSearchDirs = const []})` | [textureSearchDirs] are searched first for the FBX's textures (the Import dialog's "Textures Folder"). |
| `applyMaterialDetails` | `static Uint8List applyMaterialDetails(Uint8List glb, List<Map> details)` | [FbxMaterialMapper.applyToGltf] on a GLB. |
| `missingTextureDetailsKey` | `static const String missingTextureDetailsKey` | Each referenced texture that was found nowhere: `material` (FBX name), `slot` (`normalMap`, …), `path` (as the FBX wrote it), `file` (its file name). The import names each in the Output Log. |
| `materialTexturesKey` | `static const String materialTexturesKey` | Each texture bound to a material: `material` (FBX name), `slot`, `file` (the file found), `texture` (the image's name, which the texture asset is named after) and `source` (`referenced`, `embedded` or `matched by name`). |
| `textureSlots` | `static Iterable<(String, Map)> textureSlots(Map material) sync*` | glTF texture slots of a material, as the `.lmas` sampler names. |
| `attachMatchedTextures` | `static ({Uint8List glb, List<String> embedded, List<Map<String, dynamic>> bound}) attachMatchedTextures(Uint8L...` | Gives the materials of [glb] the images of the locator's near folders that match them by name ([FbxTextureLocator.matchByName]) in the channels no referenced texture fills: an FBX that names no texture (an Unreal export of a material with constants and textures carries only the constants) still gets the textures its author dropped next to it. Each becomes an embedded image named `T_<material core>_<channel>`. |
| `embeddedTexturesKey` | `static const String embeddedTexturesKey` | Textures the FBX referenced that were found and embedded (file names). |
| `missingTexturesKey` | `static const String missingTexturesKey` | Textures the FBX referenced that exist nowhere near it (the exporter's absolute paths, e.g. `W:/Cafe/.../T_Leather_Normal.png`). |
| `clipNamesFor` | `static List<String> clipNamesFor(String baseName, List<String> takeNames)` | Clip names for [takeNames]: a single take is named after the file (an Unreal export calls every take "Unreal Take"); several are `<file>_<take>`, made unique. |
| `postProcess` | `static Uint8List postProcess(Uint8List glb, {required List<({String name, int channels})> takes, String? gener...` | Rewrites the exporter's GLB (see the class doc). [takes] lists each take's clip name and channel count in export order; when their channel counts do not add up to the animations present, everything is merged into one clip named after the first take. |
| `resolveExternalImages` | `static ({Uint8List glb, List<String> embedded, List<String> missing, List<Map<String, dynamic>> missingDetails...` | Makes every image of [glb] self-contained. An FBX names its textures by the path they had on the author's machine; Assimp's exporter keeps that as the image `uri`. Each one is looked up by [locator] (default: one for [sourceDir]; see [FbxTextureLocator.locateReference]). Found images are embedded (TGA re-encoded as PNG) under the name the FBX gave the file; the rest are removed together with the textures and material slots that sampled them, so the import never writes a texture asset without an image, and are listed per material in `missingDetails`. |
| `decomposeMatrix` | `static ({List<double> translation, List<double> rotation, List<double> scale}) decomposeMatrix(List<double> m)` | Column-major 4×4 → translation, unit quaternion (x, y, z, w) and scale. A mirrored basis (negative determinant) is carried by a negative X scale. |

## `lib/data/services/fbx_material_mapper.dart`

### `abstract final class FbxMaterialMapper`

FBX Phong/Lambert material values → glTF metallic/roughness:

- **base colour** = the FBX diffuse colour (Assimp: `DiffuseColor × DiffuseFactor`), raw — FBX colours are linear; alpha = the FBX `Opacity` (below 1 → alpha blend). A diffuse *texture* replaces the colour (the factor becomes white): the texture is wired straight into Base Color; - **emissive** = the FBX emissive colour (`EmissiveColor × EmissiveFactor`); above 1 it is normalized and the rest goes into `KHR_materials_emissive_strength`; an emissive texture with a black emissive colour emits at full strength; - **roughness** from the Phong exponent, see [roughnessFromPhong]; - **metallic** 0 — Phong has no metalness — unless the file carries a PBR value (Maya Stingray/Arnold `Maya|metallic`, 3ds Max Physical `metalness`). `ReflectionFactor` is *not* used: the FBX SDK template defaults it to 1, so every such export would come in as metal.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `roughnessFromPhong` | `static double roughnessFromPhong({required double shininess, required double specular})` | Perceptual roughness for a Phong material with exponent [shininess] and specular intensity [specular] (specular colour luminance × specular factor). |
| `valuesFor` | `static ({List<double>? baseColor, double alpha, double metallic, double roughness, List<double> emissive}) val...` | The glTF values for one flutter_assimp `material_details` entry. |
| `applyToGltf` | `static void applyToGltf(Map<String, dynamic> json, List<Map> details)` | Writes each FBX material's values ([details], flutter_assimp's `material_details`, matched by name, else by index) into the glTF [json]'s materials in place, replacing the glTF exporter's guess (`roughness = 1 − sqrt × specular`, which makes every such export fully rough). |
| `setEmissive` | `static void setEmissive(Map<String, dynamic> json, Map material, List<double> rgb)` | Sets [material]'s emissive colour [rgb] (linear, any intensity): a colour above 1 is normalized, the scale going into `KHR_materials_emissive_strength`; black removes the emission. |
| `emissiveOf` | `static List<double> emissiveOf(Map material)` | The emissive colour × strength a glTF [material] asks for. |

## `lib/data/services/fbx_texture_locator.dart`

### `enum FbxTextureChannel`

A texture channel an image beside an FBX can be matched to by its name, and the glTF slot it fills.

**Değerler:**

- `baseColor`
- `normal`
- `emissive`
- `orm`
- `occlusion`

**Yapıcı Metotlar (Constructors):**

- `const FbxTextureChannel(this.suffix, this.slot)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `suffix` | `final String suffix` | The suffix of the texture asset the importer names it by (`T_<core>_<suffix>`). |
| `slot` | `final String slot` | The `.lmas` material sampler / glTF slot it fills. |

### `class FbxTextureLocator`

Where the textures of an FBX are looked for, in order — the path as written, then relative to the FBX — plus the folders people keep textures in:

- **near folders** (searched first, and the only ones whose images are matched to materials by name): the folders chosen in the import options, the FBX's folder, and its `Textures/`, `textures/`, `<fbx name>/` and `<fbx name>.fbm/` subfolders (`.fbm` is where the FBX SDK extracts embedded media); - **reference folders** (a referenced file name only): the near folders, then the `Textures`/`textures`/`Texturen`/`Materials` folders of the FBX's folder and its three nearest ancestors, with their direct subfolders.

**Yapıcı Metotlar (Constructors):**

- `FbxTextureLocator({required this.fbxFile, List<String> extraDirs = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fbxFile` | `final File fbxFile` |  |
| `extraDirs` | `final List<String> extraDirs` |  |
| `sourceDir` | `Directory get sourceDir` |  |
| `nearDirs` | `late final List<Directory> nearDirs` |  |
| `referenceDirs` | `late final List<Directory> referenceDirs` |  |
| `nearImages` | `late final List<File> nearImages` | Every image file in the [nearDirs], each once. |
| `locateReference` | `File? locateReference(String uri)` | Bir FBX doku referansı [uri]'nin gösterdiği dosya: yazıldığı gibi, FBX'e göre (bu yazımla diskte yoksa klasörleri ve dosyası büyük/küçük harf fark etmeksizin eşleşerek, bkz. [findIgnoringCase]), sonra [referenceDirs] içinde dosya adıyla (büyük/küçük harf duyarsız), sonra [nearDirs] içinde adı `_<dosya adı>` ile biten bir görsel olarak (asset'in adını öne ekleyen bir exporter, ör. Godot'nun `SM_Slot_Machine_T_Tread_Plate_Normal.png`'si). |
| `findIgnoringCase` | `static File? findIgnoringCase(String path, {Directory? base})` | [path]'in (`/` veya `\` ayraçlı; [base]'e göre ya da mutlak) gösterdiği dosya, klasörleri veya dosyası büyük/küçük harf duyarlı bir diskte başka harflerle yazılmışken (Linux: `Maps/wood.png`, `maps/wood.png`'yi bulur): her parça o adın herhangi bir harf büyüklüğündeki girdisine gider ([pickIgnoringCase]). `.` ve `..` yazıldığı gibi izlenir. Bir parçanın eşi yoksa null. Büyük/küçük harf duyarsız bir dosya sistemi (Windows, macOS) bunları zaten tam yolla bulur. |
| `pickIgnoringCase` | `static T? pickIgnoringCase<T extends FileSystemEntity>(Iterable<T> entries, String name)` | [entries] içinde herhangi bir harf büyüklüğünde [name] adlı girdi: tam bu yazımla olan varsa o, yoksa ada göre (kod birimi) ilki; böylece seçim klasörün listelenme sırasına hiç bağlı değildir. |
| `channelOf` | `static (FbxTextureChannel, int)? channelOf(String stem)` | The channel a file name (without extension) ends in, and how many of its tokens the suffix takes. |
| `coreName` | `static String coreName(String material)` | A material name without its asset-type prefix (`MI_`, `M_`, `Mat_`, `Material_`). |
| `matchByName` | `Map<int, Map<FbxTextureChannel, File>> matchByName(List<String> materials, {Set<String> exclude = const {}})` | The images of the [nearDirs] matched to [materials] by name: a file matches a material when its name holds the material's name (or its [coreName]) as whole tokens before a channel suffix — `T_Wood_BaseColor` for `M_Wood`, `SM_Slot_Machine_MI_Neon_Green_SM_Slot_Machine_Emissive` for `MI_Neon_Green`. A file goes to the material with the longest matching name (`MI_Plastic_Black_Matte_1_Normal` belongs to `MI_Plastic_Black_Matte_1`, not `MI_Plastic_Black`); files in [exclude] (already bound by reference) are skipped. Result: material index → channel → file (the first by path when several fit). |

## `lib/data/services/filament_thumbnail_renderer.dart`

### `class ThumbnailMeshPart`

One glTF binary placed in a thumbnail scene.

[transform] is the placement in world space (Y up, centimetres). [unitScale] converts the glTF's own units into world units: imported glTF is metres and is drawn ×[LuminaUnits.unitsPerMetre], exactly as `LuminaStaticMeshComponent.assetUnitScale` draws it in a level; geometry generated in world units (primitives) uses 1.

**Yapıcı Metotlar (Constructors):**

- `ThumbnailMeshPart(this.glb, {Matrix4? transform, this.unitScale = LuminaUnits.unitsPerMetre, this.pose})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `glb` | `final Uint8List glb` |  |
| `transform` | `final Matrix4 transform` |  |
| `unitScale` | `final double unitScale` |  |
| `pose` | `final ThumbnailPose? pose` | The animation pose to draw a skinned mesh in; its rest pose when null. |

### `class ThumbnailPose`

A frame of an animation clip stored in a mesh's GLB: the clip named [clip] (else the one at [clipIndex]), at [fraction] of its length — an animation sequence's thumbnail is its mesh at the middle of the clip.

**Yapıcı Metotlar (Constructors):**

- `const ThumbnailPose({this.clip, this.clipIndex, this.fraction = 0.5})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `clip` | `final String? clip` |  |
| `clipIndex` | `final int? clipIndex` |  |
| `fraction` | `final double fraction` |  |
| `indexIn` | `int? indexIn(List<String> names)` | The gltfio animation index this pose names in [names], or null. |

### `class FilamentThumbnailRenderer`

Renders asset thumbnails offscreen with Filament.

It draws on the process's shared engine (flutter_filament `FilamentEngineHost`), leased on first use and released by [dispose], with its own headless swap chain, renderer, view and scene: the editor's viewports and the thumbnail queue are one Vulkan device, not one each. The engine is on the GPU every engine in the process uses (`FilamentEngine.defaultGpuPreference`, which the editor sets from its Graphics Device setting, then `FILAMENT_GPU`).

Every render is lit by the same studio rig (a sun, image-based lighting and a neutral backdrop) and framed from a three-quarter view onto the bounds of what was drawn, with the near and far planes taken from those bounds, so a 3 cm bolt and a 30 m level both fill the frame. The frame is rendered at [supersample]× and averaged down to [size]² before it is encoded.

Renders are serialized: callers may overlap, the engine never does.

**Yapıcı Metotlar (Constructors):**

- `FilamentThumbnailRenderer({super.size, super.supersample, super.sunIntensity, super.iblIntensity, super.backdrop, super.iblKtx,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `shared` | `static FilamentThumbnailRenderer get shared` | The process-wide renderer the editor's thumbnail queue uses. |
| `isAvailable` | `bool get isAvailable` | False once the engine could not be created (no GPU, no driver); every render then returns null and callers keep their fallback. |
| `environmentIbl` | `set environmentIbl(Uint8List? ktx)` | Sets the image-based light (a KTX1 cubemap, e.g. Filament's `default_env_ibl.ktx`). Without one the rig uses a neutral spherical-harmonics ambient. |
| `environmentIbl` | `Uint8List? get environmentIbl` |  |
| `renderMesh` | `Future<Uint8List?> renderMesh(Uint8List glb)` | A static or skeletal mesh (GLB / glTF bytes, metres), drawn ×100 like a level draws it. Null when nothing could be loaded or rendered. |
| `renderMeshParts` | `Future<Uint8List?> renderMeshParts(List<ThumbnailMeshPart> parts, {double pitchDegrees = 22})` | Several meshes in one frame (a Blueprint's mesh components, a level). |
| `renderMaterial` | `Future<Uint8List?> renderMaterial(LuminaAsset material, {String? projectRoot})` | A material on a preview sphere: its compiled package when it has one, else compiled from its whole `.mat` source by Filament's own material compiler (`FilamentMatc`: every header key, `vertex` and `fragment` blocks); when neither yields a package the sphere gets a default lit material in the material's base colour (the Material Editor's fallback). Texture references resolve against [projectRoot]. |
| `renderLevel` | `Future<Uint8List?> renderLevel(List<Map<String, dynamic>> actors, {String? projectRoot}) async` | A level from its stored actors (`metadata.actors`: centimetres, Z up): its primitives and meshes, framed from above on the bounds of the level. Mesh paths resolve against [projectRoot]. |
| `levelParts` | `static Future<List<ThumbnailMeshPart>> levelParts(List<Map<String, dynamic>> actors, {String? projectRoot}) as...` | The drawable pieces of a level: primitives (built in world units) and mesh actors (glTF metres), each placed by its stored transform converted from Z up to the runtime's Y up. |
| `authoringTransform` | `static Matrix4 authoringTransform(dynamic location, dynamic rotation, dynamic scale)` | A stored (Z up, cm, degrees) transform as a runtime (Y up) matrix, the conversion the level code generator emits ([LuminaAxes]). |
| `resolveProjectPath` | `static String? resolveProjectPath(String path, String? projectRoot)` | [path] as an openable file: absolute and existing paths as they are, project-relative ones (`contents/…`) under [projectRoot]. |
| `loadMeshGlb` | `static Future<Uint8List?> loadMeshGlb(String path) async` | The GLB a mesh file draws: a `.glb`/`.gltf` as it is, a `.lmas`'s embedded payload or its `.entity.glb` companion. Run through the import sanitizer (TGA → PNG, texture budget, four skin influences) so gltfio can load it; already-sanitized files pass straight through. |
| `dispose` | `void dispose()` | Releases the engine and everything on it. |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] is a compiled `.filamat` package: a `MAT_VERS` chunk of size 4. Filament aborts the process on anything else. |
| `materialParameterValues` | `static Map<String, Object?> materialParameterValues(LuminaAsset material)` | The values a material instance starts with: the `.mat` header's `default :` entries, overridden by what the Material Editor saved in `metadata.parameter_defaults`. |

## `lib/data/services/generated_code_migration.dart`

### `class LuminaGeneratedCodeMigration`

Brings a project's generated Dart written by earlier Lumina versions to the current naming rules ([dartTypeName], [dartFileName]).

Earlier generators named the files in `lib/levels/`, `lib/actors/`, `lib/anim/` and `lib/widgets/` after their assets (`L_Main.dart`, `BP_Door.dart`) and their classes `L_Main`, `BPDoor`, `WBPHud`. Today the files are snake_case (`l_main.dart`, `bp_door.dart`) and the classes UpperCamelCase (`LMain`, `BpDoor`, `WbpHud`). [migrate] renames the legacy files — keeping their contents, so `BEGIN USER CODE` regions survive — renames the classes they declare, and rewrites the imports and class references of every Dart file under `lib/`, so a project regenerates cleanly and still compiles in between. A legacy file whose snake_case file already exists is stale and is deleted.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `generatedFolders` | `static const List<String> generatedFolders` | The `lib/` folders whose files are named after assets. |
| `migrate` | `static Map<String, String> migrate(String projectDir)` | Migrates [projectDir]'s generated Dart; returns the renamed files, `lib/…` old path → new path (empty when there was nothing to migrate). |

---

[Önceki: Veri katmanı: use case'ler ve servisler (devamı, bölüm 1)](data-services-continued.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Veri katmanı: use case'ler ve servisler (devamı, bölüm 3)](data-services-continued-3.md)
