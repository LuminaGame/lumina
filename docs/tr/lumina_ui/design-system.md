# Aurora tasarım dili

Lumina Studio, tasarım tuvalinde ("Lumina Studio UI Concepts", artboard 3 · Aurora) onaylanan **Aurora** tasarım
diliyle boyanır. Dört aşamada gelir; her aşama kendi başına yayınlanır:

| Aşama | Kapsamı | Durum |
|---|---|---|
| 1 · Token'lar, yazı ve çerçeve | Obsidian rampası ve amber vurgu, Manrope + JetBrains Mono, Prism L kilidi ve editörün kendi pencere denetimleriyle 48 px menü barı, türlü çalışma alanı sekmeleri | yayında |
| 2 · Adalar ve Content Drawer | her yerleşik panel bir ada (dolgu, 1 px kenarlık, 12 px yarıçap, 8 px oluk, 36 px büyük harfli başlık), ayırıcı tutamaçlar, girintisinden başlayan seçim satırları, yukarı kayan Content Drawer | yayında |
| 3 · Viewport çerçevesi | pill sırası (Perspective, görünüm modu, snap, açı snap'i, World, Show), dikey araç sütunu, istatistik pill'leri, MiniAI istem pill'i | yayında (MiniAI istem pill'i hariç) |
| 4 · Alt editörler | Material, Blueprint, Sequencer, Static Mesh, Skeletal Mesh, Animation, Landscape, UMG, Plugins, Project Settings ve Build Manager, 1–3. aşama bileşenleri üzerinde | yayında (araç çubuğu satırları kalıyor) |

Temalar veri olarak kalır: rampa ve vurgu Lumina Dark temasının varsayılanlarıdır (`EditorThemeData.luminaDark`);
özel bir tema JSON'u her token'ı yine geçersiz kılar (bkz. [Editör temaları](core.md)).

## Token'lar (1. aşama)

Her renk, etkin tema üzerinden çözülen `const` bir `EditorColors` token'ıdır (`lib/ui/core/theme/editor_theme.dart`).
Yüzeyler hafif soğuk bir kasta sahip tek bir neredeyse siyah rampadır; adalar ve alanlar büyük açıklık adımlarıyla değil,
katı kenarlıklar ve yarıçaplarla ayrılır.

| Token | Değer | Boyadığı |
|---|---|---|
| `rail` | `#0F1013` | menü barı, sekme barı, graf tuvalleri (`graphCanvas`) |
| `sidebar` | `#111215` | adalar (her yerleşik panel), viewport pill'leri (`hudSurface`, %88) |
| `background` | `#141518` | adaların arkasındaki pencere |
| `cardHeader` | `#15171B` | panel başlık şeritleri, araç çubukları |
| `card` | `#1A1B1F` | alanlar, karolar, popover'lar |
| `muted` / `secondary` | `#1F2126` / `#24262C` | sönük dolgular, basılı düğme yüzleri |
| `border` | `#26282E` | ada ve panel kenarlıkları (katı) |
| `fieldBorder` (`input`) | `#2C2E34` | giriş çerçeveleri |
| `viewportBackdrop` | `#1B1D22` | 3B görünümün arkası |
| `foreground` / `mutedForeground` | `#E6E6E8` / `#9A9CA3` | metin, etiketler |
| `primary` / `primaryForeground` | `#F2A93B` / `#0B1D22` | amber vurgu ve üzerindeki koyu metin |
| `accent` | `#39C6E0` | ikinci vurgu (camgöbeği) |
| `success` / `warning` / `destructive` | `#7FE0A4` / `#E3B341` / `#FF7B72` | durumlar |

`test/ui/theme_surface_contrast_test.dart` her yüzeyde `foreground`'u 7:1, `mutedForeground`'u 4.5:1'de ve rampayı
sıkı sıralı tutar; `test/ui/design_tokens_test.dart` değerleri sabitler ve `lib/ui`'yi ham renk sabitleri için tarar
(bir sabit yalnızca satırında ya da üst satırında bir gerekçeyle, ya da çerçeve dışını boyayan bir dosyanın başındaki
`// design-token-exempt:` notuyla kalabilir; GLSL söz dizimi paleti ya da bir UI Theme önizlemesi gibi).

## Yazı

`EditorTypography.uiFamily` her etiket, menü, sekme ve başlık için **Manrope**'dur (400/500/600/700/800,
`assets/fonts/` altında paketli, SIL OFL); `EditorTypography.monoFamily` sayılar, yollar ve istatistikler için
**JetBrains Mono**'dur. Ölçek 9 / 10 / 11 / 12 / 15 px'tir (`captionSize`, `labelSize`, `bodySize`, `titleSize`,
`displaySize`); `EditorTypography.ui(...)` ve `EditorTypography.mono(...)` her ailede bir stil yazar. Uygulama teması
shadcn_flutter'ın `sans`'ını Manrope yapar, böylece kendini biçimlendiren widget'lar da uyar; bir tema JSON'u yine
`GeistSans` seçebilir.

## Menü barı

`MenuBarWidget` (`lib/ui/features/main_editor/views/menu_bar_widget.dart`) pencerenin başlık çubuğudur: `rail` üzerinde
48 px'lik bir satır; solda Prism L kilidi (`LuminaLockup`), sonra File · Edit · View · Build · Debug · Tools · Plugins ·
Window · Help (eklenti menüleri Window ya da Help'ten önce girer), ortada Ctrl K komut alanı (Ctrl K ve Ctrl P gibi
hızlı açma paletini açar) ve sağda kaynak denetimi düğmesi (açılır menüsü Source Control girdilerini taşır; nokta
commit edilmemiş değişiklikli bir seviyeyi işaretler), geri al, yinele, `Proje · Seviye` çipi (seviye kaydedilmemişken
amber nokta; tıklama kaydeder) ve editörün kendi pencere denetimleri: tam ekran, küçült, büyüt ⇄ geri yükle, kapat.
Satırın boş kısmı pencereyi sürükler; çift tıklama büyütür.

## Türlü sekmeler

`EditorTypedTabBar` (`lib/ui/core/widgets/typed_tab_bar.dart`) menü barının altındaki 42 px'lik çalışma alanı
şerididir. Her `EditorTypedTab` gösterdiği şeyin ikon ve rengini taşır (bir asset için `AssetTypeStyle`, Plugins ya da
Project Settings gibi bir belge için kayıt defterinin ikonu sönük gride); etkin sekme ada dolgusunda, o renkte 2 px'lik
bir alt çizgiyle oturur; kaydedilmemiş bir sekme kapatma çarpısının yerinde amber nokta gösterir, çarpı imlecin altında
geri gelir; orta tık kapatır; `+` New Asset'i açar; genişliğe sığmayan sekmeler onları listeleyip seçen bir `+N`
menüsüne katlanır ve etkin sekme her zaman görünür tutulur.

## Adalar (2. aşama)

`EditorIsland` (`lib/ui/core/widgets/editor_island.dart`) (eklenti panelleri aynı bileşeni kullansın diye eklenti API'sinin, `lumina_editor_api`'nin adalarını
dışa aktarır; editörün temasıyla `EditorIslandThemeData.active` üzerinden boyanır) yerleşik bir paneldir: ada dolgusu (`sidebar`), 1 px
`border` ve 12 px yarıçap; içeriği köşelere kırpılır, üstte isteğe bağlı bir `EditorIslandHeader` bulunur (36 px,
başlık büyük harfle 11 px kalın ve hafif harf aralıklı, sağ uçta isteğe bağlı mono `trailingInfo` ve `actions`, altında
1 px kenarlık). `EditorIslandStyle` ölçüleri tutar (`radius` 12, `gap` 8, `gripGap` 10, `headerHeight` 36, `rowHeight`
24, `rowRadius` 6).

Seviye çalışma alanı adalarını pencerenin zeminine (`background`) çevresinde 8 px'lik bir olukla dizer: sol sütunda
Details adasının üstünde Outliner adası, ortada viewport adası (`viewportBackdrop` dolgusu) ve sabitliyken altında alt
panel adası. Bölmeler hâlâ `ResizablePanel`'dır: `EditorIslandDividers.gap` adaların yanındaki 8 px oluk,
`EditorIslandDividers.grip` üst üste duran adalar arasındaki 28 × 3 px tutamaç çubuklu 10 px oluktur; panelin kendi
yeniden boyutlandırma tutamacı ikisinin de üstündedir, böylece her ada yeniden boyutlandırılabilir kalır ve boyutu
saklanır.

## Ağaç satırları

`EditorTreeRowStyle`, bir ada içindeki ağaç satırının durumunu nasıl gösterdiğidir. Satır dolgu (padding) ile değil
**kenar boşluğu** (margin) ile girintilenir (`margin(depth)`: iç oluk artı seviye başına bir girinti adımı); böylece
seçim dolgusu panel kenarından değil satırın kendi girintisinden başlar. Seçili dolgu amber `primary`'dir, üzerindeki
metin ve ikonlar `primaryForeground`'dur (`foreground(selected:)`), köşeleri 6 px yuvarlaktır; satırın üstüne
sürüklenen bir şey onu renklendirir ve amber çerçeveler. World Outliner ve Content Browser'ın klasör ağacı bunu kullanır.

## Content Drawer

Alt panel sabitlenmemişken viewport adası Content Drawer'ı taşır (`ContentDrawer`,
`lib/ui/features/main_editor/views/content_drawer.dart`): altında 36 px'lik bir `ContentDrawerBar` ve onun üstünde,
viewport'un üzerine 180 ms'de 322 px yukarı kayan alt panel (Content Browser, Output Log, Blueprint, eklenti
sekmeleri). Viewport boyutunu ve panel dışındaki girdisini korur; kapalıyken panel hiç kurulmaz. Bar şunları taşır:
**Content Drawer** düğmesi (Content Browser'da açar ya da onu öne getirir; tekrar basınca kapatır), pin (paneli düzene
ada olarak sabitler), seçili klasör breadcrumb olarak (`Content / Props / Barrels`), **Output Log** düğmesi (çekmeceyi
günlükte açar ya da kapatır) ve editörün durumu (`Ready · MCP on/off`). Açık ve sabit durumları düzenle birlikte
saklanır (`.lumina/editor_layout.json`); panelin sekme çubuğundaki pin onu yeniden serbest bırakır.

## Viewport çerçevesi (3. aşama)

`lib/ui/core/widgets/viewport_pills.dart` her 3B görünümün paylaştığı parçaları tutar: `ViewportPill` (HUD yüzeyinde
28 px, 10 px yarıçap, bir ikon, bir etiket — sayılar için mono — ve menü açıyorsa bir ok), `ViewportSnapPill` (bir snap
anahtarı ve adım değeri tek pill'de, adım menüsü değerin üstünde), `ViewportToolColumn` (30 px araç düğmeli dikey pill;
etkin olan amber ve koyu ikonlu, bir ayırıcı, sonra Focus gibi eylemler), `ViewportShowItem` ve `ViewportPillStyle`.

**Seviye viewport'u** (`LevelViewportPills`, `lib/ui/features/main_editor/views/level_viewport_chrome.dart`): sol
üstte pill sırası — kamera projeksiyonu, görünüm modu (Lit, Unlit, Wireframe, Buffer Visualization), öteleme, döndürme
ve ölçek snap'leri, adımıyla ızgara, World ⇄ Local ve kaplamalarıyla `Show · n` (Grid, Transform Gizmo, Selection
Bounds, Collision, Actor Icons & Labels, Ground Drop Shadows) — altında araç sütunu (Select, Move, Rotate, Scale, sonra
Focus; Q/W/E/R/F yine bunları değiştirir). Sağ üstte: kamera hızı, DLSS, FSR3 ve RTX pill'lerinin yanında istatistik
pill'i (`182k tris · 120 fps`), yakınlaştırma ve sıfırlama. Viewport'un üstündeki seviye araç çubuğu Play'i ve
modlarını, Blueprints menüsünü, eklenti yuvalarını, tam kare istatistiklerini ve Quality'yi tutar; araçlar, snap'ler,
görünüm modu, Show ve kamera projeksiyonu viewport'a taşındı. Play sırasında çerçeve gizlenir: o alanı ve
tıklamalarını oyunun kendi widget'ları alır (Play'i araç çubuğundaki Stop bitirir).

**Alt editör viewport'ları** (`SubEditor3DViewport`): aynı pill sırası (Wireframe'li görünüm modu, projeksiyon, sahnede
ışık varsa Scene Lights, önizleme şekli, `showItems`'tan `Show · n`, sonra World ⇄ Local ve `TransformGizmoToolbar`'ın
satır içi adım alanlı snap pill'leri) ve bir gizmo etkinken altında `TransformGizmoToolColumn`; Reset View sağ üsttedir.
Static Mesh editörü Show · Collision (çarpışma görünümü) ve Show · Bounds (mesh'in kendi sınırlarından camgöbeği bir
kutu, `StaticMeshEditorViewModel.boundsLineSet`) verir; static mesh'lerde soket olmadığı için Show menüsünde soket yoktur.

Çerçevede henüz yok: MiniAI istem pill'i. MiniAI'nin araç çubuğu eklenti yuvasındaki ✦ AI düğmesi panelini açar;
viewport'ta bir istem alanı için yazılan metni bir eklentiye ileten bir eklenti yuvası gerekir.

## Alt editörler (4. aşama)

Her alt editör bölmelerini zemin üzerinde adalar olarak dizer; yalnız 1–3. aşama bileşenleriyle: `EditorIslandGround`
(8 px boşluklu `background` dolgusu), bölme başına `EditorIsland`, adaların yanında `EditorIslandDividers.gap`, üst üste
olanların arasında `.grip`; böylece her bölme yeniden boyutlanmaya devam eder. `lib/ui/core/widgets/editor_island.dart`
üç parça daha tutar: `EditorIslandTabHeader` (sekmeleri adanın görünümünü değiştiren ada başlığı: etkin sekme `muted`
bir çip üzerinde kalın; dar bir ada birini kaydırıp gizlemek yerine etiketleri kısaltır; `tabKeys`/`keyPrefix` sekmelere
anahtar verir), `EditorIslandSectionLabel` (ada içinde büyük harfli 10 px bölüm etiketi, isteğe bağlı sağ öğeyle) ve
`editorIslandGroundGrip` (kendi boşluğunu getiren bir bölmenin altındaki tutamaç).

| Editör | Adalar |
|---|---|
| Static Mesh | LODs / Hierarchy üstte, Mesh stats altta · viewport · Details |
| Skeletal Mesh | Skeleton tree (kemik ve soket sayısı, + soket) üstte, Morphs / RigLogic altta · viewport (Show · Bones, Weights, Sockets) · Details |
| Animation | Properties / Bone Tracks / Notifies · kare kartı ve altında transport çubuğu olan viewport, altında Dope sheet · Key details / Curves / BlendSpace / Pose |
| Material | Preview üstte, Parameters & uniforms altta · GLSL Source / Node Graph üstte, Compiler log altta · Details (materyalin başlık ayarları) |
| Blueprint | Components üstte, My Blueprint altta · graph sekmeleri ve tuval üstte, derleme sonuçları altta · Details |
| Sequencer | Track outliner · 3D Viewport / Curves · Key details; altta transport ve zaman çizelgesi |
| UMG | Palette üstte, Hierarchy altta · tasarımcı · Details |
| Landscape | araç adasının başlığında Manage / Sculpt / Foliage sekmeleri · viewport · Foliage |
| Texture, Particle, Physics Asset, Blend Space, Anim Blueprint, Blueprint Interface, Pose Search, Cloth, Garment | her bölme bir ada |
| Plugins | kategoriler · eklenti listesi · ayrıntılar |
| Project Settings | kategori listesi (artık yeniden boyutlanabilir, önce sabit 220 px idi) · kaydetme alt çubuğuyla kategorinin ayarları |
| Build Manager | Build steps · Build log · Packaging (artık yeniden boyutlanabilir, önce sabit genişlikteydi) |

Skeletal Mesh editörünün Show Bones, Display Sockets ve Skin Weight Heatmap araç çubuğu düğmeleri viewport'un `Show`
menüsüne taşındı (Bones, Weights, Sockets). Static Mesh, Skeletal Mesh ve Physics Asset viewport'larının bilgi kutuları
pill yüzeyinde sol altta durur (sol üst pill sırasına ve araç sütununa ait); Animation kare kartı pill sırasının altında,
araç sütununun yanında durur ve root motion anahtarı Reset View'ın altında bir pill'dir. Material editörü
artboard'unu izler: parametreler önizlemenin altında, materyalin ayarları sağdaki Details adasında.

Alt editör kabuğu Content Browser'ı çalışma alanının altında bir ada olarak sabitler (arada tutamaç) ve sabitlenmemiş
çekmeceyi çalışma alanının altının üzerinde yüzen bir ada olarak açar. Eklentilerin sağ dock'u da bir adadır; bir
eklentinin sekmesi ya da varlık editörü host tarafından zeminde tek bir adaya yerleştirilir.

**Sekme barında araç çubuğu.** Bir alt editörün araç çubuğu bir `SubEditorToolbar`'dır
(`lib/ui/core/widgets/tab_bar_actions.dart`). Bir çalışma alanı sekmesinde (`MainEditorView`'ın her sekmenin çevresine
koyduğu `TabBarActionsScope`) satır çizmez: sekmesi etkinken kontrolleri sekme barının sağ ucuna gider
(`EditorTypedTabBar.trailing`, `TabBarActionsRegistry` üzerinde `TabBarActions`), böylece editörün adaları sekmelerin
hemen altında başlar. Sekme asset'i adlandırıp kapattığı için `SubEditorToolbarTitle` (tür rozeti ve asset adı) ile
`SubEditorToolbarClose` çocukları orada yer almaz ve `Spacer` yer kaplamaz. Eylemler barın en fazla %60'ını
(`trailingShare`) alır, daha fazlası gerekirse sağdan kayar; sekmeler kalanını alır. Kendi başına (modal içindeki ya da
widget testindeki bir alt editör) araç çubuğu eskisi gibi editörün 38 px'lik satırıdır. Seviye sekmesi araç çubuğu
satırını korur (Play, Blueprints, eklentilerin `EditorSlot`'ları).

## Doğrulama

`test/ui/theme_aurora_tokens_test.dart`, `test/ui/menu_bar_aurora_test.dart` ve `test/ui/typed_tab_bar_test.dart`
1. aşamayı, `test/ui/editor_island_test.dart` ve `test/ui/content_drawer_test.dart` 2. aşamayı, `test/ui/viewport_pills_test.dart` ve `test/ui/sub_viewport_pills_test.dart` 3. aşamayı kapsar, 4. aşama için her alt editörün kendi widget testi adalarını ve başlıklarını bulur (`test/helpers/island_expectations.dart`); "Design System Smoke: aurora design language" smoke senaryosu
(`integration_test/smoke/design_system_smoke_test.dart`) gerçek bir projeye bir varil ve mankeni import eder, Static
Mesh ve Skeletal Mesh editörlerini türlü sekmeler olarak açar, ekran görüntülerinde rail'i, komut alanını, çipi ve
sekme alt çizgilerini ölçer ve viewport dönerken sekme geçişlerini kaydeder. "Design System Smoke: aurora islands and
content drawer" bir varil, bir klima ve bir muz salkımı yerleştirir; zemini, ada dolgusunu, kenarlığı, tutamacı ve
yuvarlak köşeyi, girintisinden başlayan Outliner seçimini ve çekmece barını ölçer; çekmeceyi viewport'un üzerine açar
(322 px, viewport adası değişmeden), bardan Output Log'u açar ve paneli sabitler; hepsi videoda. "Design System
Smoke: aurora sub-editors" bir varil, mankeni ve bir idle klibini import eder, on bir editörü sekme olarak açar,
adalarını denetler, her birinde ada dolgusunu ve yanındaki zemini ölçer ve 3B viewport'ları videoda döndürür.
