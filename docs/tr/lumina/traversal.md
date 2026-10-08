[English](../../en/lumina/traversal.md)

# Traversal (engel aşma)

Bir engelin önünde zıplama tuşuna basan karakter zıplamak yerine engelin üstünden atlayabilir (hurdle), elleriyle destek alıp geçebilir (vault) ya da üstüne tırmanabilir (mantle): engel çarpışma sorgularıyla ölçülür, ona uyan eylem ve clip seçilir ve clip **root motion** ile oynar — root'unun ötelemesi ve yaw'ı karakteri taşır — ve **motion warping** ile bükülür; böylece eller ölçülen kenara, ayaklar ölçülen zemine iner. Clip, Animation Blueprint'in varsayılan slot'unda state machine'in (Motion Matching state dahil) üstünde oynar ve pozu inertialization ile geri verir.

| Parça | Yer |
| :--- | :--- |
| Engel ölçümü ve sınıflandırma | `lib/src/components/movement/traversal/traversal_check.dart` |
| Chooser satırları, clip / başlangıç zamanı seçimi | `lib/src/components/movement/traversal/traversal_chooser.dart` |
| Bileşen | `lib/src/components/movement/traversal/traversal_component.dart` |
| Motion warping | `lib/src/animation/root_motion/motion_warping.dart` |
| Bir clip'in CPU'daki root motion'ı | `lib/src/animation/root_motion/root_motion_track.dart` |
| Root-motion montage oynatıcı | `lib/src/animation/root_motion/root_motion_montage_player.dart` |
| Slot oynatıcı arayüzü | `lib/src/animation/root_motion/anim_slot_player.dart` |
| Blueprint node'ları | `lib/src/blueprint/node_library/traversal.dart`, `lib/src/blueprint/blueprint_function_library/traversal.dart` |

## Ölçüm (`LuminaTraversalCheck`)

Hepsi runtime eksenlerinde (Y yukarı, cm); yükseklikler karakterin ayaklarının üstünden:

1. Karakterden yüzü baktığı yöne süpürülen bir kapsül (`traceRadius` 30, `traceHalfHeight` 60) dikeye yakın bir yüz bulur (`|normal.y| ≤ maxWallSlope` 0.5). Süpürme dururken `minTraceDistance` (75 cm), `fastSpeed`'te (500 cm/s) `maxTraceDistance` (350 cm) kadar uzanır; temas yüksekliğinde yüze atılan bir ışın yüzü tam yerine koyar.
2. Yüzün üstünden aşağı atılan ışın tepeyi bulur: **ön kenar** (yüz üzerindeki üst ön kenar, yüzün yatay normaliyle) ve **engel yüksekliği**; `minLedgeHeight`–`maxLedgeHeight` (50–275 cm) aralığında olmalıdır; azami yüksekliği aşan duvar önce elenir.
3. Karakterin kapsülü durduğu yerden kenarın hemen üstüne süpürüldüğünde serbest olmalıdır (yükselmeye yer).
4. Tepe boyunca her 4 cm'de aşağı atılan ışınlar (ikiye bölmeyle inceltilir) arka kenarı bulur: **arka kenar** ve **engel derinliği** (`maxDepthScan` 150 cm). Kapsül tepe boyunca süpürüldüğünde serbest olmalıdır; değilse derinlik çarptığı yerde biter ve arka kenar yoktur.
5. Arka kenarın arkasında engel yüksekliği artı `backFloorReach` (20 cm) kadar aşağı süpürülen kapsül **arka zemini** bulur; **arka kenar yüksekliği** tepenin bu zeminden yüksekliğidir.
6. Ön kenarın hemen arkasında, tepede bir kapsül sığmalıdır (tepede yer).

Sınıflandırma (`LuminaTraversalActionType`):

| Eylem | Ne zaman |
| :--- | :--- |
| `hurdle` | arka kenar, arka zemin, derinlik < 59 cm, arka kenar yüksekliği ≥ 50 cm |
| `mantle` | arka kenar, tepeden en çok 10 cm aşağıda arka zemin ve derinlik < 59 cm; ya da derinlik ≥ 59 cm |
| `vault` | arka kenar, erişimde arka zemin yok (arkada düşüş; karakter sonra düşer), derinlik < 59 cm |
| `none` | hiçbiri uymaz (`reason` nedenini söyler); tepede yer olmayan mantle da `none`'dır |

`LuminaTraversalCheckResult` tüm ölçümleri, çarpılan bileşeni ve `facingYaw`'ı (engele dönük) taşır.

## Chooser satırları (`LuminaTraversalAnimation`)

Clip başına bir satır: `action`, `clip` (karakter mesh'inin bir glTF animasyonu), `minHeight`/`maxHeight`, `minDepth`/`maxDepth`, `minSpeed`/`maxSpeed` (yatay cm/s; satır `min ≤ değer ≤ max` olduğunda, hızda `< max` ile uyar), `blendOutTime` (oyuncu yön verirken clip burada bitebilir), `endTime`, `playRate`, `blendTime` (giriş ve çıkış inertialization'ı), `maxStartTime` ve warp `windows`. Satırlar JSON'a gidip gelir (`toJson` / `fromJson`); Blueprint bileşeni onları böyle saklar.

`LuminaTraversalChooser.choose` ölçüme uyan ve clip'i mesh'te bulunan satırları tutar, sonra ayakları (`foot_l`, `foot_r` ya da şemanın pozisyon kemikleri) şu an gösterilen poza en yakın clip'i ve başlangıç zamanını (her 1/30 s, `maxStartTime`'a kadar) seçer; ikisinde de root'un hareketi çıkarılmıştır — böylece sol ayak ya da sağ ayak varyantı uyan adımda başlar.

## Motion warping (`LuminaMotionWarper`)

Bir `LuminaWarpWindow` bir hedef (`FrontLedge`, `BackLedge`, `BackFloor`), clip zaman aralığı, ötelemeyi ve / veya dönüşü bükerek bükmediği, clip'in dikey hareketini koruyup korumadığı (`ignoreVertical`) ve **warp noktasını** adlandırır: root'un kendisi ya da pencere sonunda root'tan bir offset (`warpPointOffset`, root çerçevesinde: x yanal, y yukarı, z ileri, cm) — verilmiş ya da clip'in bir kemiğinden ölçülmüş (`warpPointBone`, ör. clip'in kenarının yazıldığı yere park edilmiş bir kemik).

Bir pencere içinde her adımda, clip'in pencere sonuna kalan root yer değiştirmesi hedefin çerçevesinde eksen eksen hedefe kalan mesafeye ölçeklenir (clip'in neredeyse hiç hareket etmediği eksen hedefine zamanla doğrusal varır); yaw da aynı şekilde hedefinkine döner. Böylece root clip'in şeklini korur ve pencerenin sonunda tam hedefe varır; adımlar pencere sınırlarında bölünür. Pencerelerin dışında root clip'i izler.

## Root-motion montage'ları (`LuminaRootMotionMontagePlayer`)

`LuminaRootMotionMontage` clip'i, başlangıç / bitiş / blend-out zamanını, oynatma hızını, blend süresini ve pencereleri adlandırır. Oynatıcı clip'i mesh'in GLB'sinden CPU'da örnekler (`LuminaGlbAnimationSampler`; mesh'in motion matching database'lerinin kullandığının aynısı, `LuminaPoseSearchDatabaseRuntime.meshSampler` üzerinden), pozu root'un tüm hareketi çıkarılmış hâlde gösterir (zemindeki konum, yön ve başlangıca göre yükseklik) ve onun yerine `owner`'ı taşır: her `advance` aktörü (ayakları konumunun `feetOffset` altında) bükülmüş root'a koyar ve bükülmüş yaw'a çevirir. Hem `LuminaMeshPoseDriver` hem `LuminaAnimSlotPlayer`'dır: `begin(fromPose:, fromVelocity:)` önceden gösterilen pozdan başlar ve ondan inertialization ile karışır; `pose` / `poseVelocity` sonraki poz kaynağının karıştığı şeydir. `rootVelocity` clip root'unun şimdiki hızıdır (karakterin sonra sürdürdüğü hız).

`LuminaRootMotionTrack` clip'in root zemin çerçevesinin 60 Hz örnekleridir: root çerçevesinde `delta(a, b)` (cm), `velocityAt`, `boneOffset(node, t)`.

## Animation Blueprint slot'u

`LuminaAnimBlueprintInstance.playSlot(player)` bir `LuminaAnimSlotPlayer`'ı state machine'in üstündeki varsayılan slot'ta oynatır: mesh'in gösterdiği pozdan (Motion Matching oynatıcısının pozu ve hızı) başlar, mesh'i alır ve state machine durumunu korurken her tick'te mesh uygulamadan önce ilerletilir. Oynatıcı bitince Motion Matching state slot'un son pozundan karışır (`LuminaMotionMatchingPlayer.blendFrom`: inertialization ve hemen bir arama); `stopSlot()` erken bitirir. VM ve üretilmiş Animation Blueprint'ler bu kodu paylaşır, ikisi aynı davranır.

## Bileşen (`LuminaTraversalComponent`)

| Üye | Anlamı |
| :--- | :--- |
| `animations` | Chooser satırları. |
| `tryTraversalAction()` | Ölçer, seçer ve oynatır; karakter yürümüyorsa, hiçbir eylem ya da clip uymuyorsa ya da clip'ler henüz yüklenmediyse false döner (hiçbir şey değişmez). |
| `checkTraversal()` | Yalnızca ölçüm. |
| `isTraversing`, `currentAction`, `player`, `lastCheck`, `lastChoice`, `actionCount` | Durum. |
| `stopTraversal()` | Eylemi bitirir (kesilmiş). |
| `onTraversalFinished` | `(action, interrupted)`. |
| `customMovementMode` | Eylem oynarken ayarlanan özel hareket modu indeksi (1). |
| `rootBone`, `meshYawOffsetDegrees` | Clip'ler motion matching database'inin değilse rig'leri (`rootBone` database'in root'unu da geçersiz kılar: clip'lerin root motion'ını taşıyan kemik). |
| `minLedgeHeight`, `maxLedgeHeight`, `minTraceDistance`, `maxTraceDistance`, `debugDraw`, `enabled` | Ölçüm ayarları; `debugDraw` kenarları ve zemini bir saniye işaretler. |
| `useRig(rig)` | Kodda kurulmuş bir rig kullanır. |

Eylem oynarken hareket bileşeni sıfır hızla `MovementMode.custom`'da bekletilir; aktörün konumu her karede bükülmüş root'tan ayarlanır (hareket tick'inden sonra; depenetration yolla çekişmez — ölçümler yer olduğundan emin olmuştur). Bitince karakter clip'in çıkış hızıyla (yürüme hızıyla sınırlı) yürür (vault'tan sonra düşer). Animation Blueprint varsa eylem onun slot'unda oynar; yoksa bileşen mesh'i kendisi sürer ve önceki poz sürücüsüne geri verir (bu bir motion matching oynatıcısıysa karıştırarak).

Blueprint'ler onu `LuminaTraversalComponent` tipinde bileşen olarak ekler (özelliklerinde `animations` JSON satırları) ve **Try Traversal Action** (Success), **Traversal Check** (Action Type, Obstacle Height, Obstacle Depth, Back Ledge Height, Has Front Ledge) ve **Is Traversing** node'larıyla çağırır. Önce traversal deneyen zıplama: `IA_Jump Started → Try Traversal Action → Branch (Success) → False: Jump`.

## Testler

`test/src/components/movement/traversal_check_test.dart` (kutular: hurdle, vault, alçak / yüksek mantle, platform, çok yüksek / alçak, yer yok, önde bir şey yok, hıza göre ölçüm uzunluğu), `test/src/animation/root_motion/` (warping matematiği, root izi, oynatıcı, giriş / çıkış karışımı), `test/src/components/movement/traversal_component_test.dart` (hurdle ve mantle yapan Blueprint karakter, Jump'a geri dönüş, slot'un motion matching'e geri vermesi), `lumina_editor_data/test/blueprint/traversal_blueprint_parity_test.dart` (VM ve üretilmiş Dart aynı), `lumina_editor_data/test/samples/gasp_traversal_fbx_test.dart` (gerçek traversal clip'leri kutularda: her warp hedefine 1 cm içinde varılır) ve GPU smoke'u `lumina_editor_data/test/smoke/traversal_smoke_test.dart`.
