[English](../../en/lumina/character-slots.md)

# Karakter slotları

Birkaç skinned mesh'ten oluşan bir karakter — gövde, yüz, saç, kaşlar, sakal, giysiler — tek seferde animasyonlanır ve parçaları adlarıyla değiştirilir. Bunu üç parça sağlar:

- **Poz takibi**: bir skeletal mesh her karede liderinin pozunu kemik adına göre alır (`LuminaAnimatedMeshComponent.poseLeader`, Blueprint özelliği `poseFrom`; bkz. [Bileşenler: mesh'ler](components-mesh-and-particles.md)).
- **Slotlar**: `slot` adı taşıyan bileşenler çalışma anında listelenir, doldurulur ve boşaltılır (`LuminaCharacterSlots`, *Character|Slots* Blueprint düğümleri).
- **Gövde maskeleri**: bir giysi slotu altındaki gövde üçgenlerini gizler; ten giysinin içinden çıkmaz.

| Parça | Yer |
| :--- | :--- |
| Slotlar | `lib/src/components/mesh/character_slots.dart` |
| Gövde maskeleri (motor tarafı) | `lib/src/components/mesh/character_slots/body_masks.dart` |
| Maske hesabı, skinned GLB geometrisi, en yakın nokta sorguları | `lumina_core/lib/src/garment/` (`LuminaBodyMask`, `LuminaSkinnedMeshData`, `LuminaTriangleGrid`) |
| Giysi uyumu | `lumina_core/lib/src/garment/` (`LuminaGarmentFitter`, `LuminaRbfField`, `LuminaGarmentGlbWriter`); önbellek: `lib/src/components/mesh/garment_cache.dart` (`LuminaGarmentCache`) |
| Blueprint düğümleri | `lib/src/blueprint/node_library/character_slots.dart`, `lib/src/blueprint/blueprint_function_library/character_slots.dart` |

## Slotlu bir Blueprint

Her parça, aktör Blueprint'inin iki özellikli bir bileşenidir:

| Özellik | Anlamı |
| :--- | :--- |
| `slot` | Slot adı (`Body`, `Face`, `Hair`, `Torso`, …). Boş: slot değil. |
| `poseFrom` | Bu bileşenin pozunu takip ettiği skeletal mesh bileşeninin id'si (yoksa adı); bir Skinned Cloth'ta giyildiği mesh. |
| `masksBody` | İsteğe bağlı: bu slottaki giysi altındaki gövdeyi gizler mi (varsayılan: `Torso`, `Legs`, `Feet` için evet). |

Mesh'i boş bir slot boş bir sahne bileşeni olarak kurulur ve sonra doldurulabilir. MetaHuman eklentisinin bölünmüş dışa aktarımı böyle bir Blueprint yazar: `Root` > `Body` > `Face` > `Eyelashes`, `Eyebrows`, `Beard`, `Fuzz`, `Hair`, `Mustache`, ve `Body` altında `Torso`, `Legs`, `Feet`. Blueprint düzenleyicisinde Details paneli Skeletal Mesh ve Skinned Cloth bileşenlerinde *CHARACTER* altında **Slot** ve **Pose From** gösterir (Blueprint'in diğer skeletal mesh'leri arasından bir seçici; bileşenin kendisi ya da onu zaten takip eden biri asla listelenmez).

`LuminaBlueprintComponents.construct` (Blueprint önizlemesi, PIE'nin VM'i ve üretilen oyun kodu aynı şekilde kullanır) poz liderlerini bağlar ve slotları kaydeder; oyun, düzenleyicinin gösterdiği gibi davranır.

## `class LuminaCharacterSlots`

`LuminaCharacterSlots.of(actor)` (ya da `maybeOf`) aktörün slotlarını verir.

| Üye | Açıklama |
| :--- | :--- |
| `names` | Slot adları, kayıt sırasıyla. |
| `slot(name)` / `component(name)` / `meshOf(name)` | Slot, şu anki bileşeni, kayıtlı mesh referansı (boşsa '', bilinmiyorsa null). |
| `setMesh(name, mesh)` | Slotu doldurur (Blueprint'inki gibi çözülen kayıtlı bir mesh yolu). Bir skeletal mesh mesh'ini **yerinde** değiştirir (`LuminaStaticMeshComponent.setMeshAsset`): animasyonu, Animation Blueprint'i, takipçileri ve çocukları kalır. Boş bir slot, slotun liderini takip eden yeni bir skeletal mesh alır; bir Skinned Cloth slotu yeni giysiyle yeniden kurulur. Yüklenince tamamlanır; bilinmeyen slot için false. |
| `clear(name)` | Slotu boşaltır (çocuklar boş bir bileşenin altında kalır). |
| `register(name, component, {mesh, leaderSlot, properties})` | Dart'ta kurulmuş bir slotu kaydeder. |
| `refreshBodyMask(bodySlot)` | Gövdeyi takip eden giysi slotlarından gövde maskesini yeniden hesaplar. |
| `changes` | Bir slotun bileşeni her değiştiğinde slot adlarının akışı. |

## Gövde maskeleri

Bir giysi slotu (`masksBody`) doldurulunca ya da boşaltılınca, ya da gövdenin kendisi değişince gövde maskesi bir worker isolate'ta yeniden hesaplanır: `LuminaBodyMask.compute`, dışında 4 cm içinde bir giysi yüzeyi olan ve o giysi noktası giysinin açık kenarlarından en az 3 cm uzakta olan gövde köşesini örtülü sayar (yakalar, manşetler ve etekler altındaki ten çizilmeye devam eder); üç köşesi örtülü olan üçgen örtülüdür. `LuminaBodyMask.applyDegenerate`, örtülü üçgenleri dejenere (çizilmeyen) gövde GLB'sinin bir kopyasını yazar ve gövde bileşeni bu kopyayı yerinde çizer (`<gövde yolu>#masked-<özet>`). Kayıtlı mesh maskesiz gövde olarak kalır; giysileri boşaltmak onu geri getirir. Draco ile sıkıştırılmış bir gövde yamalanamaz ve bütün kalır.

## Yerleştirilmiş skeletal mesh'ler

Bir seviyeye yerleştirilmiş `SkeletalMesh` aktörü, Play-In-Editor'da ve üretilen oyunda aynı şekilde, Mesh Component Details'inden `LuminaLevelSkeletalMesh.build` (`lib/src/game/level_skeletal_mesh.dart`) ile kurulan animasyonlu bir skeletal mesh olarak oynar: **Cast Shadow**, seviye materyali, yayları, **Slot** (aktörün o addaki karakter slotu mesh'i tutar) ve **Pose From** (id'siyle başka bir `SkeletalMesh` aktörü: bir `LuminaPoseFromActorComponent`, o aktör dünyaya girer girmez mesh'in onun mesh'ini kemik adına göre takip etmesini sağlar). Üretilen seviye aynı Details ile aynı çağrıyı üretir. Çizim mesafeleri ve Volumetric Shadow uygulanmaz (Lumina'da henüz hiçbir mesh mesafeye göre gizlenmez); yerleştirilmiş bir mesh'in Anim Class'ı oynatılmaz (Animation Blueprint'ler Blueprint bileşenlerinde oynar).

## Slotlardaki giysiler

Bir **Garment** asset'iyle (`AssetType.garment` türünde `.lmas`, bkz. [Giysi editörü](../lumina_ui/sub-editors/garment.md)) doldurulan bir slot, giysiyi takip ettiği slotun gövdesine uydurulmuş olarak gösterir. `setMesh(slot, garment)` (ya da uyum raporunu döndüren `fitGarment(slot, garment)`) giysiyi, kaynak mesh'ini, referans gövdesini ve şu anki gövdeyi (maskesiz) okur ve onu `LuminaGarmentCache` üzerinden bir worker isolate'ta uydurur (giysi, kaynak, referans gövde ve hedef gövde içeriği başına bir uyum; aynı gövde yeniden önbellekten gelir). Gövde slotu değişince onu takip eden her giysi slotu yeni gövdeye uydurulur ve gövde maskesi yeniden hesaplanır. Kumaş olarak simüle edilen bir giysi, Cloth Settings'iyle gövdede giyilen bir Skinned Cloth olur.

Uyum (`LuminaGarmentFitter`, lumina_core, saf Dart):

1. Giysinin kaynak mesh'i, ortalama kenarı en çok 2.5 cm olana dek inceltilir (`LuminaSkinnedMeshData.refined`), referans gövdedeki yerleşimine konur.
2. Referans gövdeden hedefe pürüzsüz bir deformasyon: köşe köşe eşleşen gövdeler (aynı mesh düzeni ya da aynı UV düzeni — dikişleri farklı bölünmüş MetaHuman gövdeleri; aynalanmış UV'ler her gövdenin normalize sınırlarında en yakın konumla çözülür) için 360 en uzak nokta gövde köşesi üzerinden bir RBF alanı (`LuminaRbfField`, afin parçalı `r³`); diğer gövdeler için iskelet üzerinden: her giysi köşesi referans gövdenin skin'ini onun dinlenme pozundan hedefinkine izler (eklemler ada göre eşlenir).
3. Tene 4 cm'den yakın bir köşe tene uzaklığını korur (aynı topolojide aynı üçgen ve barisentrik, değilse en yakın hedef noktası, yüzey normali boyunca), 10 cm'ye kadar azalarak.
4. İtme: hedef gövdenin içinde ya da giysi kalınlığından yakın bir köşe yüzey normali boyunca dışarı taşınır; itme giysi üzerinde yumuşatılır ve yeniden uygulanır.
5. İsteğe bağlı kumaş oturtma (giysinin `settleSteps`'i, 0–240): o kadar 1/60 s'lik yerçekimi adımı; kenarlar uyumdaki uzunluklarında konum tabanlı kısıtlarla tutulur (adım başına 16 yineleme) ve her adımdan sonra gövde dışarı itilir; gövdeye değen köşeler sabit kalır. Worker isolate'taki uyumun içinde çalışır, bu yüzden onunla birlikte önbelleğe alınır.
6. Skin ağırlıkları en yakın hedef gövde yüzey noktasından (köşelerinin ağırlıkları barisentrik olarak), giysi üzerinde üç kez yumuşatılır, en güçlü dördü normalize edilir.

`LuminaGarmentGlbWriter` sonucu hedef gövdenin düğümleri ve eklemleri üzerinde, kaynağın materyalleriyle skinned bir GLB olarak yazar; slotun bileşenine `garment:<slot>#<özet>` anahtarıyla sunulur. `LuminaGarmentFitReport` gövdenin içindeki en büyük ve ortalama derinliği (cm), hedefteki landmark hatasını, eşlemenin yoğun olup olmadığını, itilen köşeleri ve süreyi verir. `test-assets/Props/Clothes Line/` tişörtü Manny mankeninde landmark'lanarak ölçüldü: Quinn üzerinde içeride hiçbir şey yok (0.0 cm), landmark hataları 0.8–1.0 cm, inceltilmiş tişört için yaklaşık 1.7 s (skeletal mesh smoke senaryosu 06 ölçümü).

İtme dinlenme pozunda geçerlidir; animasyon sırasında içinden çıkma gövde maskesiyle gizlenir.

## Blueprint düğümleri (*Character|Slots*)

| Düğüm | Pinler |
| :--- | :--- |
| **Set Slot Mesh** | `slot`, `mesh` (asset yolu; '' boşaltır) → sahibin o slotu varsa true; mesh arka planda yüklenir. |
| **Clear Slot** | `slot` → sahibin o slotu varsa true. |
| **Fit Garment** | `slot`, `garment` (bir Garment `.lmas`) → sahibin o slotu varsa true; giysi arka planda slotun gövdesine uydurulur. |
| **Get Slot Mesh** | `slot` → içindeki mesh (boşsa ya da bilinmiyorsa ''). |
| **Get Slots** | → sahibin slot adları. |

Her slot düğümünün bir **Target** pini (bir aktör) vardır: düğümler o aktörün slotlarında, Target bağlı değilse grafı çalıştıran aktörde çalışır. VM ve üretilen Dart aynı sonuçları verir (`blueprint_codegen_parity_test.dart`).
