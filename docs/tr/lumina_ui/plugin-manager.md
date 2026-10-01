[English](../../en/lumina_ui/plugin-manager.md)

# Eklenti yöneticisi

Eklentileri listeleyen, etkinleştiren, devre dışı bırakan, içe aktaran ve kaldıran Plugin Manager penceresi ve şablondan eklenti paketi üreten New Plugin sihirbazı. Dosya yolları `lumina_ui/` paket dizinine görelidir.

## Yerleşik eklentiler

**BUILT-IN**, engine ile gelen eklentileri listeler: engine çalışma alanının çözümlediği eklenti paketleri (plugins deposundan, commit ile sabitlenmiş `lumina_ui` dev bağımlılıkları olan `lumina_plugin_pcg` ve `lumina_plugin_miniai`); `editorPluginScanRoots` (`lib/ui/core/services/user_plugin_dir.dart`) bunları `.dart_tool/package_config.json` üzerinden bulur. Kaynak çalışma alanında yandaki `plugins` checkout'u (`pubspec_overrides.yaml`), release checkout'unda `flutter pub get`'in pub önbelleğine koyduğu git checkout'larıdır. Yerleşik bir eklenti, diğer her eklenti gibi, anahtarıyla proje başına etkinleştirilir ve devre dışı bırakılır: anahtar projenin `.lmproject` dosyasındaki `enabled_plugins` listesini yazar, kartta **Restart required** görünür ve yeniden başlatma bandı çıkar, projenin editor host'u da ona bağımlı olacak şekilde (engine'in sabitlediği aynı git bağımlılığıyla; bkz. [Eklentiler](../plugins/index.md)) yeniden üretilir, böylece **Restart Editor** proje editörünü onunla yeniden derler. Yerleşik eklentiler kapalı gelir: manifest'leri `enabled_by_default` ayarlamaz, çünkü her biri proje editörünün yeniden derlenmesini gerektiren bir code plugin'dir. Yerleşik bir eklenti Plugin Manager'dan kaldırılamaz ya da düzenlenemez (engine checkout'una aittir; ayrıntılar paneli bunu söyler); aynı adlı bir kullanıcı eklentisi (örneğin zip'ten içe aktarılmış daha yeni bir sürüm) onun yerini alır.

## Yüklenemeyen eklenti

Bir proje editörüne derlenmiş code plugin'ler editör açılırken, projenin kayıtlı layout'u yüklendikten sonra kaydolur (bir eklenti `register` içinde panellerinin görünürlüğünü okuyabilir ya da değiştirebilir). `register`'ı hata fırlatan bir eklenti yüklenmez: hatadan önce kaydettikleri kaldırılır, hata eklentinin adıyla Output Log'a yazılır (kaynak `Plugins`) ve kartında ipucu hatayı gösteren bir **Issue** rozeti çıkar (`PluginIssueType.registrationFailed`). Editör ve diğer eklentiler her zamanki gibi yüklenir.

## Eklenti içe aktarma

Liste başlığında **New Plugin**'in yanındaki **Import from Folder** ve **Import from Zip**, bir eklentiyi kopyalayarak kullanıcıya özel eklenti klasörüne (`UserPluginDir.resolve()`; Marketplace de eklentileri buraya kurar) kurar; eklenti seçildiği yerden asla bağlanmaz (link). İkisi de sistem seçicisini açar ve hiçbir şey yazmadan önce doğrular:

- `<name>.lmplugin` manifesti, marketplace paket kurallarıyla (`lumina_marketplace_shared` içindeki `checkPluginPackage`) ve editörün kendi yükleyicisiyle (`PluginRepository.loadInternal`);
- **zip**, `tool/pack_plugin.dart`'ın yazdığı marketplace eklenti paketi biçiminde okunur: her girdi güvenli bir göreli yol olmalı (`isSafeRelativePath`: `..`, mutlak yol, sürücü harfi ve ters eğik çizgi yok), sembolik bağlantı yok, yalnızca marketplace izin listesindeki dosyalar, tekrar yok, en fazla 10.000 girdi ve açılmış hâlde 1 GB; tek bir üst klasör varsa eklentinin adını taşımalı; lisans ve changelog sorunları zip'i reddeder;
- **klasör**, `.dart_tool/`, `.git/`, `.idea/`, `.vscode/`, `node_modules/`, kökteki `build/` ve `coverage/` ile `pubspec_overrides.yaml` olmadan kopyalanır; sembolik bağlantılar bir uyarıyla dışarıda kalır; lisans ve changelog bulguları yalnızca uyarıdır.

Kullanıcı klasöründe aynı adlı bir eklenti zaten varsa **Replace / Cancel** sorulur (Replace klasörün tamamını değiştirir; yazma başarısız olursa önceki kopya geri gelir). Aynı adlı bir proje eklentisi içe aktarmayı reddeder, çünkü kullanıcı kopyasını gizler. Aynı adlı bir yerleşik (built-in) eklentinin yerini, her proje için, bir uyarıyla kullanıcı kopyası alır. Kurulumdan sonra eklenti kökleri yeniden taranır ve yeni eklenti seçilir; etkinleştirmek ayrı bir adımdır.

## Eklenti kaldırma

USER ya da PROJECT bir eklentinin ayrıntılar panelinde **Remove** düğmesi vardır (yerleşik eklentide yoktur; engine checkout'una aittir). Remove önce, hiçbir şey silinmeden, silinecek her şeyi listeleyen bir onay penceresi (`plugin_remove_dialog`) açar:

- eklenti klasörü, dosya sayısı ve boyutu; **sembolik bağlantı ya da Windows junction** olan bir klasör için (kaynak checkout'unu `mklink /J` ile bağlayan geliştirici): "Linked from <target>; only the link is removed" — yalnızca bağlantı silinir, asla izlenmez, gösterdiği klasör bütün dosyalarını korur;
- bir USER eklentisi bu makinedeki her projeden kaldırılır; bir PROJECT eklentisi bu projenin `plugins/` klasöründen;
- Marketplace'in kurduğu bir eklenti (editörün `marketplace/licenses.json` dosyasında `installedTo` değeri bu klasör olan bir plugin kaydı) Marketplace'in kaldırma yolundan (`MarketplaceInstaller.removeInstall`) geçer, lisans kaydı da silinir;
- açık projede etkinse: devre dışı bırakılır (`.lmproject` içindeki `enabled_plugins`), ona bağımlı etkin eklentiler de (adlarıyla) devre dışı kalır, projenin editor host'u anahtardaki gibi yeniden üretilir ve bir code plugin'in kaldırılması yeniden başlatma bandını gösterir; bu editör oturumunun kaydettiği bir eklenti editör yeniden başlayana kadar etkin kalır (`EditorViewModel.isPluginLoaded`);
- daha düşük öncelikli bir kökte aynı adlı bir eklenti (kullanıcı kopyasının yerini aldığı yerleşik eklenti ya da bir proje eklentisinin altındaki kullanıcı eklentisi) devre dışı olarak yeniden yerine geçer ve seçilir;
- **Also delete its saved data** (işaretsiz): kullanıcıya özel `plugin_data/<name>/` (`PluginDataDir`) ve açık projenin `.lumina/plugins/<name>/` klasörü, boyutlarıyla; yalnızca var olan klasörler listelenir. Diğer projelerin verisine dokunulmaz.

Kaldırma işlemseldir (`FolderInstall.remove`): klasör önce yanında `.<name>.removing` adına taşınır, ancak sonra silinir; böylece kilitli bir dosya (Windows'ta açık bir dosya ya da yüklenmiş bir DLL) hiçbir şey silinmeden işlemi durdurur; pencere açık kalır, neyin silinip neyin silinmediğini listeler ve projede hiçbir şey değişmez. Kayıtlı veri yalnızca eklentinin kendisi silindikten sonra silinir. Tarama kökleri nokta ile başlayan klasörleri atlar, böylece kenara alınmış bir klasör asla eklenti olarak listelenmez. Ardından eklenti kökleri yeniden taranır (`EditorViewModel.rescanPlugins`, bekleyen bir yeniden başlatma bandını korur) ve seçim listedeki komşuya geçer. MCP aracı `remove_plugin` aynısını yapar; `dry_run: true` silinecekler listesini döndürür.

**Bu sayfada:**

- [`lib/ui/features/plugin_manager/views/new_plugin_wizard.dart`](#libuifeaturesplugin_managerviewsnew_plugin_wizarddart)
- [`lib/ui/features/plugin_manager/views/plugin_manager_view.dart`](#libuifeaturesplugin_managerviewsplugin_manager_viewdart)
- [`lib/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart`](#libuifeaturesplugin_managerview_modelsplugin_manager_view_modeldart)
- [`lib/ui/features/plugin_manager/views/plugin_import_dialogs.dart`](#libuifeaturesplugin_managerviewsplugin_import_dialogsdart)
- [`lib/ui/features/plugin_manager/services/plugin_importer.dart`](#libuifeaturesplugin_managerservicesplugin_importerdart)
- [`lib/ui/core/services/folder_install.dart`](#libuicoreservicesfolder_installdart)
- [`lib/ui/features/plugin_manager/views/plugin_remove_dialog.dart`](#libuifeaturesplugin_managerviewsplugin_remove_dialogdart)
- [`lib/ui/features/plugin_manager/services/plugin_remover.dart`](#libuifeaturesplugin_managerservicesplugin_removerdart)

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
| `onPluginsChanged` | `Future<void> Function()? onPluginsChanged` | Bir içe aktarma eklenti klasörlerini değiştirdikten sonra çalışır (editör `EditorViewModel.rescanPlugins`'i bağlar); yoksa kayıt defteri yenilenir. |
| `folderPicker` / `zipPicker` | `Future<String?> Function()? folderPicker` | Import from Folder / Import from Zip seçicileri; null ise sistem diyaloğu açılır (testler ve smoke'lar `EditorViewModel.pluginFolderPicker` / `pluginZipPicker` ile gerçek dosyalara yönlendirir). |
| `importing` | `bool get importing` | Bir içe aktarma doğrulanıyor veya kopyalanıyor (bu sırada içe aktarma düğmeleri devre dışıdır). |
| `importPlugin` | `Future<PluginImportResult> importPlugin(PluginImportSource source, String path)` | `path`'teki klasörü veya zip'i doğrular ve kullanıcı eklenti klasörüne kopyalar; `alreadyInstalled` sonucu `confirmReplace` veya `cancelImport` bekler; kurulan eklenti listelenir ve seçilir. |
| `confirmReplace` | `Future<PluginImportResult> confirmReplace(PluginImportResult pending)` | Replace: bekleyen eklentiyi kurulu kopyanın yerine kurar. |
| `cancelImport` | `void cancelImport(PluginImportResult pending)` | Cancel: bekleyen içe aktarmanın hazırladıklarını siler. |
| `isPluginLoaded` | `bool Function(String name)? isPluginLoaded` | Bu editör oturumunun bir eklentiyi kaydedip kaydetmediği (editör `EditorViewModel.isPluginLoaded`'ı bağlar); kaldırma penceresi eklentinin yeniden başlatmaya kadar etkin kaldığını söyler. |
| `removerFactory` | `PluginRemover Function()? removerFactory` | Bir kaldırma için `PluginRemover`'ı kurar (testler geçici veri ve Marketplace klasörlerine yönlendirir). |
| `removing` | `bool get removing` | Bir kaldırma sürüyor (bu sırada Remove devre dışıdır). |
| `planRemoval` | `PluginRemovalPlan planRemoval(PluginEntry entry)` | Bir kullanıcı ya da proje eklentisini kaldırmanın neyi silip neyi değiştireceği, hiçbir şey silinmeden; yerleşik eklenti için `ArgumentError`. |
| `removePlugin` | `Future<PluginRemovalResult> removePlugin(PluginRemovalPlan plan, {bool deleteData = false})` | Kaldırır (istenirse kayıtlı verisiyle); klasör silinince etkin bir eklenti bağımlılarıyla (cascade) devre dışı bırakılır, kökler yeniden taranır ve seçim geri gelen aynı adlı eklentiye, yoksa komşuya geçer. Duran bir kaldırma projede hiçbir şeyi değiştirmez. |

## `lib/ui/features/plugin_manager/views/plugin_import_dialogs.dart`

| Fonksiyon | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `startPluginImport` | `Future<void> startPluginImport(BuildContext context, PluginManagerViewModel vm, PluginImportSource source)` | Import from Folder / Import from Zip: seçer, içe aktarır, kullanıcı klasöründe zaten olan bir eklenti için Replace / Cancel sorar (`plugin_import_replace_dialog`), sonra sonucu gösterir (`plugin_import_done_dialog` ya da her sorunu listeleyen `plugin_import_error`). |

## `lib/ui/features/plugin_manager/services/plugin_importer.dart`

### `class PluginImporter`

Bir eklenti klasörünü veya eklenti paketi zip'ini doğrular ve kullanıcı eklenti klasörüne kopyalar (bkz. [Eklenti içe aktarma](#eklenti-içe-aktarma)).

| Metot / Getter | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `PluginImporter` | `PluginImporter({Directory? userPluginDir, Directory? stagingRoot, List<LuminaPluginDescriptor> existing = const []})` | Hedef klasör (varsayılan `UserPluginDir.resolve()`), zip'in önce açıldığı yer (varsayılan sistem temp) ve ad çakışmaları için taranmış eklentiler. |
| `inspectFolder` / `inspectZip` | `Future<PluginImportResult> inspectFolder(String path)` | Kullanıcı klasörüne yazmadan doğrular: `PluginImportCandidate` ile `ready` ya da her sorunla `invalid`. Zip bir hazırlık (staging) klasörüne açılır. |
| `install` | `Future<PluginImportResult> install(PluginImportCandidate candidate, {bool replace = false})` | Adayı `FolderInstall.replace` ile `<user plugin dir>/<name>/` altına kopyalar: `installed`, `alreadyInstalled` (`replace` yoksa), `conflict` (aynı adlı proje eklentisi) veya `failed` (önceki kopya geri yüklenir). |
| `importFolder` / `importZip` | `Future<PluginImportResult> importFolder(String path)` | Önce doğrular, sonra kurar. |
| `discard` / `discardCandidate` | `void discard(PluginImportResult result)` | Bir zip içe aktarmasının hazırladıklarını siler (Cancel). |

`PluginImportSource` `folder` veya `zip`; `PluginImportStatus` `ready`, `installed`, `alreadyInstalled`, `conflict`, `invalid` veya `failed`; `PluginImportResult` durumu, adayı, `installedDir`, `existingDir`, `messages` ve `warnings`'i taşır.

## `lib/ui/core/services/folder_install.dart`

### `class FolderInstall`

Marketplace kurucusu ile eklenti içe aktarmanın paylaştığı işlemsel (transactional) klasör kurulumu.

| Metot / Getter | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `replace` | `T replace<T>(Directory dest, T Function() write, {String tag = 'previous'})` | Var olan `dest`'i kenara alır (`.<name>.<tag>`), `write`'ı çalıştırır, sonra eski kopyayı siler ya da `write` hata verirse geri yükler. |
| `moveAside` / `dropAside` / `restore` | `Directory? moveAside(Directory dest, {String tag})` | `replace`'in üç adımı; işlem içinde daha fazlasını yapan çağıranlar için. |
| `copyTree` / `copyFiles` | `void copyTree(Directory from, Directory to)` | Bir klasörü ya da göreli yol → dosya eşlemesini kopyalar. |
| `remove` | `FolderRemoval remove(Directory dir, {String tag = 'removing'})` | Bir klasörü yarısını bırakmadan kaldırır: sembolik bağlantı ya da junction bağlantı olarak silinir (asla izlenmez); klasör önce `.<name>.<tag>` adına taşınır, sonra silinir, böylece başarısız bir taşıma (kilitli bir dosya) hiçbir şey silmez. `FolderRemoval`: `removed`, `link`, `leftovers` (kenara alınan klasörde kalan dosyalar), `error` ve `complete`. |
| `describe` | `String describe(FileSystemException e)` | Bir dosya sistemi hatası tek satırda (işletim sistemi mesajı ve yol). |

## `lib/ui/features/plugin_manager/views/plugin_remove_dialog.dart`

| Fonksiyon | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `confirmPluginRemoval` | `void confirmPluginRemoval(BuildContext context, PluginManagerViewModel vm, PluginEntry entry)` | Ayrıntılar panelinin Remove'u: silinecekleri listeleyen onay penceresi (`plugin_remove_dialog`; bkz. [Eklenti kaldırma](#eklenti-kaldırma)), veri onay kutusu (`plugin_remove_data`), Cancel (`plugin_remove_cancel`) / Remove (`plugin_remove_confirm`); tamamlanamayan bir kaldırmada pencere açık kalır ve neyin silinip neyin silinmediğini gösterir (`plugin_remove_error`, Close `plugin_remove_close`). |
| `formatPluginBytes` | `String formatPluginBytes(int bytes)` | B / KB / MB / GB. |

## `lib/ui/features/plugin_manager/services/plugin_remover.dart`

### `class PluginRemover`

Bir kullanıcı ya da proje eklentisini diskten kaldırır; yerleşik eklentiyi asla.

| Metot / Getter | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `PluginRemover` | `PluginRemover({Directory? pluginDataDir, MarketplaceInstallDirs? marketplaceDirs})` | Kullanıcıya özel eklenti veri klasörü (varsayılan `PluginDataDir.resolve()`) ve Marketplace kurulum klasörleri (varsayılan `MarketplaceInstallDirs.resolve()`). |
| `plan` | `PluginRemovalPlan plan(PluginEntry entry, {required List<PluginEntry> entries, required List<PluginScanRoot> roots, String? projectDir, bool loaded = false})` | Kaldırmanın silecekleri: klasör, bağlantı hedefi, dosyalar, baytlar, etkinlik durumu ve etkin bağımlılar, Marketplace kaydı, geri gelecek aynı adlı eklenti, var olan veri klasörleri. Yerleşik eklenti için `ArgumentError`. |
| `remove` | `PluginRemovalResult remove(PluginRemovalPlan plan, {bool deleteData = false})` | Klasörü siler (`FolderInstall.remove`, Marketplace kurulumu için `MarketplaceInstaller.removeInstall`), istenirse sonra veri klasörlerini. Projede hiçbir şeyi değiştirmez. |

`PluginRemovalPlan` (`toJson` ile; `remove_plugin` dry run'ı) `name`, `displayName`, `origin`, `pluginDir`, `linkTarget`, `fileCount`, `bytes`, `enabled`, `contentOnly`, `dependents`, `loaded`, `marketplaceRecord`, `revealedOrigin` / `revealedDir`, `data` (`PluginDataFolder`: `kind` user / project, `dir`, `fileCount`, `bytes`) ve `projectDir` taşır. `PluginRemovalResult`: `removed`, `removedPaths`, `notRemoved` (`<path>: <reason>`), `disabled` ve `restartRequired`.

---

[Önceki: Launcher ve details](launcher-and-details.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Kaynak kontrolü](source-control.md)
