[English](../../en/lumina/cloth.md)

# Kumaş

Bayraklar, perdeler, ipe asılı giysiler ve bir şeylerin üzerine örtülen çarşaflar: `LuminaClothComponent` bir ızgarayı ya da bir mesh asset'i, dünyanın [fizik](physics.md) subsystem'inin Jolt backend'inde simüle ettiği bir soft body'ye çevirir; kumaş level ile, simüle edilen objelerle ve karakterlerin kapsülleriyle çarpışır, rüzgâr alır ve her karede simüle edilen köşelerden çizilir.

| Parça | Yer |
| :--- | :--- |
| Bileşen (şekil, sabitler, ayarlar, çizim, özellikler) | `lib/src/physics/cloth/cloth_component.dart` |
| Geometri (ızgara, mesh birleştirme, parçalar, sabit seçimi) | `lib/src/physics/cloth/cloth_geometry.dart` |
| Backend arayüzü | `lib/src/physics/cloth/cloth_simulator.dart` |
| Jolt simülasyonu | `lib/src/physics/jolt/jolt_cloth_simulator.dart` ([flutter_jolt](https://github.com/LuminaGame/tools/blob/main/docs/tr/flutter_jolt.md) soft body'leri) |
| Karakterlerdeki giysiler | `lib/src/physics/cloth/skinned_cloth_component.dart`, `lib/src/physics/jolt/jolt_cloth_skinning.dart` |
| Blueprint düğümleri | `lib/src/blueprint/node_library/cloth.dart`, `blueprint_function_library/cloth.dart` |

## Bileşen

`LuminaClothComponent` bir scene bileşenidir (kendi procedural mesh bölümüyle). **Şekli** şunlardan biridir:

- `meshAsset`: bir static mesh `.glb` (Draco ile sıkıştırılmış olanlar da). Bir worker isolate'te okunur; aynı konumdaki köşeler (UV dikişlerinde bölünmüş olanlar) simülasyon için birleştirilir, birleştirmenin hiçbir üçgende bırakmadığı bir köşe en yakın simüle edilen komşusuyla çizilir. Birbirine bağlı olmayan birkaç parçadan oluşan bir mesh (bir havlunun gövdesi ve katlanmış üstü) parçalarını ayrı tutar.
- yoksa bir ızgara: yerel XY düzleminde, +Z'ye bakan, üst kenarı bileşenin orijininde ortalanmış `gridWidth` x `gridHeight` cm (varsayılan 200 x 150), `gridColumns` x `gridRows` dörtgen (24 x 18).

**Sabitler** köşeleri bileşenin koyduğu yerde tutar: `pinning` (`none`, `topEdge`, `bottomEdge`, `leftEdge`, `rightEdge`, `topCorners`; bir mesh'in her parçasında, parçanın o uçtaki köşeleri) ve `pinnedVertices` (simülasyon köşe indeksleri). Her adımda sabit köşeler bileşenin o anki dünya transform'una sürülür; böylece hareket eden bir ebeveyne (simüle edilen bir body, bir karakter, bir kemik soketi) bağlı bir kumaş onu izler ve geri kalanını sürükler. `pinVertex(i, pinned:)` çalışma anında simülasyonu yeniden başlatmadan bir köşeyi sabitler ya da serbest bırakır; başlangıçta kurulan tether'lar bir köşeyi o zaman sabit olan köşelerin yakınında tutmaya devam eder.

**Ayarlar**: `massKg` (bütün kumaş, varsayılan 1), `stiffness` (gerilme, 0..1, 0.95), `bendStiffness` (0..1, 0.3; 0 serbestçe bükülür), `damping` (0.5), `friction` (0.5), `thickness` (cm, yüzeylerden koruduğu mesafe, 1), `iterations` (8), `gravityScale` (1), `color` (doğrusal RGB, editörden `#RRGGBB`), `castShadows`. Simülasyon ayarlarından biri değişince simülasyon dinlenme pozundan yeniden kurulur.

**Kumaş ayarları asset'i**: `clothSettingsAsset` bir kumaş ayarları `.lmas`'ını adlandırır (bir `LuminaClothSettingsDocument`, [Kumaş ayarları editörü](../lumina_ui/sub-editors/cloth-settings.md) ile düzenlenir); kumaş kurulurken malzeme, simülasyon, rüzgâr, hareket ve kendisiyle çarpışma ayarlarının yerini asset'inkiler alır (`applySettings`). Onu okuyamayan bir kumaş kendininkileri korur ve nedenini günlüğe yazar.

**Görünüm**: kumaş `color` renginde, aydınlatmalı ve çift yüzlü bir malzemeyle çizilir. `baseColorTexture` (bir doku `.lmas`'ı ya da bir resim) UV'leri üzerine çizilir (ızgaranınkiler boyunca 0..1 gider; bir mesh kendininkini korur) ve `color` ile renklendirilir (beyaz dokunun renklerini bırakır). `materialAsset` (Material Editor'ün kaydettiği parametre ve dokularla bir proje malzemesi `.lmas`'ı ya da `.filamat`) onun yerine çizilir. İkisi de kumaş bir dünyada çizildiğinde yüklenir (`lookReady`, `drawsLook`, `drawnMaterial`); okunamayan renk bırakır ve günlüğe yazılır.

**Kendisiyle çarpışma**: `selfCollision` ile kumaş kendi katmanları arasında `selfCollisionDistance` (cm, varsayılan 2) bırakır: her adımdan sonra kumaşın üçgenlerinden birine o kadar yaklaşan bir köşe dışarı itilir ve ona yaklaşması durdurulur (Jolt soft body'lerinde kendisiyle çarpışma yoktur; geçişi flutter_jolt ekler). Dinlenme pozunda bir üçgene o kadar yakın olan köşeler komşusudur ve atlanır. Zaman tutar (441 köşe için adım başına yaklaşık 0.3 ms), bu yüzden varsayılan olarak kapalıdır; kendi üzerine katlanan kumaşta açın (yerde buruşan bir çarşaf, bir rayın üzerine atılmış bir havlu).

**Rüzgâr**: `wind` (cm/s, runtime eksenleri; özelliklerde ve düğümlerde authoring eksenleri), `windDrag` (saniyede, 1) ve `windTurbulence` (0..1, zamanla esintiler). Rüzgâr her yüzü, rüzgârın ona çarpan kısmı kadar normali boyunca iter; böylece bir bayrak durgun havada düz durur, sarkar, rüzgârı yakalar ve dalgalanır; rüzgâra yan duran bir yüz hiçbir şey hissetmez.

**Hareket**: `inertiaScale` (0..1, varsayılan 1) kumaşın sahibinin hareketine ne kadar direndiğidir: 1 bütün ataletini dünyada tutar (sahibi hareket edince ya da dönünce geride kalır ve sallanır), 0 onu sahibiyle birlikte katı olarak taşır, aradaki değerler her adımın hareketinin o payını taşır. Bir adım içinde `teleportDistance`'tan (100 cm) fazla bir yer değiştirme ya da `teleportRotation`'dan (60 derece) fazla bir dönüş bir ışınlanmadır: sabitler dahil bütün kumaş bir kerede birlikte taşınır; böylece sıçrama boyunca hiç gerilmez.

**Çalışma anı**: `simulate` (kapalıyken dinlenme pozu çizilir, açılınca ondan başlar), `reset()`, `isSimulating`, `ready` (geometri kuruldu), `geometry`, `currentSimPositions()`, `resolvePinnedVertices()`.

## Nasıl simüle edilir

Fizik subsystem'i dünyanın kumaşlarını tutar (`LuminaPhysicsSubsystem.cloths`, `addCloth` / `removeCloth`); onları backend'in `LuminaClothSimulator`'ı (`LuminaPhysicsBackend.cloth`) simüle eder. Jolt'ta her kumaş, bileşenin transform'undaki dinlenme pozundan, merkezinde kurulan bir Jolt soft body'sidir: kenar, kayma ve dihedral bükülme constraint'leri, sabit köşelere tether'lar (uzun menzilli bağlar), köşe yarıçapı olarak kalınlık. Compliance'lar köşelerin ters kütlesiyle (`w = köşe sayısı / massKg`) ölçeklenir: gerilme `1e-4 · w · (1/stiffness − 1)` (en az `1e-6 · w`), kayma bunun iki katı, bükülme `4.5e-3 · w · (1/bendStiffness − 1)` (en az `1e-5 · w`); böylece hafif bir kumaş ağır biri gibi davranır ve keskin kenarlar üzerinde kararlı kalır. Her adımdan önce sabitler sürülür ve rüzgâr uygulanır; bileşen çizilirken (`onRenderPrep`) köşeleri ve normallerini kendi çerçevesinde okur (native olarak hesaplanır) ve mesh bölümünü günceller. Adımın kendisi Jolt dünyasının adım thread'inde çalışır.

**Dart backend'i** (Jolt'suz bir build ya da web sayfası): kumaş simülatörü yoktur. Bileşen dinlenme pozunu çizer, `isSimulating` false olur ve motor günlüğü bir kez "Cloth needs the Jolt physics backend" der. Başka hiçbir şey değişmez. Web'de Jolt'un WebAssembly modülü yüklüyken (`LuminaPhysicsSubsystem.prepareJolt`) kumaş masaüstündeki gibi simüle edilir.

## Karakterlerdeki giysiler

`LuminaSkinnedClothComponent` animasyonlu bir karakterin giydiği kumaştır: köşeleri karakterin iskeletine skinlenir; böylece giysi animasyonla hareket eder ve skin'in koyduğu yerden belli bir mesafe içinde sallanır.

- **Giysi**: `meshAsset` (eklemleri karakterin kemikleri gibi adlandırılmış skinli bir `.glb`; kendi ağırlıkları kullanılır) ya da `waistBone` (`pelvis`, yoksa `Hips`) çevresinde üretilen bir etek: `skirtLength` (45 cm), `waistRadius` (17) ile `hemRadius` (34), kemiğin üzerinde `waistOffset` (6), `skirtColumns` x `skirtRows` (32 x 12). `fitToBody` ile (varsayılan) her halka, dinlenme pozunda kalça, omurga ve bacak kapsüllerinden kalınlık artı 2.5 cm uzak kalana kadar genişletilir ve üstündeki halkadan hiç dar olmaz; böylece bacaklar ve kalçadaki eller dışarıda kalır. Bel, bel kemiğini izler; eteğe doğru ağırlıklar (üst %70 boyunca yumuşakça) `legFollow` (0..1, 0.5) kadar en yakın iki bacak kemiğine geçer; eteğin geri kalanını bacaklar çarpışarak kenara iter.
- **Serbestlik**: giysinin uzak ucunda `maxDistance` (25 cm), üste doğru bunun `t^1.5` katı; üst kısım bedende kalır (sert skinli). `maxDistanceMap` (simülasyon köşesi başına bir değer, cm) bu azalmanın yerini alır.
- **Backstop**: `backstopDistance` (cm; null ya da negatif: yok) ile bir köşe skinli konumunun en fazla o kadar gerisine, skin'in normaline karşı gidebilir; böylece giysi rüzgâr ya da bir çarpışma onu nasıl iterse itsin bedenin içine katlanmaz. Backstop köşenin arkasında `backstopRadius` (20 cm) yarıçaplı bir küredir; `backstopMap` köşe başına mesafeler verir.
- **Boyanmış haritalar**: `paintedMaps` ile bir giysi asset'inin köşe renkleri haritaları boyar: kırmızı `maxDistance`'ın, yeşil `backstopDistance`'ın oranıdır.
- **Beden**: `collideWithBody` ile karakterin uzuvları kapsüldür (ragdoll'lardaki gibi iskeletten üretilen physics asset) ve her adımda animasyonla hareket edip giysiyi dışarı iter. Bir kumaş sahibinin diğer body'lerini (karakterin kapsülü) yok sayar; collider olarak işaretlenenler hariç.
- **Poz**: bileşen kendini `mesh`'e bağlar ve animasyonlu pozu bir pose modifier olarak okur (hiç değiştirmez); mesh'in adresleyemediği düğümler dinlenme pozunda alınır. İskelet (`sampler`) verilmezse mesh asset'inden okunur.

Jolt'ta her adım soft body'yi en son poza skinler (`SkinVertices`, ilk seferde sert) ve uzuv kapsüllerini (kinematik) taşır. Yukarıdaki hareket ayarları geçerlidir: karakterin yer değiştirmesinin ya da dönüşünün bir payı (`1 − inertiaScale`) adımdan önce giysiyi birlikte taşır; bir ışınlanma ya da ani bir dönüş (örneğin tek karede 180 derece) giysiyi her köşesi skinli konumunda ve hızsız olarak bedene geri koyar. Karakter son kez hareket etmeden önce alınmış bir poz (animasyonlu bir mesh fizik adımından sonra pozlanır, yani pozu bir kare eskidir) hem skin hem uzuv kapsülleri için karakterin şimdiki yerine taşınır: geç gelen bir poz giysiyi hiç geri çekmez ve uzuvlar onun içinden geriye doğru süpürülmez. Giysi `pinning`'i yok sayar (sabitleri sert skinli köşelerdir). Jolt yoksa dinlenme pozunu çizer.

Yürüyen mannequin'de ölçülen: eller ve ön kollar eteğin dışında kalır (bir el kapsülünün en derin 0.8 cm içindeki köşe, kumaşın kalınlığından az), bacaklar 1.3 cm içinde, kenarlar adım ortasında en fazla %18 gerilir; 3000 köşeli bir giysi 120 Hz'de 1.3 ms'de adımlanır (8 iterasyon); 416 köşeli bir etek tüm sahne için 60 Hz kare başına 1.4 ms tutar. Aynı etek bir MetaHuman bedenine de oturur (iskeleti aynı kemik adlarını kullanır; mannequin'in yürüyüşü `GlbAnimationRetargeter` ile aktarılır): eller 0.05 cm, bacaklar 1.7 cm içinde, döndüğü karede en fazla %16 gerilme.

## Blueprint'ler ve editör

Bileşen tipi `LuminaClothComponent` (bir scene bileşeni): Blueprint editörü onu **Cloth** olarak (Physics kategorisi) ekler; yukarıdaki her ayar Details panelindedir; `meshAsset` bir asset referansı, `wind` authoring eksenlerinde bir vektördür. Bileşen eşlemesi onu Play-In-Editor'da ve üretilen oyunlarda aynı şekilde kurar; özellikler Blueprint'le birlikte kaydedilir (`toProperties` / `fromProperties`).

İki bileşenin Details panelinde görünüm (Texture, Material), Self Collision ve **Cloth Settings** (bir kumaş ayarları asset'i) alanları da vardır.

Bileşen tipi `LuminaSkinnedClothComponent` **Skinned Cloth** olarak (Physics kategorisi) eklenir: onu giyen Skeletal Mesh'in altına bağlayın (yoksa aktörün ilk skeletal mesh'i giyer). Details panelinde giysi (`meshAsset`, bel kemiği, etek ölçüleri, bedene oturtma), serbestliği (max distance, leg follow, backstop mesafesi ve yarıçapı, boyanmış haritalar, bedenle çarpışma), kumaş malzemesi, rüzgâr ve hareket ayarları vardır; negatif bir backstop mesafesi backstop yok demektir. Köşe başına haritalar da özelliktir (`maxDistanceMap`, `backstopMap`); koddan verilir ya da giysinin köşe renklerine boyanır.

Düğümler (kategori **Physics|Cloth**, onları çalıştıran aktörün kumaşları üzerinde; Play-In-Editor ve üretilen kod aynı sonucu verir):

| Düğüm | Yaptığı |
| :--- | :--- |
| Set Cloth Wind (Wind, Drag) | her kumaşın rüzgârını (authoring eksenleri, cm/s) ve sürüklenmesini ayarlar |
| Set Cloth Simulation Enabled (Enabled) | simülasyonu kapatır (dinlenme pozu) ya da açar |
| Is Cloth Simulating → bool | aktörün herhangi bir kumaşı simüle ediliyorsa true |
| Reset Cloth | o anki transform'da dinlenme pozuna döner |
| Pin Cloth Vertex (Vertex, Pinned) | ilk kumaşın bir simülasyon köşesini sabitler ya da serbest bırakır |

## Sınırlar

- Kumaş başına bir malzeme (tek bölüm).
- Kendisiyle çarpışma köşeye karşı üçgendir: kaba bir kumaşta bir kenar yine de başka bir kenarın arasından kayabilir.

---

[Önceki: Ragdoll, düşme ve ayağa kalkma](ragdoll.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Yapay zeka (AI)](ai.md)
