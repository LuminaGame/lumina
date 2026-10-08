[English](../../en/lumina/ragdoll.md)

# Ragdoll, düşme ve ayağa kalkma

İskeletli bir karakter gevşeyebilir: bir **physics asset**'in kemik başına rijit gövdeleri dünyanın [fizik](physics.md) alt sisteminde oluşturulur, **eklemlerle** (salınım konisi ve burulma aralığı olan bilye-yuva, diz ve dirsekler için menteşe) bir arada tutulur, seviyeyle ve birbirleriyle çarpışır ve animasyonlu mesh'in kemiklerini animasyonla harmanlayarak sürer. `LuminaRagdollComponent` taşıyan bir karakter düşmelere de tepki verir (uzun düşüşte havada gevşer, sert yere inişte ağır iniş oynar) ve yattığı biçime uyan kalkma klibiyle yeniden ayağa kalkar.

| Parça | Yer |
| :--- | :--- |
| Physics asset biçimi ve üreteci (saf Dart) | `lumina_core/lib/src/physics_asset/physics_asset_data.dart`, `physics_asset_generator.dart` |
| Eklemler | `lib/src/physics/physics_joint.dart`, `lib/src/physics/joint_batch.dart` |
| Bir ragdoll'un gövde ve eklemleri | `lib/src/physics/ragdoll/ragdoll.dart` |
| CPU iskelet alt kümesi, gövdeler → kemikler | `lib/src/physics/ragdoll/ragdoll_skeleton.dart`, `ragdoll_poser.dart` |
| Düşmeler | `lib/src/physics/ragdoll/fall_monitor.dart` |
| Ayağa kalkma | `lib/src/physics/ragdoll/ragdoll_get_up.dart` |
| Bileşen | `lib/src/physics/ragdoll/ragdoll_component.dart` (+ `ragdoll_component_states.dart`) |
| Mesh kancası | `lib/src/components/mesh/mesh_pose_modifier.dart` |
| Blueprint düğümleri | `lib/src/blueprint/node_library/ragdoll.dart`, `lib/src/blueprint/blueprint_function_library/ragdoll.dart` |
| Projede asset üretimi | `lumina_editor_data/lib/src/services/physics_asset_generation.dart` |

## Physics asset'ler

`LuminaPhysicsAssetData`, [Physics Asset editörünün](../lumina_ui/sub-editors/physics-asset.md) yazdığı belgedir; `physicsAsset` türündeki bir `.lmas` içinde `metadata['physics_asset']` altında JSON olarak durur (şema 2, uzunluklar cm; metre cinsinden şema 1 belgesi okunurken dönüştürülür). Bu sürümün bilmediği anahtarlar korunur ve geri yazılır.

- **Gövdeler** (`LuminaPhysicsBodyData`): `bone`, `shape` (yerel Y boyunca `capsule`, `sphere`, `box`), `radius`, `half_height` (uçlar dahil), `half_extents`, `offset_t` / `offset_r` (şeklin kemik çerçevesindeki yeri: dünya dönüşü, cm, `Ry · Rx · Rz` sırasıyla Euler XYZ derece), `mass_kg`, `linear_damping`, `angular_damping`.
- **Kısıtlar** (`LuminaPhysicsConstraintData`): `body_a` (ebeveyn tarafı), `body_b` (çocuk tarafı; eklem onun kemiğinin orijinindedir), `angular_mode` (`free`, `limited`, `locked`), `swing1_deg` (eklem çerçevesinin Y'si etrafında), `swing2_deg` (Z etrafında), `twist_deg` (simetrik, X etrafında) ve çalışma zamanı anahtarları `type` (`ball` / `hinge`), `twist_min_deg` / `twist_max_deg` (asimetrik aralık: diz 0…140° bükülür) ve `frame_r` (eklem çerçevesinin çocuk kemik çerçevesindeki dönüşü; yoksa kemiğin çerçevesi). Sınırlar **dinlenme pozundan** ölçülür.
- **`disabled_collision_pairs`**: hiç çarpışmayan gövde çiftleri.

`LuminaPhysicsAssetGenerator.fromSampler(sampler, totalMassKg: 80)` bir skinned GLB'nin iskeletinden (`LuminaSkeletonRest`) asset üretir: gövdeler yalnızca adıyla bulunan ana kemiklerde — pelvis, iki omurga gövdesi, kafa, üst / alt kollar, eller, uyluklar, baldırlar, ayaklar (UE / MetaHuman adları `pelvis`, `spine_02`, `spine_04`, `upperarm_l`, … ve Mixamo adları) — twist, düzeltici, parmak ve IK kemiklerinde asla; böylece bir MetaHuman'ın yüzlerce eklemi simüle edilen kemiklerin altında animasyonlu dönüşümlerini korur. Boyutlar karakterin boyunu (kafadan ayağa) izler; kapsüller her uzuv boyunca bir sonraki gövdeye uzanır, gövde kapsülleri bedene enine yatar, ayaklar düz kutulardır (yuvarlak bir şekil yuvarlanırdı). Kütle gövdelere paylaştırılır (pelvis %15, göğüs %18, uyluklar %11,5'er, …). Pelvis dışındaki her gövde en yakın gövdeli atasına bir eklemle bağlanır: anatomik koni ve burulmalı bilye eklemler, dirsekler (öne bükülen) ve dizler (geriye bükülen) için menteşeler — ileri yön ayaklardan çıkarılır. Dinlenme pozunda çakışan çiftler devre dışı bırakılır.

`PhysicsAssetGeneration.generateForSkeletalMesh(projectDir, meshAssetPath)` arka plan isolate'inde üreterek `contents/physics/PHYS_<mesh>.lmas` yazar (referans yuvası `skeletal_mesh`, projeye göreli); `overwrite` verilmedikçe var olan asset korunur.

## Eklemler

`LuminaPhysicsJoint`, `bodyA` ile `bodyB`'yi birleştirir: her gövdenin çerçevesinde bağlantı noktası ve eklem çerçevesi (`LuminaPhysicsJoint.atWorld` bunları gövdelerin şu anki pozundan alır). B'nin eklem çerçevesinin A'nınkine göre dönüşü **salınım** (eliptik koni `swing1` × `swing2`) ve **burulma** (`twistMin` … `twistMax`) olarak ayrılır; `LuminaJointKind.hinge` salınımı kilitler. `frictionTorque` göreli dönmeye direnir (kas tonusu: ragdoll sallanmak yerine durulur); `motorEnabled` + `motorTarget` + `motorRate` + `motorMaxTorque` göreli dönüşü bir hedefe çeker (güçlendirilmiş ragdoll).

`LuminaPhysicsSubsystem.addJoint` / `removeJoint`. Her adımda uyanık eklemler (`LuminaJointBatch`) temaslarla birlikte çözülür: warm start'lı nokta ve açı satırları, yönü sırayla değişen geçişler, ardından `jointIterations` (6) yalnız-eklem geçişi; açı sınırları 0,02 rad payın ötesindeki hatanın her adımda %20'sini düzeltir; entegrasyondan sonra `jointPositionIterations` (4) geçiş bağlantı noktalarını birbirine çeker. Birleştirilmiş gövdeler birbiriyle çarpışmaz ve aynı adayı paylaşır (birlikte uyur, birlikte uyanır). Bir aktörün gövdeleri ancak ikisi de `LuminaRigidBody.collidesWithOwnBodies` açıksa ve biri ötekini `ignoredBodies` içinde listelemiyorsa birbiriyle çarpışır.

## Bir ragdoll

`LuminaRagdoll.create(physics:, owner:, asset:, skeleton:, rest:, start:, velocities:)` her asset gövdesi için bir çarpışma bileşeni ve rijit gövde oluşturur (`owner`'a ait, çarpışma alt sistemine kayıtlı değil: sahibin kapsülü ve izleri onları görmez), eklemleri dinlenme çerçevelerinde kurar, sonra gövdeleri kemiklerin hızlarıyla `start` çerçevelerine taşır. Gövdeler 0,9 sürtünme ve sıfır sekme kullanır; eklem sürtünmesi `jointFrictionPerKg` (kg başına 3000 kg·cm²/s²) × çocuğun kütlesidir.

- `boneFrames()` — gövdelerin şu an verdiği kemik çerçeveleri (`bodyWorld · offset⁻¹`).
- `addImpulse(impulse, bone:, location:)`, `addVelocity`, `driveToward(frames, maxTorque:, rate:)` (motorlar bir pozun göreli dönüşlerine), `setDamping`.
- `kineticEnergy`, `maxSpeed`, `centerOfMassSpeed`, `isSettled(speed)`, `maxJointError`, `destroy()`.

`LuminaRagdollSkeleton`, bir mesh'in düğümlerinin ebeveynlere göre kapalı bir alt kümesidir (ya da tümü), dinlenme pozuyla; pozlar düz TRS dizileri, dünya afinleri mesh'in render dönüşümü çerçevesindedir (dünya cm). `LuminaRagdollPoser.apply(pose, meshAffine, targets, weight)` dünya çerçevelerini yerel poza yazar, önce ebeveynler: sürülen bir kemiğin dünya çerçevesi `lerp(animated, target, weight)` olur ve yerel dönüşümü ebeveyninin yeni çerçevesinden çıkar; başka bir sürülen kemiğin altındaki sürülen kemikler animasyonlu yerel ötelemelerini korur (uzama yok); diğerleri birlikte taşınır.

## Mesh kancası

`LuminaAnimatedMeshComponent.poseModifiers`, klip ya da pose driver ve eklem override'larından sonra çalışır: mesh bir değiştiricinin `poseModifierNodes` düğümlerinin yerel dönüşümlerini bir poz dizisine okur, `modifyPose(pose, meshTransform, dt)` çağırır ve true dönerse geri yazar. Animation Blueprint, motion matching ve slot montage'ları altta çalışmayı sürdürür.

## Bileşen

`LuminaRagdollComponent` (Blueprint türü `LuminaRagdollComponent`; PIE'de ve üretilen oyunlarda özelliklerinden kurulur):

| Özellik | Varsayılan | |
| :--- | :--- | :--- |
| `physicsAsset` | `''` | Bir `physicsAsset` `.lmas`; boşsa mesh'in iskeletinden üretilir. |
| `blendWeight`, `blendInTime`, `blendOutTime` | 1, 0,08 s, 0,4 s | Fizik ↔ animasyon ağırlığı ve geçişler. |
| `powered`, `motorStrength` | false, 2·10⁶ | Animasyonlu poza doğru motorlar (kg başına kg·cm²/s²). |
| `autoRagdollOnFall`, `ragdollFallSpeed`, `ragdollLandingSpeed`, `hardLandingSpeed` | true, 1300, 1200, 750 cm/s | Hareket bileşeni üzerinde `LuminaFallMonitor`. |
| `flailClip`, `flailStrength` | `''`, 6·10⁵ | Ragdoll düşerken motorların izlediği klip. |
| `hardLandingClip` | `''` | Sert yere inişte animasyonun üstünde oynar (`onHardLanding`). |
| `autoGetUp`, `settleSpeed`, `settleTime`, `maxRagdollTime` | true, 8 cm/s, 0,6 s, 8 s | Ragdoll'un ne zaman kalktığı. |
| `getUpClips`, `getUpBlendIn`, `getUpBlendOut` | `[]`, 0,3 s, 0,35 s | Aday kalkma klipleri ve geçişleri. |
| `meshYawOffsetDegrees` | 0 | Mesh'in yazıldığı ileri yön (Animation Blueprint'inin dediği gibi). |

Mesh'in iskeleti ve klipleri GLB'sinden CPU'da `LuminaPoseSearchDatabaseRuntime.meshSampler` ile okunur (motion matching ile paylaşılır, arka plan isolate'inde bir kez ayrıştırılır); physics asset'in `.lmas`'ı arka plan isolate'inde ayrıştırılır.

- **`startRagdoll({impulse, bone, location})`**: gövdeler son iki karenin hızlarıyla animasyonlu kemiklerin üzerinde başlar; hareket bileşeni özel mod `ragdollMovementMode`'da (71) bekler ve kapsül yerdeki pelvisi izler (kamera da). Başka bir sistem kapsülü özel bir modda tutarken (bir traversal hareketi) reddedilir.
- **Düşmeler**: `ragdollFallSpeed`'den hızlı düşmek havada gevşetir (pelvis yerden 60 cm'den yüksekken motorlar `flailClip`'e doğru); `ragdollLandingSpeed`'den hızlı yere iniş gevşetir, `hardLandingSpeed`'den hızlısı `hardLandingClip` oynatır.
- **Durulma**: kütle merkezi 3 × `settleSpeed`'den yavaşladığında son sallantıyı durdurmak için sönüm (3 / 6) artar; `settleTime` boyunca `settleSpeed` altında (ve her gövde 4 × altında) kalınca gövdeler uyur ve `autoGetUp` ile karakter kalkar (ya da `maxRagdollTime` sonunda).
- **Ayağa kalkma** (`LuminaRagdollGetUp`): `getUpClips` arasından ilk karesi aynı biçimde yatan (pelvisin ileri ekseni aşağı ya da yukarı) ve anahtar kemik dizilimi en yakın klip; mesh, o kare ragdoll'un yattığı yere gelecek biçimde yerleştirilir (pelvis → kafa beden ekseni, pelvis ragdoll'unkinin üstünde, zemin altında), klip kök hareketi karakteri taşıyarak oynar, `getUpBlendIn` boyunca ragdoll'un son pozundan girer, `getUpBlendOut` boyunca canlı animasyona çıkar; sonra hareket bileşeni yeniden yürür. Uygun klip yoksa animasyon `blendOutTime` boyunca geri karışır.
- `stopRagdoll({getUp})`, `toggleRagdoll()`, `addImpulse(impulse, bone:, location:, startIfAnimated:)`, `playHardLanding([clip])`, `state` (`animated`, `ragdoll`, `gettingUp`, `blendingOut`), `ragdoll`, `getUpPlan`, `ready`, `loadError`, geri çağrılar `onRagdollStarted`, `onRagdollEnded`, `onGetUpStarted`, `onHardLanding`.

## Blueprint düğümleri

**Physics|Ragdoll** (sahibin ragdoll bileşeni üzerinde; VM ve üretilen kod aynı `LuminaBlueprintFunctionLibrary` fonksiyonlarını çağırır): `start_ragdoll` (→ Started), `stop_ragdoll` (Get Up), `toggle_ragdoll`, `is_ragdoll`, `add_ragdoll_impulse` (yazım eksenlerinde Impulse, Bone Name; animasyondaysa ragdoll'u başlatır).

## Sayılar

Bu makinede (Windows, smoke için RTX PRO 2000): 16 gövde, 15 eklemli bir mannequin ragdoll'u uyanıkken 120 Hz'de adım başına 0,08–0,17 ms sürer; 1,5 m'den bırakıldığında enerji kazanmaz, her eklemi 0,5 cm içinde tutar ve yaklaşık 2 s'de durulur; kalkma klipleriyle 15 m'den bırakıldığında havada gevşer ve bırakıldıktan yaklaşık 4 s sonra yeniden ayaktadır. [Game Animation Sample örneğinin](../lumina_editor_data/game-animation-sample.md) MetaHuman'ı 16 gövde alır; yaklaşık 1200 cm/s ile yere inmek eklemlerini birkaç kare boyunca 9 cm'ye kadar açar, yatarken 0,01 cm içinde kalırlar.

## Sınırlar

Çözücüde sürekli çarpışma yoktur: adım başına yaklaşık 5 cm'den hızlı giden bir uzuv dışarı itilmeden önce bir adım boyunca o kadar zemine gömülebilir. Kendi kendine çarpışma, dinlenmede çakışmayan ve komşu olmayan gövdeler arasındadır. Kısmi ragdoll (animasyonlu bedende gevşek bir kol) ve tam bir ragdoll'a itkiler dışında vuruş tepkisi harmanlaması yoktur.

---

[Önceki: Fizik](physics.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Yapay zeka (AI)](ai.md)
