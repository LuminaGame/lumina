[English](../../en/lumina/index.md)

# lumina (engine çekirdeği)

`lumina` engine paketidir: `flutter_filament` üzerine kurulmuş deklaratif bir 3D oyun runtime'ı. Editörün proje ve asset okuyup yazmak için kullandığı veri katmanı ayrı bir pakettir: [lumina_editor_data](../lumina_editor_data/index.md).

## Mimarideki yeri

`lumina`, `lumina_core` (saf Dart temeli) ve render için `flutter_filament` üzerine kurulur. Assimp ve RigLogic editör araçlarıdır: `lumina_editor_data` onlara bağımlıdır, engine değildir. `lumina_editor_data`, `lumina_editor_api` ve `lumina_ui` onun üzerine kurulur. Bkz. [Katmanlı mimari](../overview/layers.md).

## Neleri barındırır

- **Runtime** (`lib/src/`): bir oyunun çalıştırdığı kısım. Oyun, dünyasını deklaratif bir `build()` ağacıyla tanımlar ([Deklaratif ağaç](declarative.md)); engine bunu, [controller'ların](controller.md) possess ettiği ve [oyun çatısının](game.md) yönettiği, component'li [actor'lerden](object.md) oluşan bir [dünyaya](world.md) dönüştürür. Runtime sınıfları `Lumina` önekini taşır (`LuminaWorld`, `LuminaActor`, `LuminaStaticMeshComponent`, ...).
- **Runtime'ın kullandığı asset okuyucuları** (`lib/src/assets/`): kodlanmış görüntü çözücü, `LuminaGlbLoader` (lumina_core'un saf `GlbReader`'ı, Filament'in Draco çözücüsü ve platform görüntü codec'iyle), level asset manifestosu ve level mesh materyal araması. Proje input binder'ı (`lib/src/input/project_input_binder.dart`) bir `.lmproject`'in input ayarlarını action'lara ve mapping context'lere çevirir.
- **Burada olmayanlar:** editör veri katmanı (asset ve proje repository'leri, içe aktarıcılar, thumbnail'lar, kod üreteçleri, proje editörü build'leri, eklenti registry'si ve şablon üreteci, use case'ler) [lumina_editor_data](../lumina_editor_data/index.md) paketindedir. Saf formatlar ve servisler `lumina`'nın yeniden export ettiği [lumina_core](../lumina_core/index.md) paketindedir. `test/architecture/engine_without_editor_data_test.dart`, `lumina.dart` ve `lumina_runtime.dart`'ın ulaştığı her kütüphaneyi gezer ve `lumina_editor_data`, analyzer, Assimp, RigLogic ya da bir editör repository'si bulursa başarısız olur.

## Kütüphaneler

- `package:lumina/lumina.dart` engine'i ve her zaman export ettiği `lumina_core` kütüphanelerini export eder. Editör kodu bunun yerine editör veri katmanını da ekleyen `package:lumina_editor_data/lumina_editor.dart`'ı import eder.
- `package:lumina/lumina_runtime.dart` bir oyunun ihtiyaç duyduğu runtime'ı export eder; yalnızca bu kütüphaneyi import eden bir oyun web için de build edilebilir. Üretilen oyunlar bunu import eder.

Barrel'lar paketin kullanıcıları içindir: `lumina/lib` içindeki hiçbir kütüphane `lumina.dart` ya da `lumina_runtime.dart`'ı import etmez; her biri kullandığı dosyaları import eder, böylece barrel'lar import grafiğinin yaprakları olarak kalır ve hiçbir döngü onlardan geçmez. Engine nesneleri engine'in kendi `LuminaObjectKey`'ini taşır ve `lumina_object.dart` hiçbir Flutter kütüphanesine ulaşmaz. İkisini de `test/architecture/` korur (`import_cycles_test.dart`, `flutter_free_object_root_test.dart`).

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
| [Yardımcılar, matematik ve test](utilities.md) | Gameplay statics, volume'lar, timer'lar, viewport picking, matematik yardımcıları, mesh decimation, asset okuyucuları (görüntü çözücü, GLB yükleyici, level asset manifestosu), smoke artifact'leri. |

---

[Önceki: Platform entegrasyonu ve GPU seçimi](../flutter_filament/platform.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Deklaratif ağaç](declarative.md)
