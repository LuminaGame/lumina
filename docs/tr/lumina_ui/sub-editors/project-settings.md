[English](../../../en/lumina_ui/sub-editors/project-settings.md)

# Proje ayarları

Proje Ayarları editörü: projenin `.lmproject` manifest'i üzerinde aranabilir, doğrulanan, kategori tabanlı bir görünüm. Dosya yolları `lumina_ui/` paket dizinine görelidir.

## `lib/ui/features/sub_editors/views/project_settings_sub_editor.dart`

### `class ProjectSettingsSubEditor`

Project Settings: split view over the real `.lmproject`.  Left: searchable category list with validation badges. Right: the category's editors. Footer: dirty indicator, Revert, Apply & Save. Every control edits the view model's working copy instantly; only Apply writes the manifest and pushes graphics settings to the editor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectDirPath` | `String? projectDirPath` | `projectDirPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialProject` | `LuminaProject? initialProject` | `initialProject` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `ProjectSettingsViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<ProjectSettingsSubEditor> createState() => _ProjectSettingsSubEdit...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _ProjectSettingsSubEditorState`

`_ProjectSettingsSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `viewModelForTest` | `ProjectSettingsViewModel get viewModelForTest` | `viewModelForTest` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/project_settings_view_model.dart`

### `class LevelChoice`

A LEVEL asset available to the Maps & Modes pickers.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `relativePath` | `String relativePath` | `relativePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `displayName` | `String displayName` | `displayName` alanını (field/property) ve ilişkili veriyi saklar. |
| `thumbnail` | `Uint8List? thumbnail` | `thumbnail` alanını (field/property) ve ilişkili veriyi saklar. |

### `class PackagingRunState`

Result of a packaging run (`flutter build <target>`).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isRunning` | `bool isRunning` | `isRunning` alanını (field/property) ve ilişkili veriyi saklar. |
| `progress` | `double progress` | `progress` alanını (field/property) ve ilişkili veriyi saklar. |
| `exitCode` | `int? exitCode` | `exitCode` alanını (field/property) ve ilişkili veriyi saklar. |
| `lastLine` | `String? lastLine` | `lastLine` alanını (field/property) ve ilişkili veriyi saklar. |

### `class ProjectSettingsCategory`

Settings categories in display order. Keys are stable ids used by search, validation badges and the navigation list.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `title` | `static String title(String id)` | `title` işlemini gerçekleştirir. |

### `class ProjectSettingsViewModel`

Edits the real `.lmproject` manifest: loads it through [ProjectRepository], keeps a working copy with dirty tracking and per-category validation, and writes it back on [apply]. Graphics changes are pushed to the editor via [onApplied] so the toolbar scalability state is shared, not copied.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `projectDirPath` | `String projectDirPath` | `projectDirPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `loadError` | `String? get loadError` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `hasProject` | `bool get hasProject` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `project` | `LuminaProject get project` | `project` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `onDiskProject` | `LuminaProject? get onDiskProject` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `manifestPath` | `String? get manifestPath` | `manifestPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `filterQuery` | `String get filterQuery` | `filterQuery` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `levels` | `List<LevelChoice> get levels` | `levels` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `gameModeClasses` | `List<String> get gameModeClasses` | `gameModeClasses` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `packaging` | `PackagingRunState get packaging` | `packaging` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `load` | `Future<void> load()` | Locates `<projectDir>/<name>.lmproject` (any `.lmproject` if the name is unknown) and loads it. Never throws; [loadError] reports failures. |
| `revert` | `Future<void> revert()` | Reloads the on-disk manifest, discarding edits. |
| `apply` | `Future<bool> apply()` | Validates every category; refuses to save while errors exist. Warnings (e.g. a map whose file is gone) do not block saving. |
| `validationErrors` | `Map<String, List<String>> get validationErrors` | Blocking errors keyed by [ProjectSettingsCategory] id. |
| `validationWarnings` | `Map<String, List<String>> get validationWarnings` | Non-blocking warnings (a missing default map is allowed). |
| `errorCount` | `int errorCount(String category)` | `errorCount` işlemini gerçekleştirir. |
| `setFilterQuery` | `void setFilterQuery(String q)` | `FilterQuery` parametresini günceller ve sisteme uygular. |
| `visibleCategories` | `List<String> get visibleCategories` | Categories whose title or row keywords match the query (all when empty). |
| `rowMatches` | `bool rowMatches(String label) => _filterQuery.isEmpty \|\| label.toLower...` | Whether a settings row labelled [label] matches the current query. |
| `setProjectName` | `void setProjectName(String v) => _update((p) => p.copyWith(projectName: v))` | `ProjectName` parametresini günceller ve sisteme uygular. |
| `setDescription` | `void setDescription(String v) => _update((p) => p.copyWith(description: v))` | `Description` parametresini günceller ve sisteme uygular. |
| `setQualityPreset` | `void setQualityPreset(String preset) => _update((p)` | Selecting a preset instantly expands every per-category tier. |
| `setScalabilityField` | `void setScalabilityField(String field, String tier) => _update((p)` | `ScalabilityField` parametresini günceller ve sisteme uygular. |
| `setTargetFps` | `void setTargetFps(int fps) => _update((p) => p.copyWith(settings: _copyS...` | `TargetFps` parametresini günceller ve sisteme uygular. |
| `setVSync` | `void setVSync(bool on) => _update((p) => p.copyWith(settings: _copySetti...` | `VSync` parametresini günceller ve sisteme uygular. |
| `addAction` | `void addAction([String? name]) => _update((p)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeAction` | `void removeAction(int index) => _update((p)` | Belirtilen `Action` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `addMappingContext` | `void addMappingContext([String? name]) => _update((p)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeMappingContext` | `void removeMappingContext(int index) => _update((p)` | Belirtilen `MappingContext` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `addMapping` | `void addMapping(int contextIndex, ProjectInputMapping mapping) => _updat...` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeMapping` | `void removeMapping(int contextIndex, int mappingIndex) => _update((p)` | Belirtilen `Mapping` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setEditorStartupMap` | `void setEditorStartupMap(String relativePath)` | `EditorStartupMap` parametresini günceller ve sisteme uygular. |
| `setGameDefaultMap` | `void setGameDefaultMap(String relativePath)` | `GameDefaultMap` parametresini günceller ve sisteme uygular. |
| `setDefaultGameMode` | `void setDefaultGameMode(String className)` | `DefaultGameMode` parametresini günceller ve sisteme uygular. |
| `setGravityZ` | `void setGravityZ(double g) => _update((p) => p.copyWith(physics: p.physi...` | `GravityZ` parametresini günceller ve sisteme uygular. |
| `setFixedTimestep` | `void setFixedTimestep(double dt) => _update((p) => p.copyWith(physics: p...` | `FixedTimestep` parametresini günceller ve sisteme uygular. |
| `setTargetOs` | `void setTargetOs(String os) => _update((p) => p.copyWith(packaging: p.pa...` | `TargetOs` parametresini günceller ve sisteme uygular. |
| `setOutputDir` | `void setOutputDir(String dir) => _update((p) => p.copyWith(packaging: p....` | `OutputDir` parametresini günceller ve sisteme uygular. |
| `packageProject` | `Future<int> packageProject()` | Runs the real `flutter build <target>` in the project directory, streaming output into the engine log. A non-zero exit code is surfaced as an error and the progress resets; there is no fake success. |
| `cancelPackaging` | `void cancelPackaging()` | `cancelPackaging` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

## `lib/ui/features/sub_editors/view_models/project_settings_view_model/models.dart`

### `class LevelChoice`

A LEVEL asset available to the Maps & Modes pickers.

**Yapıcı Metotlar (Constructors):**

- `const LevelChoice({required this.relativePath, required this.displayName, this.thumbnail})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `relativePath` | `final String relativePath` |  |
| `displayName` | `final String displayName` |  |
| `thumbnail` | `final Uint8List? thumbnail` |  |

### `class PackagingLogLine`

One line of a packaging run's console, tagged with its source (`Cook & Package [linux]`).

**Yapıcı Metotlar (Constructors):**

- `const PackagingLogLine({required this.at, required this.level, required this.source, required this.message})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `at` | `final DateTime at` |  |
| `level` | `final String level` |  |
| `source` | `final String source` |  |
| `message` | `final String message` |  |
| `target` | `String? get target` | The platform id a line belongs to, or null for run-wide lines. |

### `class PackagingRunState`

The last Package Project run over every ticked target.

**Yapıcı Metotlar (Constructors):**

- `const PackagingRunState({this.isRunning = false, this.statuses = const {}, this.durations = const {}, this.packageDirs = const {}, this.messages = const {}, thi...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isRunning` | `final bool isRunning` |  |
| `statuses` | `final Map<String, PackageTargetStatus> statuses` | Per platform id: pending → running → ok / failed / unbuildable / cancelled. |
| `durations` | `final Map<String, Duration> durations` |  |
| `packageDirs` | `final Map<String, String> packageDirs` | Package folders of the targets that succeeded. |
| `messages` | `final Map<String, String> messages` | Why a target was not built or failed. |
| `result` | `final BuildStepStatus? result` | Result of the whole run (null while running or before the first run). |
| `stage` | `final String? stage` |  |

### `class ProjectSettingsCategory`

Settings categories in display order. Keys are stable ids used by search, validation badges and the navigation list.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `description` | `static const description` |  |
| `graphics` | `static const graphics` |  |
| `input` | `static const input` |  |
| `mapsAndModes` | `static const mapsAndModes` |  |
| `physics` | `static const physics` |  |
| `packaging` | `static const packaging` |  |
| `userInterface` | `static const userInterface` |  |
| `all` | `static const all` |  |
| `title` | `static String title(String id)` |  |
| `keywords` | `static const Map<String, List<String>> keywords` | Searchable keywords per category (row labels) for the settings search. |

## `lib/ui/features/sub_editors/views/project_editor_builds_preferences_page.dart`

### `class ProjectEditorBuildsPreferencesPage`

Editor Preferences → General › Project Editor Builds: how project editors (a project's code plugins compiled into its own editor) are built, and the shared cache they live in.

**Yapıcı Metotlar (Constructors):**

- `const ProjectEditorBuildsPreferencesPage({super.key, required this.preferences, this.projectDir, this.engineRoot})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `preferences` | `final EditorPreferences preferences` |  |
| `projectDir` | `final String? projectDir` | The open project, whose copy of the engine source the Editor Source section shows; null in the launcher. |
| `engineRoot` | `final String? engineRoot` | The engine checkout the copy syncs from; defaults to this editor's. |
| `category` | `static const String category` |  |
| `cacheFor` | `static EditorBuildCache cacheFor(EditorPreferences preferences)` | The cache the preferences point at. |

## `lib/ui/features/sub_editors/views/project_editor_source_section.dart`

### `class ProjectEditorSourceSection`

Editor Preferences › Project Editor Builds › Editor Source: the open project's copy of the engine source under `.lumina/editor/`, whether the engine moved on since it was made, and Sync, which replaces the copy (after a warning) so the next open rebuilds from the engine's current source.

**Yapıcı Metotlar (Constructors):**

- `const ProjectEditorSourceSection({super.key, required this.projectDir, required this.engineRoot, required this.formatBytes})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `engineRoot` | `final String engineRoot` |  |
| `formatBytes` | `final String Function(int bytes) formatBytes` |  |

## `lib/ui/features/sub_editors/views/project_settings/web_loading_style_section.dart`

### `typedef SettingsSectionBuilder`

Builds a titled settings section (the sub-editor's own look).

### `typedef SettingsRowBuilder`

Builds a labelled, search-aware settings row.

### `class WebLoadingStyleSection`

Project Settings → Packaging & Target → **Web Loading Style**: the look of a web build's plain HTML loading screen, shown while a web target is ticked. Every control edits the view model's working copy; Apply & Save writes `packaging.web_loading_style` and regenerates the project's `web/` loading screen. The preview draws the generated page's layout with the same values, and "Open in Browser" serves the generated page itself.

**Yapıcı Metotlar (Constructors):**

- `const WebLoadingStyleSection({super.key, required this.viewModel, required this.section, required this.row})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final ProjectSettingsViewModel viewModel` |  |
| `section` | `final SettingsSectionBuilder section` |  |
| `row` | `final SettingsRowBuilder row` |  |

### `class WebLoadingPreview`

The loading screen's layout, drawn in Flutter with the page's values (`web/index.html` + `loading.css`): background or gradient, logo, title, subtitle, the progress in its style and the phase label `loading.js` shows at [fraction].

**Yapıcı Metotlar (Constructors):**

- `const WebLoadingPreview({super.key, required this.style, required this.logo, required this.fraction})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `style` | `final ResolvedWebLoadingStyle style` |  |
| `logo` | `final Widget? logo` |  |
| `fraction` | `final double fraction` |  |
| `labelFor` | `static String labelFor(double fraction)` | `loading.js`'in [fraction] civarında gösterdiği aşama etiketi. |

## `lib/ui/features/sub_editors/views/project_settings/key_binding_dialog.dart`

### `class KeyBindingDialog`

Kullanıcıların herhangi bir tuşa basarak (Escape, Space, Enter vb. dahil) veya kategorize edilmiş, aranabilir bir Combobox / hızlı seçim listesinden seçerek giriş tuşu atamasını sağlayan modal diyalog penceresi.

**Yapıcı Metotlar (Constructors):**

- `const KeyBindingDialog({super.key, this.initialKeyId, this.initialKeyLabel = '', required this.onKeySelected, required this.onClose})`

**Üyeler ve Metotlar:**

| Üye / Metot | İmza | Açıklama |
| :--- | :--- | :--- |
| `initialKeyId` | `final int? initialKeyId` | Varsa önceden seçilmiş tuş kimliği (keyId). |
| `initialKeyLabel` | `final String initialKeyLabel` | Önceden seçilmiş okunabilir tuş etiketi. |
| `onKeySelected` | `final void Function(int keyId, String keyLabel) onKeySelected` | Kullanıcı tuş atamasını onayladığında çağrılan geri çağırma fonksiyonu. |
| `onClose` | `final VoidCallback onClose` | Kullanıcı diyaloğu kapattığında veya iptal ettiğinde çağrılır. |

### `class KeyOption`

Diyalog içerisindeki seçilebilir her bir tuş veya eksen seçeneğini temsil eden veri sınıfı.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `keyId` | `final int keyId` | Tuş kimliği (Flutter tuş kodu veya fare/oyun kolu negatif sabiti). |
| `id` | `final String id` | Lumina tuş tanımlayıcısı (örn. `KeyEscape`, `MouseLeft`). |
| `label` | `final String label` | Kullanıcıya gösterilen etiket (örn. `Escape`, `Space`). |
| `category` | `final String category` | Tuş kategorisi (örn. `Navigation & Controls`, `Mouse`). |
| `icon` | `final IconData icon` | Tuş türünü temsil eden ikon. |
| `searchTerms` | `final List<String> searchTerms` | Hızlı filtreleme için arama terimleri ve takma adlar. |

## Ölçeklenebilirlik Presetleri ve Teknik Karşılıkları

**Engine & Graphics** kategorisi, projenin `.lmproject` manifest dosyasındaki `settings.scalability` altında saklanan genel grafik ayarlarını yapılandırır. Bir preset seçildiğinde motor seviyesinde arka plandaki tüm render parametreleri ve kamera kırpma mesafeleri (far clip plane) anında güncellenir:

| Preset | Görüş Mesafesi | Gölgeler | Kenar Yumuşatma (AA) | Post-Processing | Dokular | Gölgelendirme (Shading) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Low** | 250 m (25.000 cm) | 512×512 PCF (1 cascade) | Yok | Düşük HDR arabelleği, minimal bloom | 1/4 çözünürlük (MIP bias +2, 1x lineer) | Basit PBR (min %50 dinamik çözünürlük) |
| **Medium** | 500 m (50.000 cm) | 1024×1024 PCF (2 cascades, lambda 0.5) | FXAA | Orta HDR arabelleği, standart bloom | 1/2 çözünürlük (MIP bias +1, 2x trilineer) | Standart PBR (min %75 dinamik çözünürlük) |
| **High** | 1.000 m (100.000 cm) | 2048×2048 VSM (3 cascades, 2x anizo) | FXAA | Yüksek HDR arabelleği, bloom, vignette, CA | Tam çözünürlük (4x anizotropik) | Tam PBR, doğal %100 çözünürlük, SSR |
| **Epic** | 2.000 m (200.000 cm) | 4096×4096 PCSS (4 cascades, 8 adım temas) | TAA | Ultra HDR arabelleği, tam bloom, ACES | Tam çözünürlük (8x anizotropik) | Ultra PBR, SSR & Ekran Alanı Ortam Kapatma (AO) |
| **Cinematic** | 4.000 m (400.000 cm) | 4096×4096 PCSS (4 cascades, 16 adım temas, lambda 0.4) | 4x MSAA + TAA | Ultra HDR arabelleği, tam DoF ve sinematik tonlama | Sıkıştırmasız (16x anizotropik filtreleme) | Ultra PBR, 4x MSAA + TAA, maksimum SSR |

### Presetlerin Detaylı Teknik Açıklamaları:
- **Low**: Düşük güçlü mobil çipler veya dahili ekran kartları için maksimum performans modudur. Kenar yumuşatma ve SSR kapatılır, gölge haritası tek cascade ile 512×512'ye sınırlandırılır, dokular iki kademe alt örneklenir ve kamera far clip mesafesi 250 metrede tutulur.
- **Medium**: Giriş ve orta seviye donanımlar için dengeli oyun modudur. 2 cascade 1024×1024 PCF gölgeler, FXAA, orta seviye HDR bloom, yarı çözünürlüklü dokular ve 500 metre kamera görüş mesafesi sunar.
- **High**: Modern masaüstü sistemleri için yüksek kaliteli oyun profili. 3 cascade 2048×2048 Varyans Gölge Haritaları (VSM), doğal %100 viewport çözünürlüğü, ekran alanı yansımaları (SSR), 4x anizotropik doku filtrelemesi ve 1.000 metre (1 km) görüş mesafesi sağlar.
- **Epic**: Yüksek kaliteli modern oyun deneyimi hedefidir. 4 cascade 4096×4096 Percentage-Closer Soft Shadows (PCSS) ve 8 adımlı temas gölgeleri, alt piksel titreme arabelleğine sahip Temporal Anti-Aliasing (TAA), ekran alanı ortam kapatma (AO), ACES renk tonlaması, 8x anizotropik dokular ve 2.000 metre (2 km) görüş mesafesi içerir.
- **Cinematic**: Sinematik ara sahneler, çevrimdışı render alımları, tanıtım videoları ve ultra üst düzey iş istasyonları için tasarlanmış en üstün render modudur. Kamera görüş mesafesini 4.000 metreye (4 km) uzatır; gölgeleri 4 cascade 4096×4096 PCSS, 16 adımlı ekran temas gölgesi ve lambda 0.4 pratik bölünme ile çizer; donanımsal 4x MSAA ile zamansal TAA'yı birlikte kullanır; dokularda 16x anizotropik tam sıkıştırmasız örneklemeyi açar ve sinematik alan derinliği (DoF) ile tam renk derecelendirmesi uygular. Yüksek kare hızlı etkileşimli oynanış için **Epic** veya **High** modu tavsiye edilir.

Bu ayarlar çalışma zamanında (runtime) Blueprint'lerde yer alan `SetOverallScalabilityLevel`, `SetViewDistance`, `ApplyScalabilitySettings` gibi düğümlerle veya kod tarafında `LuminaUserSettingsSubsystem` aracılığıyla dinamik olarak değiştirilebilir.

---

[Önceki: Fizik asset editörü](physics-asset.md) | [Üst: Alt editörler](index.md) | [Sonraki: Sequencer](sequencer.md)
