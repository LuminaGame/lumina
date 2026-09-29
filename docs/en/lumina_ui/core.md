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

---

[Previous: lumina_ui (Lumina Studio)](index.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: App shell and shared UI (continued, part 1)](core-continued.md)
