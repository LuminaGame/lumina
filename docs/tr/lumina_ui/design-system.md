# Aurora tasarım dili

Lumina Studio, tasarım tuvalinde ("Lumina Studio UI Concepts", artboard 3 · Aurora) onaylanan **Aurora** tasarım
diliyle boyanır. Dört aşamada gelir; her aşama kendi başına yayınlanır:

| Aşama | Kapsamı | Durum |
|---|---|---|
| 1 · Token'lar, yazı ve çerçeve | Obsidian rampası ve amber vurgu, Manrope + JetBrains Mono, Prism L kilidi ve editörün kendi pencere denetimleriyle 48 px menü barı, türlü çalışma alanı sekmeleri | yayında |
| 2 · Adalar ve Content Drawer | her yerleşik panel bir ada (dolgu, 1 px kenarlık, 12 px yarıçap, 8 px oluk, 36 px büyük harfli başlık), ayırıcı tutamaçlar, girintisinden başlayan seçim satırları, yukarı kayan Content Drawer | yayında |
| 3 · Viewport çerçevesi | pill sırası (Perspective, görünüm modu, snap, açı snap'i, World, Show), dikey araç sütunu, istatistik pill'leri, MiniAI istem pill'i | planlı |
| 4 · Alt editörler | Material, Blueprint, Sequencer, Static Mesh, Skeletal Mesh, Animation, Landscape, UMG, Plugins, Project Settings ve Build Manager, 1–3. aşama bileşenleri üzerinde | planlı |

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

`EditorIsland` (`lib/ui/core/widgets/editor_island.dart`) yerleşik bir paneldir: ada dolgusu (`sidebar`), 1 px
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

## Doğrulama

`test/ui/theme_aurora_tokens_test.dart`, `test/ui/menu_bar_aurora_test.dart` ve `test/ui/typed_tab_bar_test.dart`
1. aşamayı, `test/ui/editor_island_test.dart` ve `test/ui/content_drawer_test.dart` 2. aşamayı kapsar; "Design System Smoke: aurora design language" smoke senaryosu
(`integration_test/smoke/design_system_smoke_test.dart`) gerçek bir projeye bir varil ve mankeni import eder, Static
Mesh ve Skeletal Mesh editörlerini türlü sekmeler olarak açar, ekran görüntülerinde rail'i, komut alanını, çipi ve
sekme alt çizgilerini ölçer ve viewport dönerken sekme geçişlerini kaydeder. "Design System Smoke: aurora islands and
content drawer" bir varil, bir klima ve bir muz salkımı yerleştirir; zemini, ada dolgusunu, kenarlığı, tutamacı ve
yuvarlak köşeyi, girintisinden başlayan Outliner seçimini ve çekmece barını ölçer; çekmeceyi viewport'un üzerine açar
(322 px, viewport adası değişmeden), bardan Output Log'u açar ve paneli sabitler; hepsi videoda.
