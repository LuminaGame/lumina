[English](../../en/lumina/pose-authoring.md)

# Poz verme (pose authoring)

Skinli bir karakter çalışma zamanında bir manken gibi pozlanabilir: eli hareket ettirince dirsek ve omuz bükülür, dirseği hareket ettirince kol düzlemi omuz–el ekseni etrafında döner ve el yerinde kalır, başı çevirince boyun dönüşü paylaşır, göğsü çekince omurga bükülür, pelvisi hareket ettirince yere basan ayaklar yerinde kalır. Ayarlanan her şey değişene kadar her karede korunur; bir poz yakalanabilir, kaydedilebilir ve geri yüklenebilir. Bunu `LuminaPoseAuthoringComponent`, mesh'in bir poz değiştiricisi olarak yapar ([Mesh bileşenleri](components-mesh-and-particles.md) içindeki `poseModifiers`), klip ya da poz sürücüsü ve eklem geçersiz kılmalarından sonra, [ragdoll](ragdoll.md) gibi.

| Parça | Yer |
| :--- | :--- |
| Bileşen ve kare başına çözüm | `lib/src/components/mesh/pose_authoring/pose_authoring_component.dart` (+ `pose_authoring_solve.dart`) |
| Rig: kemikler, sınırlar, rig asset'i | `pose_rig.dart`, kemik adından algılama `pose_rig_detect.dart` |
| Tutamaçlar, yakalama kipleri | `pose_handle.dart` |
| Çözücüler (iki kemik, pole, bakış, omurga, pelvis, twist) | `pose_solve_state.dart` üzerinde `pose_solvers.dart`; quaternion yardımcıları `pose_quat.dart` |
| Pozlar: poz kütüphanesi, save game slotları, Play-In-Editor | `pose_library.dart` |
| Tutup pozlama: tutucular, fare tutucusu, etkileşimci, tutamaç görselleri | `lib/src/interaction/grab/` |
| Blueprint düğümleri | `pose_authoring_nodes.dart`, `lib/src/blueprint/node_library/pose_authoring.dart`, `lib/src/blueprint/blueprint_function_library/pose_authoring.dart` |

## Rig

`LuminaPoseRig.detect(GlbSkeleton)` bir insansının kemiklerini adlarından bulur: MetaHuman ve UEFN mankeni adları (`upperarm_l`, `lowerarm_l`, `hand_l`, `thigh_l`, `calf_l`, `foot_l`, `spine_01`…`spine_05`, `neck_01`, `neck_02`, `head`, `pelvis`) ve Mixamo adları (`mixamorig:LeftArm`, `Spine1`, `Neck`, `Hips`, …).

- **Uzuvlar** (`arm_l`, `arm_r`, `leg_l`, `leg_r`): üst, alt ve uç kemik. Onları `TwoBoneIkChain.detect` (`lumina_core`) bulur; skin ağırlığı taşımayan kemikler (bir MetaHuman'ın üst kolları ve uylukları) o kaçırınca adlarından bulunur. Üst ve alt kemiğin altındaki twist kemikleri (`upperarm_twist_01_l`, `lowerarm_twist_02_l`, `calf_twist_01_l`, …) kemik boyundaki yerleriyle tutulur.
- **Boyun zinciri**: omurganın üstündeki boyun kemikleri ve baş; her birinin başın dönüşündeki payı: iki boyun kemiği ve baş için 0.25 / 0.35 / 0.4 (tek boyun kemiğinde 0.4 / 0.6).
- **Omurga**: boynun altındaki `spine*` / `chest` kemikleri, pelvis tarafı önce; göğüs noktası başa doğru sonraki kemiktir (`neck_01`).
- **Pelvis**: omurganın altındaki kemik.
- Bacağı (ya da boynu) olmayan bir iskeletin onlar için tutamacı olmaz, hata da olmaz. Düzeltici (corrective) eklemler ve parmaklar sürülmez; ebeveynlerini izlerler.

Rig, rig kemiklerinin ve tüm atalarının poz dizisi üzerinde (`nodeNames`, düğüm başına 10 double: mesh'in yerel TRS'i), GLB'nin model çerçevesinde çalışır. Gövdenin yukarı, ileri ve sol yönleri dinlenme pozundan gelir (pelvis → baş, sol uzuvlar eksi sağdakiler); mesh'in ileri yönü hiç varsayılmaz.

**Rig asset'i**: `LuminaPoseRigDefinition` (kemik adıyla uzuvlar, omurga, boyun, ağırlıklar, pelvis, sınırlar) algılamanın döndürdüğüdür; `toAssetBytes` / `fromAssetBytes` onu bir `.lmas` içinde `metadata['pose_rig']` altında saklar. Bileşen algılamak yerine `rigAssetPath`'ten okur.

**Sınırlar** (`LuminaPoseRigLimits`, derece): dirsek ve diz menteşesi 0–150, kolun dışa yönü etrafında 150 omuz konisi, aşağı yön etrafında 120 kalça konisi, boyun yaw 80, pitch 60, roll 40 (tüm zincir), eklem başına gelen poz üzerine 20 omurga bükümü.

## Tutamaçlar

| Tutamaç | Tür | Neyi hareket ettirir |
| :--- | :--- | :--- |
| `hand_l`, `hand_r`, `foot_l`, `foot_r` | effector | İki kemikli IK: orta eklem kendi menteşesi etrafında kosinüs teoreminin verdiği açıya bükülür (menteşe sınırlarına ve koniye kırpılır), uzuv hedefe döner. Verilen rotasyon uç kemiğin dünya rotasyonudur; verilmezse el yerel rotasyonunu, ayak dünya rotasyonunu korur (düz kalır). Alt twist kemikleri ucun ön kol / incik etrafındaki twist'ini oradaki yerlerine göre paylaşır; üst twist kemikleri üst kemiğin kendi twist'ini geri tutar. |
| `elbow_l`, `elbow_r`, `knee_l`, `knee_r` | pole | Uzuv kök–uç ekseni etrafında döner, orta eklem tutamaca doğru düşer; el ya da ayak yerinde kalır (hedefinde, ya da animasyonun koyduğu yerde). |
| `head` | bakış | Tutamaç yüzün önündedir. Boyun zinciri, baş ilk boyun kemiği etrafında tutamaca doğru gidecek şekilde döner: göğsün yukarı ekseni etrafında yaw ve pitch, her biri kırpılır, zincirin ağırlıklarıyla paylaşılır; verilen rotasyon bakış yönü etrafındaki roll'unu ekler. |
| `chest` | göğüs | Omurga eklemleri üzerinde FABRIK, omurga kökü sabit, her eklemin bükümü sınırlı; ardından rotasyonlar yeni segment yönlerinden türetilir (boylar korunur). Başın tutamacı ayarlı değilse baş izler; kollar sonra yeniden çözülür. |
| `pelvis` | pelvis | Pelvis hareket eder (rotasyon verilirse döner). Hedefi olan ayaklar yerinde kalır (bacakları en son çözülür); hedefsizler izler. |

Kare başına çözüm sırası: pelvis → omurga → baş → kollar → bacaklar, tek geçiş.

```dart
final poser = LuminaPoseAuthoringComponent(mesh: mesh); // ya da BeginPlay'de bulunur
character.addComponent(poser);
await poser.ready;                                       // rig, mesh'in GLB'sinden bir worker isolate'te okunur
poser.setHandleTarget('hand_r', handWorld, worldRotation: gripWorld);
poser.setHandleTarget('elbow_r', elbowWorld);
poser.handleWorldTransform('head');                      // bir tutamacın şimdiki yeri (dünya, birim ölçek)
poser.findNearestHandle(cursorWorld, maxDistance: 8);    // (ad, mesafe) ya da null
poser.clearHandle('elbow_r');
poser.resetToReference();
```

- `setHandleTarget(name, worldLocation, {worldRotation})` dünya birimi (cm) alır. Hedef bir sonraki çözümde mesh'in render dönüşümüyle (dünya dönüşümü çarpı asset birim ölçeği) mesh'in model çerçevesine girer ve orada kalır: `captureMode` **`holdTargets`** (varsayılan) ile hedefler bileşen uzayında yaşar, poz aktörü izler ve bir tutamacı temizlemek uzvunu gelen poza geri verir; **`bakeToPose`** ile her çözülen poz bir sonraki karenin tabanı olur, temizlemek uzvu olduğu yerde bırakır. Rig yüklenmeden ayarlanan hedef, yüklenince kullanılmak üzere tutulur.
- `weight` (0–1) çözülen pozu gelen animasyonun üzerine harmanlar. Bir mankenin pozunu tutmak için hiçbir şey oynatmayın (ya da bir hold klibi) ve `weight` 1 kalsın.
- Transform manager'ın hâlâ son yazılan olarak tuttuğu bir düğüm canlandırılmamış sayılır: tabanı yazmadan önceki pozdur, böylece çözüm hiç kendi çıktısının üzerine kurulmaz.
- Bir hedef ayarlanınca ya da temizlenince `onHandleChanged` ve sahibin `onPoseHandleChanged(handle)`'ı (Blueprint olayı) çalışır.
- `lastSolveMicros`: son çözümün maliyeti.

## Pozlar

- `toAuthoredPose(name)` gösterilen pozu (her rig ekleminin yerel TRS'i) bir `AuthoredPose` (`lumina_core`) olarak yakalar.
- `applyAuthoredPose(pose, blendSeconds:)` tüm hedefleri bırakır ve `pose`'u gösterilen pozdan harmanlayarak gösterir; sonra ayarlanan tutamaçlar onun üzerinde çözülür. `resetToReference()` hedefleri, uygulanan pozu ve pişirileni bırakır.
- `LuminaPoseLibrary.load(assetPath, provider:)` bir mesh'in `PoseLibrary.lmas`'ını (Animation Editor'ün yazdığı, `contents/animations/<Mesh>/PoseLibrary.lmas`) `LuminaAssets` üzerinden (oyunun bundle'ı ya da disk) okur; `parse(bytes)` bellekteki birini okur.
- `savePose(slot, name)` / `loadPose(slot, name, blendSeconds:)` pozları bir save game slotunda tutar (`customSaveData['lumina_poses']`, slottaki diğer veri korunur), `LuminaPoseLibrary.saveToSlot` / `loadFromSlot` üzerinden. Play-In-Editor çalışırken (`LuminaPoseLibrary.editorProjectDir`, Play ayarlar) Save Pose pozu projedeki mesh'in `PoseLibrary.lmas`'ına da bir worker isolate'te yazar.

## Blueprint düğümleri

**Animation|Pose Authoring** (VM ve üretilen kod aynı `LuminaPoseAuthoringNodes` fonksiyonlarını çağırır; konumlar authoring eksenlerinde, rotatörler derece; Add Pose Authoring dışındaki her düğüm sahibin ilk pose authoring bileşeninde çalışır):

- `add_pose_authoring` (Mesh → bileşen; bağlı değilse sahibin ilk skeletal mesh'i; o mesh'te zaten varsa o döner),
- `set_pose_handle_target` (Handle, Location, Use Rotation, Rotation → kabul edildi),
- `get_pose_handle_transform` (Handle → Location, Rotation),
- `clear_pose_handle` (Handle), `reset_pose`,
- `find_nearest_pose_handle` (Location, Max Distance → Handle, Distance; yoksa `''` ve −1),
- `capture_pose` (Name → Pose, bir JSON metni) / `apply_pose` (Pose, Blend Time → uygulandı),
- `save_pose` (Slot, Name) / `load_pose` (Slot, Name, Blend Time) → başarı,
- **Event On Pose Handle Changed** (`event_pose_handle_changed` → Handle), `LuminaActor.onPoseHandleChanged`'den gönderilir.

`LuminaPoseAuthoringComponent` bir Blueprint bileşen türüdür de (`LuminaPoseAuthoringComponent.fromProperties`: `rigAsset`, `weight`, `captureMode`).

## Etkileşim: tutup pozlama

`lib/src/interaction/grab/`: tutucular (grabber) tutamaçları alır, sürükler ve olduğu yerde bırakır; poz kalır. Motor tutucuları yalnızca `LuminaGrabber` üzerinden tanır (`id`, `worldTransform` — cm cinsinden tutma pozu, `grip` 0–1, `isTracked`, isteğe bağlı `ray`, `pulse(amplitude, seconds)` — titreşimi olmayan cihazda hiçbir şey yapmaz, `grabbedAt(point)`); bu yüzden bir XR kumandası (OpenXR eklentisinin adaptörü) ve fare aynı bileşeni kullanır.

`LuminaPoseGrabInteractor` (pawn'da ya da XR origin'de bir aktör bileşeni) her karede her tutucu için:

- **Üzerine gelme**: `grabRadius` (8 cm; `handleRadius`: baş 12, pelvis 15) içindeki en yakın tutamaç, yoksa ışını varsa ona `rayAngleDegrees` (3°) içinde, `rayMaxDistance`'a (300 cm) kadar olan tutamaç.
- **Tutma**: grip `pressThreshold`'u (0.7) geçince (`releaseThreshold`, 0.3 altında bırakır): tutamacın tutucuya göre dönüşümü saklanır (uzuv sıçramaz), karakterin hedefleri bir geri alma adımı olarak itilir, `pulse(0.5, 0.03)`, `onHandleGrabbed` ve sahibin `onPoseHandleGrabbed(handle, grabber)`'ı. Tutucu başına bir tutamaç, tutamaç başına bir tutucu: tutulan bir tutamacı alan tutucu onu çalar (diğeri bırakır; ikisi de titrer).
- **Sürükleme**: hedef = tutucu dönüşümü × ofset; eller, ayaklar ve baş rotasyonunu da alır. Etkileşimci her karakterin `beforeSolve` kancasından (dünya karesi başına bir kez) çalışır, böylece uzuv tutucuyu aynı karede izler.
- **Bırakma**: tutamaç son hedefini korur, `pulse(0.2, 0.015)`, `onHandleReleased`. İzlenmeyen bir tutucu bırakır.
- **Geri alma**: `undoLastGrab()` karakterin hedeflerini son tutmadan önceki haline getirir (`LuminaPoseAuthoringComponent.pushUndo` / `undo` / `targetSnapshot` / `restoreTargets`, 32 adım).
- Karakterler `register(poser)`'dan ve `findPosersInReach` ile dünyadaki, bir tutucuya (`reach`, 300 cm) ya da ışınına yakın her pose authoring bileşeninden gelir.

`LuminaPoseHandleVisuals` (dünya render edilirken etkileşimcinin yaptığı, `showHandles`) bir tutucuya yakın (60 cm, ya da ışınından 12°) tutamaçları mesh'lerin üzerinde Filament çizgilerinden küçük halkalar olarak çizer: boşta `idleAlpha` ile (0 gizler), üzerine gelinende vurgu renginde 1.3×, tutulanda parlak ve tutucuya bir çizgiyle.

`LuminaMouseGrabber` masaüstü tutucusudur: `cursor`'dan (viewport pikseli; `viewportSize`, `cameraLocation`, `cameraRotation`, `fovYDegrees`) geçen kamera ışını boyunca bakar, `leftDown` grip'tir ve kameranın ileri ekseni boyunca `depth` cm'de tutar — tutunca tutulan tutamacın derinliğine ayarlanır, böylece sürükleme tutamacı kameraya bakan düzlemde hareket ettirir; `wheel(notches)` onu yaklaştırır ya da uzaklaştırır. `syncFromWorld(world)` görünümü ve host'un input subsystem'e enjekte ettiği imleç / `MouseLeft`'i okur (Play-In-Editor yapar); etkileşimcide `useMouse: true` bir tane yapar ve her kare eşitler. İşletim sistemi girdisi okumaz. 3 m'den uzak bir kamera daha uzun bir `rayMaxDistance` ister.

**Blueprint düğümleri** (aynı kategori): `add_grab_interactor` (Use Mouse → etkileşimci), `register_grabber` (Grabber nesnesi → kaydedildi), `set_grab_radius` (Radius), `undo_last_grab` (→ geri alındı) ve **On Pose Handle Grabbed / Released / Hovered** olayları (`event_pose_handle_grabbed` / `_released` / `_hovered` → Handle, Grabber), etkileşimcinin sahibindeki `LuminaActor.onPoseHandleGrabbed` / `onPoseHandleReleased` / `onPoseHandleHovered`'dan gönderilir. `LuminaPoseGrabInteractor` bir Blueprint bileşen türüdür de (`grabRadius`, `useMouse`, `showHandles`).

## Sayılar

Bu makinede (Windows, smoke için RTX PRO 2000) bir manken rig'i 41 slottur; 11 tutamacın hepsi tutulurken bir çözüm yaklaşık 0.025 ms sürer; smoke'un render edilen karelerinde medyan yaklaşık 0.1–0.19 ms'dir (CPU'yu render ve kare okumalarıyla paylaşır). Erişimdeki hedeflere 1e-13 cm'ye kadar ulaşılır; kemik boyları 1e-4 cm içinde korunur.

## Sınırlar

Tek geçiş, zincirler arasında yineleme yok: göğüs büküldükten sonra erişim dışında kalan bir el hedefi kısa kalır. Parmaklar pozlanmaz (sonraki bir el hazır ayarı). Omurganın büküm sınırı mutlak bir aralık değil, gelen poz üzerine ölçülür. MetaHuman düzeltici eklemleri ebeveynlerini katı olarak izler (rig mantıkları çalışma zamanında çalışmaz).
