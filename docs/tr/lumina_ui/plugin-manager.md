[English](../../en/lumina_ui/plugin-manager.md)

# Eklenti yöneticisi

Eklentileri listeleyen, etkinleştiren ve devre dışı bırakan Plugin Manager penceresi ve şablondan eklenti paketi üreten New Plugin sihirbazı. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/plugin_manager/views/new_plugin_wizard.dart`](#libuifeaturesplugin_managerviewsnew_plugin_wizarddart)
- [`lib/ui/features/plugin_manager/views/plugin_manager_view.dart`](#libuifeaturesplugin_managerviewsplugin_manager_viewdart)
- [`lib/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart`](#libuifeaturesplugin_managerview_modelsplugin_manager_view_modeldart)

## `lib/ui/features/plugin_manager/views/new_plugin_wizard.dart`

### `class NewPluginWizardDialog`

`NewPluginWizardDialog`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `rootContext` | `BuildContext rootContext` | `rootContext` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `PluginManagerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `generatorService` | `PluginTemplateGeneratorService? generatorService` | `generatorService` alanını (field/property) ve ilişkili veriyi saklar. |
| `configFilePath` | `String? configFilePath` | `configFilePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectRoot` | `Directory? projectRoot` | `projectRoot` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorApiRoot` | `Directory? editorApiRoot` | `editorApiRoot` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<NewPluginWizardDialog> createState() => _NewPluginWizardDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _NewPluginWizardDialogState`

`_NewPluginWizardDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _TemplateTile`

`_TemplateTile`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `description` | `String description` | `description` alanını (field/property) ve ilişkili veriyi saklar. |
| `icon` | `IconData icon` | `icon` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSelected` | `bool isSelected` | `isSelected` alanını (field/property) ve ilişkili veriyi saklar. |
| `onTap` | `VoidCallback onTap` | `onTap` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/plugin_manager/views/plugin_manager_view.dart`

### `class PluginManagerView`

`PluginManagerView`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `PluginManagerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _CategorySidebar`

`_CategorySidebar`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `PluginManagerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _CategoryRow`

`_CategoryRow`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `count` | `int count` | `count` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSelected` | `bool isSelected` | `isSelected` alanını (field/property) ve ilişkili veriyi saklar. |
| `onTap` | `VoidCallback onTap` | `onTap` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _PluginCardList`

`_PluginCardList`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `PluginManagerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _PluginCard`

`_PluginCard`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `entry` | `PluginEntry entry` | `entry` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `PluginManagerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _ScanErrorsSection`

`_ScanErrorsSection`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `errors` | `List<PluginScanError> errors` | `errors` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _PluginDetailsPane`

`_PluginDetailsPane`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `PluginManagerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _PluginIcon`

`_PluginIcon`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `iconFile` | `File? iconFile` | `iconFile` alanını (field/property) ve ilişkili veriyi saklar. |
| `size` | `double size` | `size` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart`

### `class PluginManagerViewModel`

`PluginManagerViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `registryService` | `PluginRegistryService registryService` | `registryService` alanını (field/property) ve ilişkili veriyi saklar. |
| `searchQuery` | `String get searchQuery` | `searchQuery` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `searchQuery` | `searchQuery(String value)` | `searchQuery` işlemini gerçekleştirir. |
| `selectedCategory` | `String get selectedCategory` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedGroup` | `String get selectedGroup` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectCategory` | `void selectCategory(String group, String category)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedEntry` | `PluginEntry? get selectedEntry` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedEntry` | `selectedEntry(PluginEntry? entry)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `entries` | `List<PluginEntry> get entries` | `entries` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `installedCount` | `int get installedCount` | `installedCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `builtInCount` | `int get builtInCount` | `builtInCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `totalCount` | `int get totalCount` | `totalCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `enabledCount` | `int get enabledCount` | `enabledCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `scanErrors` | `List<PluginScanError> get scanErrors` | `scanErrors` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `categoryCounts` | `Map<String, int> get categoryCounts` | `categoryCounts` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `refresh` | `Future<void> refresh()` | `refresh` işlemini gerçekleştirir. |
| `resolve` | `PluginResolution resolve(Set<String> wantedEnabled)` | `resolve` işlemini gerçekleştirir. |

---

[Önceki: Launcher ve details](launcher-and-details.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Kaynak kontrolü](source-control.md)
