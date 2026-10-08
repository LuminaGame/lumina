[English](../../en/lumina_editor_data/game-animation-sample.md)

# Game Animation Sample örnek projesi

`lib/src/samples/game_animation_sample/`, Game Animation Sample gibi oynayan bir örnek proje kurar: örneğin animasyon seti üzerinde [motion matching](../lumina/motion-matching.md) ile sürülen, yürüyüş türleri, çömelme ve zıplaması olan bir karakter ve bir oyun alanı level'ı. Örneğin animasyonları ve level'ı yayıncısına, bir MetaHuman karakteri de kendi sahibine aittir: hiçbiri Lumina'nın parçası değildir. Kurucu, örneğin yerel bir dışa aktarımını ve projede zaten bulunan bir skeletal mesh'i okur, geri kalan her şeyi yazar; proje onu kuran makinede kalır.

`package:lumina_editor_data/lumina_editor_data.dart` tarafından dışa aktarılır.

## Girdiler

- **Animasyon dışa aktarımı**: `Game/Characters/UEFN_Mannequin/Animations/<kategori>/…/*.fbx` (FBX başına bir clip, kök hareketi `root` kemiğinde) ve yanında bir `metadata.json` içeren klasör: `anim_sequences` (yol, `length_s`) ve `assets.PoseSearchDatabase` (yol, `schema`, `tags`, `base_cost_bias`, `looping_cost_bias` ve veritabanının `DatabaseAnimationAssets(i)=(AnimAsset=…, SamplingRange=(Min=…,Max=…), MirrorOption=…, bEnabled=…)` satırlarını taşıyan metin dışa aktarımı `t3d`). `GaspExport.open(root)` onu okur; clip adları FBX taban adlarıdır (aynı adlı iki clip'ten ilki kazanır).
- **Karakter**: projede bir skeletal mesh asset'i (örneğin MetaHuman Creator eklentisinin dışa aktardığı bir MetaHuman), GLB'si animasyonsuz.
- **İsteğe bağlı** bir level dışa aktarımı: `{actors: [{class, label, transform, components: [{mesh, corners}]}]}`; `corners`, köşe pivotlu bir küpün sol elli Z-yukarı bir çerçevedeki (X ileri, Y sağ) sekiz dünya köşesidir; ve prop olarak yerleştirilecek model dosyaları.

## Ne kurar

| Adım | Sınıf | Sonuç |
| :--- | :--- | :--- |
| Proje | `GameAnimationSampleBuilder.createProject` | Yoksa `<projeler>/<ad>`, `ProjectRepository.createProject` ile (boş şablon). |
| Clip'ler | `GaspAnimationImport.run` | Her FBX arka plan isolate'lerinde dönüştürülür (`FbxImportService.convert`, aynı anda altı tane), bir worker isolate bunları sırayla `GlbRetargetBatch` ile retarget eder ([lumina_core servisleri](../lumina_core/services-continued.md)). Bir veritabanının kullandığı clip'ler karakter mesh'inin `.entity.glb`'sine, geri kalanlar `<mesh>_Library.lmas` + `.entity.glb`'ye (aynı mesh) girer; böylece oyun yalnızca oynattığı clip'leri yükler. Zıplama clip'leri kök yüksekliğini kaybeder (`removeRootHeight`: yayı kapsül taşır). Clip başına bir animasyon `.lmas`'ı `contents/animations/<mesh>/<kategori>/` altında. Dışa aktarıldığı haliyle mesh, yeniden kurulum ondan başlasın diye `Saved/GameAnimationSample/<mesh>.base.glb`'de saklanır. |
| Veritabanları | `GaspDatabases` | `PSD_Stand` (bekleme, yerinde dönüş, yürüme / koşma / sprint döngüleri, başlangıçlar, duruşlar, pivotlar, dönüşler), `PSD_Crouch`, `PSD_Jump`, `PSD_Land`; örneğin yoğun (dense) veritabanlarından birleştirilir, her clip yürüyüş türüyle (`Idle`, `Walk`, `Run`, `Sprint`, `Crouch`, `Jump`) ve veritabanının etiketleriyle etiketlenir, döngülerde veritabanının looping cost bias'ı ve örnekleme aralıkları alınır; şema: −0,05, 0,35, 0,7 ve 1,0 s'de yörünge, ayak konum + hız, pelvis hızı. Örneğin base cost bias'ları alınmaz: bunlar örneğin seçicisinin aynı an için seçtiği veritabanlarını sıralar; tek veritabanında birleşince ayakta duran karakteri durmadan döndürürlerdi. `.posedb` önbellekleri arka plan isolate'inde kurulur. |
| Karakter | `GaspCharacterContent` | `BP_SandboxCharacter`: kapsül 35 × 90, gecikmeli 320 cm spring arm, karakter hareketi; Move / Look / Jump, basılı tutulan Left Shift ile sprint, Left Ctrl ile yürüme anahtarı, C ile çömelme anahtarı ve yürüme hız sınırını yürüyüş türüne göre koyan bir Tick (çömelme 225 > sprint 700 > yürüme 200 > koşu 500 cm/s, örneğin döngülerinin hızları). `ABP_SandboxCharacter`: Stand, Crouch, Air ve Land; her biri kendi veritabanı üzerinde bir Motion Matching state'i (harekete dön), böylece kök hareketli hiçbir clip gltfio tarafından oynatılmaz. `BP_SandboxGameMode` karakteri doğurur. `DartCodeGeneratorService.compileAndWriteActor` ile `lib/`'e derlenir. |
| Level | `GaspSandboxLevel` | `L_Sandbox`: level dışa aktarımının blokları (`GaspLevelBlock.fromCorners`: dışa aktarımın X ve Y'si yazım uzayında yer değiştirir, kutunun kendi X'i küpün Y kenarını izler, dönüş `authoringRotation` ile yazım `[pitch, roll, yaw]` olarak geri gelir) ya da `defaultBlocks()` (alçak / orta / yüksek bloklar, bir duvar, 20 cm'lik bir kiriş, 20°'lik bir rampa, on 20 cm'lik basamak, bir platform); dünya hizalı ızgara malzemeli kutu primitive'leri (`M_Grid_Floor`, `M_Grid_Block`, `M_Grid_Traversable`, süreç içi malzeme derleyicisiyle derlenir), bir zemin, oyun moduna bağlı oyuncu başlangıcı, güneş, gökyüzü, yükseklik sisi, proplar. |
| Proje | | Girdi, Maps & Modes (`L_Sandbox` editör açılış ve oyun varsayılan haritası, oyun modu), level'ın kodu, girdi kodu, Blueprint kayıt defteri ve `lib/main.dart`. |

`GameAnimationSampleBuilder.build` bir `GameAnimationSampleReport` döndürür (clip'ler, hatalar, içe aktarma / dönüştürme / retarget süreleri, GLB boyutları, veritabanı istatistikleri); çalıştırıcı bunu `Saved/GameAnimationSample/report.json`'a yazar.

## Çalıştırma

`lumina_editor_data` içinden (Flutter gerekir: içe aktarıcı ve küçük resimler onu kullanır):

```bash
LUMINA_GASP_EXPORT=<dışa aktarım klasörü> \
LUMINA_GASP_MESH=contents/meshes/skeletal/SK_MH_Sandbox.lmas \
LUMINA_GASP_LEVEL=<level dışa aktarımı .json> LUMINA_GASP_PROPS='<model>;<model>' \
flutter test tool/game_animation_sample/build_game_animation_sample_test.dart
```

`LUMINA_GASP_PROJECTS` (varsayılan `~/Lumina Projects`) ve `LUMINA_GASP_PROJECT` (varsayılan `game_animation_sample`) projeyi adlandırır; `LUMINA_GASP_CATEGORIES=Idle,Sprint` clip'leri sınırlar. `LUMINA_GASP_MESH` olmadan çalıştırıcı yalnızca projeyi oluşturur: karakterin skeletal mesh'ini içine koyun (MetaHuman Creator → Export), sonra yeniden çalıştırın. `LUMINA_GASP_EXPORT` olmadan atlanır.

Örneğin 1879 clip'i bir MetaHuman'a (1201 düğüm, Windows) ölçüldü: clip'ler için 33 s (altı isolate'e dağılmış 190 s FBX dönüştürme, 31 s retarget), karakterin GLB'sinde 704 clip (200 MB mesh ile 320 MB), kütüphanede 1175 (422 MB); `PSD_Stand` 447 clip / 51 195 satır (6,8 MB önbellek), `PSD_Crouch` 199 / 22 413, `PSD_Jump` 19 / 1 292, `PSD_Land` 39 / 3 765; tüm kurulum yaklaşık 55 s.

## Doğrulama

`test/smoke/game_animation_sample_smoke_test.dart`, kurulmuş projenin `L_Sandbox`'ını GPU'da oynatır (proje kurulmamışsa atlanır; `LUMINA_GASP_PROJECT_DIR` başkasını adlandırır): oyun modu karakteri doğurur, proje girdisi bekleme → yürüme → koşma → sprint → durma → çömelerek yürüme → kalkma → zıplama → koşarak zıplamayı sürer; yürüyüş türü hızlarını, evre başına eşleşen clip'leri ve Air state'ini denetler; evre başına PNG, bir video ve kare başına maliyet (oyun tick'i, motion matching güncelleme ve arama) metriklerde. `test/samples/game_animation_sample_test.dart` örnek verisi gerektirmeyen parçaları kapsar.

## Kapsanmayanlar

Örneğin traversal (vault, mantle, hurdle, climb), etkileşim, kayma, aim offset, look-at ve ragdoll clip'leri kütüphane asset'ine aktarılır ama hiçbir şey onları oynatmaz: motorda traversal, etkileşim ya da kayma mantığı, Motion Matching state'lerinde aim offset ve ragdoll yoktur. Çömelme kapsülü küçültmez. Level dışa aktarımının landscape'i ve Blueprint actor'ları (ışınlayıcılar, düğmeler, hedef mankeni) yeniden kurulmaz.
