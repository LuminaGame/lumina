[English](../../en/overview/what-is-lumina.md)

# Lumina nedir

Lumina, Google Filament üzerine Dart ve Flutter ile yazılmış bir 3D oyun motoru ve onun editörü Lumina Studio'dan oluşur. Bu sayfa engine'in ve editörün ne yaptığını ve hangi paketlerden oluştuğunu anlatır.

## Engine

Engine, `lumina` paketidir. Bir oyun dünyasını deklaratif olarak tanımlar: engine'in actor'lerden, pawn'lardan, character'lardan ve bunların component'lerinden oluşan canlı bir dünyaya dönüştürdüğü nesnelerden oluşan bir `build()` ağacı. Engine bu çekirdeğin etrafında şunları sunar:

- dünyalar, level'lar, level streaming, world partition, hiyerarşik LOD ve data layer'lar;
- actor'ler, pawn'lar, character'lar, controller'lar ve oyun çatısı (game instance, game mode, game state, HUD, player camera manager);
- mesh (static, instanced, procedural, skeletal), ışık, kamera ve spring arm, hareket, ses, parçacık, sky ve landscape component'leri;
- GJK/EPA narrow phase'li çarpışma, character movement ve fizik subsystem'leri;
- yapay zeka: behavior tree'ler, blackboard, A* ile grid navigasyonu ve görme/duyma algısı;
- iskelet animasyonu: clip'ler, state machine'li anim instance'lar, montage'lar, blend space'ler ve retargeting;
- mapping context, modifier ve trigger'larıyla action tabanlı input;
- post-processing, scalability profilleri ve gölge ayarları;
- save game'ler.

Render işlemi, Google Filament'in Dart FFI binding'i olan `flutter_filament` üzerinden yapılır; masaüstünde Vulkan, OpenGL ya da Metal, tarayıcıda WebGL2 ile çizer. Yalnızca `package:lumina/lumina_runtime.dart`'ı (editör veri katmanı, Assimp ve RigLogic olmadan runtime) import eden bir oyun web için de build edilebilir.

## Editör

Lumina Studio, shadcn_flutter ile geliştirilmiş masaüstü bir Flutter uygulaması olan `lumina_ui` paketidir. 3D viewport, outliner, details inspector, content browser ve output log'un yanında Play-In-Editor modu, Git kaynak kontrolü, eklenti yöneticisi ve tek tek asset tipleri için alt editörler içerir: materyaller, Blueprint'ler, widget'lar (UMG), animasyon, ses, parçacıklar, landscape ve foliage, navigasyon, fizik asset'leri, static ve skeletal mesh'ler, texture'lar, çevre ışıklandırması, sequencer, proje ayarları ve build yöneticisi.

Projeler, `.lmproject` manifest'i olan disk üzerindeki klasörlerdir; her asset bir `.lmas` dosyasıdır. Editör bu dosyalardan oyunun Dart kodunu üretir; dolayısıyla yayınlanan bir oyun sıradan bir Flutter uygulamasıdır.

Eklentiler editörü, yalnızca `lumina`'ya bağımlı küçük bir sözleşme paketi olan `lumina_editor_api` üzerinden genişletir.

## Paketler

| Paket | Repository | Görevi |
|---|---|---|
| `flutter_filament` | lumina | Google Filament v1.77.0 için Dart FFI binding'leri |
| `lumina` | lumina | Engine runtime'ı ve editöre dönük veri katmanı |
| `lumina_editor_api` | lumina | Lumina Studio'nun eklenti API'si |
| `lumina_ui` | lumina | Editör uygulaması Lumina Studio |
| `flutter_assimp` | tools | Assimp için Dart FFI binding'leri: GLB'ye model içe aktarma |
| `flutter_riglogic` | tools | MetaHuman RigLogic için Dart FFI binding'leri |
| `flutter_gstreamer` | tools | GStreamer için Dart FFI binding'leri; smoke test videolarını encode etmek için kullanılır |
| `lumina_smoke` | tools | Smoke test sistemi: artifact'ler, video kontrolleri ve rapor çalıştırıcısı |
| `lumina_mouse_capture` | tools | Oyunlar ve Play-In-Editor için pointer capture (Linux, Windows) |

Her paketin nerede durduğu için [repository haritasına](repositories.md), birbirlerine nasıl bağlandıkları için [katmanlı mimariye](layers.md) bakın.

---

[Önceki: Lumina dokümantasyonu](../../README.tr.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Katmanlı mimari](layers.md)
