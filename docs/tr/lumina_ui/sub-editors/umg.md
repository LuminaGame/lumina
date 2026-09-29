[English](../../../en/lumina_ui/sub-editors/umg.md)

# Widget (UMG) tasarımcısı

Oyun arayüzü için widget tasarımcısı: UMG belge modeli, tasarım kanvası, palet, hiyerarşi ağacı ve slot inspector'ı, view model ve bir widget asset'ini Flutter widget sınıfına dönüştüren kod üreteci. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/umg/designer_canvas.dart`](#libuifeaturessub_editorsviewsumgdesigner_canvasdart)
- [`lib/ui/features/sub_editors/views/umg/hierarchy_tree.dart`](#libuifeaturessub_editorsviewsumghierarchy_treedart)
- [`lib/ui/features/sub_editors/views/umg/palette.dart`](#libuifeaturessub_editorsviewsumgpalettedart)
- [`lib/ui/features/sub_editors/views/umg/slot_inspector.dart`](#libuifeaturessub_editorsviewsumgslot_inspectordart)
- [`lib/ui/features/sub_editors/views/umg/widget_sub_editor.dart`](#libuifeaturessub_editorsviewsumgwidget_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/umg_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsumg_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/umg_widget_codegen.dart`](#libuifeaturessub_editorsservicesumg_widget_codegendart)
- [`lib/ui/features/sub_editors/models/umg_document.dart`](#libuifeaturessub_editorsmodelsumg_documentdart)
- [`lib/ui/features/sub_editors/services/umg_widget_validator.dart`](#libuifeaturessub_editorsservicesumg_widget_validatordart)
- [`lib/ui/features/sub_editors/services/widget_class_catalog.dart`](#libuifeaturessub_editorsserviceswidget_class_catalogdart)
- [`lib/ui/features/sub_editors/views/umg/umg_components.dart`](#libuifeaturessub_editorsviewsumgumg_componentsdart)
- [`lib/ui/features/sub_editors/views/umg/umg_runtime_view.dart`](#libuifeaturessub_editorsviewsumgumg_runtime_viewdart)
- [`lib/ui/features/sub_editors/views/umg/umg_text_style.dart`](#libuifeaturessub_editorsviewsumgumg_text_styledart)

## `lib/ui/features/sub_editors/views/umg/designer_canvas.dart`

### `class UmgDesignerCanvas`

Visual Designer Canvas: renders the document with the real shadcn_flutter widgets (wrapped in [IgnorePointer]) under a design-time overlay that does hit-testing, selection, drag-move, 8-handle resize, snap-to-grid, alignment guides and the resolution/DPI frame.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<UmgDesignerCanvas> createState() => UmgDesignerCanvasState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class UmgDesignerCanvasState`

`UmgDesignerCanvasState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel get vm` | `vm` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rectFor` | `Rect? rectFor(String id)` | Last measured rect of [id] in canvas (logical design) coordinates. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(covariant UmgDesignerCanvas oldWidget)` | `didUpdateWidget` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _Guide`

`_Guide`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vertical` | `bool vertical` | `vertical` alanını (field/property) ve ilişkili veriyi saklar. |
| `at` | `double at` | `at` alanını (field/property) ve ilişkili veriyi saklar. |
| `from` | `double from` | `from` alanını (field/property) ve ilişkili veriyi saklar. |
| `to` | `double to` | `to` alanını (field/property) ve ilişkili veriyi saklar. |

### `class _GridPainter`

`_GridPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `gridSize` | `double gridSize` | `gridSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `screenScale` | `double screenScale` | `screenScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(_GridPainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

### `class _OverlayPainter`

`_OverlayPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `rects` | `Map<String, Rect> rects` | `rects` alanını (field/property) ve ilişkili veriyi saklar. |
| `document` | `UmgDocument document` | `document` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedId` | `String? selectedId` | `selectedId` alanını (field/property) ve ilişkili veriyi saklar. |
| `hoverId` | `String? hoverId` | `hoverId` alanını (field/property) ve ilişkili veriyi saklar. |
| `guides` | `List<_Guide> guides` | `guides` alanını (field/property) ve ilişkili veriyi saklar. |
| `screenScale` | `double screenScale` | `screenScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(_OverlayPainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

### `class _UmgRuntimeTree`

Maps document nodes to real shadcn_flutter widgets (same registry as [UmgWidgetCodegen], executed live).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `onInteraction` | `VoidCallback onInteraction` | `onInteraction` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context) => _build(vm.document.root)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/umg/hierarchy_tree.dart`

### `class UmgHierarchyTree`

Widget Hierarchy `Tree`: rows are drop targets for palette widgets and for reordering (`Draggable<String>` node ids); the `ContextMenu` offers Wrap With / Replace With / Add Child / Rename / Delete.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<UmgHierarchyTree> createState() => _UmgHierarchyTreeState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _UmgHierarchyTreeState`

`_UmgHierarchyTreeState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel get vm` | `vm` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _RenameDialog`

`_RenameDialog`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `node` | `UmgNode node` | `node` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<_RenameDialog> createState() => _RenameDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _RenameDialogState`

`_RenameDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/umg/palette.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`IconData umgIconFor(UmgWidgetType type)`**: Icon per palette type (LucideIcons, shadcn_flutter).

### `class UmgPalette`

Widget palette: `Accordion` categories whose entries are real `Draggable<UmgWidgetType>`s (pointer-anchored so the drop point is the pointer). Double-click places the widget into the selected panel.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/umg/slot_inspector.dart`

### `class UmgSlotInspector`

Right panel: Slot (anchors preset matrix, position/size/ alignment, size-to-content, Z-order — or the honest box/overlay slot fields), Appearance (color & tint, font size, image brush, per-type content) and Widget Events (`[+] OnClicked` …).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _AnchorGlyphPainter`

Draws the little anchor glyph (dot/bar) of a preset.

**Yapıcı Metotlar (Constructors):**
- `_AnchorGlyphPainter(this.preset)`: `_AnchorGlyphPainter(this.preset)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `preset` | `UmgAnchorPreset preset` | `preset` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(_AnchorGlyphPainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/views/umg/widget_sub_editor.dart`

### `class UMGWidgetSubEditor`

UMG designer: Palette | Hierarchy tabs on the left, the live designer canvas (or the generated-source Graph view) in the center and the slot/appearance/events inspector on the right — all bound to one [UmgEditorViewModel] over a real WIDGET `.lmas`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `LuminaAsset? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectDirPath` | `String? projectDirPath` | `projectDirPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `UmgEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<UMGWidgetSubEditor> createState() => _UMGWidgetSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _UMGWidgetSubEditorState`

`_UMGWidgetSubEditorState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModelForTest` | `UmgEditorViewModel get viewModelForTest` | `viewModelForTest` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/umg_editor_view_model.dart`

### `enum UmgEditorMode`

Designer mode of the center panel.

### `class UmgEditorViewModel`

View model of the UMG designer: one persisted [UmgDocument] inside a real WIDGET `.lmas`, every mutation recorded on its own [TransactionManager], `save()` through `LuminaAsset.toProtoBufferBytes()`, `compile()` through [UmgWidgetCodegen] into the project's `lib/widgets/`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectDirPathOverride` | `String? projectDirPathOverride` | `projectDirPathOverride` alanını (field/property) ve ilişkili veriyi saklar. |
| `document` | `UmgDocument get document` | `document` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isLoaded` | `bool get isLoaded` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `selectedId` | `String? get selectedId` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedNode` | `UmgNode? get selectedNode` | İlgili aktör veya varlığı seçili duruma getirir. |
| `mode` | `UmgEditorMode get mode` | `mode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `resolution` | `UmgResolution get resolution` | `resolution` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dpiScale` | `double get dpiScale` | `dpiScale` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `logicalSize` | `Size get logicalSize` | `logicalSize` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastRejectionReason` | `String? get lastRejectionReason` | `lastRejectionReason` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastCompile` | `UmgCompileResult? get lastCompile` | `lastCompile` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `compileError` | `String? get compileError` | `compileError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `textureAssets` | `List<RealAssetInfo> get textureAssets` | `textureAssets` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `className` | `String get className` | `className` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `projectDirPath` | `String? get projectDirPath` | `projectDirPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `generatedSource` | `String get generatedSource` | Generated source for the current document (Graph tab / compile preview). |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `compile` | `Future<UmgCompileResult> compile()` | Saves, then writes `lib/widgets/wbp_<name>.dart` (class `Wbp<Name>`) into the project. |
| `discardChanges` | `void discardChanges()` | `discardChanges` işlemini gerçekleştirir. |
| `select` | `void select(String? id)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `setMode` | `void setMode(UmgEditorMode mode)` | `Mode` parametresini günceller ve sisteme uygular. |
| `setResolution` | `void setResolution(UmgResolution resolution)` | `Resolution` parametresini günceller ve sisteme uygular. |
| `setCustomResolution` | `void setCustomResolution(int width, int height)` | `CustomResolution` parametresini günceller ve sisteme uygular. |
| `setDpiScale` | `void setDpiScale(double scale)` | `DpiScale` parametresini günceller ve sisteme uygular. |
| `beginInteraction` | `void beginInteraction(String label)` | Starts a coalesced interaction (canvas drag, scrub): previews mutate the document live, [endInteraction] records a single transaction. |
| `endInteraction` | `void endInteraction()` | `endInteraction` işlemini gerçekleştirir. |
| `undo` | `void undo() => transactions.undo()` | Yapılan son işlemi geri alır. |
| `redo` | `void redo() => transactions.redo()` | Geri alınan son işlemi yineler. |
| `setCanvasPosition` | `void setCanvasPosition(String id, Offset position)` | `CanvasPosition` parametresini günceller ve sisteme uygular. |
| `setCanvasSize` | `void setCanvasSize(String id, Size size)` | `CanvasSize` parametresini günceller ve sisteme uygular. |
| `previewCanvasPosition` | `void previewCanvasPosition(String id, Offset position)` | Live (un-recorded) canvas position update used inside an interaction. |
| `previewCanvasRect` | `void previewCanvasRect(String id, Rect rect, Size parentSize)` | Live (un-recorded) rect update used by move/resize handles: rewrites position/size so the slot resolves to [rect] inside [parentSize]. |
| `previewSlot` | `void previewSlot(String id, void Function(UmgSlot slot) edit)` | Live (un-recorded) slot field edit used by inspector scrubbing. |
| `applyAnchorPreset` | `void applyAnchorPreset(String id, UmgAnchorPreset preset)` | `applyAnchorPreset` özelliğine yeni değer atayan setter değiştiricisi. |
| `canvasSizeOf` | `Size canvasSizeOf(String id)` | Best-effort design-time size of a panel (its own canvas rect if it is a canvas child, otherwise the simulated screen). |
| `setZOrder` | `void setZOrder(String id, int zOrder)` | `ZOrder` parametresini günceller ve sisteme uygular. |
| `setProp` | `void setProp(String id, String key, dynamic value)` | `Prop` parametresini günceller ve sisteme uygular. |
| `previewProp` | `void previewProp(String id, String key, dynamic value)` | Live (un-recorded) prop edit used by inspector scrubbing. |
| `rename` | `bool rename(String id, String newName)` | Renames the element; the display name becomes the generated identifier via [UmgNaming.toFieldName]. Rejects empty/non-identifier/duplicate names. |
| `wrapWith` | `UmgNode? wrapWith(String id, UmgWidgetType type)` | Inserts a new [type] parent between [id] and its parent, handing the child's slot to the wrapper. |
| `replaceWith` | `UmgNode? replaceWith(String id, UmgWidgetType type)` | Swaps the node's type, keeping identity, name, slot and compatible children. |
| `deleteNode` | `bool deleteNode(String id)` | Belirtilen `Node` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `addEvent` | `bool addEvent(String id, String eventName)` | `[+] OnClicked` etc.: records a named handler on the node. |
| `removeEvent` | `bool removeEvent(String id, String eventName)` | Belirtilen `Event` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `bindTexture` | `void bindTexture(String id, RealAssetInfo? texture)` | Binds a real TEXTURE `.lmas` to an Image element. |
| `textureBytesFor` | `Uint8List? textureBytesFor(String id)` | Raw image bytes of the texture bound to [id] (read from disk, cached). |
| `refreshTextures` | `void refreshTextures()` | `refreshTextures` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/services/umg_widget_codegen.dart`

### `class UmgCompileResult`

Outcome of one compile of a widget document.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `filePath` | `String filePath` | `filePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `written` | `bool written` | `written` alanını (field/property) ve ilişkili veriyi saklar. |
| `source` | `String source` | `source` alanını (field/property) ve ilişkili veriyi saklar. |
| `warnings` | `List<String> warnings` | `warnings` alanını (field/property) ve ilişkili veriyi saklar. |

### `class UmgWidgetCodegen`

Generates the real Flutter widget class for a [UmgDocument] (`<project>/lib/widgets/wbp_<name>.dart`, class `Wbp<Name>`). Same principles as the actor codegen: deterministic, idempotent, compare-before-write, `// BEGIN USER CODE: <tag>` … `// END USER CODE` regions survive regeneration, orphaned regions are kept commented at the end of the file. The game never parses the `.lmas`; this file is the truth.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fileBaseName` | `static String fileBaseName(String assetName)` | Widget class base name the document registers under (`WBP_` prefix enforced); the generated file and class derive from it (`WBP_PlayerHUD` → `wbp_player_hud.dart`, class `WbpPlayerHUD`). |
| `classNameFor` | `static String classNameFor(String assetName) => UmgNaming.toClassName(fi...` | `classNameFor` işlemini gerçekleştirir. |
| `outputPath` | `static String outputPath(String projectPath, String assetName)` | `outputPath` işlemini gerçekleştirir. |
| `parseUserRegions` | `static Map<String, String> parseUserRegions(String? existing)` | Parses guarded regions out of an existing generated file. |

## `lib/ui/features/sub_editors/models/umg_document.dart`

### `enum UmgWidgetCategory`

Palette categories of the UMG designer.

### `enum UmgWidgetType`

Every widget type the designer can place. The order here is the palette order; `displayName` is what the palette/hierarchy show and `dartWidget` the shadcn_flutter class the runtime renderer and the code generator map it to.

**Yapıcı Metotlar (Constructors):**
- `UmgWidgetType(this.displayName, this.category, this.capacity)`: `UmgWidgetType(this.displayName, this.category, this.capacity)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `comboBox` | `comboBox('Combo Box', UmgWidgetCategory.common, UmgChildCapacity.none)` | `comboBox` işlemini gerçekleştirir. |
| `displayName` | `String displayName` | `displayName` alanını (field/property) ve ilişkili veriyi saklar. |
| `category` | `UmgWidgetCategory category` | `category` alanını (field/property) ve ilişkili veriyi saklar. |
| `capacity` | `UmgChildCapacity capacity` | `capacity` alanını (field/property) ve ilişkili veriyi saklar. |
| `isPanel` | `bool get isPanel` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isCanvas` | `bool get isCanvas` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isBox` | `bool get isBox` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `childSlotKind` | `UmgSlotKind get childSlotKind` | Which slot kind children of this type carry. |
| `availableEvents` | `List<String> get availableEvents` | Events the designer offers for this type (Widget Events section). |
| `isInteractive` | `bool get isInteractive` | Whether the runtime widget carries user-mutable state (needs a StatefulWidget in generated code even without events). |
| `defaultProps` | `Map<String, dynamic> defaultProps()` | Default props for a freshly placed widget of this type. |
| `defaultCanvasSize` | `Size get defaultCanvasSize` | Default size of a newly dropped canvas slot for this type. |
| `fromName` | `static UmgWidgetType fromName(String name)` | `fromName` işlemini gerçekleştirir. |

### `enum UmgChildCapacity`

`UmgChildCapacity`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `enum UmgSlotKind`

Slot kinds: a child's slot is decided by its *parent* panel.

### `enum UmgAlign`

Horizontal/vertical alignment of box/overlay slots.

### `class UmgSlot`

Per-child slot data. One class carries every field so wrap/replace can migrate slots without loss; only the fields relevant to [kind] are serialized and shown in the inspector.

**Yapıcı Metotlar (Constructors):**
- `UmgSlot.fromJson(Map<String, dynamic> map)`: `UmgSlot.fromJson(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `kind` | `UmgSlotKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `anchorMin` | `Offset anchorMin` | `anchorMin` alanını (field/property) ve ilişkili veriyi saklar. |
| `anchorMax` | `Offset anchorMax` | `anchorMax` alanını (field/property) ve ilişkili veriyi saklar. |
| `position` | `Offset position` | `position` alanını (field/property) ve ilişkili veriyi saklar. |
| `size` | `Size size` | `size` alanını (field/property) ve ilişkili veriyi saklar. |
| `alignment` | `Offset alignment` | `alignment` alanını (field/property) ve ilişkili veriyi saklar. |
| `sizeToContent` | `bool sizeToContent` | `sizeToContent` alanını (field/property) ve ilişkili veriyi saklar. |
| `zOrder` | `int zOrder` | `zOrder` alanını (field/property) ve ilişkili veriyi saklar. |
| `paddingLeft` | `double paddingLeft` | `paddingLeft` alanını (field/property) ve ilişkili veriyi saklar. |
| `paddingTop` | `double paddingTop` | `paddingTop` alanını (field/property) ve ilişkili veriyi saklar. |
| `paddingRight` | `double paddingRight` | `paddingRight` alanını (field/property) ve ilişkili veriyi saklar. |
| `paddingBottom` | `double paddingBottom` | `paddingBottom` alanını (field/property) ve ilişkili veriyi saklar. |
| `fill` | `bool fill` | `fill` alanını (field/property) ve ilişkili veriyi saklar. |
| `flex` | `double flex` | `flex` alanını (field/property) ve ilişkili veriyi saklar. |
| `hAlign` | `UmgAlign hAlign` | `hAlign` alanını (field/property) ve ilişkili veriyi saklar. |
| `vAlign` | `UmgAlign vAlign` | `vAlign` alanını (field/property) ve ilişkili veriyi saklar. |
| `copy` | `UmgSlot copy() => UmgSlot.fromJson(toJson())` | `copy` işlemini gerçekleştirir. |
| `isStretchX` | `bool get isStretchX` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isStretchY` | `bool get isStretchY` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class UmgEvent`

A named event handler recorded on a node (`OnClicked` → `onClickedStartButton`).

**Yapıcı Metotlar (Constructors):**
- `UmgEvent.fromJson(Map<String, dynamic> map)`: `UmgEvent.fromJson(Map<String, dynamic> map)` nesnesini ilklendirir.
- `UmgEvent(name: map['name']?.toString() ?? '', handler: map['handler']?.toString() ?? '')`: `UmgEvent(name: map['name']?.toString() ?? '', handler: map['handler']?.toString() ?? '')` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `handler` | `String handler` | `handler` alanını (field/property) ve ilişkili veriyi saklar. |
| `regionTag` | `String get regionTag` | Snake-case tag used for the guarded user region in generated code. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class UmgNode`

One element of the widget tree.

**Yapıcı Metotlar (Constructors):**
- `UmgNode.fromJson(Map<String, dynamic> map)`: `UmgNode.fromJson(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `UmgWidgetType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `fieldName` | `String fieldName` | `fieldName` alanını (field/property) ve ilişkili veriyi saklar. |
| `slot` | `UmgSlot slot` | `slot` alanını (field/property) ve ilişkili veriyi saklar. |
| `props` | `Map<String, dynamic> props` | `props` alanını (field/property) ve ilişkili veriyi saklar. |
| `events` | `List<UmgEvent> events` | `events` alanını (field/property) ve ilişkili veriyi saklar. |
| `children` | `List<UmgNode> children` | `children` alanını (field/property) ve ilişkili veriyi saklar. |
| `deepCopy` | `UmgNode deepCopy() => UmgNode.fromJson(toJson())` | `deepCopy` işlemini gerçekleştirir. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `visit` | `void visit(void Function(UmgNode node, UmgNode? parent) fn, [UmgNode? pa...` | Depth-first walk, parents before children. |

### `class UmgNaming`

Dart-identifier naming helpers for element names.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `toFieldName` | `static String toFieldName(String display)` | `HealthBar Progress` → `healthBarProgress`; returns '' when nothing usable remains. |
| `isIdentifier` | `static bool isIdentifier(String s) => _identifier.hasMatch(s) && !_reser...` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toClassName` | `static String toClassName(String assetName)` | `WBP_PlayerHUD` → `WbpPlayerHUD` (the rule every code generator follows). |

### `enum UmgAnchorPreset`

Anchor presets of the 3×3 + stretch matrix.

**Yapıcı Metotlar (Constructors):**
- `UmgAnchorPreset(this.min, this.max)`: `UmgAnchorPreset(this.min, this.max)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fullStretch` | `fullStretch(Offset(0, 0), Offset(1, 1))` | `fullStretch` işlemini gerçekleştirir. |
| `min` | `Offset min` | `min` alanını (field/property) ve ilişkili veriyi saklar. |
| `max` | `Offset max` | `max` alanını (field/property) ve ilişkili veriyi saklar. |
| `alignment` | `Offset get alignment` | Alignment that keeps the pivot on the anchored corner/edge. |
| `label` | `String get label` | `label` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class UmgResolution`

Screen Resolution Simulator entries.

**Yapıcı Metotlar (Constructors):**
- `UmgResolution('1920x1080 Full HD', 1920, 1080)`: `UmgResolution('1920x1080 Full HD', 1920, 1080)` nesnesini ilklendirir.
- `UmgResolution('2560x1440 2K', 2560, 1440)`: `UmgResolution('2560x1440 2K', 2560, 1440)` nesnesini ilklendirir.
- `UmgResolution('3840x2160 4K UHD', 3840, 2160)`: `UmgResolution('3840x2160 4K UHD', 3840, 2160)` nesnesini ilklendirir.
- `UmgResolution('Mobile iPhone 15 Pro (393x852)', 393, 852)`: `UmgResolution('Mobile iPhone 15 Pro (393x852)', 393, 852)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `isCustom` | `bool isCustom` | `isCustom` alanını (field/property) ve ilişkili veriyi saklar. |
| `key` | `String get key` | `key` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `class UmgLayout`

Canvas-slot layout math shared by the designer canvas, the inspector and (as emitted source) the generated widget. Semantics: when an axis is not stretched, `position` is the pivot offset from the anchor point and `size` the extent; when stretched, `position` is the near margin and `size` the far margin.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `resolveCanvasRect` | `static Rect resolveCanvasRect(UmgSlot slot, Size parent)` | `resolveCanvasRect` işlemini gerçekleştirir. |
| `fitSlotToRect` | `static void fitSlotToRect(UmgSlot slot, Rect rect, Size parent)` | Rewrites `position`/`size` of [slot] so that it resolves to [rect] at [parent] with its current anchors/alignment. |
| `applyPreset` | `static void applyPreset(UmgSlot slot, UmgAnchorPreset preset, Size parent)` | Applies [preset] to [slot] keeping its resolved rect at [parent] unchanged. |
| `snap` | `static double snap(double v, double grid)` | `snap` işlemini gerçekleştirir. |

### `class UmgDocument`

The persisted designer document (`rawPayload` UTF-8 JSON of the WIDGET `.lmas`).

**Yapıcı Metotlar (Constructors):**
- `UmgDocument.createDefault()`: A new widget: one root Canvas Panel.
- `UmgDocument.fromJson(Map<String, dynamic> map)`: `UmgDocument.fromJson(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `root` | `UmgNode root` | `root` alanını (field/property) ve ilişkili veriyi saklar. |
| `designResolution` | `UmgResolution designResolution` | `designResolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `dpiScale` | `double dpiScale` | `dpiScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `logicalSize` | `Size get logicalSize` | `logicalSize` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `toFormattedJson` | `String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(t...` | `toFormattedJson` işlemini gerçekleştirir. |
| `deepCopy` | `UmgDocument deepCopy() => UmgDocument.fromJson(toJson())` | `deepCopy` işlemini gerçekleştirir. |
| `findNode` | `UmgNode? findNode(String id)` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `parentOf` | `UmgNode? parentOf(String id)` | `parentOf` işlemini gerçekleştirir. |
| `allNodes` | `List<UmgNode> get allNodes` | `allNodes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDescendant` | `bool isDescendant(String ancestorId, String id)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `lastRejectionReason` | `String? lastRejectionReason` | Attaches a detached [node] under [parentId]; returns the node, or null (with a reason in [lastRejectionReason]) when the parent cannot take it. |
| `removeNode` | `bool removeNode(String id)` | Belirtilen `Node` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |

## `lib/ui/features/sub_editors/services/umg_widget_validator.dart`

### `abstract final class UmgWidgetValidator`

Checks a widget document against the project's widget library: a plain-Flutter game cannot import shadcn_flutter, so a shadcn component in such a project is an error naming the element.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `shadcnNodes` | `static List<UmgNode> shadcnNodes(UmgDocument doc)` | The shadcn components of [doc], parents before children. |
| `errors` | `static List<String> errors(UmgDocument doc, String library)` | One error per shadcn component when [library] is plain Flutter. |

## `lib/ui/features/sub_editors/services/widget_class_catalog.dart`

### `class WidgetClassCatalog`

The project's classes as the Blueprint type context needs them: every widget `.lmas` under `contents/` as a [LuminaBlueprintWidgetClass] (its designer elements become `Get <Element>` rows and `Widget:<name>` pin classes), and every actor Blueprint's parent class for assignability up the chain. Read from disk, refreshed on [AssetRepository.onAssetsChanged] (the UMG editor saved → the next palette open sees the new element), and registered into [LuminaWidgetClassRegistry] when Play starts.

**Yapıcı Metotlar (Constructors):**

- `WidgetClassCatalog(this.projectDir, {bool watch = true})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `widgetClasses` | `List<LuminaBlueprintWidgetClass> get widgetClasses` | The widget classes on disk, by name. |
| `actorParents` | `Map<String, String> get actorParents` | Project Blueprint class → its parent class (`BP_Door` → `LuminaActor`). |
| `widgetClass` | `LuminaBlueprintWidgetClass? widgetClass(String? name)` |  |
| `refresh` | `void refresh()` | Re-reads the project; listeners are told when anything changed. |
| `registerRuntimeClasses` | `void registerRuntimeClasses()` | Makes every widget class of this project known to the runtime (`Create Widget` seeds per-element state from it). |
| `scanWidgetClasses` | `static List<LuminaBlueprintWidgetClass> scanWidgetClasses(String projectDir)` | Every widget Blueprint under `contents/` of [projectDir], sorted by name: found through the project's asset index, so only the widget `.lmas` files are read. |
| `readWidgetClass` | `static LuminaBlueprintWidgetClass? readWidgetClass(File file)` | The widget class stored in the widget `.lmas` [file], or null when the file is not a widget Blueprint (or cannot be read). |
| `fromUmgDocument` | `static LuminaBlueprintWidgetClass fromUmgDocument(String name, UmgDocument doc)` | [doc] as the engine sees it: one element per designer widget below the root, typed by its `UmgWidgetType` name and seeded with its stored properties. |
| `scanActorParents` | `static Map<String, String> scanActorParents(String projectDir)` | Every actor Blueprint under `contents/blueprints/` → its parent class, from the asset index's summaries (the Blueprint document's `parentClass`, else `metadata.parent_class`). |

## `lib/ui/features/sub_editors/views/umg/umg_components.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `umgContainerStyle` | `LuminaUmgContainerStyle umgContainerStyle(Map<String, dynamic> props, Map<String, Object?>? element)` | How the designer canvas and [UmgRuntimeView] draw a Container and the shadcn components, from the designer props under the runtime element state, exactly as the generated widget does. The Container style of [props] (designer) under [element] (runtime). |
| `umgContainer` | `Widget umgContainer(UmgNode node, Map<String, Object?>? element, {ImageProvider? image, Widget? child})` | A Container element: Flutter's `Container` via [LuminaUmgContainer]. |
| `umgItems` | `List<String> umgItems(Object? v)` | The comma-separated options / items of a component. |
| `umgRequiresShadcn` | `Widget umgRequiresShadcn(UmgNode node)` | What a plain-Flutter project shows instead of a shadcn component: the game cannot import shadcn_flutter. |
| `umgShadcnValueKey` | `({String runtime, String designer})? umgShadcnValueKey(UmgWidgetType type)` | The runtime key a component's value is written under (the key the element nodes it shares read), and the designer key it was seeded from. |
| `umgShadcnComponent` | `Widget umgShadcnComponent(UmgNode node, Map<String, Object?>? element, {List<Widget> children = const [], void...` | A shadcn component of [node]: [element] is its runtime state (null in the designer), [children] its built children (a Card's / Tooltip's content, the pages of Tabs, the item contents of an Accordion). [onChanged] gets the new value of an interactive component, [onPressed] a button press. |

## `lib/ui/features/sub_editors/views/umg/umg_runtime_view.dart`

### `class UmgRuntimeView`

Renders a [UmgDocument] using real shadcn_flutter widgets and layout. Used by the Play-In-Editor (PIE) viewport overlay and widget previews.

[runtimeValues] is the widget instance map `Create Widget` built: every designer element is wrapped in a [LuminaUmgElement] and reads its live state (`elements[<name>]`) through [LuminaUmgElementBinding], exactly as the generated widget classes do, so a `Set Text (Text)` on one Text block rebuilds only that block. The instance's legacy top-level `text` / `percent` (the deprecated `Set Text (Widget)` / `Set Percent (Widget)`) still apply to elements without their own state.

**Yapıcı Metotlar (Constructors):**

- `const UmgRuntimeView({super.key, required this.document, this.runtimeValues, this.textureBytes, this.onAction, this.plainLibrary = false,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `document` | `final UmgDocument document` |  |
| `runtimeValues` | `final Map<String, Object?>? runtimeValues` |  |
| `textureBytes` | `final Map<String, Uint8List>? textureBytes` |  |
| `onAction` | `final void Function(String nodeId, String action)? onAction` |  |
| `plainLibrary` | `final bool plainLibrary` | The project uses plain Flutter widgets: shadcn components show the "requires the shadcn widget library" placeholder, as the built game cannot render them. |

## `lib/ui/features/sub_editors/views/umg/umg_text_style.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `umgTextStyle` | `TextStyle umgTextStyle(Map<String, dynamic> props, Map<String, Object?>? element, {bool outlineRing = false})` | The text look of a designer element, shared by the designer canvas and [UmgRuntimeView] so both draw what the generated widget draws: font size, colour and drop shadow from the designer [props], each overridden by the runtime element state [element] (what the Blueprint element nodes wrote; null in the designer). |
| `umgTextShadow` | `LuminaUmgTextShadow umgTextShadow(Map<String, dynamic> props, Map<String, Object?>? element)` | The drop shadow of [props] under the runtime [element]'s overrides. |
| `umgTextOutline` | `LuminaUmgTextOutline umgTextOutline(Map<String, dynamic> props, Map<String, Object?>? element)` | The outline of [props] under the runtime [element]'s overrides. |
| `umgText` | `Widget umgText(String text, Map<String, dynamic> props, Map<String, Object?>? element)` | A text of a designer element: [umgTextStyle] plus its outline drawn as a stroked layer under the fill ([LuminaUmgText], the widget the generated code uses too). |

---

[Önceki: Texture editörü](texture.md) | [Üst: Alt editörler](index.md)
