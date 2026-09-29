[English](../../en/overview/data-flow.md)

# Veri akışı

Bu sayfa model içe aktarma, render ve kod üretimi gibi ana Lumina iş akışlarını editörden native kütüphanelere kadar izler ve her katmanın katkıda bulunduğu API'yi adlandırır.

## Katmanlar arasındaki iş akışları

Her satır bir iş akışıdır. Soldan sağa, editörde başladığı yerden işi yapan native koda doğru okuyun.

| İş akışı / özellik | Başlatan (`lumina_ui`) | Eklenti API'si (`lumina_editor_api`) | Engine mantığı (`lumina`) | Native render / hesaplama (`flutter_*`) |
| :--- | :--- | :--- | :--- | :--- |
| **Model içe aktarma** | Content Browser (sürükle-bırak) | `EditorImporter` | `ImportAssetUseCase`, `GlbParserService` | `flutter_assimp` (`convertFileToGlb`) |
| **Yüz deformasyonu** | Skeletal Mesh / Animasyon alt editörü | Details özelleştirmesi | `SkeletalMeshComponent`, `AnimInstance` | `flutter_riglogic` (`calculate`, `getBlendShapes`) |
| **PBR 3D render** | Viewport (`ViewportWidget`) | - | `LuminaWorld`, `StaticMeshComponent` | `flutter_filament` (`FilamentEngine`, `FilamentView`) |
| **Görsel programlama** | Blueprint alt editörü | `EditorAssetTypeHandler` | `LuminaActor`, `ActorComponent` | Kod üretimi (`CodeGeneratorService`) |
| **Açık dünya streaming'i** | Ana editör viewport'u | - | `WorldPartition`, `LevelStreaming` | `FilamentScene` (`addEntity`, `removeEntity`) |
| **Otomatik kayıt ve kod üretimi** | Arka plan zamanlayıcısı | - | `AutoSaveTimerService`, `SaveLevelUseCase` | Disk I/O (`.lmas`, `.lmproject`) |

## Daha fazlası için

- Model içe aktarma: [Veri katmanı: use case'ler ve servisler](../lumina/data-services.md) ve [flutter_assimp referansı](https://github.com/LuminaGame/tools/tree/main/docs).
- Yüz deformasyonu: [Bileşenler: mesh'ler ve parçacıklar](../lumina/components-mesh-and-particles.md), [Animasyon](../lumina/animation.md) ve [flutter_riglogic referansı](https://github.com/LuminaGame/tools/tree/main/docs).
- Render: [Renderer, view'ler ve frame pacing](../flutter_filament/renderer-and-view.md) ve [Ana editör: view'ler](../lumina_ui/main-editor-views.md).
- Görsel programlama: [Blueprint editörü](../lumina_ui/sub-editors/blueprint.md).
- Streaming: [Dünya, level'lar ve streaming](../lumina/world.md).
- Kayıt: [Veri katmanı: modeller ve repository'ler](../lumina/data-models.md).

---

[Önceki: Repository haritası](repositories.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Gereksinimler](../getting-started/requirements.md)
