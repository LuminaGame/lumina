[Türkçe](../../tr/lumina_ui/core.md)

# App shell and shared UI

The shared core of Lumina Studio: the app entry point, the built-in editor plugin and the plugin extension registry, editor services for sky and environment, the editor theme, the property editor widgets used by every details panel, the quality settings popover, the generated plugin registrar and the editor's `SmokeArtifacts`. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

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

`LuminaStudioApp`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/built_in_editor_plugin.dart`

### `class BuiltInEditorPlugin`

`BuiltInEditorPlugin`: `class` representing the data model or functionality of the module.

**Constructors:**
- `BuiltInEditorPlugin(this.viewModel)`: Initializes `BuiltInEditorPlugin(this.viewModel)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `pluginName` | `String get pluginName` | Getter accessor returning the current value of `pluginName`. |
| `register` | `void register(LuminaEditorContext context)` | Registers the plugin with the editor context (`LuminaEditorContext`) and exposes its features. |
| `unregister` | `void unregister(LuminaEditorContext context)` | Unregisters UI extensions and clears listeners when the plugin is unloaded or disabled. |

## `lib/ui/core/plugin_extension_registry.dart`

### `class PluginExtensionRegistry`

`PluginExtensionRegistry`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `logger` | `EngineLoggerService logger` | Holds the `logger` property or configuration state. |
| `beginRegistration` | `void beginRegistration(String pluginName)` | Executes `beginRegistration` operation. |
| `endRegistration` | `void endRegistration()` | Executes `endRegistration` operation. |
| `registerMenuItem` | `void registerMenuItem(String menuPath, EditorCommand command)` | Registers a new menu item and its trigger command to the main menu bar. |
| `registerToolbarButton` | `void registerToolbarButton(EditorToolbarButton button)` | Adds a new action button to the editor main toolbar. |
| `registerPanel` | `void registerPanel(EditorPanelDescriptor panel)` | Registers a dockable editor panel to the workspace. |
| `registerAssetType` | `void registerAssetType(EditorAssetTypeHandler handler)` | Registers a custom asset type handler, icon, and sub-editor factory to the engine. |
| `registerImporter` | `void registerImporter(EditorImporter importer)` | Binds a custom asset importer for specified file extensions. |
| `registerDetailsCustomization` | `void registerDetailsCustomization(DetailsCustomization c)` | Registers a custom Details inspector UI section for a target type. |
| `registerConsoleCommand` | `void registerConsoleCommand(String name, String help, void Function(List...` | Registers a CLI console command and help text to the Output Log terminal. |
| `allMenuCommands` | `List<MapEntry<String, EditorCommand>> get allMenuCommands` | Getter accessor returning the current value of `allMenuCommands`. |
| `allToolbarButtons` | `List<EditorToolbarButton> get allToolbarButtons` | Getter accessor returning the current value of `allToolbarButtons`. |
| `allPanels` | `List<EditorPanelDescriptor> get allPanels` | Getter accessor returning the current value of `allPanels`. |
| `allAssetTypes` | `List<EditorAssetTypeHandler> get allAssetTypes` | Getter accessor returning the current value of `allAssetTypes`. |
| `allImporters` | `List<EditorImporter> get allImporters` | Getter accessor returning the current value of `allImporters`. |
| `allDetailsCustomizations` | `List<DetailsCustomization> get allDetailsCustomizations` | Getter accessor returning the current value of `allDetailsCustomizations`. |
| `allConsoleCommands` | `Map<String, _ConsoleCommand> get allConsoleCommands` | Getter accessor returning the current value of `allConsoleCommands`. |

### `class _ConsoleCommand`

`_ConsoleCommand`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_ConsoleCommand(this.help, this.handler)`: Initializes `_ConsoleCommand(this.help, this.handler)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `help` | `String help` | Holds the `help` property or configuration state. |

## `lib/ui/core/services/editor_procedural_sky.dart`

### `class EditorProceduralSky`

Owns the Procedural Sky & Ocean of one Lumina Studio viewport.  The editor viewports render a bare Filament scene rather than a [LuminaWorld], so they cannot register a [LuminaProceduralSkyComponent]. This service is the bridge: it finds the level's `ProceduralSky` actor, turns its component properties into a [LuminaProceduralSkyDescription] and hands it to lumina's [LuminaProceduralSkyBinding] — the same binding the component itself drives at runtime, so the editor and the shipped game cannot render different skies.  It is the sibling of [EditorSceneEnvironment], which does the same for the `Environment` actor's skybox and image-based lighting. The two coexist on purpose: the procedural sky is a renderable with `depthWrite: false` and lights nothing, so a level wanting both a moving sky and lit meshes needs both actors.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `projectDirPath` | `String? projectDirPath` | Absolute path of the open project, used to resolve relative HDRI paths. |
| `showSkyBackground` | `bool showSkyBackground` | Whether this viewport draws the level's sky background. Sub-editor previews leave it off: they keep the neutral editor backdrop (so the grid, gizmos and HUD stay readable) but still take the ambient light. |
| `isAttached` | `bool get isAttached` | Checks current state or capability and returns a boolean value. |
| `description` | `LuminaSkyDescription get description` | The description currently pushed to the scene. |
| `cachedDefaultIbl` | `static Uint8List? get cachedDefaultIbl` | The bundled fallback IBL, once [ensureAssetsLoaded] has completed. |
| `ensureAssetsLoaded` | `static Future<Uint8List?> ensureAssetsLoaded()` | Reads the bundled fallback IBL cubemap (once per process). |
| `attach` | `void attach(FilamentEngine engine, FilamentScene scene)` | Attaches to a live engine + scene and immediately binds the current description, so the very first rendered frame is already lit. |
| `apply` | `void apply(LuminaSkyDescription description)` | Pushes [description] onto the scene. Cheap and idempotent: only the parts that actually changed are rebuilt, so the Details panel can call it on every keystroke. |
| `detach` | `void detach()` | Removes the sky and ambient light from the scene. |

## `lib/ui/core/theme/editor_theme.dart`

### `class EditorColors`

Lumina Studio's palette. The design tokens are authored in OKLCH; these are those tokens converted to sRGB, keeping their names. The neutrals carry **no** hue, and the accent orange is `oklch(0.72 0.185 52)` rather than a pure `#FF8C00`.

**Constructors:**
- `EditorColors._()`: Initializes `EditorColors._()`.

### `class EditorTypography`

The sidebar surface is not part of this shadcn_flutter version's [ColorScheme]; the panels that need it read [EditorColors.sidebar]. The editor's type scale: every size is an explicit pixel value from the design, not a judgement call.

**Constructors:**
- `EditorTypography._()`: Initializes `EditorTypography._()`.

### `class EditorDensity`

The prototype's density, in logical pixels.  Tailwind's spacing step is 4 px, so `h-7` is 28, `h-6` is 24, `h-5.5` is 22 and `px-2` is an 8 px gutter. These are measurements off the prototype's markup, not preferences.

`inlineFieldHeight` (20) is the rendered height of a Details number field; the Mobility buttons use it. `chipButton` / `narrowChipButton` are the `ButtonDensity` (`px-2` / `px-1`) of a text button drawn at `chipHeight` (20): the Content Browser's filter chips, Show All, Import / New Asset / Refresh and the World Outliner's Add button. shadcn's `ButtonDensity.compact` has no padding, which left those buttons as tall as their label.

**Constructors:**
- `EditorDensity._()`: Initializes `EditorDensity._()`.

## `lib/ui/core/property_editors/asset_ref_field.dart`

### `class AssetRefField`

`AssetRefField`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isMixed` | `bool isMixed` | Holds the `isMixed` property or configuration state. |
| `value` | `Map<String, dynamic>? value` | Holds the `value` property or configuration state. |
| `slotName` | `String slotName` | Holds the `slotName` property or configuration state. |
| `assetType` | `String assetType` | Holds the `assetType` property or configuration state. |
| `onCommit` | `ValueChanged<Map<String, dynamic>?> onCommit` | Holds the `onCommit` property or configuration state. |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/property_editors/color_field.dart`

### `class ColorField`

`ColorField`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isMixed` | `bool isMixed` | Holds the `isMixed` property or configuration state. |
| `value` | `String value` | Holds the `value` property or configuration state. |
| `defaultValue` | `String defaultValue` | Holds the `defaultValue` property or configuration state. |
| `onChanged` | `ValueChanged<String> onChanged` | Holds the `onChanged` property or configuration state. |
| `onCommit` | `ValueChanged<String> onCommit` | Holds the `onCommit` property or configuration state. |
| `onReset` | `VoidCallback onReset` | Holds the `onReset` property or configuration state. |
| `createState` | `State<ColorField> createState() => _ColorFieldState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _ColorFieldState`

`_ColorFieldState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `didUpdateWidget` | `void didUpdateWidget(ColorField oldWidget)` | Executes `didUpdateWidget` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/property_editors/curve_field.dart`

### `class CurveField`

`CurveField`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `value` | `Map<String, dynamic> value` | Holds the `value` property or configuration state. |
| `onCommit` | `ValueChanged<Map<String, dynamic>> onCommit` | Holds the `onCommit` property or configuration state. |
| `createState` | `State<CurveField> createState() => _CurveFieldState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _CurveFieldState`

`_CurveFieldState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _CurveSparklinePainter`

`_CurveSparklinePainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `keys` | `List<dynamic> keys` | Holds the `keys` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _CurveSparklinePainter oldDelegate)` | Executes `shouldRepaint` operation. |

### `class _CurveEditorCanvas`

`_CurveEditorCanvas`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initialValue` | `Map<String, dynamic> initialValue` | Holds the `initialValue` property or configuration state. |
| `onCommit` | `ValueChanged<Map<String, dynamic>> onCommit` | Holds the `onCommit` property or configuration state. |
| `createState` | `State<_CurveEditorCanvas> createState() => _CurveEditorCanvasState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _CurveEditorCanvasState`

`_CurveEditorCanvasState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/property_editors/enum_field.dart`

### `class EnumField`

`EnumField`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isMixed` | `bool isMixed` | Holds the `isMixed` property or configuration state. |
| `value` | `String value` | Holds the `value` property or configuration state. |
| `enumValues` | `List<String> enumValues` | Holds the `enumValues` property or configuration state. |
| `onCommit` | `ValueChanged<String> onCommit` | Holds the `onCommit` property or configuration state. |
| `isRadioGroup` | `bool isRadioGroup` | Holds the `isRadioGroup` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/property_editors/rotation_row.dart`

### `class RotationRow`

`RotationRow`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `value` | `List<double> value` | Holds the `value` property or configuration state. |
| `onChanged` | `ValueChanged<List<double>> onChanged` | Holds the `onChanged` property or configuration state. |
| `onCommit` | `ValueChanged<List<double>> onCommit` | Holds the `onCommit` property or configuration state. |
| `onReset` | `VoidCallback onReset` | Holds the `onReset` property or configuration state. |
| `labelColors` | `List<Color> labelColors` | Passed straight through to the [VectorRow] this wraps. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/property_editors/scrub_numeric_field.dart`

### `class ScrubNumericField`

`ScrubNumericField`: `class` representing the data model or functionality of the module.

The axis letter (12 px column by default), the value and, when the value is not its default, a 12 px reset button each have their own slot. A value wider than the field is drawn shortened while the field is not edited or scrubbed (`fitValueText`: fewer decimals, then `12.8k` / `1.3M`) with the whole value in a tooltip; the controller's text, editing and commits always use the whole value.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isMixed` | `bool isMixed` | Holds the `isMixed` property or configuration state. |
| `value` | `double value` | Holds the `value` property or configuration state. |
| `defaultValue` | `double defaultValue` | Holds the `defaultValue` property or configuration state. |
| `unit` | `String? unit` | Holds the `unit` property or configuration state. |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `min` | `double? min` | Holds the `min` property or configuration state. |
| `max` | `double? max` | Holds the `max` property or configuration state. |
| `fractionDigits` | `int fractionDigits` | Holds the `fractionDigits` property or configuration state. |
| `labelWidth` | `double labelWidth` | Width of the label column. The default fits a single-letter axis label (`X`/`Y`/`Z`); panels with worded labels ("Position X") pass their own. |
| `labelColor` | `Color labelColor` | The colour of the label column. The editor's design paints a vector field's `X`/`Y`/`Z` in the transform axis colours, so a caller that knows it is editing an axis passes them; everything else keeps the muted foreground it shares with the other property labels. |
| `onChanged` | `ValueChanged<double> onChanged` | Holds the `onChanged` property or configuration state. |
| `onCommit` | `ValueChanged<double> onCommit` | Holds the `onCommit` property or configuration state. |
| `onReset` | `VoidCallback onReset` | Holds the `onReset` property or configuration state. |
| `createState` | `State<ScrubNumericField> createState() => _ScrubNumericFieldState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _ScrubNumericFieldState`

`_ScrubNumericFieldState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `didUpdateWidget` | `void didUpdateWidget(ScrubNumericField oldWidget)` | Executes `didUpdateWidget` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/property_editors/slider_field.dart`

### `class SliderField`

`SliderField`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `value` | `double value` | Holds the `value` property or configuration state. |
| `defaultValue` | `double defaultValue` | Holds the `defaultValue` property or configuration state. |
| `min` | `double min` | Holds the `min` property or configuration state. |
| `max` | `double max` | Holds the `max` property or configuration state. |
| `unit` | `String? unit` | Holds the `unit` property or configuration state. |
| `isMixed` | `bool isMixed` | Holds the `isMixed` property or configuration state. |
| `onChanged` | `ValueChanged<double> onChanged` | Holds the `onChanged` property or configuration state. |
| `onCommit` | `ValueChanged<double> onCommit` | Holds the `onCommit` property or configuration state. |
| `onReset` | `VoidCallback onReset` | Holds the `onReset` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/property_editors/vector_row.dart`

### `class VectorRow`

`VectorRow`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `value` | `List<double> value` | Holds the `value` property or configuration state. |
| `defaultValue` | `List<double> defaultValue` | Holds the `defaultValue` property or configuration state. |
| `onChanged` | `ValueChanged<List<double>> onChanged` | Holds the `onChanged` property or configuration state. |
| `onCommit` | `ValueChanged<List<double>> onCommit` | Holds the `onCommit` property or configuration state. |
| `onReset` | `VoidCallback onReset` | Holds the `onReset` property or configuration state. |
| `isMixedPerAxis` | `List<bool>? isMixedPerAxis` | Holds the `isMixedPerAxis` property or configuration state. |
| `labels` | `List<String> labels` | Holds the `labels` property or configuration state. |
| `labelColors` | `List<Color> labelColors` | One colour per component. The editor's design paints the axis letters of a transform field in the manipulator's own axis colours, so the default is exactly [EditorColors.axisX] / [EditorColors.axisY] / [EditorColors.axisZ], which are pinned to `FilamentTransformGizmo.defaultHandleColor`. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/core/widgets/rtx_settings_popover.dart`

### `enum RtxSettingsKind`

`dlss` or `rayTracing`: which of the two viewport HUD controls opened the popover.

### `class RtxSettingsPopover`

The settings behind the viewport's DLSS, FSR3 and RTX HUD buttons (next to the camera speed): the arrow of each button opens this popover for its kind. The FSR3 popover switches FSR3 upscaling, picks the quality preset (Ultra Performance to Native AA), the sharpness and frame generation (keys `fsr3_enabled`, `fsr3_quality_<name>`, `fsr3_sharpness`, `fsr3_frame_generation`). The DLSS popover switches DLSS Super Resolution and picks the NGX quality mode (Ultra Performance, Performance, Balanced, Quality, DLAA); the RTX popover switches ray tracing, ray-traced sun shadows and ReSTIR direct lighting and tunes the ReSTIR candidate and spatial sample counts. Every control changes the editor's per-user `EditorQualitySettings` through the view model, which the live viewport re-applies at once through `LuminaRtxController`. When the engine cannot do it (`supported` false) the header reads UNAVAILABLE and the choices are still kept.

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | The editor view model whose quality settings the controls change. |
| `kind` | `RtxSettingsKind kind` | DLSS, FSR3 or ray tracing. |
| `supported` | `bool supported` | Whether the live engine can do what this popover sets. |
| `onClose` | `VoidCallback onClose` | Closes the popover. |

## `lib/ui/core/services/crash_report.dart`

### `enum CrashReportKind`

`uncaught` (an error nobody handled while the editor ran) or `previousRun` (the last session ended without closing, found at the next launch); `wire` is the server spelling (`uncaught`, `previous_run`).

### `class CrashReport`

What the crash report screen shows and, when the user agrees, sends: the error text and stack trace, the release tag and commit, the editor version, `<os>-<arch>`, the OS version, the GPU in use, the Filament version, the open project's name and the tail of the editor log. Value object with `toJson` / `fromJson` (the file under `<data dir>/crashes/<id>.json`), `toSubmission(description, email, includeLog)` (the body of `POST /api/v1/crash-reports`) and `toText(...)` (what Copy puts on the clipboard); `sentId` once sent.

## `lib/ui/core/services/crash_reporter.dart`

### `class CrashReporter`

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `install` | `void install()` | Hooks `FlutterError.onError` and `PlatformDispatcher.onError` (the previous handlers still run) and makes this `CrashReporter.instance`. |
| `startSession` | `Future<CrashReport?> startSession()` | First reports the markers of sessions whose process is gone (`detectPreviousCrash`, the first report returned), prunes old per-process logs (the newest `keptLogs` stay, never one a marker points at), then writes this process's `crashes/session-<pid>.json` (session id, pid, start time, release, its log's path) and streams the engine log to `logs/editor-<pid>.log`. Markers and logs are per process because the launcher and the project editor it hands off to overlap for a moment. |
| `endSession` | `Future<void> endSession()` | The clean close: flushes the log and removes the marker. `editor_entry.dart` runs it from the window's close guard and from `EditorHandOff.beforeExit`, so restarts, hand-offs and Quit are clean closes too. `detachLog()` closes the log but keeps the marker. |
| `detectPreviousCrash` | `Future<CrashReport?> detectPreviousCrash()` | Every marker of another session whose process is not running (`isProcessRunning`: `tasklist` on Windows, `/proc` on Linux, `kill -0` elsewhere; a test injects `isProcessAlive`) means that session died: files a `previousRun` report with that session's log tail, deletes the marker and publishes the first report on `pending`. A marker whose process is alive (the launcher still running its exit hooks while the editor starts) is left alone. The pre-per-process `session.json` + `editor.log` pair is reported the same way. |
| `record` | `CrashReport? record(Object error, StackTrace? stack, {String? context})` | Files an `uncaught` report (with the in-memory log tail) and publishes it when nothing is pending; later errors are only filed. |
| `send` | `Future<CrashReportReceipt> send(CrashReport report, {String description, String email, bool includeLog})` | Posts the report to `serverUrl` (`MarketplaceClient.submitCrashReport`) and marks it sent. Nothing is sent without the user. |
| `pending`, `dismiss`, `filed`, `stored`, `fileOf`, `flush` | | The report the screen shows, hiding it (the file stays), the reports of this session, every report on disk, a report's file, and waiting for the file writes. |
| `dataDir`, `crashesDir`, `logsDir`, `logFile`, `sessionMarker`, `pid`, `serverUrl`, `projectName` | | Where it writes (`LuminaDataDir` by default; `logFile` and `sessionMarker` carry this process's `pid`, which a test may set), where it sends and the project named in reports. |

## `lib/ui/core/widgets/crash_report_view.dart`

### `class CrashReportOverlay`

Lays the crash report screen over the whole app while `reporter.pending` holds a report; the editor underneath keeps running. `editor_entry.dart` wraps the app in it.

### `class CrashReportView`

The crash report screen: the headline of the error, a description field (key `crash_description`), an optional contact e-mail (`crash_email`), the log checkbox (`crash_include_log`), a "What is sent" toggle showing the exact text (`crash_toggle_details`, `crash_details_text`), and the buttons Copy report (`crash_copy`), Don't send (`crash_dismiss`) and Send report (`crash_send`); after a send `crash_sent` and Continue (`crash_continue`), after a refused send `crash_send_error` with the file's path.

## `lib/ui/core/widgets/quality_settings_popover.dart`

### `class QualitySettingsPopover`

`QualitySettingsPopover`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback onClose` | Holds the `onClose` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _FeatureBtn`

`_FeatureBtn`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `active` | `bool active` | Holds the `active` property or configuration state. |
| `onTap` | `VoidCallback onTap` | Holds the `onTap` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/generated/plugin_registrar.dart`

Generated, not checked in: `PluginHostPatcherService.generateRegistrar` (lumina data layer) writes this file into each project's editor host.

**Top-level Functions:**

- **`void registerAllPlugins(LuminaEditorContext registry)`**: Executes `registerAllPlugins` operation.

**Top-level variables:** `kEnabledPlugins` (`List<LuminaEditorPlugin>`, one per enabled editor module, UI shells of isolated plugins included) and `kPluginProcesses` (`Map<String, LuminaPluginProcess Function()>`, the process part of every enabled plugin whose manifest says `"isolation": "process"`, by plugin name; the host main passes it to `runLuminaEditor` as `processes`).

---

[Previous: lumina_ui (Lumina Studio)](index.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: App shell and shared UI (continued, part 1)](core-continued.md)
