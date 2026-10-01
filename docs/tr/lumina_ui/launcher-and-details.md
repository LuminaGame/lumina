[English](../../en/lumina_ui/launcher-and-details.md)

# Launcher ve details

Proje launcher'ı (son projeler, şablonlar ve proje oluşturma akışı) ile details panelinin arkasındaki modeller ve servisler: component property registry'si, editör component node'ları ve çoklu seçim düzenleme. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/launcher/views/create_project_dialog.dart`](#libuifeatureslauncherviewscreate_project_dialogdart)
- [`lib/ui/features/launcher/views/launcher_view.dart`](#libuifeatureslauncherviewslauncher_viewdart)
- [`lib/ui/features/launcher/view_models/create_project_view_model.dart`](#libuifeatureslauncherview_modelscreate_project_view_modeldart)
- [`lib/ui/features/launcher/view_models/launcher_view_model.dart`](#libuifeatureslauncherview_modelslauncher_view_modeldart)
- [`lib/ui/features/details/services/multi_edit_service.dart`](#libuifeaturesdetailsservicesmulti_edit_servicedart)
- [`lib/ui/features/details/models/component_property_registry.dart`](#libuifeaturesdetailsmodelscomponent_property_registrydart)
- [`lib/ui/features/details/models/editor_component_node.dart`](#libuifeaturesdetailsmodelseditor_component_nodedart)
- [`lib/ui/features/details/services/blueprint_collision_overrides.dart`](#libuifeaturesdetailsservicesblueprint_collision_overridesdart)
- [`lib/ui/features/details/widgets/actor_mesh_section.dart`](#libuifeaturesdetailswidgetsactor_mesh_sectiondart)
- [`lib/ui/features/launcher/services/installed_template_repository.dart`](#libuifeatureslauncherservicesinstalled_template_repositorydart)
- [`lib/ui/features/launcher/services/project_editor_resolver.dart`](#libuifeatureslauncherservicesproject_editor_resolverdart)
- [`lib/ui/features/launcher/services/template_project_creator.dart`](#libuifeatureslauncherservicestemplate_project_creatordart)
- [`lib/ui/features/launcher/view_models/editor_build_view_model.dart`](#libuifeatureslauncherview_modelseditor_build_view_modeldart)
- [`lib/ui/features/launcher/views/editor_build_splash.dart`](#libuifeatureslauncherviewseditor_build_splashdart)
- [`lib/ui/features/launcher/views/installed_template_widgets.dart`](#libuifeatureslauncherviewsinstalled_template_widgetsdart)
- [`lib/ui/features/launcher/views/launcher_recent_projects_pane.dart`](#libuifeatureslauncherviewslauncher_recent_projects_panedart)
- [`lib/ui/features/launcher/views/launcher_settings_panes.dart`](#libuifeatureslauncherviewslauncher_settings_panesdart)
- [`lib/ui/features/launcher/views/launcher_templates_pane.dart`](#libuifeatureslauncherviewslauncher_templates_panedart)
- [`lib/ui/features/launcher/views/missing_editor_binary_dialog.dart`](#libuifeatureslauncherviewsmissing_editor_binary_dialogdart)
- [`lib/ui/features/launcher/services/project_editor_update.dart`](#libuifeatureslauncherservicesproject_editor_updatedart)
- [`lib/ui/features/launcher/views/project_editor_update_dialog.dart`](#libuifeatureslauncherviewsproject_editor_update_dialogdart)

## `lib/ui/features/launcher/views/create_project_dialog.dart`

### `class CreateProjectDialog`

`CreateProjectDialog`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `CreateProjectViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onSuccess` | `VoidCallback onSuccess` | `onSuccess` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<CreateProjectDialog> createState() => _CreateProjectDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _CreateProjectDialogState`

`_CreateProjectDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/launcher/views/launcher_view.dart`

### `class LauncherView`

`LauncherView`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `LauncherViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<LauncherView> createState() => _LauncherViewState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

**Proje açma.** Her açma (Recent Projects listesi, Open External, yeni proje, `--project <dir>`) `_openProject` üzerinden geçer: resolver karar verir (yerinde, önbellekteki proje editörü, derleme ya da eksik binary sorusu). Bir proje editörü çalıştırılacak ya da derlenecekse ve projenin motor kaynağı kopyası bu Studio'nunkinden başka bir motordan geliyorsa (`LauncherViewModel.projectEditorUpdate`), önce iki sürümü adlandıran shadcn diyaloğu "Update this project's editor?" (`ProjectEditorUpdateDialog`) açılır: **Update** kopyayı derleme splash'ında değiştirir, yeni `engine_version` değerini yazar, yeniden derler ve açar; **Open with the old editor** eskisi gibi devam eder ("Don't ask again for this version" cevabı bu makinede bu motor için saklar); **Cancel** launcher'da kalır. `--update-editor` (kullanıcı Update'i proje editöründe seçtikten sonraki devir) sormadan günceller. Proje başına editörler kapalı ve kod plugin'i yoksa proje yerinde açılır ve `engine_version` bu Studio'nun sürümü olur (Output Log'da tek satır). Kendi başına başlatılan proje editörü önce bu makinede en son başlayan Lumina Studio'yu (`LuminaStudioRecord`) okur; motoru kopyadan farklıysa aynı soruyu sorar: Update projeyi `--update-editor` ile o Studio'ya devreder, Cancel ona döner, Open with the old editor eski-derleme kontrolüne geçer.

### `class _LauncherViewState`

`_LauncherViewState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/launcher/view_models/create_project_view_model.dart`

### `class CreateProjectViewModel`

`CreateProjectViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `launcherVM` | `LauncherViewModel launcherVM` | `launcherVM` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectRepo` | `ProjectRepository projectRepo` | `projectRepo` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String get name` | `name` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `location` | `String get location` | `location` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `template` | `String get template` | `template` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `validationError` | `String? get validationError` | `validationError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeProject` | `LuminaProject? get activeProject` | `activeProject` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isCreating` | `bool get isCreating` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `currentStep` | `ProjectCreationStep? get currentStep` | `currentStep` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `progress` | `double get progress` | `progress` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `progressLabel` | `String get progressLabel` | `progressLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `processOutput` | `List<String> get processOutput` | `processOutput` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `creationError` | `String? get creationError` | `creationError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `updateName` | `void updateName(String val)` | Mevcut verileri veya durumu günceller. |
| `updateLocation` | `void updateLocation(String val)` | Mevcut verileri veya durumu günceller. |
| `updateTemplate` | `void updateTemplate(String val)` | Mevcut verileri veya durumu günceller. |
| `validateProjectName` | `static String? validateProjectName(String name)` | `validateProjectName` işlemini gerçekleştirir. |
| `validateLocation` | `static String? validateLocation(String location)` | `validateLocation` işlemini gerçekleştirir. |
| `createProject` | `Future<void> createProject()` | Yeni bir `Project` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

## `lib/ui/features/launcher/view_models/launcher_view_model.dart`

### `class LauncherTemplate`

`LauncherTemplate`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `description` | `String description` | `description` alanını (field/property) ve ilişkili veriyi saklar. |
| `icon` | `IconData icon` | `icon` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LauncherViewModel`

`LauncherViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `configDir` | `Directory? configDir` | `configDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultProjectsDir` | `static String get defaultProjectsDir` | `defaultProjectsDir` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedTabIndex` | `int get selectedTabIndex` | İlgili aktör veya varlığı seçili duruma getirir. |
| `themeMode` | `ThemeMode get themeMode` | `themeMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `projectRepo` | `ProjectRepository get projectRepo` | `projectRepo` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `defaultProjectsDirectory` | `String get defaultProjectsDirectory` | `defaultProjectsDirectory` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `recentProjects` | `List<RecentProjectEntry> get recentProjects` | `recentProjects` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isCreating` | `bool get isCreating` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `projectName` | `String get projectName` | `projectName` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `projectPath` | `String get projectPath` | `projectPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeProject` | `LuminaProject? get activeProject` | `activeProject` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `engineVersion` | `String get engineVersion` | `engineVersion` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `engineDisplayVersion` | `String get engineDisplayVersion` | `engineDisplayVersion` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `resolvedConfigDir` | `Directory get resolvedConfigDir` | `resolvedConfigDir` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `loadSettings` | `Future<void> loadSettings()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `saveSettings` | `Future<void> saveSettings()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `setTab` | `void setTab(int index)` | `Tab` parametresini günceller ve sisteme uygular. |
| `setThemeMode` | `Future<void> setThemeMode(ThemeMode mode)` | `ThemeMode` parametresini günceller ve sisteme uygular. |
| `toggleTheme` | `Future<void> toggleTheme(bool isDark)` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `setDefaultProjectsDirectory` | `Future<void> setDefaultProjectsDirectory(String path)` | `DefaultProjectsDirectory` parametresini günceller ve sisteme uygular. |
| `loadRecentProjects` | `Future<void> loadRecentProjects()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `updateProjectName` | `void updateProjectName(String val)` | Mevcut verileri veya durumu günceller. |
| `updateProjectPath` | `void updateProjectPath(String val)` | Mevcut verileri veya durumu günceller. |
| `openProject` | `Future<LuminaProject?> openProject(RecentProjectEntry entry)` | `openProject` işlemini gerçekleştirir. |
| `openExternal` | `Future<LuminaProject?> openExternal(String lmprojectPath)` | `openExternal` işlemini gerçekleştirir. |
| `renameProject` | `Future<void> renameProject(RecentProjectEntry entry, String newName)` | `renameProject` işlemini gerçekleştirir. |
| `duplicateProject` | `Future<void> duplicateProject(RecentProjectEntry entry)` | `duplicateProject` işlemini gerçekleştirir. |
| `removeFromHub` | `Future<void> removeFromHub(RecentProjectEntry entry)` | Belirtilen `FromHub` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `deleteFromDisk` | `Future<void> deleteFromDisk(RecentProjectEntry entry)` | Belirtilen `FromDisk` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `locateProject` | `Future<LuminaProject?> locateProject(RecentProjectEntry entry, String ne...` | `locateProject` işlemini gerçekleştirir. |
| `revealInFileManager` | `Future<void> revealInFileManager(RecentProjectEntry entry)` | `revealInFileManager` işlemini gerçekleştirir. |
| `updatePrompts` | `late final ProjectEditorUpdatePrompts updatePrompts` | "Don't ask again for this version" cevapları, bu makinede proje başına (launcher'ın config klasörü). |
| `projectEditorUpdate` | `Future<EditorEngineUpdate?> projectEditorUpdate(String projectDir) async` | Projenin editörüne bu Studio'nun motoruna güncelleme önerilmeli mi: motor kaynağı kopyası başka bir motordan geliyor ve kullanıcı bu motoru atlamayı seçmemiş. Karşılaştırmayı loglar. |
| `dismissProjectEditorUpdate` | `void dismissProjectEditorUpdate(String projectDir, EditorEngineUpdate update)` | "Don't ask again for this version": [update] motoru bu makinede [projectDir] için bir daha önerilmez. |
| `recordEngineVersion` | `Future<LuminaProject> recordEngineVersion(LuminaProject project, String projectDir, {String? version}) async` | [version] değerini (varsayılan: bu Studio'nun `LuminaRelease.displayVersion` değeri) projenin `engine_version` alanına yazar, değiştiyse bir satır loglar; bu değeri taşıyan [project] döner. Yerinde açma yolu kullanır. |
| `projectEditorBuild` | `EditorBuildViewModel projectEditorBuild(String projectName, String projectDir, List<LuminaPluginDescriptor> plugins, {EditorEngineUpdate? update})` | Splash arkasındaki derleme. [update] önce projenin motor kaynağı kopyasını bu Studio'nunkiyle değiştirir (`syncSource`); kopya yerine geçince yeni `engine_version` değerini yazar ve iki sürümü loglar. |

## `lib/ui/features/details/services/multi_edit_service.dart`

### `class MultiEditComponentProperty`

`MultiEditComponentProperty`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `propertyId` | `String propertyId` | `propertyId` alanını (field/property) ve ilişkili veriyi saklar. |
| `descriptor` | `PropertyDescriptor descriptor` | `descriptor` alanını (field/property) ve ilişkili veriyi saklar. |
| `isMixed` | `bool isMixed` | `isMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `commonValue` | `dynamic commonValue` | `commonValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `isMixedPerAxis` | `List<bool>? isMixedPerAxis` | `isMixedPerAxis` alanını (field/property) ve ilişkili veriyi saklar. |
| `commonVector` | `List<double>? commonVector` | `commonVector` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MultiEditComponentBlock`

`MultiEditComponentBlock`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `componentType` | `String componentType` | `componentType` alanını (field/property) ve ilişkili veriyi saklar. |
| `componentName` | `String componentName` | `componentName` alanını (field/property) ve ilişkili veriyi saklar. |
| `isMixedEnabled` | `bool isMixedEnabled` | `isMixedEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `commonEnabled` | `bool? commonEnabled` | `commonEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `properties` | `List<MultiEditComponentProperty> properties` | `properties` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MultiEditView`

`MultiEditView`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isMixedVisible` | `bool isMixedVisible` | `isMixedVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `commonVisible` | `bool? commonVisible` | `commonVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `isMixedLocked` | `bool isMixedLocked` | `isMixedLocked` alanını (field/property) ve ilişkili veriyi saklar. |
| `commonLocked` | `bool? commonLocked` | `commonLocked` alanını (field/property) ve ilişkili veriyi saklar. |
| `locationMixed` | `List<bool> locationMixed` | `locationMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `locationCommon` | `List<double> locationCommon` | `locationCommon` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotationMixed` | `List<bool> rotationMixed` | `rotationMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotationCommon` | `List<double> rotationCommon` | `rotationCommon` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleMixed` | `List<bool> scaleMixed` | `scaleMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleCommon` | `List<double> scaleCommon` | `scaleCommon` alanını (field/property) ve ilişkili veriyi saklar. |
| `components` | `List<MultiEditComponentBlock> components` | `components` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MultiEditService`

`MultiEditService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `computeMultiEditView` | `static MultiEditView computeMultiEditView(List<EditorActorNode> actors)` | `computeMultiEditView` işlemini gerçekleştirir. |

## `lib/ui/features/details/models/component_property_registry.dart`

### `enum PropertyEditorType`

`PropertyEditorType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class PropertyDescriptor`

`PropertyDescriptor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `group` | `String group` | `group` alanını (field/property) ve ilişkili veriyi saklar. |
| `editor` | `PropertyEditorType editor` | `editor` alanını (field/property) ve ilişkili veriyi saklar. |
| `unit` | `String? unit` | `unit` alanını (field/property) ve ilişkili veriyi saklar. |
| `min` | `double? min` | `min` alanını (field/property) ve ilişkili veriyi saklar. |
| `max` | `double? max` | `max` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultValue` | `dynamic defaultValue` | `defaultValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `enumValues` | `List<String>? enumValues` | `enumValues` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `String? type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |

### `class ComponentDescriptor`

`ComponentDescriptor`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `type` | `String type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `icon` | `IconData? icon` | `icon` alanını (field/property) ve ilişkili veriyi saklar. |
| `sections` | `List<String> sections` | `sections` alanını (field/property) ve ilişkili veriyi saklar. |
| `properties` | `List<PropertyDescriptor> properties` | `properties` alanını (field/property) ve ilişkili veriyi saklar. |

### `class ComponentPropertyRegistry`

`ComponentPropertyRegistry`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

## `lib/ui/features/details/models/editor_component_node.dart`

### `class EditorComponentNode`

`EditorComponentNode`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Yapıcı Metotlar (Constructors):**
- `EditorComponentNode.fromMap(Map<String, dynamic> map)`: `EditorComponentNode.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `String type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `properties` | `Map<String, dynamic> properties` | `properties` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

## `lib/ui/features/details/services/blueprint_collision_overrides.dart`

### `abstract final class BlueprintCollisionOverrides`

A placed Blueprint actor's per-instance collision, as the level Details edits it: instance overrides of a component's Collision section.

The class's collision components come from its Blueprint document; an edit stores an [EditorComponentNode] in the actor's `components` (saved in the level `.lmas` `metadata.actors[]`) with the component's type and name, [componentIdKey] naming the Blueprint component, and the collision JSON keys. Play-In-Editor applies it to the instance's built component ([applyTo]); keys an override lacks keep the class's values.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `componentIdKey` | `static const String componentIdKey` | The override node property naming the Blueprint component it overrides. |
| `overrideId` | `static String overrideId(String actorId, String componentId)` | The id of [actorId]'s override of Blueprint component [componentId]. |
| `isOverride` | `static bool isOverride(EditorComponentNode node)` | Whether [node] is an instance override (not a component of its own). |
| `documentOf` | `static LuminaBlueprintDocument? documentOf(String projectDir, String path)` | The Blueprint document at [path] (project-relative) in [projectDir]; cached until the file changes. Null when it cannot be read. |
| `collisionComponentsOf` | `static List<LuminaBlueprintComponent> collisionComponentsOf(EditorActorNode actor, String projectDir)` | The collision components of placed Blueprint [actor]'s class, in document order; empty for any other actor. |
| `overrideOf` | `static EditorComponentNode? overrideOf(EditorActorNode actor, String componentId)` | [actor]'s override of Blueprint component [componentId], if any. |
| `collisionOf` | `static Map<String, dynamic> collisionOf(EditorActorNode actor, LuminaBlueprintComponent component)` | The collision JSON the level Details shows for [component] of [actor]: the class's keys with the instance override on top. |
| `physicsComponentsOf` | `static List<LuminaBlueprintComponent> physicsComponentsOf(EditorActorNode actor, String projectDir)` | The components of placed Blueprint [actor]'s class with a Physics section: collision shapes and static meshes. |
| `physicsOf` | `static Map<String, dynamic> physicsOf(EditorActorNode actor, LuminaBlueprintComponent component)` | The physics JSON the level Details shows for [component] of [actor]: the class's `physics` map with the instance override's keys on top. |
| `baseOf` | `static LuminaCollisionProfile baseOf(LuminaBlueprintDocument? doc, LuminaBlueprintComponent component)` | [component]'s built-in setup in [doc]: a Character's root capsule is Pawn, anything else lumina's default. |
| `applyTo` | `static int applyTo(LuminaBlueprintInstance instance, EditorActorNode actor)` | Applies [actor]'s overrides to [instance]'s built collision components (Play-In-Editor, before the actor is registered). |

## `lib/ui/features/details/widgets/actor_material_section.dart`

### `class ActorMaterialSection`

Details panelinin, yerleştirilmiş bir mesh ya da temel şekil için Material bölümü: onun her bölümüne çizilen materyal varlığı (seviye görünümünde, Play'de ve derlenmiş oyunda), paylaşılan aranabilir [AssetPickerSelect] ile seçilir; temizlemek mesh'e kendi materyallerini geri verir. Her seçim tek bir geri alma adımıdır. Çizilemeyen bir materyal (derlenmemiş, bulunamamış) seçicinin altında belirtilir.

**Yapıcı Metotlar (Constructors):**

- `const ActorMaterialSection({super.key, required this.viewModel, required this.actor})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `actor` | `final EditorActorNode actor` |  |
| `appliesTo` | `static bool appliesTo(EditorActorNode actor)` | Yerleştirilmiş bir mesh ya da temel şekil (`LuminaLevelActorMaterial.actorTypes`), Blueprint değil. |

## `lib/ui/features/details/widgets/actor_mesh_section.dart`

### `class ActorMeshSection`

The Details panel's Static Mesh (or Skeletal Mesh) section of a placed mesh actor: the mesh it renders, picked with the shared searchable [AssetPickerSelect]; a pick swaps the geometry as one undo step.

**Yapıcı Metotlar (Constructors):**

- `const ActorMeshSection({super.key, required this.viewModel, required this.actor})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `actor` | `final EditorActorNode actor` |  |
| `appliesTo` | `static bool appliesTo(EditorActorNode actor)` | A placed mesh: it renders a mesh asset of the project (not a Blueprint, primitive or landscape, which draw something else). |


## `lib/ui/features/details/widgets/actor_shape_section.dart`

### `class ActorShapeSection`

Temel bir şeklin (`Primitive`) Details panelindeki Shape bölümü: aktörün `LuminaProceduralMeshComponent`'inde tutulan şekli, boyutu ve rengi. Boyutlar santimetredir ve üstündeki Transform gibi Z yukarıdır: Size Z yükseklik, Size Y Y boyunca derinliktir (düzlem X ve Y'yi kullanır). Her onay bir geri alma adımıdır ve şekli viewport'ta yeniden çizer.

**Yapıcı Metotlar (Constructors):**

- `const ActorShapeSection({super.key, required this.viewModel, required this.actor})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `actor` | `final EditorActorNode actor` |  |
| `componentType` | `static const String componentType` | `LuminaProceduralMeshComponent`. |
| `shapes` | `static const List<String> shapes` | `box`, `plane`, `sphere`, `cylinder`. |
| `appliesTo` | `static bool appliesTo(EditorActorNode actor)` | Yerleştirilmiş temel bir şekil (Blueprint değil). |


## `lib/ui/features/launcher/services/installed_template_repository.dart`

### `class InstalledGameTemplate`

A game template installed into `<config>/templates/<Folder>/`, usually from the Lumina Marketplace.

The folder is a Lumina project tree in the game template archive format: `template.json` and/or the source project's `.lmproject`, `contents/`, optionally `lib/`, `pubspec.yaml` and a `thumbnail.png`, plus the `LICENSE-<Listing>.txt` notice the installer wrote beside them.

**Yapıcı Metotlar (Constructors):**

- `const InstalledGameTemplate({required this.folderName, required this.dir, required this.title, required this.description, required this.engineVersion, this.thum...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `folderName` | `final String folderName` | The folder under `<config>/templates/`. |
| `dir` | `final String dir` | The absolute template folder. |
| `title` | `final String title` |  |
| `description` | `final String description` |  |
| `engineVersion` | `final String engineVersion` | The engine version the template was made with (`template.json` `engine_version`, else the `.lmproject`'s), or ''. |
| `thumbnailPath` | `final String? thumbnailPath` | The screenshot shown on the template's card, or null. |
| `lmprojectPath` | `final String? lmprojectPath` | The source project's manifest, or null for a template that ships only `template.json` and `contents/`. |
| `record` | `final MarketplaceInstallRecord? record` | The Marketplace install record (`<config>/marketplace/licenses.json`), or null for a folder that was copied in by hand. |
| `declaredPublisher` | `final String declaredPublisher` | `template.json` `publisher` / `version`, for hand-copied templates. |
| `declaredVersion` | `final String declaredVersion` |  |
| `id` | `String get id` | What the Create Project dialog selects (`marketplace:<Folder>`). |
| `publisher` | `String get publisher` |  |
| `version` | `String get version` |  |
| `licenseLabel` | `String get licenseLabel` | The listing's licenses as SPDX ids (`CC-BY-4.0 + MIT`), or ''. |
| `licenseNotice` | `File? get licenseNotice` | The `LICENSE-<Listing>.txt` notice the installer wrote, when it exists. |
| `canUninstall` | `bool get canUninstall` | Only Marketplace installs are removed from the launcher (through [MarketplaceInstaller.uninstall]); a hand-copied folder is the user's. |

### `class InvalidTemplateFolder`

A template folder that was skipped, and why.

**Yapıcı Metotlar (Constructors):**

- `const InvalidTemplateFolder(this.path, this.reason)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `reason` | `final String reason` |  |

### `class InstalledTemplateRepository`

Lists the game templates installed under `<config>/templates/`.

A folder is a template when it passes the shared game template check (`checkGameTemplate` in lumina_marketplace_shared), the same rules the Marketplace server applies to an upload: files under `contents/`, a `template.json` with a title or exactly one `.lmproject` that parses, an existing thumbnail when one is named, no platform or build folders, and a pubspec whose path dependencies stay inside the template. Anything else is left out of the list and reported once in the Output Log with the check's reasons.

**Yapıcı Metotlar (Constructors):**

- `InstalledTemplateRepository({required this.dirs, EngineLoggerService? logger})`
- `factory InstalledTemplateRepository.forConfigDir(Directory? configDir)`: [MarketplaceInstallDirs.resolve] for [configDir] (null: the editor's config directory).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `dirs` | `final MarketplaceInstallDirs dirs` |  |
| `thumbnailNames` | `static const List<String> thumbnailNames` |  |
| `invalid` | `List<InvalidTemplateFolder> get invalid` | The folders the last [scan] skipped. |
| `scan` | `List<InstalledGameTemplate> scan()` | The valid templates, sorted by title. |
| `byId` | `InstalledGameTemplate? byId(String id)` |  |
| `uninstall` | `bool uninstall(InstalledGameTemplate template)` | Removes a Marketplace-installed [template] and its licenses.json entry. |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kInstalledTemplateIdPrefix` | `const String kInstalledTemplateIdPrefix` | The `id` prefix of a folder template in the Create Project dialog; the built-in templates use their bare catalog ids (`blank_3d`, …). |

## `lib/ui/features/launcher/services/project_editor_resolver.dart`

### `sealed class ProjectEditorDecision`

What the launcher does with a project on Open.

**Yapıcı Metotlar (Constructors):**

- `const ProjectEditorDecision()`

### `class OpenInPlace`

The stock editor opens it: per-project editors are off (Editor Preferences) and the project has no code plugins.

**Yapıcı Metotlar (Constructors):**

- `const OpenInPlace()`

### `class ExecCached`

The project's editor is built and current: exec it.

**Yapıcı Metotlar (Constructors):**

- `const ExecCached(this.entry)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `entry` | `final EditorBuildEntry entry` |  |

### `class NeedsBuild`

The host exists but its fingerprint is not cached (stale or never built here): build it behind the splash.

**Yapıcı Metotlar (Constructors):**

- `const NeedsBuild(this.reason, this.plugins)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `reason` | `final String reason` | "editor source changed (lumina_ui)", "plugin lumina_plugin_miniai changed", …. |
| `plugins` | `final List<LuminaPluginDescriptor> plugins` |  |
| `pluginNames` | `List<String> get pluginNames` |  |

### `class MissingBinary`

Code plugins are enabled but the host is absent (an older project, a fresh clone, another OS): ask before building.

**Yapıcı Metotlar (Constructors):**

- `const MissingBinary(this.reason, this.plugins)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `reason` | `final String reason` |  |
| `plugins` | `final List<LuminaPluginDescriptor> plugins` |  |
| `pluginNames` | `List<String> get pluginNames` |  |

### `class ProjectEditorResolver`

Decides how a project opens: in place, in its cached project editor, or after a build. Scans the same plugin roots as the editor.

**Yapıcı Metotlar (Constructors):**

- `ProjectEditorResolver({String? engineRoot, EditorBuildCache? cache, EditorHostGeneratorService? generator, this.mode = 'release', String? platform, Future<Flutt...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` |  |
| `cache` | `final EditorBuildCache cache` |  |
| `generator` | `final EditorHostGeneratorService generator` |  |
| `mode` | `final String mode` | `release` (default) or `debug` (Editor Preferences → Project Editor Builds). |
| `platform` | `final String platform` |  |
| `flutterInfo` | `final Future<FlutterToolInfo> Function() flutterInfo` |  |
| `scanRoots` | `final List<PluginScanRoot> Function(String projectDir) scanRoots` |  |
| `everyProject` | `final bool everyProject` | Every project opens in its own project editor, code plugins or not (Editor Preferences › Project Editor Builds; default on). Off, a plugin-less project opens in the stock editor. |
| `currentEngine` | `final Future<EngineIdentity> Function() currentEngine` | Çalışan motorun kimliği (varsayılan: [engineRoot] konumundan okunur). |
| `enabledCodePlugins` | `Future<List<LuminaPluginDescriptor>> enabledCodePlugins(String projectDir) async` | The project's enabled plugins that contribute editor code, as found on the plugin roots (an enabled plugin that is not installed is skipped). |
| `inputsFor` | `Future<EditorHostInputs> inputsFor(String projectDir, List<LuminaPluginDescriptor> plugins) async` | The inputs of the project's host build (see `fingerprint`). |
| `resolve` | `Future<ProjectEditorDecision> resolve(String projectDir, {bool rebuild = false}) async` |  |
| `staleReason` | `static String staleReason(String hostDir, Map<String, String> current)` | What changed since the host's last build, from its stamp. |
| `readStamp` | `static Map<String, dynamic>? readStamp(String hostDir)` |  |
| `staleSelfCheck` | `Future<List<String>> staleSelfCheck(String projectDir, String compiledFingerprint) async` | A project editor's self-check: the reasons its compiled-in [compiledFingerprint] no longer matches the project's current inputs (empty when current, or when this is not a built project editor). |
| `engineUpdate` | `Future<EditorEngineUpdate?> engineUpdate(String projectDir, {EngineIdentity? current, String? engineRoot}) async` | Projenin motor kaynağı kopyası [engineRoot] (varsayılan: bu resolver'ınki, çalışan Studio) konumundaki, kimliği [current] (varsayılan: [currentEngine] ya da [engineRoot] konumundan okunur) olan motordan başka bir motordan mı geliyor; motorunu kaydetmeyen eski damgalarda projenin `engine_version` değeri yedektir. Kopya yoksa ya da günselse null. |

## `lib/ui/features/launcher/services/template_project_creator.dart`

### `class TemplateProjectCreator`

Creates a project from an installed folder template, the way [ProjectRepository.createProjectStream] creates one from a built-in template:

1. `flutter create` into `<location>/<name>/` (the platform folders a template archive does not carry); 2. the template's project tree — `contents/`, `lib/` and the rest, minus its own manifests and notice — copied over it; 3. its `pubspec.yaml` (dependencies, assets) renamed to the new package, with the engine as a git dependency, linked to this machine's engine checkout by [ProjectEngineLink] (a gitignored `pubspec_overrides.yaml` and the native hooks' settings); 4. every `package:<template>/` import in `lib/` renamed; 5. `flutter pub get`; 6. the manifest written as `<name>.lmproject` (the source project's settings, input, maps and modes under the new name), and the normal code generation: `lib/main.dart` (its game class is named after the project), the Blueprint registry and any level without generated code; 7. the template's license notice kept in `contents/Marketplace/` (`LICENSE-<Listing>.txt` and a `licenses.json` entry), and the project added to the recent projects.

A failure removes the half-created folder, as the built-in pipeline does.

**Yapıcı Metotlar (Constructors):**

- `TemplateProjectCreator(this.projectRepo, {DartCodeGeneratorService? codegen, EngineLoggerService? logger})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectRepo` | `final ProjectRepository projectRepo` |  |
| `create` | `Stream<ProjectCreationProgress> create({required InstalledGameTemplate template, required String projectName,...` |  |
| `rewritePubspec` | `static String rewritePubspec(String yaml, {required String name})` | [yaml] with `name: [name]` and the `lumina:` dependency in its git form (replacing a template's `path:` one, added when missing) and no `hooks:` block; every other dependency and asset entry is kept. |
| `renamePackageImports` | `static int renamePackageImports(String projectDir, String from, String to)` | Rewrites `package:[from]/` to `package:[to]/` in every Dart file under `lib/` and `test/` of [projectDir]; returns how many files changed. |

## `lib/ui/features/launcher/view_models/editor_build_view_model.dart`

### `enum EditorBuildSplashState`

**Değerler:**

- `running`
- `failed`
- `succeeded`
- `cancelled`

### `class EditorBuildViewModel`

Drives [EditorBuildSplash] from a real [EditorBuildJob]: the status line, the progress bar, the log tail and the failure state.

**Yapıcı Metotlar (Constructors):**

- `EditorBuildViewModel({required this.projectName, required this.projectDir, required this.startBuild, this.engineVersion = '0.0.1', this.hasPlugins = true,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectName` | `final String projectName` |  |
| `projectDir` | `final String projectDir` |  |
| `engineVersion` | `final String engineVersion` |  |
| `startBuild` | `final EditorBuildJob Function() startBuild` | Starts (and on Retry restarts) the build. |
| `hasPlugins` | `final bool hasPlugins` | Whether the project enables code plugins: a failed build then offers "Open without plugins", otherwise "Open in this editor". |
| `logTailLines` | `static const int logTailLines` |  |
| `state` | `EditorBuildSplashState get state` |  |
| `phase` | `EditorBuildPhase get phase` |  |
| `fraction` | `double get fraction` |  |
| `percent` | `int get percent` |  |
| `logPath` | `String? get logPath` |  |
| `outcome` | `EditorBuildOutcome? get outcome` |  |
| `showLog` | `bool get showLog` |  |
| `logTail` | `List<String> get logTail` |  |
| `statusText` | `String get statusText` | `NN% - <phase message>`, or the failure line. |
| `start` | `Future<EditorBuildOutcome> start()` | Completes with the outcome of the current run. |
| `toggleLog` | `void toggleLog()` |  |
| `cancel` | `void cancel()` |  |
| `openLogFile` | `Future<void> openLogFile() async` | Opens the full build log with the OS's default handler. |

## `lib/ui/features/launcher/views/editor_build_splash.dart`

### `class EditorBuildSplash`

The project editor build splash — key art, "Lumina Studio", the engine and project line, a `NN% - <phase>` status line and a 2 px bar along the bottom edge; a log tail and Cancel on hover; on failure `Open without plugins` / `Retry` / `Open log file` / `Close`.

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildSplash({super.key, required this.viewModel, required this.onSucceeded, required this.onOpenWithoutPlugins, required this.onClose, this.manageWi...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final EditorBuildViewModel viewModel` |  |
| `onSucceeded` | `final void Function(EditorBuildViewModel viewModel) onSucceeded` | The build finished: exec the project editor. |
| `onOpenWithoutPlugins` | `final VoidCallback onOpenWithoutPlugins` | Open the project in this (stock) editor without its code plugins. |
| `onClose` | `final VoidCallback onClose` | Back to the launcher (Cancel, or Close after a failure). |
| `manageWindow` | `final bool manageWindow` | Switch the OS window to the 720×400 frameless splash window (off in widget tests, which have no native window). |
| `manageNativeWindow` | `static bool manageNativeWindow` | Whether the launcher lets the splash resize the native window. A smoke run that records the splash inside its fixed-size test window turns it off; widget tests (no native window) never manage it. |
| `windowSize` | `static const Size windowSize` |  |
| `splashArt` | `static const String splashArt` |  |

## `lib/ui/features/launcher/views/installed_template_widgets.dart`

### `class InstalledTemplateThumbnail`

The pieces the launcher shows an installed game template with — its screenshot, license badge and the "publisher · version" line — in the Create Project dialog ([InstalledTemplateOption]) and the Templates pane ([InstalledTemplateCard]). The template's screenshot, or a placeholder icon when it has none.

**Yapıcı Metotlar (Constructors):**

- `const InstalledTemplateThumbnail({super.key, required this.template, required this.width, required this.height, this.radius = 4})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `template` | `final InstalledGameTemplate template` |  |
| `width` | `final double width` |  |
| `height` | `final double height` |  |
| `radius` | `final double radius` |  |

### `class InstalledTemplateLicenseBadge`

The listing's licenses (`CC-BY-4.0 + MIT`); the tooltip names them and says when attribution is required.

**Yapıcı Metotlar (Constructors):**

- `const InstalledTemplateLicenseBadge({super.key, required this.template})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `template` | `final InstalledGameTemplate template` |  |

### `class InstalledTemplateOption`

A selectable installed template row in the Create Project dialog, with Uninstall for Marketplace installs.

**Yapıcı Metotlar (Constructors):**

- `const InstalledTemplateOption({super.key, required this.template, required this.selected, required this.onTap, required this.onUninstall,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `template` | `final InstalledGameTemplate template` |  |
| `selected` | `final bool selected` |  |
| `onTap` | `final VoidCallback onTap` |  |
| `onUninstall` | `final VoidCallback onUninstall` |  |

### `class InstalledTemplateCard`

An installed template's card in the launcher's Templates pane.

**Yapıcı Metotlar (Constructors):**

- `const InstalledTemplateCard({super.key, required this.template, required this.width, required this.onUse, required this.onUninstall,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `template` | `final InstalledGameTemplate template` |  |
| `width` | `final double width` |  |
| `onUse` | `final VoidCallback onUse` |  |
| `onUninstall` | `final VoidCallback onUninstall` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `installedTemplateByline` | `String installedTemplateByline(InstalledGameTemplate t)` | `by <publisher> · v<version>`, leaving out what is unknown. |

## `lib/ui/features/launcher/views/launcher_recent_projects_pane.dart`

### `class LauncherRecentProjectsPane`

The launcher's Recent Projects pane: the searchable project cards with their Open / Locate… actions and context menu (rename, reveal, duplicate, remove from the hub, delete from disk).

**Yapıcı Metotlar (Constructors):**

- `const LauncherRecentProjectsPane({super.key, required this.viewModel, required this.onOpenProject, required this.onNewProject,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final LauncherViewModel viewModel` |  |
| `onOpenProject` | `final void Function(LuminaProject project, String projectDir) onOpenProject` | Opens [project] (in [projectDir]) in the editor. |
| `onNewProject` | `final VoidCallback onNewProject` | Opens the Create Project dialog (the empty state's button). |

## `lib/ui/features/launcher/views/launcher_settings_panes.dart`

### `class LauncherEngineVersionsPane`

The launcher's Engine Versions pane: the running engine, its render backend and the graphics device in use.

**Yapıcı Metotlar (Constructors):**

- `const LauncherEngineVersionsPane({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final LauncherViewModel viewModel` |  |

### `class LauncherSettingsPane`

The launcher's Settings pane: the default projects directory and the graphics device.

**Yapıcı Metotlar (Constructors):**

- `const LauncherSettingsPane({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final LauncherViewModel viewModel` |  |

### `class LauncherSettingRow`

One label / value row of a launcher info card.

**Yapıcı Metotlar (Constructors):**

- `const LauncherSettingRow({super.key, required this.label, required this.value})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `label` | `final String label` |  |
| `value` | `final String value` |  |

## `lib/ui/features/launcher/views/launcher_templates_pane.dart`

### `class LauncherTemplatesPane`

The launcher's Templates pane: the built-in templates (`GameTemplateCatalog`) and, below them, the game templates installed from the Marketplace. "Use Template" opens the Create Project dialog with that template selected.

**Yapıcı Metotlar (Constructors):**

- `const LauncherTemplatesPane({super.key, required this.viewModel, required this.onUseTemplate})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final LauncherViewModel viewModel` |  |
| `onUseTemplate` | `final void Function(String templateId) onUseTemplate` | Opens the Create Project dialog on the template with this id. |

## `lib/ui/features/launcher/views/missing_editor_binary_dialog.dart`

### `enum MissingBinaryChoice`

The answer to [MissingEditorBinaryDialog].

**Değerler:**

- `buildAndOpen`
- `openWithoutPlugins`
- `cancel`

### `class MissingEditorBinaryDialog`

A project with code plugins whose editor was never built on this machine (an older project, a fresh clone, another OS): the modules are missing or built with a different engine version, so it offers to rebuild them now.

**Yapıcı Metotlar (Constructors):**

- `const MissingEditorBinaryDialog({super.key, required this.projectName, required this.pluginNames, required this.reason})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectName` | `final String projectName` |  |
| `pluginNames` | `final List<String> pluginNames` |  |
| `reason` | `final String reason` |  |
| `show` | `static Future<MissingBinaryChoice> show(BuildContext context, {required String projectName, required List<Stri...` |  |

## `lib/ui/features/launcher/services/project_editor_update.dart`

### `class ProjectEditorUpdatePrompts`

Kullanıcının "Update this project's editor?" sorusunu "Don't ask again for this version" ile cevapladığı projeler, bu makinede: proje klasörü başına bir daha sorulmayacak motor ([EngineIdentity.key]). Daha yeni bir motor yeniden sorar. Config klasöründe tutulur (`project_editor_updates.json`), paylaşılan `.lmproject` içinde asla.

**Yapıcı Metotlar (Constructors):**

- `ProjectEditorUpdatePrompts({this.configDir})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `configDir` | `final Directory? configDir` |  |
| `fileName` | `static const String fileName` | `project_editor_updates.json`. |
| `projectKey` | `static String projectKey(String projectDir)` | Yolun yazılışı ne olursa olsun proje klasörü başına tek anahtar. |
| `isDismissed` | `bool isDismissed(String projectDir, EngineIdentity engine)` | Kullanıcı [projectDir] için [engine] hakkında sorulmamasını istedi mi. |
| `dismiss` | `void dismiss(String projectDir, EngineIdentity engine)` | [projectDir] için [engine] bir daha sorulmaz. |

### `class LuminaStudioRecord`

Bu makinede en son başlayan Lumina Studio (stok editör): çalıştırılabilir dosyası, motor kökü ve motoru. Kendi başına başlatılan proje editörü, daha yeni bir Studio kurulu mu diye bakmak ve projeyi ona devretmek için okur (config klasöründe `lumina_studio.json`).

**Yapıcı Metotlar (Constructors):**

- `const LuminaStudioRecord({required this.executable, required this.engineRoot, required this.engine})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `executable / engineRoot / engine` | `final String executable · final String engineRoot · final EngineIdentity engine` |  |
| `read` | `static LuminaStudioRecord? read({Directory? configDir})` | Kayıt; yoksa ya da okunamıyorsa null. |
| `write` | `void write({Directory? configDir})` |  |
| `recordThisStudio` | `static Future<LuminaStudioRecord?> recordThisStudio({Directory? configDir}) async` | Çalışan stok editörü kaydeder, gerçekten oysa: gerçek `lumina_ui` binary'si, proje editörü değil, test çalışması değil. Launcher açılırken çağırır. |

## `lib/ui/features/launcher/views/project_editor_update_dialog.dart`

### `enum ProjectEditorUpdateChoice`

[ProjectEditorUpdateDialog] cevapları.

**Değerler:**

- `update`
- `openWithOldEditor`
- `cancel`

### `class ProjectEditorUpdateAnswer`

Kullanıcının seçimi ve "Don't ask again for this version" işaretli mi ([ProjectEditorUpdateChoice.openWithOldEditor] için geçerlidir).

**Yapıcı Metotlar (Constructors):**

- `const ProjectEditorUpdateAnswer(this.choice, {this.dontAskAgain = false})`

### `class ProjectEditorUpdateDialog`

Editörü, onu açandan başka bir Lumina ile kurulmuş proje: "Update this project's editor?" — "<Project> was set up with Lumina <old>; this Studio is Lumina <new>. Update the project's editor to Lumina <new>? Its copy of the engine source is replaced and the editor is rebuilt; edits made inside .lumina/editor are lost." Update, Open with the old editor, Cancel ve "Don't ask again for this version" onay kutusu. Yalnızca shadcn_flutter.

**Yapıcı Metotlar (Constructors):**

- `const ProjectEditorUpdateDialog({super.key, required this.projectName, required this.fromLabel, required this.toLabel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `show` | `static Future<ProjectEditorUpdateAnswer> show(BuildContext context, {required String projectName, required String fromLabel, required String toLabel}) async` | Diyaloğu gösterir; cevapsız kapatmak Cancel sayılır. |
| `lumina` | `static String lumina(String label)` | "Lumina 0.0.1-dev.6", ya da olduğu gibi "an older engine". |

---

[Önceki: Ana editör: view model ve servisler (devamı)](main-editor-state-continued.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Eklenti yöneticisi](plugin-manager.md)
