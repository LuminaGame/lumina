[English](../../en/overview/repositories.md)

# Repository haritası

Lumina kod tabanı, LuminaGame organizasyonundaki birkaç repository'ye dağılmıştır. Bu sayfa her repository'nin içeriğini ve repository'lerin birbirine git dependency'leriyle nasıl bağlandığını listeler.

## Repository'ler

| Repository | İçerik |
|---|---|
| [lumina](https://github.com/LuminaGame/lumina) | Bu repository: `flutter_filament`, `lumina`, `lumina_editor_api` ve `lumina_ui`, ayrıca `tool/ci.sh` ve bu dokümantasyon. |
| [tools](https://github.com/LuminaGame/tools) | Engine'in üzerine kurulduğu native ve FFI paketleri: `flutter_assimp`, `flutter_riglogic`, `flutter_gstreamer`, `lumina_smoke` (smoke test sistemi) ve `lumina_mouse_capture`. [tools dokümantasyonunda](https://github.com/LuminaGame/tools/tree/main/docs) anlatılır. |
| [plugins](https://github.com/LuminaGame/plugins) | Örnek editör eklentileri: `lumina_plugin_pcg` (prosedürel içerik üretimi, eklenti API'sinin referans örneği) ve `lumina_plugin_miniai` (bir yapay zeka asistanı paneli). |
| [marketplace](https://github.com/LuminaGame/marketplace) | Lumina Marketplace: `shelf` API sunucusu, ortak paket (`lumina_marketplace_shared`, DTO'lar ve `MarketplaceClient`) ve Flutter web arayüzü. |
| [test-assets](https://github.com/LuminaGame/test-assets) | Testlerin ve smoke testlerin kullandığı ortak 3D modeller ve fixture'lar (Git LFS, isteğe bağlı). |

Google Filament hiçbir repository'de yer almaz. Lumina, birkaç yerel yamayla Filament v1.77.0 kullanır; Filament bir kez static kütüphaneler olarak build edilir (bkz. [Checkout ve kurulum](../getting-started/setup.md)).

## Workspace'ler

Birden fazla paket barındıran her repository, melos 7 ile yönetilen bir Dart pub workspace'idir: kök `pubspec.yaml` paketleri `workspace:` altında listeler, her paket `resolution: workspace` bildirir ve tek bir `pubspec.lock` hepsini kapsar. Bu repository'nin kök pubspec'i `flutter_filament`, `lumina`, `lumina_editor_api` ve `lumina_ui`'ı (ve örnek uygulamaları) listeler ve `analyze`, `format`, `format:check`, `test` ve `smoke` melos script'lerini tanımlar.

## Repository'ler birbirine nasıl bağlanır

Repository'ler birbirine git dependency'leriyle bağlanır:

| Kullanan | Bağımlılık | Kaynak |
|---|---|---|
| `flutter_filament`, `lumina`, `lumina_ui` | `lumina_smoke`, `flutter_gstreamer` (smoke testler) | tools (git) |
| `lumina`, `lumina_ui` | `flutter_assimp`, `flutter_riglogic` | tools (git) |
| `lumina`, `lumina_ui` | `lumina_mouse_capture` | tools |
| `lumina_ui` | `lumina_marketplace_shared` | marketplace (git) |
| `lumina_ui` (dev) | `lumina_plugin_pcg`, `lumina_plugin_miniai` | plugins (git) |
| plugins | `lumina`, `lumina_editor_api` | lumina (git) |
| marketplace web arayüzü | `lumina`, `flutter_filament` | yanındaki bir `../lumina` checkout'u |

Bu repository içinde paketler path dependency kullanır (`lumina` → `../flutter_filament`, `lumina_ui` → `../lumina` vb.).

Yan yana checkout'larla yerel geliştirme için workspace kökündeki, gitignore edilmiş bir `pubspec_overrides.yaml` git dependency'lerini komşu klasörlere yönlendirir (pub workspace'leri override'ları yalnızca kökten okur):

```yaml
dependency_overrides:
  flutter_assimp:
    path: ../tools/flutter_assimp
  flutter_riglogic:
    path: ../tools/flutter_riglogic
  flutter_gstreamer:
    path: ../tools/flutter_gstreamer
  lumina_marketplace_shared:
    path: ../marketplace/shared
  lumina_plugin_pcg:
    path: ../plugins/lumina_plugin_pcg
  lumina_plugin_miniai:
    path: ../plugins/lumina_plugin_miniai
```

---

[Önceki: Katmanlı mimari](layers.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Veri akışı](data-flow.md)
