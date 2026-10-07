[English](../../en/lumina_ui/index.md)

# lumina_ui (Lumina Studio)

`lumina_ui`, Lumina projeleri için masaüstü editör olan Lumina Studio'dur. shadcn_flutter ve elle yazılmış bir ChangeNotifier MVVM ile geliştirilmiş bir Flutter uygulamasıdır ve engine'i `lumina` ile `flutter_filament` üzerinden yönetir.

## Mimarideki yeri

`lumina_ui` en üst katmandır. `lumina`'ya (engine), `lumina_editor_data`'ya (editör veri katmanı; editör kodu onun `lumina_editor.dart` şemsiye kütüphanesini import eder), `lumina_editor_api`'ya (gerçeklediği eklenti sözleşmesi), `flutter_filament`'e (viewport'lar ve önizlemeler tarafından doğrudan kullanılır), tools repository'sinin native paketlerine ve marketplace repository'sinden `lumina_marketplace_shared`'a bağımlıdır. Yeni 3D özellikleri doğrudan `flutter_filament` çağrılarıyla değil, `lumina` üzerinden yapılır. Bkz. [Katmanlı mimari](../overview/layers.md).

## Yapı

- **UI toolkit**: editör arayüzünün tamamında Material widget'ları yerine shadcn_flutter widget'ları.
- **State**: elle yazılmış bir ChangeNotifier MVVM. `EditorViewModel` ana editörün merkezi view model'idir; her alt editörün kendi view model'i vardır.
- **Özellikler** `lib/ui/features/<özellik>/` altında, `views/`, `view_models/`, `services/` ve `models/` alt klasörleriyle yer alır. Aynı alana ait alt editör view'leri kendi klasörlerinde durur (`views/blueprint/`, `views/material/`, `views/sequencer/`, `views/umg/`, ...).
- **Ortak UI** `lib/ui/core/` altındadır: tema, property editor'leri, sahne servisleri ve eklenti uzantı registry'si.
- **Yalnızca gerçek veri**: projeler `.lmproject` ve `.lmas` dosyaları olan gerçek klasörlerdir (varsayılan olarak `~/Lumina Projects/` altında); testler mock yerine geçici dizinler kullanır.

## Referans sayfaları

| Sayfa | Kapsam |
|---|---|
| [Uygulama kabuğu ve ortak UI](core.md) | Uygulama girişi, yerleşik eklenti, eklenti uzantı registry'si, tema, property editor'leri, sahne servisleri. |
| [Uygulama kabuğu ve ortak UI (devamı, bölüm 1)](core-continued.md) | `lib/`, `lib/testing/`, `lib/ui/core/`, `lib/ui/core/host/`, `lib/ui/core/property_editors/`, `lib/ui/core/services/`, `lib/ui/core/theme/`, `lib/ui/core/widgets/` altındaki diğer dosyalar. |
| [Uygulama kabuğu ve ortak UI (devamı, bölüm 2)](core-continued-2.md) | `lib/ui/core/window/` altındaki diğer dosyalar, medya oynatıcıları ve bildirimsel eklenti panelleri (`PluginViewRenderer`). |
| [Ana editör: view'ler](main-editor-views.md) | Viewport, outliner, details, content browser, toolbar, menü çubuğu, output log, diyaloglar. |
| [Ana editör: view'ler (devamı)](main-editor-views-continued.md) | `lib/ui/features/main_editor/views/` altındaki diğer dosyalar. |
| [Ana editör: view model ve servisler](main-editor-state.md) | `EditorViewModel`, kalite ayarları, gizmo'lar, Play-In-Editor, snapping, picking, kısayollar, komutlar, transaction'lar. |
| [Ana editör: view model ve servisler (devamı)](main-editor-state-continued.md) | `lib/ui/features/main_editor/services/`, `lib/ui/features/main_editor/services/pie_controller/`, `lib/ui/features/main_editor/view_models/`, `lib/ui/features/main_editor/view_models/editor_view_model/` altındaki diğer dosyalar. |
| [Launcher ve details](launcher-and-details.md) | Proje launcher'ı, proje oluşturma diyaloğu, component property registry'si, çoklu düzenleme. |
| [Eklenti yöneticisi](plugin-manager.md) | Eklenti yöneticisi view'i ve view model'i, yeni eklenti sihirbazı. |
| [Eklenti süreçleri](plugin-processes.md) | Yalıtılmış eklentiler: denetleyici, durumlar, yeniden başlatmalar, süreç koruması, `plugin_crash` raporları, editör içi geçersiz kılma, çalıştırılabilir dosyanın eklenti süreci kipi. |
| [Kaynak kontrolü](source-control.md) | Git servisi, kaynak kontrolü view model'i, commit, geçmiş, geri alma ve kimlik diyalogları. |
| [Marketplace](marketplace.md) | Oturum açma, göz atma, listing kurma ve lisans kayıtları. |
| [MCP sunucusu](mcp-server.md) | Editörün Model Context Protocol sunucusu: transport, oturumlar, registry, job'lar, sandbox, snapshot'lar, panel. |
| [MCP araç kataloğu](mcp-tools.md) | Editörün sunduğu her MCP aracı, alana göre, risk seviyesiyle. |
| [Windows paketleme](windows-packaging.md) | Lumina Studio'nun MSIX paketinin build edilmesi ve imzalanması. |
| [Alt editörler](sub-editors/index.md) | Kendi sekmelerinde açılan asset editörleri. |

---

[Önceki: Editör eklentileri](../plugins/index.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Uygulama kabuğu ve ortak UI](core.md)
