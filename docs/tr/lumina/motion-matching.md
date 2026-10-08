[English](../../en/lumina/motion-matching.md)

# Motion matching

Motion matching bir karakteri büyük ve yapılandırılmamış bir clip kümesinden (yürüme döngüleri, başlangıçlar, duruşlar, pivotlar, dönüşler, yaylar, yan adımlar, idle'lar) elle kurulmuş bir state grafiği olmadan canlandırır: saniyede birkaç kez, pozu ve kök yörüngesi karakterin şu anki pozuna ve oyuncunun istediği yörüngeye en iyi uyan clip karesini arar ve inertialization ile ona geçer. Lumina'da üç parçası vardır:

- **Pose search database** (`lumina_core/lib/src/pose_search/`, saf Dart): asset, CPU clip örnekleyicisi, özellik çıkarımı, normalizasyon, aynalama, arama ve özellik önbelleği.
- **Çalışma zamanı** (`lumina/lib/src/animation/motion_matching/`): yörünge tahmini, oynatıcı, inertialization, mesh poz sürücüsü, actor bileşeni ve debug çizimi.
- **Animation Blueprint'ler**: VM'de (Play-In-Editor) ve üretilen Dart'ta aynı sonucu veren bir **Motion Matching** state pozu; ve Lumina Studio'da **Pose Search Database editörü**.

## Pose search database asset'i

Pose search database, `raw_payload`'ı JSON olarak bir `LuminaPoseSearchDatabaseDocument` olan (`target_mesh` metadata'da) `poseSearchDatabase` türünde bir `.lmas` asset'idir. Özellik matrisi yanındaki bir `.posedb` dosyasında önbelleklenir (`PSD_Locomotion.lmas` → `PSD_Locomotion.posedb`); editör bunu **Build** ile yazar, oyun da `contents/`'in geri kalanıyla birlikte paketler.

| Alan | Anlamı |
| :--- | :--- |
| `targetMesh` | Clip'leri GLB'sinde tutan iskelet mesh (bir mesh'in oynattığı her clip onun GLB'sindedir, bkz. [Animasyon](animation.md)). |
| `clips` | `LuminaPoseSearchClip`: `clip` (glTF animasyon adı), `loop` (yörünge sarar), `mirror` (aynalanmış kopya da aranır), `tags`, `enabled`, `costBias` (clip'in maliyetine eklenir; negatif onu kayırır), `samplingStart` / `samplingEnd` (yalnız bu aralıktaki karelere atlanır; 0 bitiş clip'in sonudur; geri kalanı oynamaya devam eder). |
| `schema` | `LuminaPoseSearchSchema`: `sampleRate` (30 Hz), `trajectoryTimes` (−0.33, 0.33, 0.67, 1.0 sn), `trajectoryPositionWeight`, `trajectoryFacingWeight`, `bones` (`LuminaPoseSearchBone(name, position:, velocity:)` ağırlıkları; varsayılan `foot_l` / `foot_r` konum + hız, `pelvis` hız), `rootBone` ('' = skin'in üstündeki `root` adlı kemik, yoksa skin'in en üst eklemi), `meshYawOffsetDegrees`. |
| `searchInterval` | Aramalar arası saniye (0.1). |
| `continuingPoseBias` | Arama, bir kare devam etmeyi bu kadar geçtiğinde geçiş yapar (0.05). |
| `loopingCostBias` | Her döngü clip'inin maliyetine eklenir (−0.05: duran pozlar döngüleri tercih eder). |
| `blendTime` | Bir geçişin harmanlandığı saniye (0.2; inertialization yarı ömrü bunun dörtte biri). |
| `excludeEndSeconds` | Tek seferlik bir clip'in son saniyelerine hiç atlanmaz (0.3). |

### Özellikler

Örneklenen her kare bir satırdır ve hepsi karakterin kendi çerçevesindedir: orijin = kök kemiğin zemine izdüşümü, ileri = kökün dinlenme ileri yönünün dönüşüyle çevrilmiş hali (+Z, yanal +X = sol, yukarı +Y), mesh'in model birimlerinde (glTF için metre):

- her yörünge zamanı için: kökün zemin konumu (x, z) ve bakış yönü (x, z) — döngü, tur başına yer değiştirmesiyle sarar; tek seferlik clip sonundaki (başındaki) hızla devam eder;
- her şema kemiği için: konumu ve karakter çerçevesine çevrilmiş **dünya** hızı (yere basan ayak yaklaşık 0 okunur).

Her özellik grubu (yörünge konumları, yörünge yönleri, her kemik konumu, her kemik hızı) ortalama standart sapmasıyla normalize edilir; şema ağırlıkları arama sırasında (karesi alınarak) uygulanır, böylece Motion Matching pozunun `poseWeight` / `trajectoryWeight` değerleri yeniden derleme olmadan ölçekler. Aynalanmış satırlar düz satırlardan türetilir (yanal bileşenler eksi, `_l` / `_r` kemikleri yer değiştirir).

### Arama

`LuminaPoseSearchIndex.search(query, weights:, requiredTags:, bound:)` `bound`'un altındaki en ucuz aranabilir satırı döndürür: satırlar alt sınır veren sınırlayıcı kutularla 16 karelik bloklarda gruplanır (kazanamayacak blok atlanır) ve her satırın toplamı o ana kadarki en iyiyi geçince durur. Budanmış arama, kaba kuvvetle tam olarak aynı satırı döndürür (1000 rastgele sorguda test edildi).

Game Animation Sample (UEFN mannequin) kümesinde, Windows, Dart JIT ile ölçüldü:

| Veritabanı | Satır (aynalılarla) | Derleme | Arama ort. / p99 | Oynatıcı karesi (bölüşülmüş arama + poz + inertialization) |
| :--- | :--- | :--- | :--- | :--- |
| 26 idle / walk / run clip'i | 5 866 | 0.13 sn | 22 µs / 42 µs | ort. 71 µs |
| 933 Idle + Walk + Run clip'i | 233 712 | 3.2 sn | 474 µs / 1.1 ms (kaba kuvvet 2.4 ms) | ort. 85 µs |

### Derleme ve önbellek

`LuminaPoseSearchBuilder.buildWithStats(glb, document)` dizini kurar ve `LuminaPoseSearchBuildStats` raporlar (clip'ler, satırlar, aynalı satırlar, boyutlar, mesh'te olmayan clip'ler, eksik kemikler, kök hareketi olmayan clip'ler, derleme süresi). `buildInBackground` bunu arka plan isolate'inde çalıştırır. Önbellek başlığı mesh GLB'sinin ve belgenin parmak izini taşır (`LuminaPoseSearchBuilder.fingerprint`); `LuminaPoseSearchIndex.decode` / `encode` onu okur ve yazar.

`LuminaPoseSearchDatabaseRuntime.load(path)` bir veritabanını yol başına bir kez yükler. Mesh'in CPU'daki clip'leri (`LuminaGlbAnimationSampler`) ve GLB hash'i (`LuminaPoseSearchBuilder.glbHash`) hedef mesh başına bir kez, arka plan isolate'inde üretilir ve o mesh'in tüm veritabanlarınca paylaşılır. `.posedb` parmak izi (`fingerprintOfHash`) güncel olan veritabanı bunların yanında çözülür; eksik ya da eskimiş olan yeniden kurulur. GLB'si 700 clip taşıyan (320 MB) bir MetaHuman'da dört veritabanı, her biri 2,6 s yerine toplam yaklaşık 4 s'de yüklenir.

## Çalışma zamanı

### Yörünge tahmini

`LuminaTrajectoryPredictor` karakterin nerede olduğunu kaydeder (geçmiş örnekler) ve nerede olacağını tahmin eder: her yatay hız bileşeni istenen hıza doğru tam kritik sönümlü bir yayı izler (`velocityHalflife` 0.2 sn, `LuminaSpringMath.springCharacter`), bakış yönü istenen yaw'a doğru bir yayı (`facingHalflife` 0.25 sn). İstenen hız, hareket bileşeninin son girdisi (`LuminaCharacterMovementComponent.lastInputVector`, uzunluğu 1'e kırpılır) × yürüme hızıdır; istenen yön hareket yönü (harekete dön) ya da pawn'ın kendi yönüdür (yan adım).

### Oynatıcı

`LuminaMotionMatchingPlayer(database)` eşleşen clip'i her karede ilerletir ve `searchInterval` geçince, istenen hız keskin değişince (%30'dan ya da 30 dünya birimi/sn'den fazla) ya da tek seferlik clip bitince arar. Sorgunun poz özellikleri oynatılan karenin satırıdır; yörüngesi tahmin edilendir, karakter çerçevesine ve model birimlerine çevrilmiştir. Geçiş yalnız en iyi kare devam etmeyi `continuingPoseBias` kadar geçince olur ve `LuminaInertializer` ile harmanlanır: gösterilen pozla yeni poz arasındaki fark (düğüm başına öteleme ve dönüş, hızlarıyla) kritik sönümlü bir yayla sönen bir ofset olur; iki poz arasında hiç crossfade yapılmaz. İstatistikler: `searchCount`, `switchCount`, `switches`, `meanSearchMicroseconds`, `maxSearchMicroseconds`, `meanUpdateMicroseconds`, `matchedRootSpeed`.

**Kök hareketi politikası: kapsül sürer.** Hareket bileşeni actor'ü taşır; poser (`LuminaPoseSearchPoser`) clip'in kök ötelemesini ve yaw'ını gösterilen pozdan çıkarır, böylece eşleşen kareler kapsülü izler. Ayak kayması kapsülün hızıyla clip'in hızı arasındaki farkla büyür (`matchedRootSpeed`); hareketin yürüme hızını clip'lerinkine eşitleyin.

### Pozu göstermek

`LuminaAnimatedMeshComponent.poseDriver` bir `LuminaMeshPoseDriver` alır: atanmışken mesh, bir gltfio clip'i uygulamak yerine sürücünün pozunu (adıyla düğüm başına yerel TRS) skin eklemlerine yazar, sonra joint override'ları uygular ve kemik matrislerini günceller. Kemikler skin eklemleri ve onların üstündeki her düğümdür; böylece kendisi hiçbir vertex'i ağırlıklandırmayan bir kemik (vertex'leri twist ve corrective eklemlere ağırlıklı bir MetaHuman'ın uylukları ve üst kolları) da pozlanır; yoksa altındaki her şey dinlenme pozunda kalırdı. Aynalı kareler CPU'da aynalanır (`LuminaPoseSearchPoser`, dinlenme pozuna göre düzeltilmiş); gltfio bunu yapamazdı.

### `LuminaMotionMatchingComponent`

Kodla sürülen bir karakter için: `LuminaMotionMatchingComponent(databasePath: …)` (ya da `runtime:`) sahibinin animasyonlu mesh'ini ve hareket bileşenini bulur, veritabanını `LuminaPoseSearchDatabaseRuntime.load` ile yükler (yol başına paylaşılır; `.posedb` parmak izi uyuyorsa kullanılır, yoksa dizin arka planda yeniden kurulur ve diskteyse geri yazılır) ve oynatıcıyı her tick besler. `orientToMovement` sahibini tahmincinin yön yayıyla hareketine çevirir; `desiredYaw` korunacak yönü verir (yan adım); `requiredTags`; `debugDraw` istenen (yeşil) ve eşleşen (turuncu) yörüngeleri dünya debug çizgileri olarak ekler (`LuminaWorld.addDebugShape`).

## Bir Animation Blueprint'te

Bir state'in pozu `LuminaAnimPose.motionMatching(database, blendTime:, poseWeight:, trajectoryWeight:, requiredTags:, orientToMovement:, debugDraw:)` olabilir. Böyle bir state etkinken instance mesh'i, sahip pawn'ın hareketiyle beslenen bir motion matching oynatıcısıyla sürer ve oynattığı clip'i ayrılmış `MatchedClip` değişkenine yazar (kurallarda ya da update grafiğinde okumak için tanımlayın). State'ten çıkmak mesh'i eşleşen clip ve zamanda gltfio'ya geri verir, böylece geçişin crossfade'i oradan başlar. Her Motion Matching state'inin veritabanı begin play'de yüklenmeye başlar (önce giriş state'ininki, sırayla); böylece bir state'e sonradan girmek, veritabanı yüklenirken pozu bekletmez; `LuminaAnimMotionMatchingDriver.isLoaded(path)` birinin yüklenip yüklenmediğini söyler. Bir Motion Matching state'inden doğrudan başka birine geçmek (aynı mesh'in başka bir veritabanı, örneğin Stand → Crouch) yörünge geçmişini korur ve yeni veritabanının ilk eşleşmesine sıçramak yerine gösterilen pozdan inertialization ile karışır (`LuminaMotionMatchingPlayer.continueFrom`). VM `LuminaAnimBlueprintClass.fromDocument(document, poseDatabases: {...})` ile kurulur; üretilen sınıf belgeleri satır içi taşır (`_poseDatabases`); doğrulayıcı eksik veritabanını raporlar. Bkz. [Animation Blueprint'ler](blueprint/animation.md).

Instance'ın varsayılan slot'unda oynatılan bir montage (`playSlot`, örneğin bir traversal eylemi, bkz. [Traversal](traversal.md)) mesh'i Motion Matching state'inden çıkmadan alır; montage bitince oynatıcı montage'ın son pozundan karışır (`LuminaMotionMatchingPlayer.blendFrom(pose, velocity)`: eşleşen kareye inertialization'lı geçiş ve hemen bir arama). `poseVelocity` gösterilen pozun hızıdır; montage ondan karışarak başlar. Bir mesh'in tüm veritabanları o mesh'in ayrıştırılmış clip'lerini paylaşır (`LuminaPoseSearchDatabaseRuntime.meshSampler`); okunamayan bir mesh onu bekleyen her çağırana hata verir ve unutulur, böylece sonraki yükleme yeniden dener; Animation Blueprint hatayı `LuminaAnimMotionMatchingDriver.lastError`'da raporlar.

## Veritabanı oluşturmak

Lumina Studio'da: **Content Browser → New → Animation → Pose Search Database**, iskelet mesh'i seçin, adlandırın (`PSD_<Ad>`). Editör mesh'in clip'lerini harekete göre gruplanmış bir ağaç olarak gösterir (Walk, Run, Stand, …; eklemek ya da çıkarmak için tıklayın, "+" bir grubu ekler, filtre ve **Add matching** adında metni geçen her clip'i ekler), veritabanının clip'lerini Loop / Mirror / Use anahtarlarıyla ve Details'i (clip başına etiketler, maliyet sapması, arama aralığı; arama ayarları; şema). **Build** `.posedb`'yi arka plan isolate'inde yazar ve kare, özellik, derleme süresi ve zamanlanmış örnek aramayı raporlar. Sonra aynı mesh için bir Animation Blueprint'te bir state'in pozunu **Motion Matching** yapıp veritabanını seçin.

Koddan: belgeyi `AnimGraphAssetService.writePoseSearchDatabase` (editör) ile yazın ya da satır içi tutun, `LuminaPoseSearchBuilder.buildInBackground(meshGlb, document)` ile derleyin.

FBX'ten içe aktarılan clip'ler kök hareketi iskeletin kök kemiğinde anahtarlıysa onu korur (içe aktarıcı, hedef mesh'in kök kemiği skin ağırlığı taşımasa bile kök kemiğin ötelemesini kopyalar).

## Sınırlamalar

- Yerinde clip'ler (kök hareketi yok) sıfır yörünge verir ve yalnız durmaya eşleşir.
- Yürüyüşü kapsül sürer; kök hareketli clip'ler (traversal) veritabanında değil, motion warping'li slot montage'ları olarak oynar ([Traversal](traversal.md)); yürüyüş için hız ya da yön warping'i henüz yok.
- Aynalama, `_l` / `_r` (ya da `Left` / `Right`) adlı sol/sağ simetrik bir iskelet varsayar; karşılığı olmayan kemik kendi üzerine aynalanır.
- Motion Matching state'i başına bir veritabanı (birden çok state farklı veritabanları kullanabilir); veritabanları tek bir iskelet mesh'e bağlıdır.
- Cubic-spline clip'ler CPU'da anahtar değerleri arasında doğrusal değerlendirilir.
