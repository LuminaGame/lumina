[English](README.md)

# Lumina dokümantasyonu

Lumina, Google Filament renderer'ı üzerine kurulmuş, Flutter ve Dart için bir 3D oyun motoru ve Lumina projeleri için masaüstü editörü olan Lumina Studio'dan oluşur. Bu dokümantasyon mimariyi, bir checkout'un nasıl kurulacağını ve bu repository'deki paketlerin API referansını kapsar: `flutter_filament`, `lumina_core`, `lumina`, `lumina_editor_api` ve `lumina_ui`.

## Nereden başlamalı

### Oyun geliştiriciler

Oyunları `lumina` runtime'ı ile yazarsınız: actor'lerden ve component'lerden oluşan bir dünyaya dönüşen deklaratif bir `build()` ağacı.

1. [Lumina nedir](tr/overview/what-is-lumina.md) ve [Katmanlı mimari](tr/overview/layers.md)
2. [Gereksinimler](tr/getting-started/requirements.md), [Checkout ve kurulum](tr/getting-started/setup.md), [Editörü ve testleri çalıştırmak](tr/getting-started/running.md)
3. [lumina (engine çekirdeği)](tr/lumina/index.md), ardından [Deklaratif ağaç](tr/lumina/declarative.md), [Dünya, level'lar ve streaming](tr/lumina/world.md), [Actor'ler, pawn'lar ve character'lar](tr/lumina/object.md) ve [Oyun çatısı](tr/lumina/game.md)
4. İhtiyaç duydukça component'ler, [Girdi](tr/lumina/input.md), [Animasyon](tr/lumina/animation.md), [Yapay zeka](tr/lumina/ai.md) ve [Kayıt](tr/lumina/save.md)

### Editör ve eklenti geliştiriciler

Lumina Studio'yu eklentilerle genişletir ya da editörün kendisi üzerinde çalışırsınız.

1. [Lumina nedir](tr/overview/what-is-lumina.md) ve [Checkout ve kurulum](tr/getting-started/setup.md)
2. [Editör eklentileri](tr/plugins/index.md) ve [lumina_editor_api referansı](tr/lumina_editor_api/api-reference.md)
3. [lumina_ui (Lumina Studio)](tr/lumina_ui/index.md), [Ana editör: view model ve servisler](tr/lumina_ui/main-editor-state.md) ve [Alt editörler](tr/lumina_ui/sub-editors/index.md)
4. Editörün ve eklentilerin okuyup yazdığı dosyalar: [lumina_core](tr/lumina_core/index.md) (dosya formatları, yollar, logger, saf servisler), ardından engine'in [modeller ve repository'ler](tr/lumina/data-models.md) ile [use case'ler ve servisler](tr/lumina/data-services.md) sayfaları

### Engine katkıcıları

Engine, renderer binding'leri ya da native build üzerinde çalışırsınız.

1. [Katmanlı mimari](tr/overview/layers.md), [Repository haritası](tr/overview/repositories.md) ve [Veri akışı](tr/overview/data-flow.md)
2. Filament build'i dahil [Checkout ve kurulum](tr/getting-started/setup.md) ve [Editörü ve testleri çalıştırmak](tr/getting-started/running.md)
3. [flutter_filament](tr/flutter_filament/index.md), önce [Engine, entity'ler ve temel tipler](tr/flutter_filament/engine.md)
4. [lumina (engine çekirdeği)](tr/lumina/index.md)
5. tools repository'sinin native paketleri: [tools dokümantasyonu](https://github.com/LuminaGame/tools/tree/main/docs)

## İçindekiler

### Genel bakış

- [Lumina nedir](tr/overview/what-is-lumina.md) - Engine, editör ve bunları oluşturan paketler.
- [Katmanlı mimari](tr/overview/layers.md) - Katman diyagramı ve her katmanın sorumluluğu.
- [Repository haritası](tr/overview/repositories.md) - Hangi LuminaGame repository'sinin hangi paketi barındırdığı ve birbirlerine nasıl bağlandıkları.
- [Veri akışı](tr/overview/data-flow.md) - Ana iş akışlarının katmanlar arasında nasıl ilerlediği.

### Başlangıç

- [Gereksinimler](tr/getting-started/requirements.md) - Lumina'yı build etmek için gereken SDK'lar, toolchain'ler ve native kütüphaneler.
- [Checkout ve kurulum](tr/getting-started/setup.md) - Yan yana checkout'lar, `dart pub get`, hook ayarları ve Filament build'i.
- [Editörü ve testleri çalıştırmak](tr/getting-started/running.md) - Lumina Studio'yu başlatmak, testleri, smoke raporlarını ve workspace script'lerini çalıştırmak.

### flutter_filament

- [flutter_filament](tr/flutter_filament/index.md) - Google Filament için Dart FFI binding'leri.
  - [Engine, entity'ler ve temel tipler](tr/flutter_filament/engine.md) - Engine yaşam döngüsü, entity'ler, ortak enum'lar, fence'ler, exception'lar, callback'ler, tanılama.
  - [Renderer, view'ler ve frame pacing](tr/flutter_filament/renderer-and-view.md) - Renderer, swap chain'ler, view'ler, render target'lar, frame pacing, Flutter widget'ı.
  - [View seçenekleri ve color grading](tr/flutter_filament/view-options.md) - View başına post-processing ve kalite seçenekleri, tone mapping ve color grading.
  - [Sahne ve geometri](tr/flutter_filament/scene-and-geometry.md) - Sahneler, renderable'lar, transform'lar, vertex/index/instance/morph/skinning buffer'ları, filamesh.
  - [Kamera ve manipulator](tr/flutter_filament/camera-and-manipulator.md) - Kameralar, projeksiyonlar, exposure ve orbit/map/free-flight kamera manipulator'ı.
  - [Işıklandırma ve image-based lighting](tr/flutter_filament/lighting-and-ibl.md) - Işıklar, gölgeler, indirect light, skybox'lar, IBL bake ve prefilter.
  - [Materyaller](tr/flutter_filament/materials.md) - Materyaller, material instance'lar, parametreler ve runtime materyal derleyicisi.
  - [Texture'lar ve görseller](tr/flutter_filament/textures-and-images.md) - Texture'lar, sampler'lar, görsel I/O, görsel işlemleri, KTX1/KTX2, Basis transcoding.
  - [glTF yükleme ve animasyon](tr/flutter_filament/gltfio.md) - glTF/GLB asset'leri, instance'lar, material provider'lar, animator'lar, Draco decode.
  - [Matematik tipleri](tr/flutter_filament/math.md) - Vektör, quaternion ve matris değer tipleri, box'lar, frustum'lar, renkler, exposure.
  - [Editör primitifleri, araçlar ve test](tr/flutter_filament/editor-tools-and-testing.md) - Grid, seçim kutusu, transform gizmo, offline araçlar, smoke test giriş noktası.
  - [Platform entegrasyonu ve GPU seçimi](tr/flutter_filament/platform.md) - Paylaşılan engine host, Vulkan GPU listeleme ve tercihi, web başlatma ve platforma özel widget varyantları.

### lumina_core (saf Dart temeli)

- [lumina_core (saf Dart temeli)](tr/lumina_core/index.md) - Engine, editör ve eklenti süreçlerinin paylaştığı temel; Flutter, `dart:ui` ya da FFI yok.
  - [Matematik: birimler, eksenler ve dönüşler](tr/lumina_core/math.md) - `LuminaUnits`, `LuminaAxes`, Euler ve control rotation'lar, interpolasyon, transform anlık görüntüleri.
  - [Dosya formatları ve repository'ler](tr/lumina_core/formats.md) - `.lmas` asset'leri, `.lmproject` manifest'leri, level dokümanları, eklenti tanımları, landscape, sequencer ve tema verisi, level ve eklenti repository'leri.
  - [Servisler](tr/lumina_core/services.md) - Animasyon yazımı, asset indeksi, config dosyaları, build parmak izi ve önbelleği, engine kurulumu, engine logger, şablonlar.
  - [Servisler (devamı)](tr/lumina_core/services-continued.md) - Üretilmiş kod göçü, GLB animasyon araçları, glTF paketleyici, config ve veri klasörleri, eklenti paketleme, primitive GLB fabrikası, TGA çözücü, çalışma alanı yolları.

### lumina (engine çekirdeği)

- [lumina (engine çekirdeği)](tr/lumina/index.md) - Deklaratif 3D oyun motoru ve editöre dönük veri katmanı.
  - [Deklaratif ağaç](tr/lumina/declarative.md) - Build context, build owner, element'ler, object'ler ve runtime object'ler.
  - [Dünya, level'lar ve streaming](tr/lumina/world.md) - World, level'lar, subsystem'ler, world partition, level streaming, HLOD, data layer'lar.
  - [Actor'ler, pawn'lar ve character'lar](tr/lumina/object.md) - LuminaActor, LuminaPawn, LuminaCharacter ve saveable mixin'i.
  - [Controller'lar](tr/lumina/controller.md) - Controller'lar, player controller'lar ve player state.
  - [Bileşenler: temel, hareket, kamera, ışık, ses, çarpışma](tr/lumina/components-core.md) - Actor ve scene component'leri, hareket, kamera ve spring arm, oyuncu girdisi, ışıklar, ses, çarpışma.
  - [Bileşenler: mesh'ler ve parçacıklar](tr/lumina/components-mesh-and-particles.md) - Static, instanced, procedural ve skeletal mesh'ler, morph target'lar, parçacık sistemleri.
  - [Bileşenler: çevre ve landscape](tr/lumina/components-environment-and-landscape.md) - Sky, procedural sky, reflection capture'lar, landscape arazi ve foliage.
  - [Girdi (input)](tr/lumina/input.md) - Input action'lar, mapping context'ler, tuşlar, modifier'lar ve trigger'lar.
  - [Animasyon](tr/lumina/animation.md) - Anim instance'lar, montage'lar, clip'ler, blend space'ler, keyframe track'leri, retargeting.
  - [Ses](tr/lumina/audio.md) - Ses backend'i, ses subsystem'i, sesler ve attenuation.
  - [Çarpışma](tr/lumina/collision.md) - Çarpışma şekilleri, filtreler ve profiller, sorgular, GJK/EPA narrow phase.
  - [Fizik](tr/lumina/physics.md) - Rigid body'ler, kütle özellikleri, fiziksel materyaller, temaslar ve fizik subsystem'i.
  - [Yapay zeka (AI)](tr/lumina/ai.md) - AI controller, behavior tree'ler, blackboard, navigasyon, algı (perception).
  - [Materyaller ve post-processing](tr/lumina/materials-and-post-process.md) - Engine materyalleri, dynamic material instance'lar, materyal cache'i, post-process, ölçeklenebilirlik, gölgeler.
  - [Render cihazları](tr/lumina/rendering.md) - GPU seçimi ve kullanılan render backend'i.
  - [Oyun çatısı (game framework)](tr/lumina/game.md) - Game instance, game mode, game state, HUD, oyun widget'ı, player camera manager.
  - [Oyun arayüzü widget'ları (UMG runtime)](tr/lumina/umg.md) - Runtime UMG widget'ları, element binding'leri, user widget'lar ve widget katmanı.
  - [Kayıt (save game)](tr/lumina/save.md) - Save game nesneleri ve save game subsystem'i.
  - [Blueprint'ler](tr/lumina/blueprint/index.md) - Görsel programlama: belgeler, node kütüphanesi, VM, üretilen kod.
    - [Blueprint belgeleri ve asset'leri](tr/lumina/blueprint/model.md) - Pin'ler, node'lar, wire'lar, graph'lar, fonksiyonlar, macro'lar, interface'ler, enum'lar, save-game ve montage asset'leri, doğrulama.
    - [Blueprint runtime'ı, VM ve node kütüphanesi](tr/lumina/blueprint/runtime.md) - Node kataloğu, yorumlayıcı, Blueprint actor'leri, level ve widget Blueprint'leri, delegate'ler.
    - [Blueprint fonksiyon kütüphanesi](tr/lumina/blueprint/function-library.md) - VM ve üretilen kodun paylaştığı, her pure ve impure node'un davranışı.
    - [Animation Blueprint'ler](tr/lumina/blueprint/animation.md) - Animation Blueprint belgeleri, state machine'ler, blend space'ler, aim offset'ler ve instance'ları.
  - [Yardımcılar, matematik ve test](tr/lumina/utilities.md) - Gameplay statics, volume'lar, timer'lar, viewport picking, matematik yardımcıları, mesh decimation, smoke artifact'leri.
  - [Veri katmanı: use case'ler ve servisler](tr/lumina/data-services.md) - Use case'ler, GLB/OBJ/TGA parser'ları, kod üreteci, şablonlar, eklenti servisleri, logger, thumbnail'lar.
  - [Veri katmanı: use case'ler ve servisler (devamı, bölüm 1)](tr/lumina/data-services-continued.md) - `lib/data/services/`, `lib/data/services/blueprint_codegen/` altındaki diğer dosyalar.
  - [Veri katmanı: use case'ler ve servisler (devamı, bölüm 2)](tr/lumina/data-services-continued-2.md) - `lib/data/services/` altındaki diğer dosyalar.
  - [Veri katmanı: use case'ler ve servisler (devamı, bölüm 3)](tr/lumina/data-services-continued-3.md) - `lib/data/services/` altındaki diğer dosyalar.
  - [Veri katmanı: modeller ve repository'ler](tr/lumina/data-models.md) - Asset, koleksiyon ve proje repository'leri (modeller `lumina_core`'da).
  - [Veri katmanı: modeller ve repository'ler (devamı)](tr/lumina/data-models-continued.md) - `lib/data/models/`, `lib/data/repositories/`, `lib/data/repositories/asset_repository/` altındaki diğer dosyalar.

### lumina_editor_api

- [lumina_editor_api](tr/lumina_editor_api/index.md) - Lumina Studio'nun az bağımlılıklı eklenti API'si.
  - [API referansı](tr/lumina_editor_api/api-reference.md) - Plugin, context, komutlar, menüler, slot butonları, paneller, asset tipleri, importer'lar, level erişimi, tema, depolama, ayarlar.
  - [MCP araçları API'si](tr/lumina_editor_api/mcp.md) - MCP araç, şema, risk ve onay tipleri; eklentiler için editörün MCP araçları.
  - [Eklenti süreçleri](tr/lumina_editor_api/plugin-processes.md) - bir eklentinin riskli kısmı kendi sürecinde: süreç API'si, editör proxy'leri, adaptör.

### Editör eklentileri

- [Editör eklentileri](tr/plugins/index.md) - Eklentilerin nasıl paketlendiği, bulunduğu, etkinleştirildiği ve kaydedildiği.

### lumina_ui (Lumina Studio)

- [lumina_ui (Lumina Studio)](tr/lumina_ui/index.md) - Lumina Studio editör uygulaması.
  - [Uygulama kabuğu ve ortak UI](tr/lumina_ui/core.md) - Uygulama girişi, yerleşik eklenti, eklenti uzantı registry'si, tema, property editor'leri, sahne servisleri.
  - [Uygulama kabuğu ve ortak UI (devamı, bölüm 1)](tr/lumina_ui/core-continued.md) - `lib/`, `lib/testing/`, `lib/ui/core/`, `lib/ui/core/host/`, `lib/ui/core/property_editors/`, `lib/ui/core/services/`, `lib/ui/core/theme/`, `lib/ui/core/widgets/` altındaki diğer dosyalar.
  - [Uygulama kabuğu ve ortak UI (devamı, bölüm 2)](tr/lumina_ui/core-continued-2.md) - `lib/ui/core/window/` altındaki diğer dosyalar.
  - [Ana editör: view'ler](tr/lumina_ui/main-editor-views.md) - Viewport, outliner, details, content browser, toolbar, menü çubuğu, output log, diyaloglar.
  - [Ana editör: view'ler (devamı)](tr/lumina_ui/main-editor-views-continued.md) - `lib/ui/features/main_editor/views/` altındaki diğer dosyalar.
  - [Ana editör: view model ve servisler](tr/lumina_ui/main-editor-state.md) - `EditorViewModel`, kalite ayarları, gizmo'lar, Play-In-Editor, snapping, picking, kısayollar, komutlar, transaction'lar.
  - [Ana editör: view model ve servisler (devamı)](tr/lumina_ui/main-editor-state-continued.md) - `lib/ui/features/main_editor/services/`, `lib/ui/features/main_editor/services/pie_controller/`, `lib/ui/features/main_editor/view_models/`, `lib/ui/features/main_editor/view_models/editor_view_model/` altındaki diğer dosyalar.
  - [Launcher ve details](tr/lumina_ui/launcher-and-details.md) - Proje launcher'ı, proje oluşturma diyaloğu, component property registry'si, çoklu düzenleme.
  - [Eklenti yöneticisi](tr/lumina_ui/plugin-manager.md) - Eklenti yöneticisi view'i ve view model'i, yeni eklenti sihirbazı.
  - [Kaynak kontrolü](tr/lumina_ui/source-control.md) - Git servisi, kaynak kontrolü view model'i, commit, geçmiş, geri alma ve kimlik diyalogları.
  - [Marketplace](tr/lumina_ui/marketplace.md) - Oturum açma, göz atma, listing kurma ve lisans kayıtları.
  - [MCP sunucusu](tr/lumina_ui/mcp-server.md) - Editörün Model Context Protocol sunucusu: transport, oturumlar, registry, job'lar, sandbox, snapshot'lar, panel.
  - [MCP araç kataloğu](tr/lumina_ui/mcp-tools.md) - Editörün sunduğu her MCP aracı, alana göre, risk seviyesiyle.
  - [Windows paketleme](tr/lumina_ui/windows-packaging.md) - Lumina Studio'nun MSIX paketinin build edilmesi ve imzalanması.
  - [Alt editörler](tr/lumina_ui/sub-editors/index.md) - Kendi sekmelerinde açılan asset editörleri.
    - [Alt editör altyapısı](tr/lumina_ui/sub-editors/framework.md) - Ortak 3D önizleme viewport'u, hiyerarşi widget'ı, çalışma alanı modalı, önizleme mesh'leri.
    - [Animasyon editörü](tr/lumina_ui/sub-editors/animation.md) - Animasyon alt editörü, dope sheet, retargeting, notify'lar ve eğriler.
    - [Ses editörü](tr/lumina_ui/sub-editors/audio.md) - Dalga formu, transport, attenuation eğrisi, WAV decode.
    - [Blueprint editörü](tr/lumina_ui/sub-editors/blueprint.md) - Blueprint alt editörü, component ağacı, event graph, component registry'si.
    - [Blueprint editörü (devamı, bölüm 1)](tr/lumina_ui/sub-editors/blueprint-continued.md) - `lib/ui/features/sub_editors/models/`, `lib/ui/features/sub_editors/services/`, `lib/ui/features/sub_editors/view_models/`, `lib/ui/features/sub_editors/views/blueprint/` altındaki diğer dosyalar.
    - [Blueprint editörü (devamı, bölüm 2)](tr/lumina_ui/sub-editors/blueprint-continued-2.md) - `lib/ui/features/sub_editors/views/blueprint/`, `lib/ui/features/sub_editors/views/blueprint/graph_canvas/`, `lib/ui/features/sub_editors/views/blueprint/timeline/`, `lib/ui/features/sub_editors/views/blueprint_enum/`, `lib/ui/features/sub_editors/views/blueprint_interface/` altındaki diğer dosyalar.
    - [Build yöneticisi](tr/lumina_ui/sub-editors/build-manager.md) - Build adımları, doğrulama ve `flutter build` ile Cook & Package.
    - [Çevre ışıklandırması](tr/lumina_ui/sub-editors/environment-lighting.md) - Güneş ve günün saati, sky ve IBL, sis ve post-process kontrolleri.
    - [Landscape ve foliage](tr/lumina_ui/sub-editors/landscape.md) - Şekillendirme fırçaları, foliage boyama, heightmap asset'leri, arazi önizlemesi.
    - [Materyal editörü](tr/lumina_ui/sub-editors/material.md) - GLSL materyal kaynağı, parametreler, derleme ve önizleme.
    - [Navigasyon editörü](tr/lumina_ui/sub-editors/navigation.md) - Nav sınır volume'ları, grid bake, yol testi.
    - [Parçacık editörü](tr/lumina_ui/sub-editors/particle.md) - Emitter yığını, eğri ve gradient editörleri, canlı önizleme.
    - [Fizik asset editörü](tr/lumina_ui/sub-editors/physics-asset.md) - Gövdeler, kısıtlar, çakışma kontrolleri ve fizik önizlemesi.
    - [Proje ayarları](tr/lumina_ui/sub-editors/project-settings.md) - `.lmproject` manifest'ini kategori bazında düzenleme.
    - [Sequencer](tr/lumina_ui/sub-editors/sequencer.md) - Timeline, track ağacı, eğri editörü, değerlendirme ve film render'ı.
    - [Static ve skeletal mesh editörleri](tr/lumina_ui/sub-editors/meshes.md) - Mesh önizlemesi, LOD'lar, çarpışma, materyal slot'ları, socket'ler.
    - [Texture editörü](tr/lumina_ui/sub-editors/texture.md) - Texture önizlemesi, mip seviyeleri ve texture ayarları.
    - [Widget (UMG) tasarımcısı](tr/lumina_ui/sub-editors/umg.md) - Tasarım kanvası, palet, hiyerarşi, slot inspector'ı, widget kod üretimi.

## İlgili dokümantasyon

- [tools dokümantasyonu](https://github.com/LuminaGame/tools/tree/main/docs): `flutter_assimp`, `flutter_riglogic`, `flutter_gstreamer` ve `lumina_mouse_capture`.
- [plugins](https://github.com/LuminaGame/plugins): örnek editör eklentileri.
- [marketplace](https://github.com/LuminaGame/marketplace): Lumina Marketplace sunucusu, ortak paketi ve web arayüzü.

---

[Sonraki: Lumina nedir](tr/overview/what-is-lumina.md)
