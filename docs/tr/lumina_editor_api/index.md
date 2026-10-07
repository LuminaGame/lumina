[English](../../en/lumina_editor_api/index.md)

# lumina_editor_api

`lumina_editor_api`, Lumina Studio ile eklentileri arasındaki küçük sözleşme paketidir. `lumina_core`'a (dosya formatları), saf Dart eklenti süreci paketine (`lumina_plugin_process`) ve `lumina_widgets`'a (medya widget'ları ve observable'ların Flutter görünümleri; engine onunla gelir) bağımlıdır, editör uygulamasına asla; böylece eklentiler editör uygulamasının kendisine bağımlı olmadan build edilebilir.

## Mimarideki yeri

Editör (`lumina_ui`) API'yi gerçekler, eklentiler onu kullanır. İkisi de `lumina_editor_api`'ya bağımlıdır; `lumina_editor_api` ise yalnızca `lumina_core`, `lumina_plugin_process` ve `lumina_widgets`'a (ve ikonlar ile widget'lar için `shadcn_flutter`'a) bağımlıdır. Bu, pub bağımlılık grafiğini döngüsüz tutar: bir eklentinin hiçbir zaman editör uygulamasına bağımlı olması gerekmez. New Plugin sihirbazının ürettiği eklentiler de bu pakete bağımlıdır. Eklentilerin nasıl bulunduğu, etkinleştirildiği ve derlenip editöre eklendiği için bkz. [Editör eklentileri](../plugins/index.md).

## Paketin içeriği

- `lib/src/api_types.dart`: `LuminaEditorPlugin`, `LuminaEditorContext` ve bir eklentinin kaydedebileceği tüm uzantı tipleri.
- `lib/src/editor_command.dart`: menü öğelerinin ve toolbar butonlarının arkasındaki eylem olan `EditorCommand`.
- `lib/src/editor_slot_button.dart`, `lib/src/editor_panels.dart`: canlı durumlu slot butonları ve eklenti panellerini açma ve izleme.
- `lib/src/editor_level.dart`: eklentilerin gördüğü haliyle açık level (`changes`'i bir Flutter `Listenable` olan `EditorLevelAccess`; `LuminaEditorHostContext`; `EditorAssetPicker`) ve bir eklenti sürecinin `PluginLevelAccess`'ine ve ondan dönüşümler.
- `lib/src/editor_theme.dart`: editörün renk temasına salt okunur erişim.
- `lib/src/project_settings_section.dart`: Project Settings sayfaları.
- `lib/src/process/`: eklenti süreçlerinin Flutter tarafı: kabuğun `PluginProcessChannel`'ı (`PluginProcessChannel.ofLink`, `.detached`), `PluginProcessAdapter`, `pluginIconOf` / `iconDataOf` ve `lumina_core`'un saf değişim tipleri ile Flutter'ınkiler arasındaki yeniden export edilen adaptörler (`asValueListenable()`, `asListenable()`, `asObservable()`, `asChangeSignal()`; bu paketin yeniden export ettiği medya oynatıcıları gibi `lumina_widgets` içindedir).
- `lib/testing.dart`: Flutter `channel`'ıyla birlikte loopback test host'u.

[lumina_plugin_process](../lumina_plugin_process/index.md) paketinden değiştirilmeden yeniden dışa aktarılanlar (bir eklenti yalnızca `package:lumina_editor_api/lumina_editor_api.dart`'ı import etmeye devam eder): level anlık görüntü ve tanım tipleri, `PluginStorage` ve `EditorProjectInfo`, `LuminaPluginCrashReporter`, MCP tipleri ve `EditorMcp`, eklenti süreci API'si ve çalışma zamanı ve tel protokolü (`lumina_plugin_protocol`).

## Referans sayfaları

| Sayfa | Kapsam |
|---|---|
| [API referansı](api-reference.md) | Plugin, context, komutlar, menüler, slot butonları, paneller, asset tipleri, importer'lar, level erişimi, tema, depolama, ayarlar. |
| [MCP araçları API'si](mcp.md) | MCP araç, şema, risk ve onay tipleri; eklentiler için editörün MCP araçları. |
| [lumina_plugin_process](../lumina_plugin_process/index.md) | Süreç tarafının saf Dart paketi, değişim tipleri ve loopback test host'u. |
| [Eklenti süreçleri](../lumina_plugin_process/plugin-processes.md) | Bir eklentinin riskli kısmını kendi sürecinde çalıştırmak: süreç API'si, yaşam döngüsü ve çıkış kodları, editör proxy'leri (level, depolama, MCP) ve mevcut, yalnızca veriyle çalışan eklentiler için adaptör. |

---

[Önceki: Veri katmanı: modeller ve repository'ler (devamı)](../lumina_editor_data/repositories-continued.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: API referansı](api-reference.md)
