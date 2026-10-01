[English](../../en/lumina_ui/main-editor-views.md)

# Ana editör: view'ler

Ana editör penceresinin widget'ları: ana editör view'i ve layout state'i, 3D viewport, outliner, details paneli, content browser, toolbar, menü çubuğu, output log, yeni level diyaloğu ve yeniden başlatma uyarı bandı. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/main_editor/views/content_browser_widget.dart`](#libuifeaturesmain_editorviewscontent_browser_widgetdart)
- [`lib/ui/features/main_editor/views/details_widget.dart`](#libuifeaturesmain_editorviewsdetails_widgetdart)
- [`lib/ui/features/main_editor/views/main_editor_view.dart`](#libuifeaturesmain_editorviewsmain_editor_viewdart)
- [`lib/ui/features/main_editor/views/menu_bar_widget.dart`](#libuifeaturesmain_editorviewsmenu_bar_widgetdart)
- [`lib/ui/features/main_editor/views/new_level_dialog.dart`](#libuifeaturesmain_editorviewsnew_level_dialogdart)
- [`lib/ui/features/main_editor/views/outliner_widget.dart`](#libuifeaturesmain_editorviewsoutliner_widgetdart)
- [`lib/ui/features/main_editor/views/output_log_widget.dart`](#libuifeaturesmain_editorviewsoutput_log_widgetdart)
- [`lib/ui/features/main_editor/views/restart_required_banner.dart`](#libuifeaturesmain_editorviewsrestart_required_bannerdart)
- [`lib/ui/features/main_editor/views/toolbar_widget.dart`](#libuifeaturesmain_editorviewstoolbar_widgetdart)
- [`lib/ui/features/main_editor/views/viewport_widget.dart`](#libuifeaturesmain_editorviewsviewport_widgetdart)
- [`lib/ui/features/main_editor/view_models/editor_layout_state.dart`](#libuifeaturesmain_editorview_modelseditor_layout_statedart)

## `lib/ui/features/main_editor/views/content_browser_widget.dart`

### `class ContentBrowserWidget`

`ContentBrowserWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<ContentBrowserWidget> createState() => _ContentBrowserWidgetState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _ContentBrowserWidgetState`

`_ContentBrowserWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _LuminaClassInfo`

`_LuminaClassInfo`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `className` | `String className` | `className` alanını (field/property) ve ilişkili veriyi saklar. |
| `category` | `String category` | `category` alanını (field/property) ve ilişkili veriyi saklar. |
| `description` | `String description` | `description` alanını (field/property) ve ilişkili veriyi saklar. |
| `icon` | `IconData icon` | `icon` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/ui/features/main_editor/views/details_widget.dart`

### `class DetailsWidget`

`DetailsWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<DetailsWidget> createState() => _DetailsWidgetState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _DetailsWidgetState`

`_DetailsWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _CategoryHeader`

`_CategoryHeader`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _MobilityBtn`

`_MobilityBtn`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `active` | `bool active` | `active` alanını (field/property) ve ilişkili veriyi saklar. |
| `onTap` | `VoidCallback onTap` | `onTap` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/views/main_editor_view.dart`

### `class MainEditorView`

`MainEditorView`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `project` | `LuminaProject? project` | `project` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectLocation` | `String? projectLocation` | `projectLocation` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `EditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<MainEditorView> createState() => _MainEditorViewState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _MainEditorViewState`

`_MainEditorViewState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/views/menu_bar_widget.dart`

### `class MenuBarWidget`

`MenuBarWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engineVersion` | `String engineVersion` | `engineVersion` alanını (field/property) ve ilişkili veriyi saklar. |
| `activeLevelName` | `String activeLevelName` | `activeLevelName` alanını (field/property) ve ilişkili veriyi saklar. |
| `onSave` | `VoidCallback onSave` | `onSave` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `EditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/views/new_level_dialog.dart`

### `class NewLevelDialog`

`File → New Level…` — a name plus the template the level starts from.  Every entry is honest about what it seeds (including `Empty`, which seeds nothing on purpose), and the chosen template's actors and world-partition section are written into the new `.lmas` before the editor switches to it, so the level opens populated.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<NewLevelDialog> createState() => _NewLevelDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _NewLevelDialogState`

`_NewLevelDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _TemplateTile`

One selectable template row. It is a real focusable button, so the list is keyboard-navigable with Tab / Enter without any custom key handling.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `template` | `LevelTemplate template` | `template` alanını (field/property) ve ilişkili veriyi saklar. |
| `selected` | `bool selected` | `selected` alanını (field/property) ve ilişkili veriyi saklar. |
| `onSelected` | `VoidCallback onSelected` | `onSelected` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/views/outliner_widget.dart`

### `class OutlinerWidget`

`OutlinerWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<OutlinerWidget> createState() => _OutlinerWidgetState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _OutlinerWidgetState`

`_OutlinerWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _FlattenedNode`

`_FlattenedNode`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_FlattenedNode(this.node, this.depth, this.hasChildren)`: `_FlattenedNode(this.node, this.depth, this.hasChildren)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `node` | `EditorActorNode node` | `node` alanını (field/property) ve ilişkili veriyi saklar. |
| `depth` | `int depth` | `depth` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasChildren` | `bool hasChildren` | `hasChildren` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/ui/features/main_editor/views/output_log_widget.dart`

### `class OutputLogWidget`

`OutputLogWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<OutputLogWidget> createState() => _OutputLogWidgetState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _OutputLogWidgetState`

`_OutputLogWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/views/restart_required_banner.dart`

### `class RestartRequiredBanner`

`RestartRequiredBanner`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `onDismiss` | `VoidCallback onDismiss` | `onDismiss` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/views/toolbar_widget.dart`

### `class ToolbarWidget`

`ToolbarWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<ToolbarWidget> createState() => _ToolbarWidgetState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _ToolbarWidgetState`

`_ToolbarWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _ToolBtn`

`_ToolBtn`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `icon` | `IconData icon` | `icon` alanını (field/property) ve ilişkili veriyi saklar. |
| `active` | `bool active` | `active` alanını (field/property) ve ilişkili veriyi saklar. |
| `onTap` | `VoidCallback onTap` | `onTap` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _SnapCluster`

`_SnapCluster`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_SnapCluster(this.vm)`: `_SnapCluster(this.vm)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `EditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _SnapToggleWithMenu`

`_SnapToggleWithMenu`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `icon` | `IconData icon` | `icon` alanını (field/property) ve ilişkili veriyi saklar. |
| `active` | `bool active` | `active` alanını (field/property) ve ilişkili veriyi saklar. |
| `onToggle` | `VoidCallback onToggle` | `onToggle` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `double value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `options` | `List<double> options` | `options` alanını (field/property) ve ilişkili veriyi saklar. |
| `onChanged` | `ValueChanged<double> onChanged` | `onChanged` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<_SnapToggleWithMenu> createState() => _SnapToggleWithMenuState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _SnapToggleWithMenuState`

`_SnapToggleWithMenuState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _GridPopover`

`_GridPopover`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `EditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<_GridPopover> createState() => _GridPopoverState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _GridPopoverState`

`_GridPopoverState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/main_editor/views/viewport_widget.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`with TickerProviderStateMixin`**: `TickerProviderStateMixin` işlemini gerçekleştirir.

### `class ViewportWidget`

`ViewportWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<ViewportWidget> createState() => _ViewportWidgetState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### Kamera önizlemesi (`camera_preview_panel.dart`, `level_scene_view.dart`)

Tek bir kamera aktörü seçilince (yerleştirilmiş `Camera`; Play sırasında değil) 3D alanın sol altında, istatistik şeridinin üstünde bir **Camera preview** paneli açılır: kameranın adı, kapatma düğmesi (×) ve level'a o kameradan canlı bakan bir görüntü — konumu ve dönüşü (gizmo sürüklemeleri ve Details düzenlemeleriyle birlikte), projeksiyonu (dikey görüş açısı ya da ortografik genişlik), yakın / uzak kırpma düzlemleri ve pozlaması (kendi diyafram / enstantane / ISO değerleri ya da Auto Exposure açıkken level viewport'unun ölçtüğü pozlama). Görüntü 16:9'dur (kameranın henüz en-boy ayarı yok; dikey görüş açısı kameranınki olduğundan dikey kadraj Play ile aynıdır). Sağ üst köşeden sürüklenerek boyutlandırılır (16:9 korunur, 192–960 px genişlik, 3D alanın izin verdiğinden uzun olmaz); genişlik kullanıcıya özel bir editör tercihidir (`EditorPreferences.cameraPreviewWidth`). × paneli başka bir kamera seçilene (ya da seçim başka yere gidip geri gelene) kadar gizler; kamera olmayan bir aktör ya da birden çok aktör seçilince panel kapanır. Panele yapılan tıklamalar panelde kalır (arkadaki seçimi ya da gezinmeyi etkilemez). Gizliyken hiç Filament view'ı yoktur.

Önizleme level viewport'unun kendi sahnesini (`EditorViewModel.levelScene`) editör yardımcıları olmadan çizer; bunu Filament görünürlük katmanları (`EditorViewLayers`) sağlar: içerik (varsayılan katman), yardımcılar (grid, gizmo, seçim kutuları, ışık / kapsül / hacim çizgileri, Wireframe kenar çizgileri) ve aktör katıları. Level view Lit / Unlit'te üçünü de gösterir, Wireframe'de katıları gizler (sahnede kalırlar, böylece önizleme ışıklı level'ı göstermeye devam eder); önizleme içerik ve katıları gösterir. Işıklar sahnenin parçası olduğundan Unlit'te önizleme de doğrudan ışıkları kaybeder; level viewport'unun sisi ve Post Process Volume'ları önizlemeye uygulanmaz.

| Sınıf | Amaç |
| :--- | :--- |
| `CameraPreviewOverlay` | 3D alanı kaplar, `previewCameraOf(vm)` için (Play dışında seçili tek kamera) paneli gösterir, × ve köşe sürüklemesini yönetir; `panelWidth`, `maxWidth`, `close()`. |
| `CameraPreviewPanel` | Panel: başlık çubuğu, kameradan bakan `LevelSceneView` (`CameraActorView.apply`), sağ üst boyutlandırma tutamağı. `aspect` = 16:9. |
| `LevelSceneView` / `LevelSceneViewState` | Level sahnesinin paylaşılan motor üzerindeki ikinci bir view'ı; sahibi tarafından yönlendirilir (`onAim`: oluşturulunca, sahne değişince, yeniden boyutlanınca ve her karede çağrılır), kendi görünür katmanlarıyla. Sequencer viewport'u da bunun üzerine kuruludur. `drawsLevelScene`, `view`, `camera`, `drawn`, `aspect`, `aim()`. |
| `CameraActorView` (`services/camera_actor_view.dart`) | Bir kamera aktörünü view'a çevirir: `settingsOf` (`LuminaCameraSettings`), `pose` (`LevelViewPose`), `apply` (projeksiyon, kırpma düzlemleri, poz, pozlama). |
| `EditorViewLayers` (`services/editor_view_layers.dart`) | Katman bitleri (`content`, `helpers`, `solids` ve `gizmo`: level viewport'unun native dönüşüm gizmosu; Sequencer'ın view'ı (`editorView`) kendi gizmosunu çizdiği için onu dışarıda bırakır), her view'ın maskesi, `show(view, layers)`, `tag(engine, entities, layer)`. |

Level viewport state'indeki test noktaları: `viewLayersForTest` (level view'ın görünür katmanları), `editorActorsInSceneForTest` (level view'ın çizdiği katılar; Wireframe'de 0), `editorActorSolidsInSceneForTest` (sahnedeki katılar).

### `class _ViewportWidgetState`

`_ViewportWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(covariant ViewportWidget oldWidget)` | `didUpdateWidget` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `pieCameraDrivesViewForTest` | `bool get pieCameraDrivesViewForTest` | Test seam: whether the game's camera owns the Filament view. |
| `pieCameraEyeForTest` | `List<double>? get pieCameraEyeForTest` | Test seam: the eye position the PIE camera is pointing from, or null when the editor camera owns the view. |
| `nativeGizmoForTest` | `FilamentTransformGizmo? get nativeGizmoForTest` | The live transform gizmo, so smoke tests can assert which mode is on screen and which handle is highlighted. |
| `hoveredGizmoAxisForTest` | `String? get hoveredGizmoAxisForTest` | The gizmo handle the pointer is currently over, or null. |
| `nativeViewForTest` | `FilamentView? get nativeViewForTest` | The live Filament view, so smoke tests can assert what the renderer was actually told rather than what the view model believes. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |
| `gizmoHandleScreenPositionsForTest` | `Map<String, Offset>? gizmoHandleScreenPositionsForTest(Size viewportSize)` | `gizmoHandleScreenPositionsForTest` işlemini gerçekleştirir. |

### `class _CameraMatrix`

`_CameraMatrix`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewportSize` | `Size viewportSize` | `viewportSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `yawDeg` | `double yawDeg` | `yawDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `pitchDeg` | `double pitchDeg` | `pitchDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `dist` | `double dist` | `dist` alanını (field/property) ve ilişkili veriyi saklar. |
| `panX` | `double panX` | `panX` alanını (field/property) ve ilişkili veriyi saklar. |
| `panY` | `double panY` | `panY` alanını (field/property) ve ilişkili veriyi saklar. |
| `panZ` | `double panZ` | `panZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `cx` | `final double cx` | `cx` alanını (field/property) ve ilişkili veriyi saklar. |
| `cy` | `final double cy` | `cy` alanını (field/property) ve ilişkili veriyi saklar. |
| `yawRad` | `final double yawRad` | `yawRad` alanını (field/property) ve ilişkili veriyi saklar. |
| `pitchRad` | `final double pitchRad` | `pitchRad` alanını (field/property) ve ilişkili veriyi saklar. |
| `fovScale` | `final double fovScale` | `fovScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `camX` | `final double camX` | `camX` alanını (field/property) ve ilişkili veriyi saklar. |
| `camY` | `final double camY` | `camY` alanını (field/property) ve ilişkili veriyi saklar. |
| `camZ` | `final double camZ` | `camZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `fZ` | `final double fX, fY, fZ` | `fZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `rZ` | `final double rX, rY, rZ` | `rZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `uZ` | `final double uX, uY, uZ` | `uZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `project` | `Offset? project(double wx, double wy, double wz)` | `project` işlemini gerçekleştirir. |
| `getWorldRayDirection` | `List<double> getWorldRayDirection(Offset screenPos)` | `WorldRayDirection` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `unprojectToFloor` | `Offset unprojectToFloor(Offset screenPos)` | `unprojectToFloor` özelliğine yeni değer atayan setter değiştiricisi. |

## `lib/ui/features/main_editor/view_models/editor_layout_state.dart`

### `class EditorLayoutState`

`EditorLayoutState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `EditorLayoutState.fromJson(Map<String, dynamic> json)`: `EditorLayoutState.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `outlinerWidth` | `double outlinerWidth` | `outlinerWidth` alanını (field/property) ve ilişkili veriyi saklar. |
| `detailsWidth` | `double detailsWidth` | `detailsWidth` alanını (field/property) ve ilişkili veriyi saklar. |
| `bottomHeight` | `double bottomHeight` | `bottomHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `outlinerVisible` | `bool outlinerVisible` | `outlinerVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `detailsVisible` | `bool detailsVisible` | `detailsVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `bottomVisible` | `bool bottomVisible` | `bottomVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `activeBottomTab` | `int activeBottomTab` | `activeBottomTab` alanını (field/property) ve ilişkili veriyi saklar. |
| `rightWidth` | `double rightWidth` | Sağ dock'un genişliği (varsayılan 340, en az 260); tüm editör sekmelerinde ortaktır. |
| `pluginPanelVisible` | `Map<String, bool> pluginPanelVisible` | Hangi sağ dock eklenti panellerinin açık olduğu (gösterilene kadar kapalı). |
| `activeRightPanel` | `String? activeRightPanel` | Sağ dock'un etkin sekmesi. |
| `pluginPanelAlways` | `Map<String, bool> pluginPanelAlways` | Kullanıcının sağ dock paneli başına "Always" seçimi: panel yalnızca level editöründe değil, her editör sekmesinde görünür. Burada olmayan panel eklentisinin `defaultAlwaysVisible` değerini kullanır. `editor_layout.json` içinde `pluginPanelAlways` olarak kaydedilir; Reset Layout temizler. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `resetToDefault` | `void resetToDefault()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |

---

[Önceki: Uygulama kabuğu ve ortak UI (devamı, bölüm 2)](core-continued-2.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Ana editör: view'ler (devamı)](main-editor-views-continued.md)
