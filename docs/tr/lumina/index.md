[English](../../en/lumina/index.md)

# lumina (engine çekirdeği)

`lumina` engine paketidir: `flutter_filament` üzerine kurulmuş deklaratif bir 3D oyun runtime'ı ve editörün proje ve asset okuyup yazmak için kullandığı veri katmanı.

## Mimarideki yeri

`lumina`, render için `flutter_filament`, yüz rig'leri için `flutter_riglogic` ve model içe aktarma için `flutter_assimp` üzerine kurulur (son ikisi tools repository'sinden gelir). `lumina_editor_api` ve `lumina_ui` onun üzerine kurulur. Bkz. [Katmanlı mimari](../overview/layers.md).

## İki yarı

- **Runtime** (`lib/src/`): bir oyunun çalıştırdığı kısım. Oyun, dünyasını deklaratif bir `build()` ağacıyla tanımlar ([Deklaratif ağaç](declarative.md)); engine bunu, [controller'ların](controller.md) possess ettiği ve [oyun çatısının](game.md) yönettiği, component'li [actor'lerden](object.md) oluşan bir [dünyaya](world.md) dönüştürür. Runtime sınıfları `Lumina` önekini taşır (`LuminaWorld`, `LuminaActor`, `LuminaStaticMeshComponent`, ...).
- **Veri katmanı** (`lib/data/`, `lib/domain/`): editörün projeleri okuyup yazmak için kullandığı kısım. `.lmas` asset ve `.lmproject` manifest modellerini, repository'leri, GLB, OBJ ve TGA parser'larını, Dart kod üretecini, şablonları, eklenti servislerini, logger'ı ve otomatik kaydı barındırır.

## Kütüphaneler

- `package:lumina/lumina.dart` veri katmanı dahil her şeyi export eder. Lumina Studio bunu import eder.
- `package:lumina/lumina_runtime.dart` runtime'ı editör veri katmanı, Assimp ve RigLogic olmadan export eder; yalnızca bu kütüphaneyi import eden bir oyun web için de build edilebilir. Üretilen oyunlar bunu import eder.

Runtime kodu dosyaları hiçbir zaman doğrudan `File(...)` ile okumaz: açık bir asset provider verilmeyen asset yüklemeleri `LuminaAssets.defaultProvider` üzerinden geçer; üretilen `main()` bunu Flutter'ın `rootBundle`'ına ayarlar (null, editör ve testler için dosya sistemi anlamına gelir). Pointer geçiren kod `dart:ffi` ve `package:ffi` yerine `package:flutter_filament/ffi.dart` ve `ffi_package.dart`'ı import eder.

## Referans sayfaları

| Sayfa | Kapsam |
|---|---|
| [Deklaratif ağaç](declarative.md) | Build context, build owner, element'ler, object'ler ve runtime object'ler. |
| [Dünya, level'lar ve streaming](world.md) | World, level'lar, subsystem'ler, world partition, level streaming, HLOD, data layer'lar. |
| [Actor'ler, pawn'lar ve character'lar](object.md) | LuminaActor, LuminaPawn, LuminaCharacter ve saveable mixin'i. |
| [Controller'lar](controller.md) | Controller'lar, player controller'lar ve player state. |
| [Bileşenler: temel, hareket, kamera, ışık, ses, çarpışma](components-core.md) | Actor ve scene component'leri, hareket, kamera ve spring arm, oyuncu girdisi, ışıklar, ses, çarpışma. |
| [Bileşenler: mesh'ler ve parçacıklar](components-mesh-and-particles.md) | Static, instanced, procedural ve skeletal mesh'ler, morph target'lar, parçacık sistemleri. |
| [Bileşenler: çevre ve landscape](components-environment-and-landscape.md) | Sky, procedural sky, reflection capture'lar, landscape arazi ve foliage. |
| [Girdi (input)](input.md) | Input action'lar, mapping context'ler, tuşlar, modifier'lar ve trigger'lar. |
| [Animasyon](animation.md) | Anim instance'lar, montage'lar, clip'ler, blend space'ler, keyframe track'leri, retargeting. |
| [Ses](audio.md) | Ses backend'i, ses subsystem'i, sesler ve attenuation. |
| [Medya alt sistemi (video & ses)](media.md) | Donanım hızlandırmalı video/ses oynatıcı (media-kit), controller'lar, UMG widget'ları, Blueprint node'ları. |
| [Çarpışma](collision.md) | Çarpışma şekilleri, filtreler ve profiller, sorgular, GJK/EPA narrow phase. |
| [Fizik](physics.md) | Rigid body'ler, kütle özellikleri, fiziksel materyaller, temaslar ve fizik subsystem'i. |
| [Yapay zeka (AI)](ai.md) | AI controller, behavior tree'ler, blackboard, navigasyon, algı (perception). |
| [Materyaller ve post-processing](materials-and-post-process.md) | Engine materyalleri, dynamic material instance'lar, materyal cache'i, post-process, ölçeklenebilirlik, gölgeler. |
| [Render cihazları](rendering.md) | GPU seçimi ve kullanılan render backend'i. |
| [Oyun çatısı (game framework)](game.md) | Game instance, game mode, game state, HUD, oyun widget'ı, player camera manager. |
| [Oyun arayüzü widget'ları (UMG runtime)](umg.md) | Runtime UMG widget'ları, element binding'leri, user widget'lar ve widget katmanı. |
| [Kayıt (save game)](save.md) | Save game nesneleri ve save game subsystem'i. |
| [Blueprint'ler](blueprint/index.md) | Görsel programlama: belgeler, node kütüphanesi, VM, üretilen kod. |
| [Yardımcılar, matematik ve test](utilities.md) | Gameplay statics, volume'lar, timer'lar, viewport picking, matematik yardımcıları, mesh decimation, smoke artifact'leri. |
| [Veri katmanı: use case'ler ve servisler](data-services.md) | Use case'ler, GLB/OBJ/TGA parser'ları, kod üreteci, şablonlar, eklenti servisleri, logger, thumbnail'lar. |
| [Veri katmanı: use case'ler ve servisler (devamı, bölüm 1)](data-services-continued.md) | `lib/data/services/`, `lib/data/services/blueprint_codegen/` altındaki diğer dosyalar. |
| [Veri katmanı: use case'ler ve servisler (devamı, bölüm 2)](data-services-continued-2.md) | `lib/data/services/` altındaki diğer dosyalar. |
| [Veri katmanı: use case'ler ve servisler (devamı, bölüm 3)](data-services-continued-3.md) | `lib/data/services/` altındaki diğer dosyalar. |
| [Veri katmanı: modeller ve repository'ler](data-models.md) | `.lmas` asset'leri, `.lmproject` manifest'leri, eklenti tanımları, sequencer ve landscape verisi, repository'ler. |
| [Veri katmanı: modeller ve repository'ler (devamı)](data-models-continued.md) | `lib/data/models/`, `lib/data/repositories/`, `lib/data/repositories/asset_repository/` altındaki diğer dosyalar. |

---

[Önceki: Platform entegrasyonu ve GPU seçimi](../flutter_filament/platform.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Deklaratif ağaç](declarative.md)
