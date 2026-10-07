[English](../../en/lumina_editor_api/index.md)

# lumina_editor_api

`lumina_editor_api`, Lumina Studio ile eklentileri arasındaki küçük sözleşme paketidir. Yalnızca `lumina`'ya bağımlıdır; böylece eklentiler editör uygulamasının kendisine bağımlı olmadan build edilebilir.

## Mimarideki yeri

Editör (`lumina_ui`) API'yi gerçekler, eklentiler onu kullanır. İkisi de `lumina_editor_api`'ya bağımlıdır; `lumina_editor_api` ise yalnızca `lumina`'ya (ve ikonlar ile widget'lar için `shadcn_flutter`'a) bağımlıdır. Bu, pub bağımlılık grafiğini döngüsüz tutar: bir eklentinin hiçbir zaman editör uygulamasına bağımlı olması gerekmez. New Plugin sihirbazının ürettiği eklentiler de bu pakete bağımlıdır. Eklentilerin nasıl bulunduğu, etkinleştirildiği ve derlenip editöre eklendiği için bkz. [Editör eklentileri](../plugins/index.md).

## Paketin içeriği

- `lib/src/api_types.dart`: `LuminaEditorPlugin`, `LuminaEditorContext` ve bir eklentinin kaydedebileceği tüm uzantı tipleri.
- `lib/src/editor_command.dart`: menü öğelerinin ve toolbar butonlarının arkasındaki eylem olan `EditorCommand`.
- `lib/src/editor_slot_button.dart`, `lib/src/editor_panels.dart`: canlı durumlu slot butonları ve eklenti panellerini açma ve izleme.
- `lib/src/editor_level.dart`: eklentilerin gördüğü haliyle açık level (`EditorLevelAccess`, `LuminaEditorHostContext`).
- `lib/src/editor_theme.dart`: editörün renk temasına salt okunur erişim.
- `lib/src/plugin_storage.dart`, `lib/src/project_settings_section.dart`: eklentiye özel JSON depolama ve Project Settings sayfaları.
- `lib/src/mcp/`: MCP araç, şema, risk ve onay tipleri ile `EditorMcp`.
- `lib/src/process/`: kendi sürecinde çalışan eklentiler: `LuminaPluginProcess`, `PluginProcessContext`, `runPluginProcessMain`, level proxy'si, `PluginProcessAdapter` ve kabuğun `PluginProcessChannel`'ı.

## Referans sayfaları

| Sayfa | Kapsam |
|---|---|
| [API referansı](api-reference.md) | Plugin, context, komutlar, menüler, slot butonları, paneller, asset tipleri, importer'lar, level erişimi, tema, depolama, ayarlar. |
| [MCP araçları API'si](mcp.md) | MCP araç, şema, risk ve onay tipleri; eklentiler için editörün MCP araçları. |
| [Eklenti süreçleri](plugin-processes.md) | Bir eklentinin riskli kısmını kendi sürecinde çalıştırmak: süreç API'si, yaşam döngüsü ve çıkış kodları, editör proxy'leri (level, depolama, MCP) ve mevcut, yalnızca veriyle çalışan eklentiler için adaptör. |

---

[Önceki: Veri katmanı: modeller ve repository'ler (devamı)](../lumina_editor_data/repositories-continued.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: API referansı](api-reference.md)
