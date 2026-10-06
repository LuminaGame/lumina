[English](../../en/lumina_ui/core.md)

# Uygulama kabuğu ve ortak UI

Lumina Studio'nun ortak çekirdeği: uygulama giriş noktası, yerleşik editör eklentisi ve eklenti uzantı registry'si, sky ve çevre için editör servisleri, editör teması, tüm details panellerinin kullandığı property editor widget'ları, kalite ayarları popover'ı, üretilen plugin registrar ve editörün `SmokeArtifacts` sınıfı. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/main.dart`](#libmaindart)
- [`lib/ui/core/built_in_editor_plugin.dart`](#libuicorebuilt_in_editor_plugindart)
- [`lib/ui/core/plugin_extension_registry.dart`](#libuicoreplugin_extension_registrydart)
- [`lib/ui/core/services/editor_procedural_sky.dart`](#libuicoreserviceseditor_procedural_skydart)
- [`lib/ui/core/services/editor_scene_environment.dart`](#libuicoreserviceseditor_scene_environmentdart)
- [`lib/ui/core/theme/editor_theme.dart`](#libuicorethemeeditor_themedart)
- [`lib/ui/core/property_editors/asset_ref_field.dart`](#libuicoreproperty_editorsasset_ref_fielddart)
- [`lib/ui/core/property_editors/color_field.dart`](#libuicoreproperty_editorscolor_fielddart)
- [`lib/ui/core/property_editors/curve_field.dart`](#libuicoreproperty_editorscurve_fielddart)
- [`lib/ui/core/property_editors/enum_field.dart`](#libuicoreproperty_editorsenum_fielddart)
- [`lib/ui/core/property_editors/rotation_row.dart`](#libuicoreproperty_editorsrotation_rowdart)
- [`lib/ui/core/property_editors/scrub_numeric_field.dart`](#libuicoreproperty_editorsscrub_numeric_fielddart)
- [`lib/ui/core/property_editors/slider_field.dart`](#libuicoreproperty_editorsslider_fielddart)
- [`lib/ui/core/property_editors/vector_row.dart`](#libuicoreproperty_editorsvector_rowdart)
- [`lib/ui/core/widgets/quality_settings_popover.dart`](#libuicorewidgetsquality_settings_popoverdart)
- [`lib/ui/core/widgets/rtx_settings_popover.dart`](#libuicorewidgetsrtx_settings_popoverdart)
- [`lib/generated/plugin_registrar.dart`](#libgeneratedplugin_registrardart)

## `lib/main.dart`

### `class LuminaStudioApp`

`LuminaStudioApp`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/built_in_editor_plugin.dart`

### `class BuiltInEditorPlugin`

`BuiltInEditorPlugin`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `BuiltInEditorPlugin(this.viewModel)`: `BuiltInEditorPlugin(this.viewModel)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `pluginName` | `String get pluginName` | `pluginName` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `register` | `void register(LuminaEditorContext context)` | Eklentiyi editör bağlamına (`LuminaEditorContext`) kaydeder ve yeteneklerini tanıtır. |
| `unregister` | `void unregister(LuminaEditorContext context)` | Eklenti kaldırıldığında veya devre dışı bırakıldığında kayıtlı arayüz öğelerini temizler. |

## `lib/ui/core/plugin_extension_registry.dart`

### `class PluginExtensionRegistry`

`PluginExtensionRegistry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `logger` | `EngineLoggerService logger` | `logger` alanını (field/property) ve ilişkili veriyi saklar. |
| `beginRegistration` | `void beginRegistration(String pluginName)` | `beginRegistration` işlemini gerçekleştirir. |
| `endRegistration` | `void endRegistration()` | `endRegistration` işlemini gerçekleştirir. |
| `registerMenuItem` | `void registerMenuItem(String menuPath, EditorCommand command)` | Üst menüye yeni bir menü öğesi ve tetiklenecek komutu kaydeder. |
| `registerToolbarButton` | `void registerToolbarButton(EditorToolbarButton button)` | Editör ana araç çubuğuna yeni bir eylem butonu ekler. |
| `registerPanel` | `void registerPanel(EditorPanelDescriptor panel)` | Editör çalışma alanına dock edilebilir yeni bir panel tanıtır. |
| `registerAssetType` | `void registerAssetType(EditorAssetTypeHandler handler)` | Özel bir varlık türü işleyicisini, simgesini ve alt editörünü sisteme tanıtır. |
| `registerImporter` | `void registerImporter(EditorImporter importer)` | Belirli dosya uzantıları için varlık içe aktarma motoru bağlar. |
| `registerDetailsCustomization` | `void registerDetailsCustomization(DetailsCustomization c)` | Details panelinde hedef tür için özel UI alanları kaydeder. |
| `registerConsoleCommand` | `void registerConsoleCommand(String name, String help, void Function(List...` | Output Log konsoluna yeni bir CLI komutu ve yardım metni ekler. |
| `allMenuCommands` | `List<MapEntry<String, EditorCommand>> get allMenuCommands` | `allMenuCommands` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allToolbarButtons` | `List<EditorToolbarButton> get allToolbarButtons` | `allToolbarButtons` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allPanels` | `List<EditorPanelDescriptor> get allPanels` | `allPanels` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allAssetTypes` | `List<EditorAssetTypeHandler> get allAssetTypes` | `allAssetTypes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allImporters` | `List<EditorImporter> get allImporters` | `allImporters` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allDetailsCustomizations` | `List<DetailsCustomization> get allDetailsCustomizations` | `allDetailsCustomizations` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allConsoleCommands` | `Map<String, _ConsoleCommand> get allConsoleCommands` | `allConsoleCommands` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class _ConsoleCommand`

`_ConsoleCommand`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_ConsoleCommand(this.help, this.handler)`: `_ConsoleCommand(this.help, this.handler)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `help` | `String help` | `help` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/ui/core/services/editor_procedural_sky.dart`

### `class EditorProceduralSky`

Owns the Procedural Sky & Ocean of one Lumina Studio viewport.  The editor viewports render a bare Filament scene rather than a [LuminaWorld], so they cannot register a [LuminaProceduralSkyComponent]. This service is the bridge: it finds the level's `ProceduralSky` actor, turns its component properties into a [LuminaProceduralSkyDescription] and hands it to lumina's [LuminaProceduralSkyBinding] — the same binding the component itself drives at runtime, so the editor and the shipped game cannot render different skies.  It is the sibling of [EditorSceneEnvironment], which does the same for the `Environment` actor's skybox and image-based lighting. The two coexist on purpose: the procedural sky is a renderable with `depthWrite: false` and lights nothing, so a level wanting both a moving sky and lit meshes needs both actors.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isActive` | `bool get isActive` | Set while a level actually has a `ProceduralSky` actor. |
| `description` | `LuminaProceduralSkyDescription? get description` | The description currently pushed to the scene, if any. |
| `attach` | `void attach(FilamentEngine engine, FilamentScene scene)` | Remembers the engine and scene. Nothing is created until a level actually carries a `ProceduralSky` actor — an ordinary level pays nothing. |
| `actorIn` | `static EditorActorNode? actorIn(Iterable<EditorActorNode> actors)` | Finds the level's `ProceduralSky` actor, if it has one. |
| `describeLevel` | `static LuminaProceduralSkyDescription? describeLevel(Iterable<EditorActo...` | Builds the sky description for a level from its `ProceduralSky` actor.  Returns null when the level has no such actor — the common case, and the signal to tear the sky down. The outliner's eye toggle drives [EditorActorNode.isVisible], so hiding the actor hides the sky. |
| `apply` | `void apply(LuminaProceduralSkyDescription? description)` | Pushes [description] onto the scene, creating or destroying the binding as the level gains or loses its `ProceduralSky` actor.  Cheap and idempotent: an unchanged description does nothing, and a changed one is a uniform upload rather than a rebuild, so this is safe on every Details-panel keystroke. |
| `advance` | `double? advance(double deltaSeconds)` | Advances the day cycle by [deltaSeconds] and returns the new time of day, or null when there is nothing to advance.  The hour is deliberately *not* written back onto the actor: the level saves the authored `timeOfDay`, and the viewport just previews the cycle running from it. Writing every frame would mark the document dirty sixty times a second and fight auto-save. |

## `lib/ui/core/services/editor_scene_environment.dart`

### `class EditorSceneEnvironment`

Owns the sky background and the image-based lighting of one Lumina Studio Filament viewport (the level viewport and every sub-editor preview).  The editor viewports render a bare Filament scene rather than a [LuminaWorld], so they cannot register a [LuminaSkyComponent]. This service is the bridge: it resolves the level's `Environment` actor (or a sensible default), reads any HDRI off disk, and hands the result to lumina's [LuminaSkyBinding], which creates the real `Skybox` and `IndirectLight`.  ### Why every viewport gets image-based lighting, always  Before this existed the viewports had directional lights only. Filament's PBR shading takes its *ambient* diffuse and **all** of its ambient specular from an `IndirectLight`; with none bound, every surface the sun does not directly face resolves to near-black, which is why imported meshes showed up as black silhouettes. Measured on `Props/AC_units/roof_aircon_unit_150x150_a.glb`, the mean luminance of the mesh pixels went from 45.8 to 117.3 (/255) once an IBL was bound.  A solid-colour sky carries no reflection information and spherical harmonics alone give no specular ambient at all, so the service always falls back to a bundled neutral studio cubemap (`assets/ibl/default_env/default_env_ibl.ktx`, Filament's `default_env`) for lighting when the level has no HDRI of its own. It lights and reflects; it never replaces the level's own sky background.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `projectDirPath` | `String? projectDirPath` | Absolute path of the open project, used to resolve relative HDRI paths. |
| `showSkyBackground` | `bool showSkyBackground` | Whether this viewport draws the level's sky background. Sub-editor previews leave it off: they keep the neutral editor backdrop (so the grid, gizmos and HUD stay readable) but still take the ambient light. |
| `isAttached` | `bool get isAttached` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `description` | `LuminaSkyDescription get description` | The description currently pushed to the scene. |
| `cachedDefaultIbl` | `static Uint8List? get cachedDefaultIbl` | The bundled fallback IBL, once [ensureAssetsLoaded] has completed. |
| `ensureAssetsLoaded` | `static Future<Uint8List?> ensureAssetsLoaded()` | Reads the bundled fallback IBL cubemap (once per process). |
| `attach` | `void attach(FilamentEngine engine, FilamentScene scene)` | Attaches to a live engine + scene and immediately binds the current description, so the very first rendered frame is already lit. |
| `apply` | `void apply(LuminaSkyDescription description)` | Pushes [description] onto the scene. Cheap and idempotent: only the parts that actually changed are rebuilt, so the Details panel can call it on every keystroke. |
| `detach` | `void detach()` | Removes the sky and ambient light from the scene. |

## `lib/ui/core/theme/editor_theme.dart`

### `class EditorColors`

Lumina Studio's palette. The design tokens are authored in OKLCH; these are those tokens converted to sRGB, keeping their names. The neutrals carry **no** hue, and the accent orange is `oklch(0.72 0.185 52)` rather than a pure `#FF8C00`.

**Yapıcı Metotlar (Constructors):**
- `EditorColors._()`: `EditorColors._()` nesnesini ilklendirir.

### `class EditorTypography`

The sidebar surface is not part of this shadcn_flutter version's [ColorScheme]; the panels that need it read [EditorColors.sidebar]. The editor's type scale: every size is an explicit pixel value from the design, not a judgement call.

**Yapıcı Metotlar (Constructors):**
- `EditorTypography._()`: `EditorTypography._()` nesnesini ilklendirir.

### `class EditorDensity`

The prototype's density, in logical pixels.  Tailwind's spacing step is 4 px, so `h-7` is 28, `h-6` is 24, `h-5.5` is 22 and `px-2` is an 8 px gutter. These are measurements off the prototype's markup, not preferences.

`inlineFieldHeight` (20), Details panelindeki bir sayı alanının çizilen yüksekliğidir; Mobility düğmeleri bunu kullanır. `chipButton` / `narrowChipButton`, `chipHeight` (20) yüksekliğinde çizilen bir metin düğmesinin `ButtonDensity` değeridir (`px-2` / `px-1`): Content Browser'ın filtre çipleri, Show All, Import / New Asset / Refresh ve World Outliner'ın Add düğmesi. shadcn'in `ButtonDensity.compact` yoğunluğunda hiç dolgu yoktur; bu düğmeler etiketleri kadar alçak kalıyordu.

**Yapıcı Metotlar (Constructors):**
- `EditorDensity._()`: `EditorDensity._()` nesnesini ilklendirir.

## `lib/ui/core/property_editors/asset_ref_field.dart`

### `class AssetRefField`

`AssetRefField`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isMixed` | `bool isMixed` | `isMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `Map<String, dynamic>? value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `slotName` | `String slotName` | `slotName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetType` | `String assetType` | `assetType` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<Map<String, dynamic>?> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/property_editors/color_field.dart`

### `class ColorField`

`ColorField`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isMixed` | `bool isMixed` | `isMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `String value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultValue` | `String defaultValue` | `defaultValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `onChanged` | `ValueChanged<String> onChanged` | `onChanged` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<String> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `onReset` | `VoidCallback onReset` | `onReset` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<ColorField> createState() => _ColorFieldState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _ColorFieldState`

`_ColorFieldState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(ColorField oldWidget)` | `didUpdateWidget` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/property_editors/curve_field.dart`

### `class CurveField`

`CurveField`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `value` | `Map<String, dynamic> value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<Map<String, dynamic>> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<CurveField> createState() => _CurveFieldState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _CurveFieldState`

`_CurveFieldState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _CurveSparklinePainter`

`_CurveSparklinePainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `keys` | `List<dynamic> keys` | `keys` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _CurveSparklinePainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

### `class _CurveEditorCanvas`

`_CurveEditorCanvas`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initialValue` | `Map<String, dynamic> initialValue` | `initialValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<Map<String, dynamic>> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<_CurveEditorCanvas> createState() => _CurveEditorCanvasState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _CurveEditorCanvasState`

`_CurveEditorCanvasState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/property_editors/enum_field.dart`

### `class EnumField`

`EnumField`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isMixed` | `bool isMixed` | `isMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `String value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `enumValues` | `List<String> enumValues` | `enumValues` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<String> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `isRadioGroup` | `bool isRadioGroup` | `isRadioGroup` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/property_editors/rotation_row.dart`

### `class RotationRow`

`RotationRow`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `value` | `List<double> value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `onChanged` | `ValueChanged<List<double>> onChanged` | `onChanged` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<List<double>> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `onReset` | `VoidCallback onReset` | `onReset` alanını (field/property) ve ilişkili veriyi saklar. |
| `labelColors` | `List<Color> labelColors` | Passed straight through to the [VectorRow] this wraps. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/property_editors/scrub_numeric_field.dart`

### `class ScrubNumericField`

`ScrubNumericField`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

Eksen harfi (varsayılan 12 px sütun), değer ve değer varsayılanından farklıysa 12 px'lik sıfırlama düğmesi her biri kendi yerindedir. Alana sığmayan bir değer, alan düzenlenmez ya da sürüklenmezken kısaltılmış çizilir (`fitValueText`: daha az ondalık, sonra `12.8k` / `1.3M`); değerin tamamı ipucunda (tooltip) görünür. Denetleyicinin metni, düzenleme ve kaydetme her zaman tam değeri kullanır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isMixed` | `bool isMixed` | `isMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `double value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultValue` | `double defaultValue` | `defaultValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `unit` | `String? unit` | `unit` alanını (field/property) ve ilişkili veriyi saklar. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `min` | `double? min` | `min` alanını (field/property) ve ilişkili veriyi saklar. |
| `max` | `double? max` | `max` alanını (field/property) ve ilişkili veriyi saklar. |
| `fractionDigits` | `int fractionDigits` | `fractionDigits` alanını (field/property) ve ilişkili veriyi saklar. |
| `labelWidth` | `double labelWidth` | Width of the label column. The default fits a single-letter axis label (`X`/`Y`/`Z`); panels with worded labels ("Position X") pass their own. |
| `labelColor` | `Color labelColor` | The colour of the label column. The editor's design paints a vector field's `X`/`Y`/`Z` in the transform axis colours, so a caller that knows it is editing an axis passes them; everything else keeps the muted foreground it shares with the other property labels. |
| `onChanged` | `ValueChanged<double> onChanged` | `onChanged` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<double> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `onReset` | `VoidCallback onReset` | `onReset` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<ScrubNumericField> createState() => _ScrubNumericFieldState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _ScrubNumericFieldState`

`_ScrubNumericFieldState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(ScrubNumericField oldWidget)` | `didUpdateWidget` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/property_editors/slider_field.dart`

### `class SliderField`

`SliderField`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `value` | `double value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultValue` | `double defaultValue` | `defaultValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `min` | `double min` | `min` alanını (field/property) ve ilişkili veriyi saklar. |
| `max` | `double max` | `max` alanını (field/property) ve ilişkili veriyi saklar. |
| `unit` | `String? unit` | `unit` alanını (field/property) ve ilişkili veriyi saklar. |
| `isMixed` | `bool isMixed` | `isMixed` alanını (field/property) ve ilişkili veriyi saklar. |
| `onChanged` | `ValueChanged<double> onChanged` | `onChanged` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<double> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `onReset` | `VoidCallback onReset` | `onReset` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/property_editors/vector_row.dart`

### `class VectorRow`

`VectorRow`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `value` | `List<double> value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultValue` | `List<double> defaultValue` | `defaultValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `onChanged` | `ValueChanged<List<double>> onChanged` | `onChanged` alanını (field/property) ve ilişkili veriyi saklar. |
| `onCommit` | `ValueChanged<List<double>> onCommit` | `onCommit` alanını (field/property) ve ilişkili veriyi saklar. |
| `onReset` | `VoidCallback onReset` | `onReset` alanını (field/property) ve ilişkili veriyi saklar. |
| `isMixedPerAxis` | `List<bool>? isMixedPerAxis` | `isMixedPerAxis` alanını (field/property) ve ilişkili veriyi saklar. |
| `labels` | `List<String> labels` | `labels` alanını (field/property) ve ilişkili veriyi saklar. |
| `labelColors` | `List<Color> labelColors` | One colour per component. The editor's design paints the axis letters of a transform field in the manipulator's own axis colours, so the default is exactly [EditorColors.axisX] / [EditorColors.axisY] / [EditorColors.axisZ], which are pinned to `FilamentTransformGizmo.defaultHandleColor`. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/core/widgets/rtx_settings_popover.dart`

### `enum RtxSettingsKind`

`dlss` ya da `rayTracing`: popover'ı viewport HUD'undaki iki denetimden hangisi açtı.

### `class RtxSettingsPopover`

Viewport'un DLSS, FSR3 ve RTX HUD düğmelerinin (kamera hızının yanında) arkasındaki ayarlar: her düğmenin oku bu popover'ı kendi türü için açar. FSR3 popover'ı FSR3 büyütmeyi açıp kapatır, kalite ön ayarını (Ultra Performance'tan Native AA'ya), keskinliği ve kare üretimini seçer (anahtarlar `fsr3_enabled`, `fsr3_quality_<name>`, `fsr3_sharpness`, `fsr3_frame_generation`). DLSS popover'ı DLSS Super Resolution'ı açıp kapatır ve NGX kalite modunu seçer (Ultra Performance, Performance, Balanced, Quality, DLAA); RTX popover'ı ışın izlemeyi, ışın izlemeli güneş gölgelerini ve ReSTIR doğrudan aydınlatmayı açıp kapatır, ReSTIR aday ve uzamsal örnek sayılarını ayarlar. Her denetim editörün kullanıcı başına `EditorQualitySettings` değerini view model üzerinden değiştirir; canlı viewport bunu `LuminaRtxController` ile hemen uygular. Motor bunu yapamıyorsa (`supported` false) başlık UNAVAILABLE yazar ve seçimler yine saklanır.

| Metot / Getter | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Denetimlerin kalite ayarlarını değiştirdiği editör view model'i. |
| `kind` | `RtxSettingsKind kind` | DLSS, FSR3 ya da ışın izleme. |
| `supported` | `bool supported` | Canlı motorun bu popover'ın ayarladığını yapıp yapamadığı. |
| `onClose` | `VoidCallback onClose` | Popover'ı kapatır. |

## `lib/ui/core/widgets/quality_settings_popover.dart`

### `class QualitySettingsPopover`

`QualitySettingsPopover`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _FeatureBtn`

`_FeatureBtn`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `active` | `bool active` | `active` alanını (field/property) ve ilişkili veriyi saklar. |
| `onTap` | `VoidCallback onTap` | `onTap` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/generated/plugin_registrar.dart`

Üretilen bir dosyadır, repoda yer almaz: `PluginHostPatcherService.generateRegistrar` (lumina veri katmanı) bu dosyayı her projenin editor host'una yazar.

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`void registerAllPlugins(LuminaEditorContext registry)`**: `registerAllPlugins` işlemini gerçekleştirir.

---

[Önceki: lumina_ui (Lumina Studio)](index.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Uygulama kabuğu ve ortak UI (devamı, bölüm 1)](core-continued.md)
