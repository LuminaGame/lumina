[English](../../en/plugins/index.md)

# Editör eklentileri

Lumina Studio eklentilerle genişletilebilir: `lumina_editor_api` üzerinden menü öğeleri, paneller, toolbar butonları, asset tipleri, importer'lar, details özelleştirmeleri ve konsol komutları kaydeden Flutter paketleri. Bu sayfa parçaların nasıl bir araya geldiğini anlatır.

## Parçalar

| Parça | Paket | Görevi |
|---|---|---|
| `LuminaEditorPlugin`, `LuminaEditorContext` ve uzantı tipleri | `lumina_editor_api` | Bir eklentinin karşısına yazıldığı sözleşme ([API referansı](../lumina_editor_api/api-reference.md)). |
| `LuminaPluginDescriptor`, `PluginRepository` | `lumina_core` | `.lmplugin` manifest'lerini parse eder ve eklenti köklerini tarar ([modeller ve repository'ler](../lumina_editor_data/repositories.md)). |
| `PluginRegistryService`, `PluginTemplateGeneratorService`, `PluginHostPatcherService` | `lumina_editor_data` (`PluginHostPatcherService`: `lumina_core`) | Hangi eklentilerin etkin olduğunu çözer, şablonlardan yeni eklentiler üretir ve code plugin'leri bir editor host'una derler ([use case'ler ve servisler](../lumina_editor_data/services.md)). |
| `PluginExtensionRegistry`, `BuiltInEditorPlugin` | `lumina_ui` | Eklentilerin kaydettiği her şeyi toplar ve editörde gösterir ([Uygulama kabuğu ve ortak UI](../lumina_ui/core.md)). |
| Plugin Manager, New Plugin sihirbazı | `lumina_ui` | Eklentileri etkinleştirir, devre dışı bırakır ve oluşturur ([Eklenti yöneticisi](../lumina_ui/plugin-manager.md)). |

`lumina_editor_api`, ayrılmış engine paketleri üzerinden ortak formatları, eklenti süreç/protokol API'lerini ve oyun widget'larını sunar. Bir eklenti `lumina_ui`'a bağımlı olmaz; bu, editör ile eklentileri arasında bir döngü oluştururdu.

## Bir eklentinin yapısı

Bir eklenti, `pubspec.yaml` dosyasının yanında `<ad>.lmplugin` manifest'i bulunan bir Flutter paketidir:

```json
{
  "name": "lumina_plugin_pcg",
  "friendly_name": "Procedural Content Generation",
  "version": "0.1.0",
  "category": "Procedural",
  "license": "MIT",
  "changelog": "CHANGELOG.md",
  "engine_version": ">=0.0.1 <1.0.0",
  "modules": [
    {
      "name": "lumina_plugin_pcg",
      "type": "editor",
      "entry_library": "lib/lumina_plugin_pcg.dart",
      "registration_class": "LuminaPluginPcgPlugin"
    }
  ]
}
```

Manifest `LuminaPluginDescriptor`'a karşılık gelir: ad, görünen ad, sürüm, açıklama, kategori, yazarlar, desteklenen engine sürüm aralığı, diğer eklentilere bağımlılıklar ve modüller. Code modülü olmayan bir eklenti yalnızca içerik (content-only) eklentisidir.

İki alan daha kodun nerede çalışacağını belirler (bkz. [Yalıtılmış eklentiler](#yalıtılmış-eklentiler-kendi-süreci)): `"isolation"`, `"in_process"` (varsayılan) ya da `"process"`, ve editor modülünde `"process_class"`, aynı `entry_library` içindeki `LuminaPluginProcess` alt sınıfı. `"isolation": "process"` diyen bir eklenti bir editor modülünde `process_class` adı vermek zorundadır. O zaman `registration_class` süreç içi UI kabuğudur ve kabuk yoksa (süreç parçası bir `PluginProcessAdapter` olan ya da yalnızca bildirimsel panelleri olan bir eklenti) yazılmayabilir: registrar editör sürecinde onun için hiçbir şey kaydetmez, böylece katkıları asla iki kez kaydedilmez. Süreç içi bir modül `registration_class` adı vermek zorundadır; bilinmeyen bir `isolation` değeri, Dart sınıf adı olmayan ya da eksik bir `process_class` manifest'i bir tarama hatası yapar ve Plugin Manager onu diğer bozuk manifest'ler gibi listeler.

```json
{
  "name": "my_tools",
  "version": "0.1.0",
  "isolation": "process",
  "modules": [
    {
      "name": "my_tools",
      "type": "editor",
      "entry_library": "lib/my_tools.dart",
      "registration_class": "MyToolsPlugin",
      "process_class": "MyToolsProcess"
    }
  ]
}
```

Bir editor modülünün registration sınıfı `LuminaEditorPlugin`'i extend eder. `register(LuminaEditorContext context)` içinde özelliklerini ekler, `unregister` ise bunları yeniden kaldırır:

```dart
class MyPlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'my_plugin';

  @override
  void register(LuminaEditorContext context) {
    context.registerMenuItem('Plugins/My Tools/Run My Tool', myCommand);
    context.registerPanel(myPanel);
    context.registerImporter(myImporter);
  }

  @override
  void unregister(LuminaEditorContext context) {}
}
```

`LuminaEditorContext` şunları kabul eder:

- `Plugins/<Grup>/...` altında ya da eklentinin sahip olduğu bir üst düzey menü altında (`registerMenu`, bir `EditorMenuDescriptor`) menü öğeleri (`registerMenuItem`, bir menü yolu ve bir `EditorCommand`); yerleşik menüler eklenti öğelerini reddeder;
- toolbar butonları (`EditorToolbarButton`) ve level toolbar'ının ya da durum çubuğunun adlandırılmış slot'larında canlı durumlu butonlar (`registerSlotButton`, bir `EditorSlotButton`);
- yerleştirilebilir (dockable) paneller (`EditorPanelDescriptor`, varsayılan dock konumuyla). Sağ dock paneli level editöründe görünür; "Always" açıkken (dock'un iğne butonu, "Show in every editor", ya da Window ▸ *<panel>: Show in Every Editor*) sub-editor'ler dahil her editör sekmesinde, durumu korunan aynı panel olarak görünür. `defaultAlwaysVisible: true` bunu panelin varsayılanı yapar; kullanıcının seçimi panel başına `editor_layout.json` içine kaydedilir;
- asset tipleri (`EditorAssetTypeHandler`: yerleşik ya da özel bir asset tipi, görünen ad ve ikon);
- importer'lar (`EditorImporter`: dosya uzantıları ve bir açıklama; girdi olarak `ImportContext`, çıktı olarak `ImportResult`);
- details özelleştirmeleri (`DetailsCustomization`: bir hedef tip için details panelinde bir bölüm);
- Output Log için konsol komutları (`registerConsoleCommand`);
- Project Settings > Plugins altında sayfalar (`registerProjectSettingsSection`); eklenti uygulanan değerleri `pluginSettings` üzerinden okur.

Context ayrıca eklentiye `panels` (panellerini açma, kapatma ve izleme), `storage` (kullanıcı başına ve açık proje başına kendi JSON deposu) ve `mcp` (editörün MCP araçları: eklentinin kendi araçlarını kaydetme, herhangi bir aracı süreç içinde listeleme ve çağırma; bkz. [MCP araçları API'si](../lumina_editor_api/mcp.md)) verir. Çalışan bir Lumina Studio'da context aynı zamanda açık level'ı sunan bir `LuminaEditorHostContext` ve etkin renk temasını sunan bir `EditorThemeHost`'tur.

## Bulma, etkinleştirme ve yeniden başlatma

Lumina Studio üç tür eklenti kökünü önce proje, sonra kullanıcı, sonra yerleşik (built-in) sırasıyla tarar (önce bulunan eklenti, sonra bulunan aynı adlı eklentiyi geçersiz kılar: bu bilinçli bir davranıştır; info düzeyinde loglanır ve kazanan eklentinin Plugin Manager kartında "Overrides the engine copy" yazar, hiçbir zaman tarama hatası değildir; yalnızca aynı kökün iki klasörünün aynı eklenti adını taşıması hatadır): `<proje>/plugins/`; kullanıcıya özel `~/.local/share/lumina/plugins/` klasörü (Windows'ta `%LOCALAPPDATA%\Lumina\plugins`; `LUMINA_USER_PLUGIN_DIR` bunu değiştirir), Lumina Marketplace ve Plugin Manager'ın Import from Folder / Import from Zip komutları eklentileri buraya kurar; ve engine çalışma alanının bağımlı olduğu eklenti paketleri olan **yerleşik** eklentiler. Yerleşik eklentiler (`lumina_plugin_pcg`, `lumina_plugin_miniai`, `lumina_plugin_trellis_image`) plugins deposunda durur ve commit ile sabitlenmiş `lumina_ui` dev bağımlılıklarıdır; bu yüzden çalışma alanının çözümlenmiş paketlerinden bulunurlar (`LuminaWorkspace.pluginPackageDirs`: `.dart_tool/package_config.json` içinde `<name>.lmplugin` taşıyan her paket): kaynak çalışma alanında (`pubspec_overrides.yaml` üzerinden) yandaki `plugins` checkout'u, release checkout'unda pub önbelleğindeki git checkout'u. Engine'in `plugins/` klasörü (`LUMINA_ENGINE_ROOT`) varsa hâlâ taranır. `PluginRepository` bulduğu her manifest'i okur ve bozuk olanları tarama hatası olarak bildirir; `PluginRegistryService` etkinleştirilmek istenen eklenti kümesini bağımlılıklarına ve engine sürümüne göre çözer ve sorunları bildirir.

Eklentiler **Plugins > Plugin Manager** menüsünden etkinleştirilir. Code plugin'ler editöre derlenir: `EditorHostGeneratorService` onları bir proje editor host'unun `pubspec.yaml` dosyasına ekler (git'ten çözülmüş bir yerleşik eklentiyi engine'in `pubspec.lock` dosyasındaki url, path ve commit ile aynı git bağımlılığı olarak, asla pub önbelleğine giden bir path olarak değil; diğer eklentileri klasörleriyle, ona git üzerinden bağımlı bir eklenti aynı klasörü çözsün diye bir dependency override olarak da) ve etkin her editor modülünü kaydeden `registerAllPlugins` fonksiyonunu ve `"isolation": "process"` diyen her etkin eklentiyi process sınıfına eşleyen `kPluginProcesses` haritasını (`runLuminaEditor`'a `processes` olarak verilir) içeren registrar dosyasını üretir. Bir eklentinin `.lmplugin` dosyası proje editörünün build parmak izine dahildir; `isolation` ya da `process_class` değişince editör yeniden derlenir. Bu yüzden bir code plugin'i etkinleştirmek yeniden başlatma ister ve editör eklenti kayıtlı olarak geri gelir.

## Yalıtılmış eklentiler (kendi süreci)

Bir code plugin normalde editörün içinde çalışır: senkron bir döngü editörü dondurur, eklentinin FFI kütüphanesindeki native bir çökme onu kapatır. `"isolation": "process"` diyen bir eklenti ise riskli yarısını kendi sürecinde çalıştırır: editör kendi çalıştırılabilir dosyasını `--lumina-plugin-process <name>` ile yeniden başlatır, onu denetler (2 sn'de bir sağlık ping'i; üç kaçırılan ping = askıda, öldürülür ve yeniden başlatılır; otomatik yeniden başlatmalar 1 sn, 2 sn ve 4 sn sonra, en fazla üç kez, sonra kullanıcı yeniden başlatana kadar durur) ve süreç ölünce bir `plugin_crash` raporu kaydeder. Editör çalışmaya devam eder.

Böyle bir eklentinin iki yarısı vardır:

| Yarı | Sınıf | Çalıştığı yer | Oraya ait olanlar |
|---|---|---|---|
| Process kısmı | `LuminaPluginProcess` alt sınıfı, manifest'in `process_class`'ı | eklenti süreci | çökebilen, askıda kalabilen ya da bloklayabilen her şey: native (FFI) kütüphaneler, alt süreçler, ağ, ağır CPU işi, dosya üretimi, proxy'lenen level düzenlemeleri, MCP araçları, importer'lar, iş yapan menü komutları |
| UI kabuğu | `LuminaEditorPlugin`, manifest'in `registration_class`'ı | editör | tam widget'lı paneller, sekmeler, asset editörleri ve 3D viewport'lar; native kütüphane tutmaz, süreç başlatmaz, ağır iş yapmaz |

Process kısmı her şeyi `PluginProcessContext` üzerinden veri olarak kaydeder (menü öğeleri, slot düğmeleri, importer'lar, MCP araçları, konsol komutları, bir `PluginViewSpec` ile tarif edilen bildirimsel paneller) ve kabuğa `handle(method, handler)` ile cevap verir. Kabuk ona `context.processChannel(pluginName)` ile ulaşır (`PluginProcessChannel`: `call`, `events`, `progress`, `state`, `restart`). Süreç çalışmazken editör kabuğun panellerini süreç durumu ve bir Restart düğmesiyle örter. Tamamen veriden oluşan bir eklentinin kabuğa hiç ihtiyacı yoktur.

**Proje geçersiz kılması**: bir proje, hata ayıklamak için yalıtılmış bir eklentiyi `.lmproject` `"plugin_isolation": {"<name>": "in_process"}` ile süreç içinde çalışmaya zorlayabilir (`PluginRegistryService.setIsolationOverride`, Plugin Manager). Aynı process kısmı o zaman editörün içinde, bellek içi bir bağlantı üzerinden çalışır. Geçersiz kılma yalnızca süreç içine zorlar: process kısmı olmayan bir eklenti her zaman süreç içinde çalışır. Registrar, geçersiz kılmadan bağımsız olarak manifest'te yalıtılmış her eklentiyi listeler; böylece tek editör build'i iki durumu da karşılar.

## Kernel eklentileri (editör yeniden derlenmeden)

Üç tür kod eklentisi vardır ve yalnızca ikisi proje editörü derlemesi ister:

| Tür | Manifest | Çalıştığı yer | Proje editörü derlemesi |
|---|---|---|---|
| Süreç içi | `registration_class` | editörün içinde | evet; etkinleştirmede, kapatmada ve güncellemede |
| Derlenmiş yalıtılmış | `"isolation": "process"`, `registration_class` + `process_class` | süreç kısmı, yeniden başlatılan editör çalıştırılabilirinde | evet |
| **Kernel** | `"isolation": "process"`, `process_class` + `process_entry`, `registration_class` **yok** | süreci, bir Dart kernel dosyasından Dart VM üzerinde | **hayır** |

Kernel eklentisinin UI kabuğu yoktur: katkılarının hepsi veridir (menü öğeleri, slot düğmeleri, içe aktarıcılar,
konsol komutları, MCP araçları, `PluginViewSpec` panelleri, sürecin açtığı diyaloglar) ya da eklenti içeriğidir
(`can_contain_content`, `content/` klasörü, örneğin editör paneli Widget Blueprint'leri). Hiçbir parçası editöre
derlenmez; bu yüzden `EditorHostGeneratorService.editorCodePlugins` ve registrar'ın `kPluginProcesses` haritası onu
dışarıda bırakır ve proje editörünün parmak izini hiç değiştirmez: kod eklentilerinin hepsi kernel eklentisi olan bir
proje proje editörü derlemeden açılır, karışık bir proje yalnızca derlenmiş eklentileri için derlenir. Bir kernel
eklentisini etkinleştirmek, kapatmak, kurmak, güncellemek ya da kaldırmak derleme ve yeniden başlatma olmadan hemen
geçerli olur.

Editör modülü kernel alanlarını adlandırır (yollar eklenti klasörüne görelidir; klasörden çıkan bir yol tarama
hatasıdır, `process_entry` olmadan `process_kernel` da öyle):

```json
{
  "name": "my_tool",
  "isolation": "process",
  "modules": [{
    "name": "my_tool", "type": "editor", "entry_library": "lib/my_tool.dart",
    "process_class": "MyToolProcess",
    "process_entry": "bin/my_tool_process.dart",
    "process_kernel": "bin/my_tool_process.dill",
    "process_kernel_sdk": "3.13.4"
  }]
}
```

Giriş noktası `Future<void> main(List<String> args) => runPluginProcessEntry(args, MyToolProcess.new);` biçimindedir
ve Flutter'a ya da `dart:ui`'ye ulaşamaz. `tool/pack_plugin.dart` onu paketleyenin Dart SDK'sıyla derler
(`dart compile kernel`), `.dill` dosyasını `.sha256` ile yazar, `process_kernel` ve `process_kernel_sdk` alanlarını
damgalar; giriş kaynağını, `lib/`, `pubspec.yaml`, `pubspec.lock` ve `content/` klasörünü pakete koyar. Bir kernel
yalnızca onu üreten SDK'da çalışır: editör damgayı proje derlemelerinde kullandığı Flutter SDK'sının Dart SDK'sıyla
karşılaştırır; farklıysa (ya da `.dill` yoksa veya VM onu reddederse) girişi bir kez
`<LuminaDataDir>/plugin_kernels/<ad>/<sürüm>/<sdk>/<kaynak özeti>.dill` içine yeniden derler ve sürüm, kaynak ve SDK
aynı kaldıkça onu kullanır. Gelen `.dill` çalışmadan önce `.sha256` dosyasıyla eşleşmelidir. `registration_class`'ı
olmayan bir süreç eklentisi proje tarafından süreç içine zorlanamaz (`inEditorProcessUnavailableReason`). Yeni Eklenti
sihirbazının **Kernel plugin (no editor rebuild)** şablonu (`PluginTemplateType.kernel`) böyle bir eklenti yazar.

Diğer eklentilerin editör panellerine ve kernel'e geçişte kalan eksikleri: gem_x'in yakalama paneli, openxr/metaxr
ayarları, MetaHuman Creator (Viewport öğesinde prosedürel mesh ister), map_generator, trellis ve Unreal içe aktarıcısı
editör panellerine taşınana kadar Flutter kabuklarını korur; openxr derlenmiş yalıtılmış eklenti olarak kalır, çünkü
yerel kütüphanesi bir build hook'tan gelir ve `dart compile kernel` hook çalıştırmaz.

## Eklenti oluşturmak ve yayınlamak

**Plugins > New Plugin**, bir `PluginTemplateSpec` (şablon tipi, ad, görünen ad, yazar, açıklama, kategori, `isolated`) ile `PluginTemplateGeneratorService.generate`'i çağıran ve build edilmeye hazır bir eklenti paketi yazan bir sihirbaz açar. `isolated: true` ile paket yalıtılmış bir eklentidir: `lib/src/<name>_process.dart` (bir menü komutu, bir `ping` handler'ı ve bildirimsel bir panel kaydeden process kısmı; importer şablonunun importer'ı da orada çalışır), panelinden kanal üzerinden `ping` çağıran bir UI kabuğu, her yarı için bir test ve `"isolation": "process"` ile `"process_class"` içeren bir manifest.

Eklentiler marketplace için, eklenti klasöründe `dart run tool/pack_plugin.dart` ile paketlenir; ayrıntılar için plugins repository'sine bakın.

## Örnek eklentiler

[plugins repository'si](https://github.com/LuminaGame/plugins), MIT lisanslı eklentiler barındırır:

- `lumina_plugin_pcg`: prosedürel içerik üretimi (static mesh'leri dağıtan PCG Graph asset'leri ve PCG Volume actor'leri); eklenti API'sinin referans örneği;
- `lumina_plugin_miniai`: proje üzerinde editörün MCP araçlarıyla çalışan bir yapay zeka asistanı paneli.
- `lumina_plugin_trellis_image`: stable-diffusion.cpp ile Qwen Image 2.1 Q4_K_M metinden görsel üretimi ve referans düzenleme; ardından açık görsel onayıyla Trellis 3D üretimi.

### Trellis Image Studio

`trellis_plugin` 0.3+ ve `lumina_plugin_trellis_image` eklentilerini etkinleştirip yeniden başlatın. **Plugins → Trellis Image → Text or Reference to 3D…** menüsünü açın. Windows kurucusu sabitlenmiş Vulkan çalıştırıcısını ve yaklaşık 11 GB model dosyasını sağlama toplamı doğrulaması ve kesilen indirmeleri sürdürme desteğiyle indirir. Referans düzenlemek için editör asset seçicisinden içe aktarılmış bir texture seçin ve istediğiniz değişikliği tarif edin.

**Generate image** incelenebilir bir taslak üretir. **Approve this image & generate 3D**, güncel görselin hash değerini doğrular, Trellis'i kayıtlı kalite ve texture ayarlarıyla başlatır, ilerleme olaylarını izler ve tamamlanan mesh'i kaydetmeden incelemeye açar: etkileşimli bir 3D görünüm (`build3DViewport`; döndürme, kaydırma, yakınlaştırma, `Plugin3DViewportOptions.viewMode` ile Lit / Unlit / Wireframe), üçgen, köşe, boyut ve dosya boyutu, bir **Simplify** bölümü (oran ya da üçgen hedefi, Apply / Revert, önce → sonra; Trellis'in eklenti sürecindeki meshoptimizer sadeleştiricisi, vertex renkleri ve UV'ler korunur) ve **Save to Project** (ad + proje klasörü) / **Regenerate** / **Discard**. Save'den önce projeye hiçbir şey yazılmaz; geçici çıktı Discard'da ve Trellis süreci bittiğinde silinir. Otomatik actor yerleştirmez. **Cancel current job** sahip olunan native işi iptal eder. Native hatalar ve eksik modeller çalışma alanında gösterilir. Diğer platformlarda uyumlu mevcut bir `sd-cli` elle yapılandırılabilir.

Gerçek çalıştırıcı doğrulaması için `LUMINA_QWEN_IMAGE_ROOT` ve `LUMINA_TRELLIS_PLUGIN` değişkenlerini kurulu çalıştırıcı/eklenti klasörlerine ayarlayın; `trellis_plugin` yerel dependency override üzerinden erişilebilir olmalıdır. Ardından `lumina_ui/integration_test/smoke/trellis_image_smoke_test.dart` dosyasını smoke rapor çalıştırıcısıyla çalıştırın. Üretim senaryosu onaydan önce 3D işinin başlamadığını ve Save'den önce hiçbir şeyin kaydedilmediğini doğrular; inceleme senaryosu (`LUMINA_TRELLIS_OUTPUT` gerçek bir Trellis çıktı GLB'sini gösterir) onu Lit, Unlit ve Wireframe'de gösterir, %25'e sadeleştirir ve bir proje klasörüne kaydeder.

## Editör paneli Widget Blueprint'leri

Bir eklenti arayüzünü `content/` klasöründe (`"can_contain_content": true`) editör paneli Widget Blueprint'leri olarak
taşıyabilir: UMG tasarımcısında tasarlanır, editörün Blueprint VM'i çalıştırır, hiçbir Dart derlemesi ya da proje
editörü derlemesi olmadan yerleşir. Bunlardan oluşan yalnızca içerikli bir eklenti yeniden başlatmadan etkinleşir; ağır
işi panellerin çağırdığı ve öğe durumlarını yamaladığı bir süreç kısmında olabilir. New Plugin'in varsayılan şablonu
böyle bir eklentidir. Bkz. [Editör panelleri](../lumina_ui/editor-panels.md).

---

[Önceki: Eklenti süreçleri](../lumina_plugin_process/plugin-processes.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: lumina_ui (Lumina Studio)](../lumina_ui/index.md)
