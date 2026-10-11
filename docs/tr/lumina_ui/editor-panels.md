[English](../../en/lumina_ui/editor-panels.md)

# Editör panelleri (editörün çalıştırdığı Widget Blueprint'ler)

**Editör paneli**, `editorPanel` bloğu taşıyan bir Widget Blueprint'tir (`.lmas`, tasarımcı ağacı + grafik). Lumina
Studio onu etkin bir eklentinin `content/` klasöründe ya da açık projenin `contents/` klasöründe bulur, grafiğini
bellekte editörün Blueprint VM'ine derler ve bir yan panel, alt sekme, çalışma alanı sekmesi, iletişim kutusu ya da
Proje Ayarları bölümü olarak yerleştirir: Dart derlemesi yok, proje editörü derlemesi yok, yeniden başlatma yok.
Yalnızca içerikten (editör panelleri) ve isteğe bağlı bir süreç kısmından oluşan bir eklenti, editör çalışırken
eklenir, güncellenir ve kaldırılır. Dosya yolları, başka bir paket adı vermedikçe `lumina_ui/` paketine görelidir.

## `editorPanel` bloğu

`LuminaEditorPanelInfo` (`lumina_core`, `formats/editor_panel_info.dart`) onu ayrıştırır, doğrular ve yazar:

```json
{"title": "Prop Tools", "icon": "box", "dock": "right", "defaultAlwaysVisible": false,
 "contentDroppable": true, "contentBrowserOpened": false, "menuPath": "Plugins/Prop Tools/Prop Tools",
 "minWidth": 300, "minHeight": 200, "capabilities": ["level", "assets", "process", "mcp"]}
```

- `dock`: `left` / `bottom` (eklenti panelleri gibi alt panel sekmeleri), `right` (sağ yuva), `tab` (yerleşimle geri
  açılan çalışma alanı sekmesi), `dialog` (kalıcı iletişim kutusu; yalnızca aynı sahibin bir panelinden `Open Editor
  Panel` ile açılır, hiçbir menüde listelenmez), `projectSettings` (sahip eklentinin Proje Ayarları ▸ Eklentiler bölümü).
- Bilinmeyen bir yuva ya da yetenek veya boş başlık, alanı adlandıran bir `FormatException` verir. Yalnızca yazarın
  yazdığı alanlar geri yazılır; blok bayt bayt aynı döner. `capabilityHash` güven kararlarının anahtarıdır.
- `minWidth` / `minHeight` varsayılanı 200 px; `menuPath` varsayılanı eklenti paneli için `Plugins/<Eklenti>/<Başlık>`,
  proje paneli için `Window/Editor Panels/<Başlık>`.

## Keşif ve derleme

- `EditorPanelCatalog` (`lumina_editor_data`) kaynakları arka plan isolate'inde tarar ve izler (canlı yeniden yükleme).
  Kaynaklar: `can_contain_content` taşıyan her etkin eklenti (`<eklenti>/content/**`), ardından projenin
  `contents/**` klasörü. Panel kimliği `<eklenti adı>/<varlık yolu>` ya da `project/<varlık yolu>`; başlığı bir proje
  paneliyle aynı olan eklenti paneline eklentinin dostça adı eklenir.
- `EditorPanelHost` (`lib/ui/core/editor_panels/editor_panel_host.dart`, `EditorViewModel.editorPanels`) her girdiyi
  derler (`EditorPanelRuntime.compile` → `LuminaBlueprintClass.forEditorPanel`), örnekleri açıp kapatır, editörün
  olaylarını onlarda tetikler ve onları canlı yeniden yükler. `EditorViewModel.startEditorPanels()` eklentiler
  tarandıktan sonra onu başlatır (editör zamanlayıcılarla çalışırken bunu kendisi yapar).
- Grafiğinde hata olan panel çalışmaz: yuvası hataları **Open in Widget Editor** ile listeler.

## Çalışma

- Betikler editör kayıt defterindedir (`LuminaUserWidgets.editor`): Play'i başlatmak (`LuminaUserWidgets.game`'i
  temizler) yuvadaki bir panele dokunmaz ve panel oyunun Tick'ini almaz.
- Betikler özel, başsız bir dünyada (`EditorPanelWorld`) gizli aktörlerdir: sahne yok, hiç çizilmez ya da kaydedilmez,
  yalnızca en az bir panel görünürken tick alır; Delay, zamanlayıcılar, zaman çizelgeleri ve Event Tick çalışır.
  Seviye aktörleri orada değildir; paneller onlara seviye kütüphanesiyle ulaşır.
- Yaşam döngüsü: panel açılınca Pre Construct + Construct, kapanınca Destruct (sağ yuvanın kapat düğmesi, Close This
  Panel, eklentinin devre dışı bırakılması). Başka bir sekmenin örttüğü alt sekme Tick almadan çalışmayı sürdürür.
- **Adım bütçesi**: 1.000.000 düğümden fazla çalışan ya da 250 ms'den uzun süren bir olay durdurulur; panel
  "Stopped: <olay> ran too long · Reload" gösterir, editör yanıt vermeyi sürdürür.
- **Canlı yeniden yükleme**: varlığı kaydetmek (ya da tasarımcısında Compile) çalışan örneği 500 ms içinde değiştirir:
  eski betikte Destruct, adı ve türü değişmeyen öğelerin durumu korunur (yalnızca panelin çalışırken değiştirdikleri
  yeni tasarım değerlerini ezer), adı ve türü uyan grafik değişkenleri korunur, yeni betikte Construct. Hatalı bir
  kayıt son iyi sürümü bir hata şeridi altında çalıştırmayı sürdürür. Bir eklentiyi etkinleştirmek, devre dışı bırakmak
  ya da güncellemek panellerini aynı biçimde ekler, kaldırır ya da yeniden yükler.

## Yerleştirme

`EditorPanelDocking` (`editor_panel_docking.dart`) her sahibin panellerini `PluginExtensionRegistry.setEditorPanelContributions`
ile kaydeder (eklentinin kendi kabuk ve süreç katkılarından ayrı tutulur):

- `left` / `right` / `bottom`: `EditorPanelDescriptor` olur; eklenti panelleri gibi yerleşir (sağ yuva ve "Always"
  seçeneği, alt sekmeler, yerleşimdeki görünürlük). **Window ▸ Editor Panels** yerleşen her paneli listeler; eklenti
  paneli ayrıca `Plugins/<Eklenti>/<Başlık>` menü öğesini alır.
- `tab`: bir `EditorTabDescriptor`; `contentBrowserOpened` İçerik Tarayıcısını altına yerleştirir, yoksa İçerik
  Çekmecesi düğmesi (durum çubuğunun klasör düğmesi) ve iğnesi sunulur. Açık sekmeler yerleşimde hatırlanır ve
  yeniden açılır.
- `dialog`: `showEditorPanelDialog` onu kalıcı olarak açar (`minWidth` / `minHeight` boyutunda; Escape kapatır).
- `projectSettings`: sahip eklentinin bir `ProjectSettingsSection`'ı.
- Paneller editör temasıyla çizilir (`EditorColors.sidebar`, `card`, `cardHeader`, `border`, editör yazı boyları),
  projenin oyun temasıyla asla; `UmgRuntimeView(editorTheme: true)` kullanılır.
- **İçerik Tarayıcısı bırakmaları**: `contentDroppable` bir panelde "Accepts Asset Drops" işaretli öğe
  (`acceptsAssetDrops`, tür süzgeci `assetDropTypes`) bir `DragTarget<RealAssetInfo>` olur; bırakma
  `On Asset Dropped (Asset Path, Asset Type)` olayını tetikler.

## Editör pencere öğesi seti

Tasarımcının **Editor** palet bölümü, yalnızca editör paneli için sunulur (`EditorWidgetSet`,
`lib/ui/core/editor_panels/widgets/`):

| Öğe | Durum anahtarları | Olaylar |
|---|---|---|
| Editor Section | `title`, `expanded` | On Section Toggled |
| Property Row | `label`, `labelWidth` | — |
| Tree View | `items` (`[{id, label, icon, children}]`), `selected`, `expanded`, `multiSelect` | On Item Selected, Double Clicked, Context Menu, Expanded |
| List View | `items`, `selected`, `multiSelect` | On Item Selected, Double Clicked, Context Menu |
| Asset Picker | `value`, `typeFilter`, `placeholder`, `allowClear` | On Asset Picked |
| Resizable Split | `orientation`, `split`, `minFirst`, `minSecond` | — |
| Editor Toolbar | — | — |
| Status Line | `text`, `tone` | — |
| Viewport | önizleme sahnesi (`LuminaUmgViewport`, `viewport_*` nodes) | On Picked, Gizmo Preview / Commit / Cancel, Camera Changed, Scene Ready, Asset Load Failed |

Ağaç ve liste satırları Outliner'ınkilerdir (24 px, derinlik başına girinti, ok simgeleri, seçim çubuğu, üzerine gelme
tonu); Ctrl seçimi değiştirir, Shift genişletir. Asset Picker öğesi editörün `EditorAssetPicker`'ıdır. Zaman
çizelgesi, tablo ve tuval öğeleri daha sonra yerel editör öğeleri olarak gelir.

## Editör fonksiyon kütüphanesi

`EditorPanelLibrary`, Blueprint fonksiyon kayıt defterine `editorOnly` düğümler (kategori `Editor|…`) kaydeder.
Çağrılar UI isolate'inde çalışır ve hemen döner; disk ya da süreç işi, işi eşzamansız yürüyen gecikmeli bir düğümdür
(Completed / Failed). Yazmalar panelin bildirdiği yeteneği ister (doğrulayıcı, yeteneği bildirilmemiş düğümü reddeder):

- **Seçim**: Get Selected Actors, Select Actors, Clear Selection; olay On Editor Selection Changed.
- **Seviye** (yazmalar `level` ister): Get Level Actors (sınıf / etiket süzgeci), Get Level Actor Tree (türe göre Tree
  View öğeleri), Get Actor Label, Get / Set Actor Transform, Get / Set Component Property, Add Actor From Asset, Remove
  Actors, Focus Viewport On Actors, Save Level; olay On Level Changed.
- **İşlemler**: Begin Transaction (Label) → işlem, End Transaction, Cancel Transaction. İçindeki her seviye ya da
  varlık düzenlemesi etiketle adlandırılan tek bir Edit ▸ Undo adımıdır; olay bittiğinde açık kalan işlemi ana
  bilgisayar Çıktı Günlüğüne bir uyarıyla kapatır.
- **Varlıklar** (yazmalar `assets` ister): Get Selected Assets, List Assets (Folder, Type Filter, Recursive), Get Asset
  Info, Open Asset Editor, Rename / Move / Duplicate / Delete Asset (başvuru güvenli işlemler), Save Asset Json; olay
  On Content Browser Selection Changed.
- **İçerik Tarayıcısı**: Sync Content Browser To Asset, Get Content Browser Folder, Show Content Drawer.
- **Menüler**: Add Panel Menu Item (Path, Label, Event Name), Show Context Menu (Items) → Chosen (Item Id) / Cancelled.
- **Bildirimler**: Show Toast, Show Progress / Finish Progress (panelin altındaki çubuklar), Log To Output, Show
  Confirm Dialog → Confirmed / Cancelled.
- **Varlık seçici**: Pick Asset (Type Filter) → Picked (Asset Path) / Cancelled; editörün varlık seçici açılır
  penceresini panelin üstünde açar. Varlık yoluna benzeyen bir metin alanı "use Asset Picker" uyarısıdır.
- **Paneller**: Open Editor Panel (Closed → Result Json; iletişim kutusu Close This Panel Json'ıyla yanıtlar,
  kapatılınca null), Close This Panel (Result Json), Set / Get Element State (bir Button'ın `style`'ı, `primary` / `destructive` / …, de
  öğe durumudur), Get Project Name, Is Play Active, Get /
  Set Plugin Setting (`PluginStorage`), Get / Set Project Plugin Setting (`.lmproject` `plugin_settings`; eklenti
  süreci bunu `pluginSettings` olarak alır).
- **Eklenti süreci** (`process`, yalnızca eklenti panelleri): Call Plugin Process (Method, Args Json) → Completed
  (Result) / Failed (Error Code, Error Message), 30 sn çağrı zaman aşımıyla; süreç kapalıyken hemen `unavailable` ile
  başarısız olur; Get Plugin Process State; olaylar On Plugin Process Event (Name ayarı süzer) ve On Plugin Process
  State Changed (running, stopped, crashed, restarting).
- **Json** (`lumina`): Make Json Object / Array, Json Get String / Number / Bool / Json / Array, Json Set Field, Json
  Has Field, Parse Json (hatayla Failed), Json To String.

## Eklenti süreci

Süreç öğe durumlarını `PluginProcessContext.patchPanel(panel, ops)` (`host.panelState`) ile doğrudan ayarlar:
`patchPanel('content/EPW_Tools.lmas', [PluginPanelStateOp('StatusText', {'text': 'Ready'})])` o panelin her açık
örneğine grafiğini çalıştırmadan ulaşır. `EditorPanelLinks` yamaları panel başına saniyede en çok 30 kez uygular,
patlamaları birleştirir; bilinmeyen öğeler bir kez günlüğe yazılır. `context.emit(name, data)`, On Plugin Process
Event'in aldığıdır. `context.openEditorPanel(panel)` eklentinin panellerinden birini yuvasında açar (bir sürecin
Plugins menüsü komutları çoğu zaman bunu yapar). OpenXR eklentisinin `EPW_OpenXR`'ı eksiksiz bir örnektir: grafiği
sürecin yöntemlerini çağırır, süreç durum metinlerini yamar ve geri kalanı için `openxr.status` yayar.

## Güven

- **Eklenti panelleri** eklentileriyle güvenilirdir: kodunu kabul eden onay (editör panellerini ve yeteneklerini
  listeleyen içe aktarma onayı, Marketplace kurulumu, etkinleştirme) panellerini de kabul eder.
- **Proje panelleri** kullanıcı onlara güvenene dek çalışmaz: ilk açılışta her paneli yetenekleriyle listeleyen bir
  istem çıkar ("Trust and run" / "Not now"); karar kullanıcı başına `<LuminaDataDir>/editor_panel_trust.json`
  dosyasında, projenin mutlak yolu ve her panelin yetenek özetiyle saklanır. Yeni bir panel ya da yetenekleri artan bir
  panel yeniden sorar; projeyi taşımak yeniden sorar. Güvenilmeyen paneller "Not trusted · Review" gösterir.
- Dosya, ağ ya da süreç düğümü yoktur: panelin yazmaları seviye vekili ve varlık işlemleriyle yapılır, ikisi de geri
  alınabilir; ağır ya da ayrıcalıklı iş eklenti sürecine aittir.

## Yazma

- İçerik Tarayıcısı ▸ New ▸ **Editor Panel Widget**, `contents/editor/EPW_NewEditorPanel.lmas` yazar (bir bölüm, bir
  özellik satırı ve Show Toast'a bağlı bir düğme). Yeni eklenti sihirbazının varsayılan şablonu **Editor panel (Widget
  Blueprint)**, `content/EPW_<Ad>.lmas` taşıyan yalnızca içerikli bir eklenti yapar.
- UMG tasarımcısının kök Details'i **Class Settings ▸ Editor Panel**'i gösterir (blok ve yetenek onay kutuları);
  grafik paleti editör kapsamındadır; **Run as Editor Panel** kaydeder ve paneli yerleşik açar ya da yeniden yükler.
  Bir motor eklentisinin paneli salt okunur açılır.
- Editör panelleri oyuna asla ulaşmaz: pencere öğesi kod üretimi onları atlar, oyun grafiğinde birinin `Create
  Widget`'ı doğrulayıcı hatasıdır, pişirme adımı derleme için panel içeren her varlık klasörünün diğer dosyalarını
  tek tek listeler (`EditorPanelPackaging`).

## MCP

`editor_panels_list`, `editor_panel_open`, `editor_panel_close`, `editor_panel_state`, `editor_panel_interact` ve
`editor_panel_screenshot` ([MCP araç kataloğu](mcp-tools.md)); `mcp` yeteneği olan güvenilir bir panelde "Expose to
MCP" (`exposeToMcp`) işaretli özel olay, girdileri olayın parametrelerinden türlenen ve panelin durumunu yanıtlayan
`panel_<sahip>_<olay>` aracıdır.

## Eklenti API'si

`LuminaEditorContext.editorPanels` (`EditorPanelWidgets`): `all`, `byId`, `isOpen`, `open`, `close`, `changes`;
süreç içi eklentiler panellerinden birini bir komuttan açar. Bkz. [API başvurusu](../lumina_editor_api/api-reference.md).

---

[Yukarı: lumina_ui](index.md)
