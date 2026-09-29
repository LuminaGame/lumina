[English](../../en/plugins/index.md)

# Editör eklentileri

Lumina Studio eklentilerle genişletilebilir: `lumina_editor_api` üzerinden menü öğeleri, paneller, toolbar butonları, asset tipleri, importer'lar, details özelleştirmeleri ve konsol komutları kaydeden Flutter paketleri. Bu sayfa parçaların nasıl bir araya geldiğini anlatır.

## Parçalar

| Parça | Paket | Görevi |
|---|---|---|
| `LuminaEditorPlugin`, `LuminaEditorContext` ve uzantı tipleri | `lumina_editor_api` | Bir eklentinin karşısına yazıldığı sözleşme ([API referansı](../lumina_editor_api/api-reference.md)). |
| `LuminaPluginDescriptor`, `PluginRepository` | `lumina` (veri katmanı) | `.lmplugin` manifest'lerini parse eder ve eklenti köklerini tarar ([modeller ve repository'ler](../lumina/data-models.md)). |
| `PluginRegistryService`, `PluginTemplateGeneratorService`, `PluginHostPatcherService` | `lumina` (veri katmanı) | Hangi eklentilerin etkin olduğunu çözer, şablonlardan yeni eklentiler üretir ve code plugin'leri bir editor host'una derler ([use case'ler ve servisler](../lumina/data-services.md)). |
| `PluginExtensionRegistry`, `BuiltInEditorPlugin` | `lumina_ui` | Eklentilerin kaydettiği her şeyi toplar ve editörde gösterir ([Uygulama kabuğu ve ortak UI](../lumina_ui/core.md)). |
| Plugin Manager, New Plugin sihirbazı | `lumina_ui` | Eklentileri etkinleştirir, devre dışı bırakır ve oluşturur ([Eklenti yöneticisi](../lumina_ui/plugin-manager.md)). |

`lumina_editor_api` yalnızca `lumina`'ya bağımlıdır. Bu yüzden bir eklenti hiçbir zaman `lumina_ui`'a bağımlı olmaz; olsaydı editör ile eklentileri arasında bir döngü oluşurdu.

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
- yerleştirilebilir (dockable) paneller (`EditorPanelDescriptor`, varsayılan dock konumuyla);
- asset tipleri (`EditorAssetTypeHandler`: yerleşik ya da özel bir asset tipi, görünen ad ve ikon);
- importer'lar (`EditorImporter`: dosya uzantıları ve bir açıklama; girdi olarak `ImportContext`, çıktı olarak `ImportResult`);
- details özelleştirmeleri (`DetailsCustomization`: bir hedef tip için details panelinde bir bölüm);
- Output Log için konsol komutları (`registerConsoleCommand`);
- Project Settings > Plugins altında sayfalar (`registerProjectSettingsSection`); eklenti uygulanan değerleri `pluginSettings` üzerinden okur.

Context ayrıca eklentiye `panels` (panellerini açma, kapatma ve izleme), `storage` (kullanıcı başına ve açık proje başına kendi JSON deposu) ve `mcp` (editörün MCP araçları: eklentinin kendi araçlarını kaydetme, herhangi bir aracı süreç içinde listeleme ve çağırma; bkz. [MCP araçları API'si](../lumina_editor_api/mcp.md)) verir. Çalışan bir Lumina Studio'da context aynı zamanda açık level'ı sunan bir `LuminaEditorHostContext` ve etkin renk temasını sunan bir `EditorThemeHost`'tur.

## Bulma, etkinleştirme ve yeniden başlatma

Lumina Studio üç eklenti kökünü tarar: engine'in `plugins/` klasörü, `<proje>/plugins/` ve kullanıcıya özel `~/.local/share/lumina/plugins/` klasörü (`LUMINA_USER_PLUGIN_DIR` bunu değiştirir); Lumina Marketplace de eklentileri buraya kurar. `PluginRepository` bulduğu her manifest'i okur ve bozuk olanları tarama hatası olarak bildirir; `PluginRegistryService` etkinleştirilmek istenen eklenti kümesini bağımlılıklarına ve engine sürümüne göre çözer ve sorunları bildirir.

Eklentiler **Plugins > Plugin Manager** menüsünden etkinleştirilir. Code plugin'ler editöre derlenir: `PluginHostPatcherService` onları bir proje editor host'unun `pubspec.yaml` dosyasına ekler ve etkin her editor modülünü kaydeden `registerAllPlugins` fonksiyonunu içeren `lib/generated/plugin_registrar.dart` dosyasını üretir. Bu yüzden bir code plugin'i etkinleştirmek yeniden başlatma ister ve editör eklenti kayıtlı olarak geri gelir.

## Eklenti oluşturmak ve yayınlamak

**Plugins > New Plugin**, bir `PluginTemplateSpec` (şablon tipi, ad, görünen ad, yazar, açıklama, kategori) ile `PluginTemplateGeneratorService.generate`'i çağıran ve build edilmeye hazır bir eklenti paketi yazan bir sihirbaz açar.

Eklentiler marketplace için, eklenti klasöründe `dart run tool/pack_plugin.dart` ile paketlenir; ayrıntılar için plugins repository'sine bakın.

## Örnek eklentiler

[plugins repository'si](https://github.com/LuminaGame/plugins), şablon olarak da kullanılabilen MIT lisanslı iki eklenti barındırır:

- `lumina_plugin_pcg`: prosedürel içerik üretimi (static mesh'leri dağıtan PCG Graph asset'leri ve PCG Volume actor'leri); eklenti API'sinin referans örneği;
- `lumina_plugin_miniai`: proje üzerinde editörün MCP araçlarıyla çalışan bir yapay zeka asistanı paneli.

---

[Önceki: MCP araçları API'si](../lumina_editor_api/mcp.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: lumina_ui (Lumina Studio)](../lumina_ui/index.md)
