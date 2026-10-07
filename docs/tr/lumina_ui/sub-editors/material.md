[English](../../../en/lumina_ui/sub-editors/material.md)

# Materyal editörü

Materyal editörü: materyal kaynağını düzenleme, bütün `.mat` tanımını Filament'in kendi materyal derleyicisiyle (`matc`'nin kullandığı `.mat` ayrıştırıcısı, `FilamentMatc` üzerinden) derleme, parametreleri düzenleme ve materyal önizlemesi render etme. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/material/glsl_editor_widget.dart`](#libuifeaturessub_editorsviewsmaterialglsl_editor_widgetdart)
- [`lib/ui/features/sub_editors/views/material/mat_completion_popup.dart`](#libuifeaturessub_editorsviewsmaterialmat_completion_popupdart)
- [`lib/ui/features/sub_editors/views/material/glsl_syntax_highlighter.dart`](#libuifeaturessub_editorsviewsmaterialglsl_syntax_highlighterdart)
- [`lib/ui/features/sub_editors/views/material/parameter_panel.dart`](#libuifeaturessub_editorsviewsmaterialparameter_paneldart)
- [`lib/ui/features/sub_editors/views/material/material_settings_section.dart`](#libuifeaturessub_editorsviewsmaterialmaterial_settings_sectiondart)
- [`lib/ui/features/sub_editors/views/material/material_preview_pane.dart`](#libuifeaturessub_editorsviewsmaterialmaterial_preview_panedart)
- [`lib/ui/features/sub_editors/views/material/material_sub_editor.dart`](#libuifeaturessub_editorsviewsmaterialmaterial_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/material_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsmaterial_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/material_preview_renderer.dart`](#libuifeaturessub_editorsservicesmaterial_preview_rendererdart)
- [`lib/ui/features/sub_editors/models/material_graph.dart`](#libuifeaturessub_editorsmodelsmaterial_graphdart)
- [`lib/ui/features/sub_editors/models/material_logic_nodes.dart`](#libuifeaturessub_editorsmodelsmaterial_logic_nodesdart)
- [`lib/ui/features/sub_editors/models/material_fragment_pins.dart`](#libuifeaturessub_editorsmodelsmaterial_fragment_pinsdart)
- [`lib/ui/features/sub_editors/models/material_vertex_variables.dart`](#libuifeaturessub_editorsmodelsmaterial_vertex_variablesdart)
- [`lib/ui/features/sub_editors/models/material_slot_binding.dart`](#libuifeaturessub_editorsmodelsmaterial_slot_bindingdart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/material_precompile_step.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicematerial_precompile_stepdart)
- [`lib/ui/features/sub_editors/services/mat_source.dart`](#libuifeaturessub_editorsservicesmat_sourcedart)
- [`.mat` kod tamamlama (`lib/ui/features/sub_editors/services/mat_language/`)](#mat-kod-tamamlama-libuifeaturessub_editorsservicesmat_language)
- [`tool/generate_filament_material_api.dart`](#toolgenerate_filament_material_apidart)
- [`lib/ui/features/sub_editors/services/material_graph_codegen.dart`](#libuifeaturessub_editorsservicesmaterial_graph_codegendart)
- [`lib/ui/features/sub_editors/services/material_graph_parser.dart`](#libuifeaturessub_editorsservicesmaterial_graph_parserdart)
- [`lib/ui/features/sub_editors/services/material_graph_parser/layout.dart`](#libuifeaturessub_editorsservicesmaterial_graph_parserlayoutdart)
- [`lib/ui/features/sub_editors/services/material_graph_types.dart`](#libuifeaturessub_editorsservicesmaterial_graph_typesdart)
- [`lib/ui/features/sub_editors/services/material_sampler_parser.dart`](#libuifeaturessub_editorsservicesmaterial_sampler_parserdart)
- [`lib/ui/features/sub_editors/view_models/material_graph_controller.dart`](#libuifeaturessub_editorsview_modelsmaterial_graph_controllerdart)
- [`lib/ui/features/sub_editors/view_models/material_graph_editor.dart`](#libuifeaturessub_editorsview_modelsmaterial_graph_editordart)
- [`lib/ui/features/sub_editors/views/material/graph_view.dart`](#libuifeaturessub_editorsviewsmaterialgraph_viewdart)
- [`lib/ui/features/sub_editors/views/material/node_details_panel.dart`](#libuifeaturessub_editorsviewsmaterialnode_details_paneldart)

## `lib/ui/features/sub_editors/views/material/glsl_editor_widget.dart`

### `class MaterialGlslEditorWidget`

Tek aralıklı (monospace) `.mat` kaynak düzenleyicisi: sözdizimi renklendirme (denetleyici bir [GlslCodeController] olduğunda), kodla satır satır hizalı satır numarası oluğu (her satır zorlanmış bir strut ile 20 px'e sabitlenir, böylece oluk satırı ile kod satırı hiçbir zaman kaymaz) ve VS Code tarzı kod tamamlama. Kod alanı, oluğun da paylaştığı koyu bir düzenleyici yüzeyi (`#1E1E1E`) üzerinde kenarlıksız bir alandır.

Kod tamamlama, imleç konumunda [`MatCompletion`](#mat-kod-tamamlama-libuifeaturessub_editorsservicesmat_language)'a sorar ve sonucu imlecin hemen altına sabitlenen bir [`MatCompletionPopup`](#libuifeaturessub_editorsviewsmaterialmat_completion_popupdart) içinde gösterir (alt kenara yakınken imlecin üstüne çevrilir). İmleç konumu satır ve sütundan hesaplanır: satır numarası çarpı 20 px satır yüksekliği artı 8 px kod dolgusu, eksi alanın kaydırma ofseti; sütun numarası çarpı bir kez `TextPainter` ile ölçülen tek aralıklı karakter genişliği. Açılır pencerenin sol kenarı, etiketleri değiştirilen kelimenin başıyla hizalar.

| Girdi | Etkisi |
| :--- | :--- |
| Bir tanımlayıcı karakteri (ilkinden itibaren), `_` veya `.` yazmak | Öneri varsa pencereyi açar; açıkken her düzenleme listeyi yeniden süzer |
| Ctrl+Space | Hiçbir şey yazılmamışken de pencereyi açıkça açar |
| ↑ / ↓ | Seçimi taşır (başa/sona sarar) |
| PageUp / PageDown | Seçimi bir sayfa (9 satır) taşır |
| Enter, Tab veya bir satıra tıklama | İmlecin etrafındaki kelimeyi öğeyle değiştirir ve imleci yerleştirir (argüman alan bir fonksiyonda `()` içine) |
| Esc, düzenleme olmadan imleç hareketi, odağın kaybı | Pencereyi kapatır |

Tuşlar alanın `FocusNode.onKeyEvent`'i üzerinden (önceden atanmış işleyiciye zincirlenerek) ve yalnızca pencere açıkken işlenir; böylece kapalıyken düzenleme tuşları olağan davranır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `MaterialEditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `controller` | `TextEditingController controller` | `controller` alanını (field/property) ve ilişkili veriyi saklar. |
| `focusNode` | `FocusNode focusNode` | `focusNode` alanını (field/property) ve ilişkili veriyi saklar. |
| `scrollController` | `ScrollController? scrollController` | `scrollController` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<MaterialGlslEditorWidget> createState() => MaterialGlslEditorWidge...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class MaterialGlslEditorWidgetState`

`MaterialGlslEditorWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `jumpToLine` | `void jumpToLine(int line1Indexed)` | Jumps the editor cursor to a specific 1-indexed line number. |
| `completionItems` | `List<MatCompletionItem> get completionItems` | Açık pencerenin önerileri, en iyisi önce; kapalıyken boş. |
| `selectedCompletionIndex` | `int get selectedCompletionIndex` | Açık pencerede seçili satır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/material/mat_completion_popup.dart`

### `class MatCompletionPopup`

`.mat` kaynak bölmesinin öneri listesi: her öğe için 22 px'lik bir satır; türün Lucide simgesi türün renginde, eşleşen karakterleri kalın (`EditorColors.accent`) yazılmış etiket ve sağa yaslı, soluk ayrıntı (imza veya tip). En çok 10 satır görünür, gerisi kaydırılır; seçili satır `EditorColors.selectionBg` kullanır. Listenin yanında bir ayrıntı bölmesi seçili öğenin imzasını ve belgesini (açıklama, varsayılan değer, kullanılabilirlik) gösterir: sağda, sağda yer yoksa solda, hiç yer yoksa gösterilmez. Yüzeyler `EditorColors.sidebar`, kenarlık `EditorColors.borderSolid`.

**Üyeler:**

| Üye | İmzası | Açıklama |
| :--- | :--- | :--- |
| `items` | `final List<MatCompletionItem> items` | Öneriler, en iyisi önce. |
| `selectedIndex` | `final int selectedIndex` | Vurgulanan satır; ayrıntı bölmesi onun ayrıntılarını gösterir. |
| `scrollController` | `final ScrollController scrollController` | Listenin kaydırma konumu; düzenleyici seçimi `offsetRevealing` ile görünür tutar. |
| `onAccept` | `final ValueChanged<int> onAccept` | Bir satıra tıklandığında onun indeksiyle çağrılır. |
| `detailsSide` | `final MatDetailsSide detailsSide` | `right`, `left` veya `none`. |
| `rowHeight` / `maxVisibleRows` / `listWidth` / `detailsWidth` | `static const double 22` / `int 10` / `double 380` / `double 300` | Pencerenin ölçüleri. |
| `listHeight` | `static double listHeight(int count)` | `count` öğe için liste yüksekliği, kenarlıklar dahil. |
| `offsetRevealing` | `static double offsetRevealing(int index, double offset)` | `index` satırını görünür tutan kaydırma ofseti. |

| Fonksiyon | İmzası | Açıklama |
| :--- | :--- | :--- |
| `matCompletionKindIcon` | `IconData matCompletionKindIcon(MatCompletionKind kind)` | keyword `key`, type `type`, function `box`, field `tag`, property `wrench`, value `listOrdered`, variable `variable`, parameter `atSign`, constant `pi`, snippet `squareCode`. |
| `matCompletionKindColor` | `Color matCompletionKindColor(MatCompletionKind kind)` | Türün `EditorColors` jetonu: fonksiyonlar `chart4`, alanlar ve özellikler `accent`, tipler `primary`, değerler `warning`, değişkenler ve parametreler `chart3`, sabitler `materialPinFloat2`, anahtar kelimeler `mutedForeground`. |

## `lib/ui/features/sub_editors/views/material/glsl_syntax_highlighter.dart`

### `enum GlslTokenKind`

`.mat` kaynağının bir parçasının renklendirme açısından ne olduğu.

**Değerler:**

- `plain`
- `comment`
- `string`
- `number`
- `keyword`
- `type`
- `function`
- `builtin`: Filament'in materyal API'si (`material`, `materialParams_x`, `getUV0`, ...).
- `headerKey`: `material { }` başlığının bir anahtarı (`name`, `shadingModel`, ...) ve blok adları (`material`, `vertex`, `fragment`).
- `preprocessor`
- `punctuation`

### `class GlslToken`

Kaynağın renklendirilmiş bir parçası.

**Yapıcı Metotlar (Constructors):**

- `const GlslToken(this.kind, this.start, this.end)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kind` | `final GlslTokenKind kind` |  |
| `start` | `final int start` | Parçanın ilk karakterinin konumu. |
| `end` | `final int end` | Parçanın son karakterinden bir sonraki konum. |

### `abstract final class GlslSyntaxHighlighter`

Filament `.mat` kaynağını (JSON benzeri başlık ve GLSL blokları) renkli parçalara böler. Tamamen sözcüksel (lexical) çalışır; her tuş vuruşunda çalıştırılacak kadar ucuzdur ve derleyiciye hiç ihtiyaç duymaz.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `keywords` | `static const Set<String> keywords` | GLSL akış denetimi ve niteleyici anahtar sözcükleri. |
| `types` | `static const Set<String> types` | GLSL türleri (`float`, `vec3`, `mat4`, `sampler2d`, ...). |
| `builtins` | `static const Set<String> builtins` | Filament materyal API adları; her `materialParams_*` tanımlayıcısı da bu gruba girer. |
| `headerKeys` | `static const Set<String> headerKeys` | `material` başlık anahtarları ve blok adları; yalnızca ardından `:` veya `{` geldiğinde renklendirilir. |
| `tokenize` | `static List<GlslToken> tokenize(String source)` | [source]'un renkli parçaları, sırasıyla; aradaki kapsanmayan boşluklar düz metindir. Ardından `(` gelen tanımlayıcı `function` sayılır. |
| `palette` | `static const Map<GlslTokenKind, Color> palette` | Düzenleyici paleti (koyu tema): her tür için bir renk. |
| `highlight` | `static TextSpan highlight(String source, TextStyle base)` | [source]'u [base] üzerinde renkli span'ler olarak döndürür (yorumlar italik). |

### `class GlslCodeController`

`.mat` kaynağını [GlslSyntaxHighlighter] renkleriyle çizen bir `TextEditingController`; bir IME yazım (composing) yaparken düz, altı çizili span'e geri döner. Materyal editörünün kod denetleyicisidir.

**Yapıcı Metotlar (Constructors):**

- `GlslCodeController({super.text})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `buildTextSpan` | `TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing})` | Geçerli metnin renklendirilmiş span'i. |

## `lib/ui/features/sub_editors/views/material/parameter_panel.dart`

### `class MaterialParameterPanel`

Materyalin PBR parametreleri ve doku yuvaları için yansıma (reflection) tabanlı denetçi paneli. Başlık ayarları (domain, blend mode, shading, two sided) 3B önizlemenin altındaki [MaterialSettingsSection]'dadır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `MaterialEditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<MaterialParameterPanel> createState() => _MaterialParameterPanelSt...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _MaterialParameterPanelState`

`_MaterialParameterPanelState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/material/material_settings_section.dart`

### `class MaterialSettingsSection`

Materyal başlığının ayarları; Materyal editörünün 3B önizlemesinin altında gösterilir: Domain (Surface olarak gösterilir), Blend Mode, Shading ve Two Sided. Blend Mode, Shading ve Two Sided, kaynağın `material { }` başlığındaki ilgili anahtarı `MaterialEditorViewModel.updateHeaderSettings` üzerinden yeniden yazar.

**Yapıcı Metotlar (Constructors):**

- `const MaterialSettingsSection({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |
| `build` | `Widget build(BuildContext context)` |  |

## `lib/ui/features/sub_editors/views/material/material_preview_pane.dart`

### `class MaterialPreviewPane`

Materyal editörünün sol sütunu: [MaterialSettingsSection]'ın üstündeki 3B önizleme; ikisi sürüklenebilir bir ayraçla bölünür (`ResizablePanel.vertical`; ayarlar bölmesi 190 px ile başlar, en az 120 px). Önizleme derlenmiş materyali bir Sphere, Cube, Cylinder veya Plane üzerinde ya da bir proje mesh'i (Custom) üzerinde gösterir ve bir Grid anahtarı sunar; viewport'un kendi araç çubuğunu ve şekil seçicisini gizler.

Custom, projenin mesh varlıklarını (statik ve iskeletli) arka plan isolate'inde tarar ve bir varlık seçicide sunar. Seçilen mesh diskten yüklenir (hâlâ süren eski bir yüklemeye karşı en yeni seçim kazanır); mesh'in birden fazla materyal yuvası varsa bir **Material slot** seçicisi düzenlenen materyali hangi yuvanın giyeceğini belirler, diğer bölümler mesh'in kendi materyallerini korur.

**Yapıcı Metotlar (Constructors):**

- `const MaterialPreviewPane({super.key, required this.viewModel, required this.parameterRevision})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |
| `parameterRevision` | `final int parameterRevision` | Editör her view-model değişikliğinde artırır; önizleme parametre değerlerini yeniden uygular. |
| `meshTypes` | `static const Set<AssetType> meshTypes` | Custom önizlemenin sunduğu mesh varlık türleri: `filamesh` ve `filameshSk`. |
| `sectionsOfSlot` | `static Set<int> sectionsOfSlot(GlbMeshData mesh, int slot)` | [mesh]'in [slot] materyal yuvasına ait geometri bölümleri (`materialIndex` ile, indeksi olmayan bölümde `materialName` ile); mesh'in en fazla bir yuvası varsa tüm bölümler. |
| `sizePresets` | `static final Map<double, String> sizePresets` | Size seçicisinin sunduğu şekil boyutları, cm: 10 cm, 25 cm, 50 cm, 1 m, 2 m, 5 m, 10 m. |
| `defaultSize` | `static const double defaultSize` | 100 (1 m): bir materyalin önizlemesinin başladığı boyut; son seçim editör oturumu boyunca materyal başına hatırlanır. Custom mesh kendi boyutunu korur (Size seçicisi yoktur). |
| `scanMeshes` | `static Future<List<RealAssetInfo>> scanMeshes(String projectRoot)` | [projectRoot] altındaki proje mesh varlıkları; arka plan isolate'inde (`Isolate.run`) taranır. |
| `createState` | `State<MaterialPreviewPane> createState()` |  |

## `lib/ui/features/sub_editors/views/material/material_sub_editor.dart`

### `class MaterialSubEditor`

`MaterialSubEditor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `LuminaAsset? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `MaterialEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<MaterialSubEditor> createState() => _MaterialSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _MaterialSubEditorState`

`_MaterialSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/material_editor_view_model.dart`

### `enum MaterialCompileSeverity`

`MaterialCompileSeverity`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class MaterialCompileIssue`

`MaterialCompileIssue`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `line` | `int line` | `line` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `severity` | `MaterialCompileSeverity severity` | `severity` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MaterialCompileResult`

Bir `.mat` kaynağının tek derlemesinin ürettiği: `bytes` (`.filamat` paketi, reddedilince null), `issues` (derleyicinin mesajları), `ok`.

### `class FilamatCompilerRunner`

Bütün bir `.mat` materyal tanımını derler; bir testin editörün derleyiciye ne verdiğini görebilmesi için değiştirilebilir. `Future<MaterialCompileResult> compile({required String name, required String source, String? includeDirectory})`: [source] yazıldığı gibi tam tanımdır (başlık, `vertex` ve `fragment` blokları), [name] başlığında adı olmayan materyale ad verir, `#include` [includeDirectory]'ye göre çözülür.

### `class DefaultFilamatCompilerRunner`

Editörün derleyicisi: `FilamentMatc` üzerinden Filament'in kendi `.mat` ayrıştırıcısı (`matc`'nin kullandığı), böylece her başlık anahtarı, herhangi bir sıradaki `vertex` ve `fragment` blokları ve `#include`'lar matc için ne anlama geliyorsa onu ifade eder; bir hata, matc'nin mesajlarını (olduğu gibi) `.mat` satır numaralarıyla sorun olarak listeler. `MaterialCompileIssue.fromMatc` tek mesajı eşler; `MaterialCompileIssue.fromCompiler` onu işaretler (satırı olmayanı sorun listesi `matc:` olarak etiketler). Başlık çubuğundaki gölgeleme ve karıştırma yalnızca gösterim için kaynaktan okunur (her Filament değeri, ör. `fade`, `multiply`, `specularGlossiness`); derleme bunlara hiç bağlı değildir.

### `enum MaterialParamType`

`MaterialParamType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class MaterialParamModel`

`MaterialParamModel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `MaterialParamType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `dynamic value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `min` | `double min` | `min` alanını (field/property) ve ilişkili veriyi saklar. |
| `max` | `double max` | `max` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSampler` | `bool isSampler` | `isSampler` alanını (field/property) ve ilişkili veriyi saklar. |
| `textureRef` | `AssetReference? textureRef` | `textureRef` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MaterialEditorViewModel`

`MaterialEditorViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `compilerRunner` | `FilamatCompilerRunner compilerRunner` | `compilerRunner` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentCode` | `String get currentCode` | `currentCode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `compiledBytes` | `Uint8List? get compiledBytes` | `compiledBytes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `elapsedMs` | `int get elapsedMs` | `elapsedMs` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isCompiling` | `bool get isCompiling` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `syntaxStatus` | `String get syntaxStatus` | `syntaxStatus` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `issues` | `List<MaterialCompileIssue> get issues` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `bodyLineOffset` | `int get bodyLineOffset` | `bodyLineOffset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `shading` | `FilamatShading get shading` | `shading` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `blending` | `BlendingMode get blending` | `blending` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `doubleSided` | `bool get doubleSided` | `doubleSided` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `parameters` | `List<MaterialParamModel> get parameters` | `parameters` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentCode` | `currentCode(String value)` | `currentCode` işlemini gerçekleştirir. |
| `updateCodeFromEditor` | `void updateCodeFromEditor(String value)` | Updates code directly from the text editor without triggering continuous rebuild loops. |
| `load` | `Future<void> load()` | Loads the asset from the given [assetPath]. A missing file starts from the new-material template, which declares `flipUV : false`: meshes carry glTF texture coordinates (v = 0 at the image top), so a texture sampled with `getUV0()` draws upright (matc's default `true` turns it upside down). |

## `lib/ui/features/sub_editors/services/material_preview_renderer.dart`

### `class MaterialPreviewRenderer`

Owns the Filament objects that show a compiled `.filamat` package on a procedural preview primitive inside a sub-editor viewport.  Yaşam döngüsü: motor/sahne hazır olunca [mount] (materyal başka bir renderable'a, bir mesh'in materyal yuvasına gidecekse [mountMaterialOnly]), editörün parametre değerleri değiştikçe [applyParameters], kullanıcı başka bir primitif seçtiğinde [setShape], kapanışta [dispose]. Every native call is guarded: a material that fails to load leaves [isMounted] false and the caller keeps its software fallback.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isMounted` | `bool get isMounted` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `entity` | `int get entity` | `entity` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `shape` | `PreviewShape get shape` | `shape` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastError` | `String? get lastError` | `lastError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `materialInstance` | `FilamentMaterialInstance? get materialInstance` | `materialInstance` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] look like a compiled `.filamat` package. Filament aborts the process (uncatchable panic) when handed arbitrary bytes, so callers must check this before [mount]. |
| `packageMaterialVersion` | `static int? packageMaterialVersion(Uint8List? bytes)` | The MATERIAL_VERSION a package was compiled with, or null if not a package. |
| `applyParameters` | `void applyParameters(List<MaterialParamModel> parameters)` | Pushes the editor's parameter values into the material instance. Unknown or sampler parameters are skipped; each setter is guarded so one bad value never blocks the rest. |
| `setShape` | `void setShape(PreviewShape shape)` | Aynı materyal örneğini koruyarak [shape] için geometriyi yeniden kurar. Bir sahne gerektirir: [mountMaterialOnly] sonrasında hiçbir şey yapmaz. |
| `setSize` | `void setSize(double? size)` | Şekli [size] dünya biriminde (en büyük boyut; null: birim ölçek) yeniden kurar, materyal örneğini korur. `mount` aynı `size` değerini alır. |
| `mountMaterialOnly` | `bool mountMaterialOnly({required FilamentEngine engine, required Uint8List filamatBytes, List<MaterialParamModel> parameters = const []})` | Materyali ve örneğini [filamatBytes]'tan [parameters] uygulanmış olarak, kendi primitifi olmadan oluşturur: çağıran taraf [materialInstance]'ı başka bir renderable'a (bir mesh'in materyal yuvasının bölümlerine) takar. Başarıda true döner; paket olmayan veya yüklenemeyen veri [lastError]'ı ayarlar. |
| `hasMaterial` | `bool get hasMaterial` | Bir materyal örneğinin (kendi primitifi olsun ya da olmasın) var olup olmadığı. |
| `packVertices` | `static Uint8List packVertices(PreviewMeshData mesh)` | Packs [mesh] into the interleaved layout Filament expects. Exposed for tests (no engine required). |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

## `lib/ui/features/sub_editors/models/material_graph.dart`

### `enum MaterialValueType`

Bir materyal ifadesi pininin taşıdığı değer: bir ile dört bileşenli bir float vektör, bir doku nesnesi ya da bir `bool` (`boolean`: bir karşılaştırmanın sonucu; yalnızca mantık düğümleri ve bir If'in Condition girişi alır; genişliği 0'dır, asla yayınlanmaz ve float'larla karışmaz).

**Değerler:**

- `float1`
- `float2`
- `float3`
- `float4`
- `texture`
- `boolean`

**Yapıcı Metotlar (Constructors):**

- `const MaterialValueType(this.width)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `width` | `final int width` |  |
| `isNumeric` | `bool get isNumeric` |  |
| `label` | `String get label` | The type's name, as compiler messages use it. |
| `glsl` | `String get glsl` | The GLSL type a local of this type is declared with. |
| `ofWidth` | `static MaterialValueType ofWidth(int width)` |  |
| `parse` | `static MaterialValueType? parse(String? name)` | Reads a stored type name (`float3`, `vec3`, `float`). |

### `class MaterialPinDef`

One pin of a material expression. A null [type] is a dynamic numeric pin (Multiply's A and B): its type comes from what is wired into it.

**Yapıcı Metotlar (Constructors):**

- `const MaterialPinDef(this.id, this.name, {this.type, this.defaultValue, this.optional = false, this.unused = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `name` | `final String name` |  |
| `type` | `final MaterialValueType? type` |  |
| `defaultValue` | `final Object? defaultValue` | The constant an unconnected input uses (e.g. "Const A"); edited inline on the node. Null when the input must be wired (or is [optional]). |
| `optional` | `final bool optional` | An unconnected optional input falls back to built-in behaviour (TextureSample's UVs read UV0). |
| `unused` | `final bool unused` | Set on Material output pins the current shading model or blend mode ignores (the canvas greys them out). |
| `asUnused` | `MaterialPinDef asUnused()` |  |

### `class MaterialNodeSpec`

A material expression kind: its palette entry and pins.

**Yapıcı Metotlar (Constructors):**

- `const MaterialNodeSpec({required this.id, required this.title, required this.category, required this.headerColor, this.keywords = const [], this.inputs = const...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `title` | `final String title` |  |
| `category` | `final String category` |  |
| `keywords` | `final List<String> keywords` |  |
| `headerColor` | `final int headerColor` |  |
| `inputs` | `final List<MaterialPinDef> inputs` |  |
| `outputs` | `final List<MaterialPinDef> outputs` |  |
| `defaults` | `final Map<String, dynamic> defaults` | Node settings a new node starts with. |
| `tooltip` | `final String tooltip` |  |

### `class MaterialSurface`

The surface the Material output node shades: which of its pins are used.

**Yapıcı Metotlar (Constructors):**

- `const MaterialSurface({this.shading = FilamatShading.lit, this.blending = BlendingMode.opaque})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `shading` | `final FilamatShading shading` |  |
| `blending` | `final BlendingMode blending` |  |
| `usesOpacity` | `bool get usesOpacity` |  |
| `uses` | `bool uses(String pinId)` | Whether the output pin [pinId] feeds anything for this shading model and blend mode (Filament's `MaterialInputs` has no field for the rest). |

### `abstract final class MaterialNodes`

The material expression catalog and the helpers that read a node's settings. A material graph is lumina's [LuminaBlueprintGraph]: a node's `registryId` is one of these ids, its settings and inline input constants live in `literals`, its place in `x`/`y`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `output` | `static const String output` |  |
| `constant` | `static const String constant` |  |
| `constant2` | `static const String constant2` |  |
| `constant3` | `static const String constant3` |  |
| `constant4` | `static const String constant4` |  |
| `scalarParameter` | `static const String scalarParameter` |  |
| `vectorParameter` | `static const String vectorParameter` |  |
| `textureParameter` | `static const String textureParameter` |  |
| `textureSample` | `static const String textureSample` |  |
| `textureCoordinate` | `static const String textureCoordinate` |  |
| `add` | `static const String add` |  |
| `subtract` | `static const String subtract` |  |
| `multiply` | `static const String multiply` |  |
| `divide` | `static const String divide` |  |
| `lerp` | `static const String lerp` |  |
| `oneMinus` | `static const String oneMinus` |  |
| `clamp` | `static const String clamp` |  |
| `power` | `static const String power` |  |
| `dot` | `static const String dot` |  |
| `normalize` | `static const String normalize` |  |
| `componentMask` | `static const String componentMask` |  |
| `appendVector` | `static const String appendVector` |  |
| `time` | `static const String time` |  |
| `vertexColor` | `static const String vertexColor` |  |
| `fresnel` | `static const String fresnel` |  |
| `custom` | `static const String custom` |  |
| `customFragment` | `static const String customFragment` |  |
| `worldPosition` | `static const String worldPosition` | WorldPosition: the vertex's (vertex stage) or pixel's world position; setting `space` `absolute` (API-level world) or `camera_relative` (Filament's shading world). |
| `setVertexVariable` | `static const String setVertexVariable` | Set Vertex Variable: a sink whose `value` input is evaluated once per vertex (the `.mat` `vertex` block) and written to the float4 interpolant `name` (a `variables` entry). |
| `vertexVariable` | `static const String vertexVariable` | Vertex Variable: reads interpolant `name` in the fragment (`variable_<name>`), RGBA outputs. |
| `maxVariables` | `static const int maxVariables` | Filament's limit on `variables` (matc's `MATERIAL_VARIABLES_COUNT`, 5). |
| `maxVariablesWithColor` | `static const int maxVariablesWithColor` | The limit when the colour attribute is required (4). |
| `absoluteSpace` | `static const String absoluteSpace` | WorldPosition space: the API-level world. |
| `cameraRelativeSpace` | `static const String cameraRelativeSpace` | WorldPosition space: Filament's shading world, shifted by the camera position. |
| `outputNodeId` | `static const String outputNodeId` | The Material output node's fixed id: every graph has exactly one. |
| `baseColor` | `static const String baseColor` |  |
| `metallic` | `static const String metallic` |  |
| `roughness` | `static const String roughness` |  |
| `specular` | `static const String specular` |  |
| `normal` | `static const String normal` |  |
| `emissive` | `static const String emissive` |  |
| `opacity` | `static const String opacity` |  |
| `ambientOcclusion` | `static const String ambientOcclusion` |  |
| `outputFields` | `static const Map<String, String> outputFields` | Output pin → the Filament `MaterialInputs` field it writes. |
| `rgbaSwizzles` | `static const Map<String, String> rgbaSwizzles` | The swizzle each RGBA output reads from its vec4. |
| `all` | `static const List<MaterialNodeSpec> all` |  |
| `spec` | `static MaterialNodeSpec? spec(String? id)` |  |
| `isVertexAvailable` | `static bool isVertexAvailable(String registryId)` | Kinds the vertex stage can evaluate (everything that feeds a Set Vertex Variable): no textures, no shading values, no interpolants. |
| `isParameter` | `static bool isParameter(String registryId)` | Kinds that declare a `.mat` parameter. |
| `inputsOf` | `static List<MaterialPinDef> inputsOf(LuminaBlueprintNode node, [MaterialSurface surface = const MaterialSurfac...` | Düğümün ayarlarına ve [surface]'a göre çözümlenmiş girişleri: Custom düğümünün adlandırılmış girişleri; Custom (Fragment) düğümünün kodunun okuduğu parametreler ([MaterialFragmentPins.inputPins]); çıkış düğümünün pinleri, kullanılmayanlar işaretli. |
| `outputsOf` | `static List<MaterialPinDef> outputsOf(LuminaBlueprintNode node)` | Düğümün çıkışları: Custom (Fragment) düğümünde kodunun atadığı `MaterialInputs` alanları ([MaterialFragmentPins.outputPins]); diğer tüm türlerde spec'ten gelir. |
| `customInputs` | `static List<String> customInputs(LuminaBlueprintNode node)` |  |
| `maskChannels` | `static String maskChannels(LuminaBlueprintNode node)` | A ComponentMask's selected channels, in RGBA order (`'rg'`). |
| `parameterName` | `static String? parameterName(LuminaBlueprintNode node)` | The `.mat` parameter a TextureSample, parameter node or wired TextureParameter names, or null for other nodes. |
| `titleOf` | `static String titleOf(LuminaBlueprintNode node)` | The title the canvas shows: a constant's value and a parameter's name in the header. |
| `formatNumber` | `static String formatNumber(Object? value)` | A float as GLSL and the canvas write it: always with a decimal point. |
| `create` | `static LuminaBlueprintNode create(String registryId, {required String id, double x = 0, double y = 0, Map<Stri...` | A new node of [registryId] with its default settings. |
| `ensureOutput` | `static LuminaBlueprintNode ensureOutput(LuminaBlueprintGraph graph, {String? materialName})` | The Material output node of [graph], created at [x]/[y] if missing. |
| `wireInto` | `static LuminaBlueprintWire? wireInto(LuminaBlueprintGraph graph, String nodeId, String pinId)` | The wire into input [pinId] of [nodeId], if any. |

## `lib/ui/features/sub_editors/models/material_logic_nodes.dart`

### `abstract final class MaterialLogicNodes`

Materyal grafiğinin mantık ifadeleri (palet kategorisi **Logic**): Compare, And, Or, Not ve If. Bir karşılaştırma `bool` üretir ([MaterialValueType.boolean]); bool'lar yalnızca And / Or / Not'u ve bir If'in Condition girişini besler, asla float matematiğine girmez (0/1 isteyen bir düğüm `If(c, 1.0, 0.0)` alır). If, GLSL koşul ifadesi `(c ? t : f)` olarak yazılır; bu yüzden iki değer de hesaplanır: saf ifadeler ve doku örneklemeleri için sorun değildir. Beşi de vertex aşamasında kullanılabilir.

| Düğüm | Kimlik | Girişler | Çıkış | Ayarlar / kod |
| :--- | :--- | :--- | :--- | :--- |
| Compare | `mat_compare` | A, B (float, satır içi sabitler) | bool | `op`: `>`, `>=` (varsayılan), `<`, `<=`, `==`, `!=`; düğümün üzerinde ve Details panelinde bir seçim kutusu. `(a >= b)` |
| And / Or | `mat_and` / `mat_or` | A, B (bool) | bool | `(a && b)` / `(a \|\| b)` |
| Not | `mat_not` | A (bool) | bool | `(!a)` |
| If | `mat_if` | Condition (bool), Then, Else (kimlikler `condition`, `then`, `else`; aynı sayısal tür; float yayınlanır; satır içi sabitler 1.0 / 0.0) | Result (`out`), o tür | Koşul sağlandığında Then'i, aksi halde Else'i seçer; ikisi de hesaplanır. `(c ? t : f)` |

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `compare` | `static const String compare` | `mat_compare`. |
| `and` | `static const String and` | `mat_and`. |
| `or` | `static const String or` | `mat_or`. |
| `not` | `static const String not` | `mat_not`. |
| `ifNode` | `static const String ifNode` | `mat_if`. |
| `category` | `static const String category` | `Logic`. |
| `operators` | `static const List<String> operators` | Compare'in operatörleri, editörün listelediği sırayla. |
| `defaultOperator` | `static const String defaultOperator` | `>=`. |
| `compareBodyHeight` | `static const double compareBodyHeight` | Bir Compare düğümünün başlığının altına çizdiği operatör seçim kutusunun yüksekliği. |
| `specs` | `static const List<MaterialNodeSpec> specs` | Beş düğüm tanımı; [MaterialNodes.all] içine yayılır. |
| `isLogic` | `static bool isLogic(String registryId)` |  |
| `operatorOf` | `static String operatorOf(LuminaBlueprintNode node)` | Bir Compare düğümünün operatörü (ayarlanmamış ya da bilinmiyorsa `>=`). |
| `titleOf` | `static String? titleOf(LuminaBlueprintNode node)` | Bir mantık düğümünün tuvaldeki başlığı: Compare operatörünü gösterir (`Compare (A >= B)`). |

## `lib/ui/features/sub_editors/models/material_fragment_pins.dart`

### `abstract final class MaterialFragmentPins`

Bir Custom (Fragment) düğümünün, birebir (verbatim) kodundan okunan pinleri ve kabloları: okuduğu başlık parametreleri (`materialParams.x` / `materialParams_x`) parametre düğümlerinden kablolanan girişler, atadığı `MaterialInputs` alanları (`material.normal = …`, ayrıca `+=` biçimli ve swizzle'lı yazımlar) Material düğümüne kablolanan çıkışlar olur. Doğruluğun kaynağı koddur: kablolar yalnızca akışını gösterir ve kod her değiştiğinde yeniden kurulur (ayrıştırıcının Custom (Fragment) geri dönüşü ve `code` için `MaterialGraphEditor.setProperty` [syncWires]'ı çağırır).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `parameters` | `static List<String> parameters(LuminaBlueprintNode node)` | [node]'un kodunun okuduğu parametreler, ilk kullanım sırasıyla. |
| `outputs` | `static List<String> outputs(LuminaBlueprintNode node)` | [node]'un kodunun alanlarını atadığı Material düğümü pinleri, Material düğümünün pin sırasıyla. |
| `inputPins` | `static List<MaterialPinDef> inputPins(LuminaBlueprintNode node)` | Kodun okuduğu her parametre için bir dinamik giriş pini. |
| `outputPins` | `static List<MaterialPinDef> outputPins(LuminaBlueprintNode node)` | Atanan her alan için, eşleşen Material düğümü pini gibi adlandırılmış ve türlenmiş bir çıkış pini. |
| `syncWires` | `static void syncWires(LuminaBlueprintGraph graph)` | [graph]'taki bir Custom (Fragment) düğümüne dokunan her kabloyu kodunun gerektirdikleriyle değiştirir: parametre düğümü → fragment girişi, fragment çıkışı → Material düğümü pini. Grafikte düğümü olmayan parametre kablo almaz. |

## `lib/ui/features/sub_editors/models/material_vertex_variables.dart`

### `abstract final class MaterialVertexVariables`

Materyal grafiğinin vertex değişkeni yardımcıları: bir Set / Vertex Variable düğümünün hangi değişkeni adlandırdığı, `variables` başlık girdilerinin bildirdiği adlar ve Material düğümünde tutulan girdiler.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `variableName` | `static String? variableName(LuminaBlueprintNode node)` | Bir Set Vertex Variable'ın yazdığı ya da bir Vertex Variable'ın okuduğu değişken. |
| `declaredVariableName` | `static String? declaredVariableName(String entry)` | Bir `variables` başlık girdisinin bildirdiği ad (`tint`, `"tint"` veya `{ name : tint, precision : medium }`). |
| `extraVariables` | `static List<String> extraVariables(LuminaBlueprintGraph graph)` | Hiçbir Set Vertex Variable düğümünün karşılamadığı başlık `variables` girdileri; bir grafik düzenlemesinden sağ çıksınlar diye Material düğümünde (`extraVariables`) tutulur. |

## `lib/ui/features/sub_editors/models/material_slot_binding.dart`

### `class MaterialSlotBinding`

One geometry section's material assignment in a mesh sub-editor.

Slots are keyed by section index (`element_0`, `element_1`, …), never by the source GLB's material *name* — two sections may legitimately share a name. Shared by the Static Mesh and Skeletal Mesh editors.

**Yapıcı Metotlar (Constructors):**

- `MaterialSlotBinding({required this.index, required this.slotName, this.assignedMaterialPath, this.assignedMaterialId, this.isHighlighted = false, this.isIsolate...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `index` | `final int index` |  |
| `slotName` | `final String slotName` |  |
| `assignedMaterialPath` | `String? assignedMaterialPath` |  |
| `assignedMaterialId` | `String? assignedMaterialId` |  |
| `isHighlighted` | `bool isHighlighted` |  |
| `isIsolated` | `bool isIsolated` |  |
| `textureBindings` | `final Map<String, MaterialTextureBinding> textureBindings` | Per-sampler texture overrides, keyed by the parameter name the bound material declares (e.g. `baseColorMap`). Empty when the slot uses the material's own defaults. |
| `sourceMaterialName` | `final String? sourceMaterialName` | The material name the source mesh itself declares for this section, when it has one. An unbound slot is not "nothing applied" — the mesh ships its own material, and the editor has to say which one. |
| `samplerNames` | `List<String> samplerNames` | Sampler parameter names the currently bound material declares. Empty for an unbound slot, and refreshed when the binding changes — never a guessed PBR list. |
| `samplerNames` | `, samplerNames` |  |
| `isBound` | `bool get isBound` |  |
| `effectiveMaterialLabel` | `String get effectiveMaterialLabel` | What this section actually renders with right now: the bound asset's file name when a material was picked, otherwise the mesh's own material name. |

### `class MaterialTextureBinding`

A texture `.lmas` bound to one sampler parameter of a slot's material.

**Yapıcı Metotlar (Constructors):**

- `const MaterialTextureBinding({required this.assetId, required this.assetPath})`
- `factory MaterialTextureBinding.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `assetId` | `final String assetId` |  |
| `assetPath` | `final String assetPath` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

## `lib/ui/features/sub_editors/services/build_pipeline_service/material_precompile_step.dart`

### `class MaterialCompileOutcome`

**Yapıcı Metotlar (Constructors):**

- `const MaterialCompileOutcome.ok({this.note})`
- `const MaterialCompileOutcome.failed(this.error)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ok` | `final bool ok` |  |
| `error` | `final String? error` |  |
| `note` | `final String? note` | Extra detail for the log line (e.g. "compiled from .mat source"). |

### `class MaterialCompileInput`

What the precompile seam receives for one FILAMAT asset.

**Yapıcı Metotlar (Constructors):**

- `const MaterialCompileInput({required this.name, required this.relativePath, required this.package, required this.source, this.includeDirectory})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `relativePath` | `final String relativePath` |  |
| `package` | `final Uint8List package` |  |
| `source` | `final String source` |  |
| `includeDirectory` | `final String? includeDirectory` | The folder `#include "…"` in [source] resolves against (the asset's own). |

### `typedef MaterialCompiler`

Compiles one FILAMAT asset; injectable so tests need no GPU.

### `class FilamentMaterialCompiler`

The real seam: builds the `Material` on a headless Filament engine from the asset's compiled package bytes (or, when the asset only carries `.mat` source, from a package the material compiler — Filament's own `.mat` parser, as the Material Editor uses it — builds from the whole source) and warms its variants via `compile()`. A rejected source fails as `matc: <matc's messages>`.

**Yapıcı Metotlar (Constructors):**

- `FilamentMaterialCompiler({this.timeout = const Duration(seconds: 30)})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `timeout` | `final Duration timeout` |  |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] look like a compiled `.filamat` package (a `MAT_VERS` chunk of size 4). Filament aborts the process on arbitrary bytes, so this guard is mandatory before `fromBuffer`. |
| `buildPackageFromSource` | `MatcResult buildPackageFromSource(String name, String source, {String? includeDirectory})` | Compiles the whole `.mat` [source] with the material compiler (every header key, `vertex` and `fragment` blocks, `#include`s from [includeDirectory]), as the Material Editor does. |
| `call` | `Future<MaterialCompileOutcome> call(MaterialCompileInput input) async` |  |
| `dispose` | `void dispose()` |  |

### `class MaterialPrecompileStep`

**Yapıcı Metotlar (Constructors):**

- `MaterialPrecompileStep({MaterialCompiler? compiler})`

## `lib/ui/features/sub_editors/services/mat_source.dart`

### `sealed class MatValue`

A header value: a bare word or number, a quoted string, a list or an object.

**Yapıcı Metotlar (Constructors):**

- `const MatValue()`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `render` | `String render({int indent = 0})` |  |

### `class MatAtom`

**Yapıcı Metotlar (Constructors):**

- `const MatAtom(this.text)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `text` | `final String text` |  |

### `class MatString`

**Yapıcı Metotlar (Constructors):**

- `const MatString(this.text)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `text` | `final String text` |  |

### `class MatList`

**Yapıcı Metotlar (Constructors):**

- `const MatList(this.items)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `items` | `final List<MatValue> items` |  |

### `class MatObject`

**Yapıcı Metotlar (Constructors):**

- `const MatObject(this.entries)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `entries` | `final List<MatEntry> entries` |  |
| `operator` | `MatValue? operator [](String key)` |  |

### `class MatEntry`

**Yapıcı Metotlar (Constructors):**

- `const MatEntry(this.key, this.value)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `key` | `final String key` |  |
| `value` | `final MatValue value` |  |

### `class MatBlock`

One top-level block: `name { body }`.

**Yapıcı Metotlar (Constructors):**

- `const MatBlock(this.name, this.body)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `body` | `final String body` |  |

### `class MatParameterDecl`

A parameter the header declares.

**Yapıcı Metotlar (Constructors):**

- `const MatParameterDecl(this.type, this.name, this.defaultValue, this.raw)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `type` | `final String type` |  |
| `name` | `final String name` |  |
| `defaultValue` | `final MatValue? defaultValue` |  |
| `raw` | `final MatObject raw` | The declaration as written, for re-emitting a parameter the graph does not model. |
| `isSampler` | `bool get isSampler` |  |

### `class MatVariableDecl`

A custom interpolant the header's `variables` declares: `tint`, or `{ name : tint, precision : medium }`.

**Yapıcı Metotlar (Constructors):**

- `const MatVariableDecl(this.name, this.precision, this.raw)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `precision` | `final String? precision` |  |
| `raw` | `final MatValue raw` | The entry as written. |

### `class MatSource`

**Yapıcı Metotlar (Constructors):**

- `const MatSource(this.blocks, this.header)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `blocks` | `final List<MatBlock> blocks` |  |
| `header` | `final List<MatEntry> header` | The `material` block's entries, in order; empty when there is none. |
| `block` | `MatBlock? block(String name)` |  |
| `headerValue` | `MatValue? headerValue(String key)` |  |
| `materialName` | `String? get materialName` |  |
| `requires` | `List<String> get requires` |  |
| `parameters` | `List<MatParameterDecl> get parameters` |  |
| `variables` | `List<MatVariableDecl> get variables` | The custom interpolants the header's `variables` declares, in order. |
| `tryParse` | `static MatSource? tryParse(String source)` | [parse], or null when the blocks cannot be told apart. |
| `parse` | `static MatSource parse(String source)` | Splits [source] into blocks. Throws [FormatException] on unbalanced braces. |
| `matchingBrace` | `static int matchingBrace(String s, int open)` | The index of the brace closing the one at [open], skipping strings and comments. |
| `renderHeader` | `static String renderHeader(List<MatEntry> entries)` | Renders a `material` header block from [entries]. |

## `.mat` kod tamamlama (`lib/ui/features/sub_editors/services/mat_language/`)

Saf Dart (Flutter içe aktarımı yok); aynı motor başka ön yüzlere de hizmet edebilir. API tabloları Filament'in kendi materyal belgesinden [`tool/generate_filament_material_api.dart`](#toolgenerate_filament_material_apidart) ile üretilir.

| Dosya | İçerik |
| :--- | :--- |
| `mat_api_types.dart` | Tablo değer tipleri: `MatHeaderKeyInfo` (ad, grup, tip, izin verilen `values`, `defaultValue`, açıklama), `MatEntryKeyInfo` (bir `parameters` / `constants` / `variables` girdisinin veya `blendFunction`'ın anahtarı), `MatParamTypeInfo`, `MatStructFieldInfo` (ad, GLSL tipi, varsayılan, kullanılabildiği `shadingModels` — boşsa hepsi —, kullanılabilirlik notu, açıklama, API seviyesi; `availableWith(model)`), `MatFunctionInfo` (ad, tam imza, dönüş tipi, `MatStage` `any` / `vertex` / `fragment`, açıklama, API seviyesi, kategori; `hasArguments`, `availableIn(stage)`), `MatTypeInfo`, `MatConstantInfo`. |
| `filament_material_api.g.dart` | Üretilmiş, depoya eklenmiş, elle düzenlenmez. `filamentMaterialApiVersion` (`1.77.2`), `filamentHeaderKeys` (42: 41 `### <Grup>: <anahtar>` bölümü artı `apiLevel`), `filamentParameterTypes` (22) ve `filamentConstantTypes` (3), `filamentPrecisions`, `filamentParameterEntryKeys` / `filamentConstantEntryKeys` / `filamentVariableEntryKeys` / `filamentBlendFunctionKeys`, `filamentMaterialInputs` (28 `MaterialInputs` alanı; açıklamalar, aralıklar ve API seviyeleri materyal modellerinin özellik tablolarından, varsayılanlar ve gölgelendirme modelleri yapının yorumlarından), `filamentMaterialVertexInputs` (10 alan; `variable0`… başlığın `variables` adlarının yerini tutar), `filamentFunctions` (64 girdi, 62 ad: Math, Matrices, Frame constants, Material globals, Vertex only ve Fragment only tablolarından, `getCustom0()`–`getCustom7()` açılmış, artı `prepareMaterial`), `filamentTypeAliases` (14) ve `filamentConstants` (`PI`, `HALF_PI`). |
| `glsl_builtins.dart` | Elle yazılmış: `glslBuiltinFunctions` (yaygın GLSL ES 3.0 yerleşikleri — `texture`, `textureLod`, `textureSize`, `texelFetch`, `mix`, `clamp`, `step`, `smoothstep`, `min`, `max`, `abs`, `sign`, `floor`, `ceil`, `fract`, `mod`, `pow`, `exp`, `exp2`, `log`, `log2`, `sqrt`, `inversesqrt`, `length`, `distance`, `dot`, `cross`, `normalize`, `reflect`, `refract`, trigonometri, `dFdx` / `dFdy` / `fwidth` (yalnızca fragment), `any`, `all`, `not`, `transpose`, `inverse`, `determinant` ve vektör / matris kurucuları — imzaları ve tek satırlık açıklamalarıyla), `glslTypes`, `glslKeywords`, `glslFragmentKeywords` (`discard`). |
| `mat_document.dart` | `MatDocumentIndex.of(source)`: kaynağın üzerinden tek geçiş; yarım yazılmış bir kaynakta bile hata fırlatmaz. Üst düzey bloklar (`MatBlockRange`), yorum ve dize aralıkları (`isInCommentOrString`, ikili arama), başlığın `shadingModel`'i (`effectiveShadingModel` belgelenen varsayılan `lit`'e düşer), `parameters` ve `constants` (`MatDeclaredParam`), `variables`, `requires` ve `vertex` / `fragment` bloklarındaki bildirimler (`MatLocal`: değişkenler, fonksiyon parametreleri, fonksiyonlar, struct'lar; `localsBefore(block, offset)`). Son indeks metne göre önbelleğe alınır; aynı metin sürümündeki sorgular onu bir kez tarar. |
| `mat_header_context.dart` | `MatHeaderContext.at(doc, block, offset)`: başlığı imlece kadar yürür ve imlecin bir anahtarda mı yoksa bir değerde mi olduğunu, anahtarı, içinde bulunduğu nesne ya da listeyi (`owner`: başlığın kendisi, bir `parameters` / `constants` / `variables` girdisi, `blendFunction`, `requires`, …) ve orada zaten yazılmış anahtarları bildirir. |
| `mat_fuzzy_match.dart` | VS Code tarzı eşleştirme: `matchLabel(label, query)` bir `MatMatch` döndürür: kademe (0 büyük/küçük harf birebir önek, 1 büyük/küçük harfe duyarsız önek, 2 camelCase / kelime başları, örn. `gwp` → `getWorldPosition`, 3 alt dize), eşleşen konumlar ve aynı kademedeki eşleşmeleri sıralayan bir puan (atlanan kelimeler, alt dizenin başlangıcı). |
| `mat_completion_item.dart` | `MatCompletionKind` (`keyword`, `type`, `function`, `field`, `property`, `value`, `variable`, `parameter`, `constant`, `snippet`; her biri bir alaka sırasıyla) ve `MatCompletionItem` (`label`, `kind`, `detail`, `documentation`, `insertText`, `cursorOffsetInInsert`, `highlights`; `caretOffset`). |
| `mat_completion_sources.dart` | Her bağlamın adayları (aşağıda); aşamaya göre statik listeler bir kez kurulur. |
| `mat_completion.dart` | `MatCompletion.suggest(String source, int offset, {bool explicit = false}) → MatCompletionResult {replaceStart, replaceEnd, items}` ve `MatCompletion.rank(candidates, prefix)`. |

**Bağlamlar.** Değiştirilen aralık imlecin etrafındaki tanımlayıcıdır. Boş önekle yalnızca açık bir istek (Ctrl+Space) veya bir üye erişimi (`material.`) öneri üretir; yorum ve dizelerin içinde hiçbir şey önerilmez.

| Nerede | Öneriler |
| :--- | :--- |
| Her bloğun dışında | Kaynakta henüz bulunmayan `material`, `fragment` ve `vertex` blok kalıpları (`fragment`, `material()` ve `prepareMaterial(material);` ile; imleç boş satırda). |
| `material { }` içinde anahtar konumunda | Henüz yazılmamış başlık anahtarları, `key : ` olarak eklenir; bir `parameters` girdisinde `type`, `name`, `precision`, `format`, `multisample`, `filterable`, `transformName`; bir `constants` girdisinde `name`, `type`, `default`; bir `variables` girdisinde `name`, `precision`; `blendFunction` içinde `srcRGB`, `srcA`, `dstRGB`, `dstA`. |
| `material { }` içinde `<anahtar> :` sonrasında veya listesinde | Anahtarın belgelenmiş değerleri: `shadingModel` → `lit`, `subsurface`, `cloth`, `unlit`, `specularGlossiness`; `blending` → `opaque`, `transparent`, `fade`, `add`, `masked`, `multiply`, `screen`, `custom`; `requires : [ ]` → `uv0`, `uv1`, `color`, `position`, `tangents`, `custom0`…`custom7`; boolean'lar → `true`, `false`; bir parametrenin `type :`'ı → parametre tipleri (`float`…`float4`, `int`…, `uint`…, `bool`…, `float3x3`, `float4x4`, `sampler2d`, `sampler2dArray`, `samplerExternal`, `samplerCubemap`); `precision :` → `default`, `low`, `medium`, `high`. |
| `fragment { }` içinde `material.` sonrasında | Başlığın gölgelendirme modeliyle kullanılabilen `MaterialInputs` alanları (`unlit` yalnızca `baseColor`, `emissive`, `postLightingColor`'ı bırakır; `cloth` `metallic`, `clearCoat`, … alanlarını çıkarıp `subsurfaceColor`'ı ekler). |
| `vertex { }` içinde `material.` sonrasında | `MaterialVertexInputs` alanları; `variable0`… yerine başlığın `variables` adları. |
| `materialParams.` sonrasında | Başlığın sampler olmayan parametreleri. |
| `fragment` / `vertex` içinde bir tanımlayıcı | Blokta daha önce bildirilmiş yereller, `materialParams`, `materialParams_<sampler>`, `materialConstants_<sabit>`, `variable_<ad>` (yalnızca fragment), bloğun aşamasındaki Filament fonksiyonları, GLSL yerleşikleri, tipler (`vec3` gibi bir kurucu bir kez, tip olarak görünür), sabitler ve anahtar kelimeler. |

**Sıralama.** Önce birebir aynı etiket, sonra eşleşme kademesi ve puanı, sonra tür (yereller ve parametreler, alanlar / özellikler / değerler, fonksiyonlar, sabitler, tipler, anahtar kelimeler, kalıplar), sonra alfabetik. Bir fonksiyon `name()` olarak eklenir; aşırı yüklemelerinden biri argüman alıyorsa imleç parantezlerin içine, yoksa arkasına gider; aşırı yüklemeler bir kez görünür (ayrıntıda `(+1 overload)`). 200 satırlık bir kaynakta bir sorgu bir milisaniyenin çok altında sürer (`test/view_models/mat_completion_test.dart` her yeni metin sürümü için 5 ms sınırını denetler).

## `tool/generate_filament_material_api.dart`

`lib/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart` dosyasını Filament'in materyal belgesinden, `docs_src/src_markdeep/Materials.md.html`'den (<https://google.github.io/filament/Materials.md.html> olarak yayımlanan sayfa) üretir.

```bash
dart run tool/generate_filament_material_api.dart [<Materials.md.html>] [--version <x.y.z>]
```

| Girdi | Varsayılan |
| :--- | :--- |
| Belge | `tool/filament/build_prebuilt.*`'ın derlediği Filament kopyasındaki `docs_src/src_markdeep/Materials.md.html`: `LUMINA_FILAMENT_WORK`, yoksa `<çalışma alanı>/build/filament-src` (`LuminaWorkspace.root`) |
| `--version` | Kopyanın `android/gradle.properties` dosyasındaki `VERSION_NAME`; üretilen başlık yorumuna ve `filamentMaterialApiVersion`'a yazılır |

Ayrıştırıcı (`tool/src/filament_material_doc.dart`, `FilamentMaterialDoc.parse`), `### <Grup>: <anahtar>` bölümlerinin `Type` / `Value` / `Description` tanımlarını (izin verilen değerler "Defaults to"dan önceki ters tırnaklı kelimelerden, `custom0` through `custom7` açılarak; varsayılan "Defaults to"dan sonra), `[materialParamsTypes]` ve `[materialConstantsTypes]` tablolarını, sampler alanlarını, yorumlarıyla `struct MaterialInputs` / `struct MaterialVertexInputs` bloklarını, materyal modellerinin özellik tablolarını ve Shader public APIs tablolarını okur. `tool/src/filament_material_api_writer.dart` tabloları her satıra bir girdi olacak biçimde yazar (`// dart format off`). `test/view_models/filament_material_api_test.dart` belge varsa onu yeniden ayrıştırır (yoksa nedenini belirterek atlanır), API tablolarındaki her fonksiyon adının üretilen tabloda olduğunu ve üretilen tabloların taze bir ayrıştırmayla eşleştiğini denetler.

## `lib/ui/features/sub_editors/services/material_graph_codegen.dart`

### `class MaterialGraphCodegen`

Writes a material graph as `.mat` source.

`material` başlığı mevcut kaynağınkidir; `parameters`, `requires` ve `variables` grafikten yeniden yazılır (diğer her anahtar yazıldığı gibi kalır; başlığı olmayan bir kaynak, yeni materyal şablonunun yaptığı gibi `flipUV : false` bildiren bir başlık alır); `vertex` ve `fragment` dışındaki bloklar yazıldığı gibi kalır. Fragment grafiğin kendisidir: ifadeler satır içi, birden çok kullanılan (ya da ayrıştırıldığı kaynakta adlandırılmış) her değer için bir yerel değişken, Normal'i besleyenler `prepareMaterial(material)`'dan önce, geri kalan her şey sonra. Mantık düğümleri de birer ifadedir: Compare `(a >= b)`, And / Or / Not `(a && b)`, `(a || b)`, `(!a)`, If ise koşul ifadesi `(c ? t : f)` (daha geniş bir If'in float girişi dönüştürülür, `vec3(x)`); üreteç hiçbir zaman `if` deyimi ya da değersiz bildirim yazmaz. Bir Custom (Fragment) düğümü, üretilen fragment'in yerine kodunu birebir koyar.

The `vertex` block is the Set Vertex Variable nodes: each writes its interpolant (`material.<name> = …`, widened to `vec4`: `vec4(x)`, `vec4(xy, 0.0, 1.0)`, `vec4(xyz, 1.0)`) from the expressions upstream of it, evaluated per vertex with the vertex stage's reads (`material.uv0`, `material.color`, `material.worldPosition`). With no such node a hand-written vertex block stays as written; one the graph wrote goes away with its last setter.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `generate` | `static String generate(LuminaBlueprintGraph graph, {required String currentSource, required MaterialSurface su...` |  |

## `lib/ui/features/sub_editors/services/material_graph_parser.dart`

### `class MaterialGraphParseResult`

What [MaterialGraphParser.parse] made of a `.mat` source.

**Yapıcı Metotlar (Constructors):**

- `const MaterialGraphParseResult(this.graph, {this.fallbackReason, this.notes = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `graph` | `final LuminaBlueprintGraph graph` |  |
| `fallbackReason` | `final String? fallbackReason` | Why the fragment became one Custom (Fragment) node, or null when the graph expresses it. |
| `notes` | `final List<String> notes` | Things a later graph edit will not keep (comments). |
| `isFallback` | `bool get isFallback` |  |

### `class MaterialGraphParser`

Reads a `.mat` source into a material graph.

Fragment'in `material()` gövdesi deyim deyim ifadelere ayrıştırılır; üretecin kendi çıktısı geldiği grafiğe geri ayrışır. Katalogda düğümü olmayan bir çağrı, GLSL'ini tutan bir Custom ifade düğümü olur (`abs(…)`, `getWorldGeometricNormalVector()` ve diğer Filament getter'ları dahil). Karşılaştırmalar (`>`, `>=`, `<`, `<=`, `==`, `!=`), `&&`, `||`, `!` ve `?:` (en düşük öncelik, sağdan birleşimli) mantık düğümleri olur. Dalları yalnızca kendisinden önce bildirilmiş yerel değişkenlere atama yapan (`=`, `+=`, `-=`, `*=`, `/=`) bir `if (c) { … } else if (c2) { … } else { … }` zinciri (süslü parantezli ya da tek deyimli; dal içindeki iç içe if'ler de) atanan her yerel değişken için `If(c, v1, If(c2, v2, … v_else))` olur; o değişkeni atamayan bir dal, `if`'ten önceki değeri korur. Değersiz bir bildirim (`vec2 finalUV;`) kabul edilir; her yol atamadan önce okunması geri dönüşe düşer ("finalUV may be read unassigned"). `material.*` yazan, `prepareMaterial` çağıran ya da kendisinden sonra okunan bir yerel değişken bildiren bir dal, bir döngü ve deyim deyim ifade edilemeyen diğer her şey (bilinmeyen alanlar veya bildirimler) fragment'in tamamını, nedenini adıyla belirten bir açıklamayla birebir korunan tek bir Custom (Fragment) düğümü yapar; bu düğümün pinleri ve kabloları kodunun akışını gösterir (okuduğu parametreler içeri, yazdığı alanlar Material düğümüne kablolanır; bkz. [MaterialFragmentPins]). Başlık parametreleri her zaman parametre düğümü olur, böylece bir grafik düzenlemesi hiçbir bildirimi düşürmez.

The header's `variables` and the `vertex` block are read too: `material.<variable> = …` in `materialVertex()` becomes a Set Vertex Variable node (the codegen's `vec4` widening reads back as the unwidened value), `variable_<name>` in the fragment one Vertex Variable node per name, `getUserWorldPosition()` / `getWorldPosition()` (and their vertex-block forms) a WorldPosition. A Time, VertexColor, TexCoord, WorldPosition or parameter used by both stages is one node. A vertex block that writes anything else (moves vertices, writes `material.color`) or uses a loop is kept as written (`notes` says why) and its declared variables stay readable.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `parse` | `static MaterialGraphParseResult parse(String source)` |  |

## `lib/ui/features/sub_editors/services/material_graph_parser/layout.dart`

### `abstract final class MaterialGraphLayout`

Lays a parsed graph out left to right: the Material node on the right, each expression one column left of its left-most consumer.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `columnGap` | `static const double columnGap` |  |
| `rowGap` | `static const double rowGap` |  |
| `textureBodyHeight` | `static const double textureBodyHeight` | The texture thumbnail picker a Texture Sample / TextureParameter node draws under its header (`MaterialGraphEditor.nodeBody`). |
| `width` | `static double width(LuminaBlueprintNode n)` | The width the graph canvas gives [n] (its title and pin labels), so a column is as wide as its widest node. |
| `arrange` | `static void arrange(LuminaBlueprintGraph graph)` |  |
| `keepPositions` | `static void keepPositions(LuminaBlueprintGraph next, LuminaBlueprintGraph previous)` | Gives nodes of [next] the places their counterparts had in [previous] (matched by kind and settings), so a re-parse keeps the author's layout. |

## `lib/ui/features/sub_editors/services/material_graph_types.dart`

### `class MaterialGraphDiagnostic`

A problem the type checker found on a node (or one of its inputs), worded as a material compiler message.

**Yapıcı Metotlar (Constructors):**

- `const MaterialGraphDiagnostic(this.message, {this.nodeId, this.pinId, this.isError = true})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `nodeId` | `final String? nodeId` |  |
| `pinId` | `final String? pinId` |  |
| `message` | `final String message` |  |
| `isError` | `final bool isError` |  |

### `class MaterialGraphAnalysis`

The resolved types and diagnostics of one material graph.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `diagnostics` | `final List<MaterialGraphDiagnostic> diagnostics` |  |
| `reachable` | `final Set<String> reachable` | Nodes that feed the Material output node (or are it): the fragment. |
| `vertexReachable` | `final Set<String> vertexReachable` | Nodes that feed a Set Vertex Variable (or are one): the vertex block. A node can be in both sets. |
| `empty` | `static const MaterialGraphAnalysis empty` |  |
| `outputType` | `MaterialValueType? outputType(String nodeId, String pinId)` |  |
| `inputType` | `MaterialValueType? inputType(String nodeId, String pinId)` |  |
| `hasErrors` | `bool get hasErrors` |  |
| `errorNodeIds` | `Set<String> get errorNodeIds` |  |
| `diagnosticsFor` | `List<MaterialGraphDiagnostic> diagnosticsFor(String nodeId)` |  |
| `inputHasError` | `bool inputHasError(String nodeId, String pinId)` | Whether the wire into [nodeId].[pinId] carries a type error. |

### `class MaterialGraphChecker`

Her pinin türünü çıkarır (örtük skaler yayınlamalı float1–float4, doku ya da bir karşılaştırmanın bool'u) ve derlenemeyecek olanı raporlar; mantık kuralları (bir If'in Condition'ı ile And / Or / Not girişleri bool alır, If'in Then ve Else girişleri aynı sayısal türü ya da bir float'ı, Compare'in girişleri bir float'ı alır ve bool başka hiçbir pine ulaşmaz: her biri o pinde bir hata) ve vertex aşamasının kuralları da dahil: bir Set Vertex Variable'ı besleyen yalnızca-fragment düğüm (TextureSample, TextureParameter, Fresnel, Vertex Variable), geçersiz veya yinelenen değişken adı, matc'nin izin verdiğinden fazla değişken (5; vertex rengiyle 4), adını hiçbir şeyin yazmadığı ya da bildirmediği bir Vertex Variable, kaynağın vertex bloğu grafiğin üzerine yazacağı elle yazılmış kodken bir setter, ve bir Custom (Fragment) düğümünün yanında Material düğümüne giren bir kablo (o düğüm fragment'in tamamını yazar, böyle bir kablo yok sayılırdı; düğümün yalnızca kodunun akışını gösteren kendi kabloları raporlanmaz).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `graph` | `final LuminaBlueprintGraph graph` |  |
| `surface` | `final MaterialSurface surface` |  |
| `check` | `static MaterialGraphAnalysis check(LuminaBlueprintGraph graph, MaterialSurface surface)` |  |

## `lib/ui/features/sub_editors/services/material_sampler_parser.dart`

### `class MaterialSamplerParser`

Extracts the sampler parameter names a Filament `.mat` source declares.

Used by the mesh sub-editors to show one texture row per sampler the bound material actually has. A material that declares no samplers yields an empty list — the parser never falls back to a guessed PBR set, because a row the material cannot consume would be a dead control.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `declaredSamplers` | `static List<String> declaredSamplers(String matSource)` | Sampler names in declaration order, de-duplicated. |

## `lib/ui/features/sub_editors/view_models/material_graph_controller.dart`

### `class MaterialGraphController`

The Material Editor's node graph and its link to the `.mat` source.

Graph and source are two views of one material. A graph edit is one undo step on [transactions] that regenerates the source (unless the graph has type errors, which the compiler log shows instead); a hand edit of the source re-parses it into the graph the next time the graph is looked at ([ensureSynced]), keeping the nodes where the author put them. The graph is stored in the `.lmas` metadata `material_graph` with a hash of the source it matches, so its layout survives a save and reload.

**Yapıcı Metotlar (Constructors):**

- `MaterialGraphController(this._vm)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `transactions` | `final TransactionManager transactions` |  |
| `editor` | `late final MaterialGraphEditor editor` |  |
| `bindTexture` | `bool bindTexture(String parameter, RealAssetInfo? asset)` | Binds sampler [parameter] to [asset] (null clears it) as one undo step: the panel, the node Details and the Texture Sample node all go through here. The binding lives in the view model's parameters, not in the graph, so the step restores it directly. |
| `graph` | `LuminaBlueprintGraph get graph` |  |
| `analysis` | `MaterialGraphAnalysis get analysis` |  |
| `surface` | `MaterialSurface get surface` |  |
| `isInitialized` | `bool get isInitialized` |  |
| `isAhead` | `bool get isAhead` | The graph holds edits the source lacks (its type errors kept it from being written). A hand edit of the source since makes the source the newer of the two again. |
| `isLayoutDirty` | `bool get isLayoutDirty` |  |
| `fallbackReason` | `String? get fallbackReason` | Why the fragment is one Custom (Fragment) node, when it is. |
| `notes` | `List<String> get notes` |  |
| `sourceHash` | `static String sourceHash(String code)` |  |
| `restore` | `void restore(String? storedJson)` | Forgets the graph; the next [ensureSynced] reads it from [storedJson] (the `.lmas` metadata) or parses the source. |
| `storedJson` | `String storedJson()` | The metadata value [restore] reads back. |
| `markSaved` | `void markSaved()` |  |
| `ensureSynced` | `void ensureSynced()` | Brings the graph in line with the source: the stored graph when it was saved with this very source, else a parse of the source laid out like the graph before it. A re-parse after a hand edit clears graph undo. |
| `headerChanged` | `void headerChanged(String previousCode)` | The source's header changed (shading model, blend mode) without its fragment: keep the graph, re-check it against the new surface, and regenerate the fragment so the pins the new surface does not use are left out, and come back when it uses them again (e.g. Unlit rejects `material.metallic`). A graph not opened yet is read first; a hand-written fragment kept as Custom (Fragment) stays as it is. |
| `issues` | `List<MaterialCompileIssue> get issues` | The graph's diagnostics as compiler-log rows. |
| `undo` | `void undo()` |  |
| `redo` | `void redo()` |  |
| `arrange` | `void arrange()` | Lays the graph out again (one undo step). |

## `lib/ui/features/sub_editors/view_models/material_graph_editor.dart`

### `class MaterialGraphEditor`

Bir materyal grafiğini paylaşılan Blueprint grafik tuvali üzerinden düzenler: lumina'nın Blueprint düğüm kütüphanesi yerine materyal ifadeleri, Blueprint pin türleri yerine float1–float4, doku ve bool pinleri (bool pinleri Blueprint boolean renginde) ve materyal kablolama kuralı — bir kablo yalnızca bir döngü ya da doku/sayı karışıklığı için reddedilir; diğer her uyumsuzluk kırmızı çizilir ve tür denetleyicisi tarafından raporlanır.

**Yapıcı Metotlar (Constructors):**

- `MaterialGraphEditor({required super.host, required super.graphSource, required this.analysis, required this.surface, required this.textures, required this.textu...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `analysis` | `final MaterialGraphAnalysis Function() analysis` |  |
| `surface` | `final MaterialSurface Function() surface` |  |
| `textures` | `final List<RealAssetInfo> Function() textures` | The project's textures, the one bound to a sampler parameter, and the undoable rebind, for the Texture Sample node's thumbnail picker. |
| `textureFor` | `final RealAssetInfo? Function(String parameter) textureFor` |  |
| `bindTexture` | `final bool Function(String parameter, RealAssetInfo? asset) bindTexture` |  |
| `samplerOf` | `String? samplerOf(LuminaBlueprintNode node)` | The `.mat` sampler a Texture Sample / TextureParameter node reads: its own parameter, or the TextureParameter wired into Tex. |
| `textureBodyHeight` | `static const double textureBodyHeight` |  |
| `nodeBody` | `Widget? nodeBody(BuildContext context, LuminaBlueprintNode node)` | Texture Sample düğümü: bağlı dokunun küçük resmi ve adı; bir tıklama aranabilir seçiciyi açar. Compare düğümü: operatör seçim kutusu. |
| `compareOperatorSelect` | `static Widget compareOperatorSelect(LuminaBlueprintNode node, {required String keyPrefix, required void Function(String op) onChanged})` | Compare'in operatörleri (`A >= B` …) üzerinde bir seçim kutusu; düğüm ve Details paneli ortak kullanır. |
| `displayType` | `static LuminaPinType displayType(MaterialValueType? t)` | The Blueprint pin type the canvas uses to pick an inline editor. |
| `colorFor` | `static Color colorFor(MaterialValueType? t)` |  |
| `typeOf` | `MaterialValueType? typeOf(String nodeId, String pinId, {required bool output})` | The resolved type of a pin: its fixed type, else what flows through it. |
| `showsInlineLiteral` | `bool showsInlineLiteral(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin)` | Only inputs with a "Const" fallback (Multiply's B, Lerp's Alpha, Fresnel's exponent) edit a constant on the node. |
| `uniqueParameterName` | `String uniqueParameterName(String base)` | A parameter name no node uses yet: [base], `base_1`, `base_2`, … |
| `declaredVariables` | `List<String> get declaredVariables` | The vertex variables the material has: the names Set Vertex Variable nodes write (graph order), then those the header declares without one. |
| `uniqueVariableName` | `String uniqueVariableName(String base)` | A variable name no Set Vertex Variable writes yet: [base], `base_1`, … (a new setter's default; a new Vertex Variable reads the first declared name). |
| `removeNodes` | `bool removeNodes(Set<String> ids)` | Every node but the Material output can be deleted. |
| `setProperty` | `bool setProperty(String nodeId, String key, Object? value)` | Düğüm ayarı [key]'i (bir sabitin değeri, bir parametrenin adı, bir Custom düğümünün kodu) tek bir geri alma adımı olarak ayarlar. Bir Custom girişini yeniden adlandırmak kablosunu korur; birini kaldırmak kablosunu düşürür. Bir değişkenin tek Set Vertex Variable'ını yeniden adlandırmak onu okuyan Vertex Variable düğümlerini de yeniden adlandırır. Bir Custom (Fragment) düğümünün `code`'unu değiştirmek pinlerini ve kablolarını yeniden kurar ([MaterialFragmentPins.syncWires]). |

## `lib/ui/features/sub_editors/views/material/graph_view.dart`

### `class MaterialGraphView`

The Material Editor's Node Graph tab: the material as material expressions on the Blueprint editor's graph canvas, with a Details panel for the selected node. Graph and GLSL tab are two views of one material: an edit here rewrites the source, an edit there re-parses into this graph.

**Yapıcı Metotlar (Constructors):**

- `const MaterialGraphView({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |

### `class MaterialGraphViewState`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `canvas` | `BlueprintGraphCanvasState? get canvas` |  |

## `lib/ui/features/sub_editors/views/material/node_details_panel.dart`

### `class MaterialNodeDetailsPanel`

Materyal grafiğinin Details paneli: seçili ifadenin ayarları — sabit değerler, parametre adları ve varsayılanları, bir TextureSample'ın okuduğu doku, TexCoord döşemesi, maske kanalları, bir Compare'in operatörü ve bir Custom düğümünün girişleri ile GLSL'i. İşlenen her düzenleme bir geri alma adımıdır.

**Yapıcı Metotlar (Constructors):**

- `const MaterialNodeDetailsPanel({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |

---

[Önceki: Landscape ve foliage](landscape.md) | [Üst: Alt editörler](index.md) | [Sonraki: Navigasyon editörü](navigation.md)
