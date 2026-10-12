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

**Rüzgâr**: `wind` (cm/s, runtime eksenleri; özelliklerde ve düğümlerde authoring eksenleri), `windDrag` (saniyede, 1) ve `windTurbulence` (0..1, zamanla esintiler). Rüzgâr her yüzü, rüzgârın ona çarpan kısmı kadar normali boyunca iter; böylece bir bayrak durgun havada düz durur, sarkar, rüzgârı yakalar ve dalgalanır; rüzgâra yan duran bir yüz hiçbir şey hissetmez.

**Çalışma anı**: `simulate` (kapalıyken dinlenme pozu çizilir, açılınca ondan başlar), `reset()`, `isSimulating`, `ready` (geometri kuruldu), `geometry`, `currentSimPositions()`, `resolvePinnedVertices()`.

## Nasıl simüle edilir

Fizik subsystem'i dünyanın kumaşlarını tutar (`LuminaPhysicsSubsystem.cloths`, `addCloth` / `removeCloth`); onları backend'in `LuminaClothSimulator`'ı (`LuminaPhysicsBackend.cloth`) simüle eder. Jolt'ta her kumaş, bileşenin transform'undaki dinlenme pozundan, merkezinde kurulan bir Jolt soft body'sidir: kenar, kayma ve dihedral bükülme constraint'leri, sabit köşelere tether'lar (uzun menzilli bağlar), köşe yarıçapı olarak kalınlık. Compliance'lar köşelerin ters kütlesiyle (`w = köşe sayısı / massKg`) ölçeklenir: gerilme `1e-4 · w · (1/stiffness − 1)` (en az `1e-6 · w`), kayma bunun iki katı, bükülme `4.5e-3 · w · (1/bendStiffness − 1)` (en az `1e-5 · w`); böylece hafif bir kumaş ağır biri gibi davranır ve keskin kenarlar üzerinde kararlı kalır. Her adımdan önce sabitler sürülür ve rüzgâr uygulanır; bileşen çizilirken (`onRenderPrep`) köşeleri ve normallerini kendi çerçevesinde okur (native olarak hesaplanır) ve mesh bölümünü günceller. Adımın kendisi Jolt dünyasının adım thread'inde çalışır.

**Dart backend'i** (web, Jolt'suz build'ler): kumaş simülatörü yoktur. Bileşen dinlenme pozunu çizer, `isSimulating` false olur ve motor günlüğü bir kez "Cloth needs the Jolt physics backend" der. Başka hiçbir şey değişmez; web build'i Jolt'a hiç ulaşmaz.

## Karakterlerdeki giysiler

`LuminaSkinnedClothComponent` animasyonlu bir karakterin giydiği kumaştır: köşeleri karakterin iskeletine skinlenir; böylece giysi animasyonla hareket eder ve skin'in koyduğu yerden belli bir mesafe içinde sallanır.

- **Giysi**: `meshAsset` (eklemleri karakterin kemikleri gibi adlandırılmış skinli bir `.glb`; kendi ağırlıkları kullanılır) ya da `waistBone` (`pelvis`, yoksa `Hips`) çevresinde üretilen bir etek: `skirtLength` (45 cm), `waistRadius` (17) ile `hemRadius` (34), kemiğin üzerinde `waistOffset` (6), `skirtColumns` x `skirtRows` (32 x 12); her köşe en yakın iki kalça ve bacak kemiğine ağırlıklandırılır.
- **Serbestlik**: giysinin uzak ucunda `maxDistance` (25 cm), üste doğru bunun `t^1.5` katı; üst kısım bedende kalır (sert skinli).
- **Beden**: `collideWithBody` ile karakterin uzuvları kapsüldür (ragdoll'lardaki gibi iskeletten üretilen physics asset) ve her adımda animasyonla hareket edip giysiyi dışarı iter. Bir kumaş sahibinin diğer body'lerini (karakterin kapsülü) yok sayar; collider olarak işaretlenenler hariç.
- **Poz**: bileşen kendini `mesh`'e bağlar ve animasyonlu pozu bir pose modifier olarak okur (hiç değiştirmez); mesh'in adresleyemediği düğümler dinlenme pozunda alınır. İskelet (`sampler`) verilmezse mesh asset'inden okunur.

Jolt'ta her adım soft body'yi en son poza skinler (`SkinVertices`, ilk seferde sert) ve uzuv kapsüllerini (kinematik) taşır. Giysi `pinning`'i yok sayar (sabitleri sert skinli köşelerdir). Jolt yoksa dinlenme pozunu çizer. Ölçülen: yürüyen mannequin'de 416 köşeli bir etek, tüm sahne için 60 Hz kare başına 1.4 ms.

## Blueprint'ler ve editör

Bileşen tipi `LuminaClothComponent` (bir scene bileşeni): Blueprint editörü onu **Cloth** olarak (Physics kategorisi) ekler; yukarıdaki her ayar Details panelindedir; `meshAsset` bir asset referansı, `wind` authoring eksenlerinde bir vektördür. Bileşen eşlemesi onu Play-In-Editor'da ve üretilen oyunlarda aynı şekilde kurar; özellikler Blueprint'le birlikte kaydedilir (`toProperties` / `fromProperties`).

Düğümler (kategori **Physics|Cloth**, onları çalıştıran aktörün kumaşları üzerinde; Play-In-Editor ve üretilen kod aynı sonucu verir):

| Düğüm | Yaptığı |
| :--- | :--- |
| Set Cloth Wind (Wind, Drag) | her kumaşın rüzgârını (authoring eksenleri, cm/s) ve sürüklenmesini ayarlar |
| Set Cloth Simulation Enabled (Enabled) | simülasyonu kapatır (dinlenme pozu) ya da açar |
| Is Cloth Simulating → bool | aktörün herhangi bir kumaşı simüle ediliyorsa true |
| Reset Cloth | o anki transform'da dinlenme pozuna döner |
| Pin Cloth Vertex (Vertex, Pinned) | ilk kumaşın bir simülasyon köşesini sabitler ya da serbest bırakır |

## Sınırlar

- Kumaş başına bir malzeme (bir temel renk, çift yüzlü, henüz doku yok).
- Kumaş body'ler ve collider'larla çarpışır; kendisiyle çarpışmaz.
- Skinli giysiler yalnızca çalışma anı bileşenidir: Blueprint editörü ve bileşen eşlemesi henüz `LuminaSkinnedClothComponent` sunmuyor; backstop'u açık değil.

---

[Önceki: Ragdoll, düşme ve ayağa kalkma](ragdoll.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Yapay zeka (AI)](ai.md)
