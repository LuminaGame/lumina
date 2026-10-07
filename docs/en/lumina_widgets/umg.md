[Türkçe](../../tr/lumina_widgets/umg.md)

# Game UI widgets (UMG runtime)

The runtime side of game UI: the plain Flutter widgets that compiled widget assets are built from (buttons, sliders, text, containers and more), the bindings that connect a widget instance's per-element state to those widgets, and the widget layer that shows a world's widgets over the game view. The user widget a Widget Blueprint graph runs on is engine code ([lumina: user widgets](../lumina/user-widgets.md)); the world's widget list is the engine's `LuminaWidgetSubsystem.activeWidgets`, an `ObservableValue` the layer listens to. File paths are relative to the `lumina_widgets/` package directory.

**On this page:**

- [`lib/src/umg/element_binding.dart`](#libsrcumgelement_bindingdart)
- [`lib/src/umg/umg_widgets.dart`](#libsrcumgumg_widgetsdart)
- [`lib/src/umg/umg_media_widgets.dart`](#libsrcumgumg_media_widgetsdart)
- [`lib/src/umg/widget_layer.dart`](#libsrcumgwidget_layerdart)
- [`lib/src/umg/theme_document_colors.dart`](#libsrcumgtheme_document_colorsdart)

## `lib/src/umg/element_binding.dart`

### `abstract final class LuminaUmgElementBinding`

Reads and watches the per-element runtime state of a widget instance. A widget instance is the JSON-plain map `Create Widget` builds: `{'class', 'owner', 'inViewport', 'zOrder', 'visibility', 'elements': {name: {'type', 'name', 'visibility', 'isEnabled', 'renderOpacity', ...designer props, ...values the element nodes wrote}}}` (the placeholder in angle brackets is the element name).

The element setters (`Set Text (Text)`, `Set Percent`, …) write into that map and call [LuminaWidgetSubsystem.notifyChanged]; a [LuminaWidgetLayer] turns that into a [LuminaUmgInstanceBinding] refresh, and every [LuminaUmgElement] bound to the instance rebuilds only when its own element's state changed.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `designerKeys` | `static const Map<String, String> designerKeys` | Runtime keys the element nodes write, and the designer key the same value was seeded under (`Set Is Checked` writes `isChecked`, the designer stored `checked`). A read of the runtime key falls back to the designer key. The text shadow and outline keys (`shadowEnabled`, `shadowColor`, `shadowOffsetX`, `shadowOffsetY`, `shadowBlur`, `outlineSize`, `outlineColor`) are the same in both, so they need no entry. |
| `elements` | `static Map<String, Object?>? elements(Map<String, Object?>? instance)` | The elements map of [instance], or null. |
| `element` | `static Map<String, Object?>? element(Map<String, Object?>? instance, String elementName)` | The state map of element [elementName] of [instance], or null when the instance has no such element (an unregistered class, or a stale name). |
| `elementValue` | `static T elementValue<T>(Map<String, Object?>? instance, String elementName, String key, T fallback)` | `instance.elements[elementName][key]` as a [T], or [fallback] (the designer's value the generated code carries) when the element or the key is missing or of another type. Numbers coerce between `int` and `double`. |
| `value` | `static T value<T>(Map<String, Object?>? element, String key, T fallback)` | [elementValue] on an element state map that was already looked up. |
| `color` | `static Color color(Map<String, Object?>? element, String key, Color fallback)` | A colour of [element]: `[r, g, b, a]` (0–1, what `Set Color and Opacity` writes), a `#RRGGBB` / `#RRGGBBAA` string (what the designer stored), or [fallback]. |
| `parseColor` | `static Color? parseColor(Object? v)` | [color] as `Color?`: null when nothing usable is stored. `#RRGGBB`, or `#RRGGBBAA` with the alpha last (the Blueprint colour literal's order). |
| `edgeInsets` | `static EdgeInsets edgeInsets(Map<String, Object?>? element, String key, EdgeInsets fallback)` | Padding / margin of [element] under [key] (a number or `[l, t, r, b]`, what `Set Padding` writes), or [fallback]. |
| `borderRadius` | `static BorderRadius borderRadius(Map<String, Object?>? element, String key, BorderRadius fallback)` | Corner radius of [element] under [key] (a number, what `Set Corner Radius` writes, or `[tl, tr, br, bl]`), or [fallback]. |
| `containerStyle` | `static LuminaUmgContainerStyle containerStyle(Map<String, Object?>? element, LuminaUmgContainerStyle fallback)` | The Container style of [element]: every Container key the element state holds (`backgroundColor`, `gradient`, `borderColor`, `borderWidth`, `borderSides`, `cornerRadius`, `padding`, `margin`, `shadows`, sizes, `alignment`, `backgroundFit`) over [fallback], the designer's style the generated code carries. |
| `shadow` | `static LuminaUmgTextShadow shadow(Map<String, Object?>? element, LuminaUmgTextShadow fallback)` | The drop shadow of a text-bearing element: each of `shadowEnabled`, `shadowColor`, `shadowOffsetX`, `shadowOffsetY` and `shadowBlur` [element] holds overrides [fallback] (the designer's shadow, which the generated code carries). |
| `outline` | `static LuminaUmgTextOutline outline(Map<String, Object?>? element, LuminaUmgTextOutline fallback)` | The outline of a text-bearing element: `outlineSize` and `outlineColor` of [element] override [fallback]. |
| `options` | `static List<String> options(Map<String, Object?>? element, List<String> fallback)` | The options of a Combo Box element: a list (what `Add Option` writes) or the designer's comma-separated string. |
| `visibility` | `static String visibility(Map<String, Object?>? element)` | `Visible` / `Hidden` / `Collapsed` (with `HitTestInvisible` / `SelfHitTestInvisible` rendering as visible). |
| `isVisible` | `static bool isVisible(Map<String, Object?>? element)` |  |
| `isEnabled` | `static bool isEnabled(Map<String, Object?>? element)` |  |
| `renderOpacity` | `static double renderOpacity(Map<String, Object?>? element)` |  |
| `write` | `static bool write(Map<String, Object?>? instance, String elementName, String key, Object? newValue)` | Writes [key] of element [elementName] (what an interactive widget does when the player moves a slider or types), so `Get Slider Value` and friends read what is on screen. Creates the element state when the instance has none for that name. Returns false without an instance. |
| `maybeOf` | `static LuminaUmgInstanceBinding? maybeOf(BuildContext context)` | The binding of the instance a [LuminaWidgetLayer] is rendering above [context], or null outside a layer (a designer preview, a bare test). Does not register a dependency: elements subscribe themselves. |

### `class LuminaUmgInstanceBinding`

One widget instance as a [ValueListenable]: [value] is the instance map itself (mutated in place by the element nodes) and [refresh] is what the [LuminaWidgetLayer] calls when the widget subsystem notified.

**Constructors:**

- `LuminaUmgInstanceBinding(this.instance)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `instance` | `final Map<String, Object?> instance` |  |
| `refresh` | `void refresh()` | Tells every bound element to compare its state and rebuild if it changed. |

### `class LuminaUmgInstanceScope`

Makes a [LuminaUmgInstanceBinding] available to the compiled widget class built for that instance.

**Constructors:**

- `const LuminaUmgInstanceScope({super.key, required this.binding, required super.child})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `binding` | `final LuminaUmgInstanceBinding binding` |  |

### `class LuminaUmgElement`

Builds the state of one element of [instance], rebuilding only when that element's state changed, and applying the common element properties: `Collapsed` takes the element out of layout, `Hidden` keeps its space, `renderOpacity` below 1 draws it through an [Opacity], and a disabled element ignores pointers and is dimmed.

Generated widget classes (umg_widget_codegen) wrap every designer element in one of these; without an [instance] (a preview) the builder sees `null` and the designer's defaults apply.

**Constructors:**

- `const LuminaUmgElement({super.key, required this.instance, required this.name, required this.builder,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `instance` | `final Map<String, Object?>? instance` |  |
| `name` | `final String name` |  |
| `builder` | `final Widget Function(BuildContext context, Map<String, Object?>? element) builder` |  |

## `lib/src/umg/umg_widgets.dart`

### `abstract final class LuminaUmgColors`

The UMG widgets a game uses when its project picks plain Flutter widgets: built from `package:flutter/widgets.dart` alone, so a game needs no Material and no shadcn_flutter, and they compile for the web. The UMG codegen and the designer preview both use them.

The look follows a dark neutral palette close to shadcn's, so a menu reads the same whichever library the project picked.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `foreground` | `static const Color foreground` |  |
| `muted` | `static const Color muted` |  |
| `surface` | `static const Color surface` |  |
| `raised` | `static const Color raised` |  |
| `border` | `static const Color border` |  |
| `destructive` | `static const Color destructive` |  |
| `primary` | `static const Color primary` | Primary buttons: saturated enough for the designer's default white label. |

### `enum LuminaUmgButtonStyle`

The five button styles the UMG designer offers.

**Values:**

- `primary`
- `secondary`
- `outline`
- `ghost`
- `destructive`

### `class LuminaUmgButton`

A clickable button with hover reporting (UMG `OnClicked` / `OnHovered` / `OnUnhovered`). Without [onPressed] it is disabled.

**Constructors:**

- `const LuminaUmgButton({super.key, this.style = LuminaUmgButtonStyle.primary, this.onPressed, this.onHovered, required this.child,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `style` | `final LuminaUmgButtonStyle style` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `onHovered` | `final ValueChanged<bool>? onHovered` | `true` when the pointer enters, `false` when it leaves. |
| `child` | `final Widget child` |  |

### `class LuminaUmgSlider`

A horizontal slider: tap or drag anywhere on the track (UMG `OnValueChanged`).

**Constructors:**

- `const LuminaUmgSlider({super.key, required this.value, this.onChanged, this.min = 0, this.max = 1, this.color})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `value` | `final double value` |  |
| `onChanged` | `final ValueChanged<double>? onChanged` |  |
| `min` | `final double min` |  |
| `max` | `final double max` |  |
| `color` | `final Color? color` |  |

### `class LuminaUmgCheckbox`

A check box with an optional label; tapping either toggles it (UMG `OnCheckStateChanged`).

**Constructors:**

- `const LuminaUmgCheckbox({super.key, required this.value, this.onChanged, this.label})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `value` | `final bool value` |  |
| `onChanged` | `final ValueChanged<bool>? onChanged` |  |
| `label` | `final Widget? label` |  |

### `class LuminaUmgTextField`

A single-line text input with a placeholder (UMG Editable Text, `OnTextChanged`).

**Constructors:**

- `const LuminaUmgTextField({super.key, this.initialValue, this.placeholder, this.style, this.onChanged, this.onSubmitted})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `initialValue` | `final String? initialValue` |  |
| `placeholder` | `final String? placeholder` |  |
| `style` | `final TextStyle? style` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onSubmitted` | `final ValueChanged<String>? onSubmitted` | Enter pressed (a widget graph's On Text Committed). |

### `class LuminaUmgComboBox`

A drop-down of string options (UMG Combo Box, `OnSelectionChanged`). The list opens in the nearest [Overlay], which every game app has.

**Constructors:**

- `const LuminaUmgComboBox({super.key, required this.value, required this.options, this.onChanged, this.placeholder, this.style, this.outline = LuminaUmgTextOutlin...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `value` | `final String? value` |  |
| `options` | `final List<String> options` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `placeholder` | `final String? placeholder` |  |
| `style` | `final TextStyle? style` | Merged over the default label style (font size, colour, shadow). |
| `outline` | `final LuminaUmgTextOutline outline` | The outline of the selected label. |

### `class LuminaUmgProgressBar`

A horizontal progress bar; [progress] is clamped to 0..1 (UMG Progress Bar `Percent`).

**Constructors:**

- `const LuminaUmgProgressBar({super.key, required this.progress, this.color, this.trackColor})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fillKey` | `static const Key fillKey` | Key of the filled part, for tests and tools that measure it. |
| `progress` | `final double progress` |  |
| `color` | `final Color? color` |  |
| `trackColor` | `final Color? trackColor` |  |

### `class LuminaUmgSkeleton`

A loading placeholder (the shadcn Skeleton component): [lines] stretched rows of [text], each drawn as a rounded bone over the text's own line boxes, so the placeholder takes the space the text would. The bones pulse between 5 % and 10 % of [color]'s alpha over [duration], back and forth (shadcn passes its primary colour).

**Constructors:**

- `const LuminaUmgSkeleton({super.key, this.lines = 3, this.text = 'Loading placeholder text line', this.color = LuminaUmgColors.foreground, this.duration = const Duration(seconds: 1)})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `lines` | `final int lines` |  |
| `text` | `final String text` |  |
| `color` | `final Color color` |  |
| `duration` | `final Duration duration` | One pulse, from the faint to the strong colour. |

### `class LuminaUmgBorder`

A filled, rounded panel around one child (UMG Border).

**Constructors:**

- `const LuminaUmgBorder({super.key, this.color, this.padding = EdgeInsets.zero, this.radius = 6, this.child})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `color` | `final Color? color` |  |
| `padding` | `final EdgeInsetsGeometry padding` |  |
| `radius` | `final double radius` |  |
| `child` | `final Widget? child` |  |

### `class LuminaUmgTextShadow`

The drop shadow of a text-bearing UMG element (Shadow Offset / Shadow Color): stored under `shadowEnabled`, `shadowColor` (`#RRGGBBAA`, or the `[r, g, b, a]` the Blueprint nodes write), `shadowOffsetX` / `shadowOffsetY` and `shadowBlur` (design px).

**Constructors:**

- `const LuminaUmgTextShadow({this.enabled = false, this.color = const Color(0xB3000000), this.offsetX = 1.0, this.offsetY = 1.0, this.blur = 0.0,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `defaults` | `static const LuminaUmgTextShadow defaults` | The designer's defaults: off, 70 % black, (1, 1), sharp. |
| `enabled` | `final bool enabled` |  |
| `color` | `final Color color` |  |
| `offsetX` | `final double offsetX` |  |
| `offsetY` | `final double offsetY` |  |
| `blur` | `final double blur` |  |
| `shadows` | `List<Shadow> get shadows` | The shadows a [TextStyle] draws: none while disabled or fully transparent. |

### `class LuminaUmgTextOutline`

The outline of a text-bearing UMG element (Font Outline Settings): `outlineSize` in design px (0 = off) and `outlineColor`.

**Constructors:**

- `const LuminaUmgTextOutline({this.size = 0.0, this.color = const Color(0xFF000000)})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `defaults` | `static const LuminaUmgTextOutline defaults` | The designer's defaults: no outline, opaque black. |
| `size` | `final double size` |  |
| `color` | `final Color color` |  |
| `isVisible` | `bool get isVisible` |  |
| `strokePaint` | `Paint get strokePaint` | The stroke painted under the fill: a centred stroke of twice [size] shows [size] px outside the glyph. |
| `ringShadows` | `List<Shadow> get ringShadows` | The outline as eight sharp shadows around the glyphs, for text a second layer cannot sit under (an editable field). |

### `class LuminaUmgText`

A UMG text with an optional [outline]: Flutter has no text outline, so the outline is a second [Text] painted with a stroke under the fill, laid out identically (same style, lines and overflow) so the glyphs align. The drop shadow of [style] is drawn by the stroked layer, under both.

**Constructors:**

- `const LuminaUmgText(this.data, {super.key, this.style, this.outline = LuminaUmgTextOutline.defaults, this.maxLines, this.overflow, this.textAlign,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `data` | `final String data` |  |
| `style` | `final TextStyle? style` |  |
| `outline` | `final LuminaUmgTextOutline outline` |  |
| `maxLines` | `final int? maxLines` |  |
| `overflow` | `final TextOverflow? overflow` |  |
| `textAlign` | `final TextAlign? textAlign` |  |

### `class LuminaUmgGradient`

The background gradient of a UMG Container: Flutter's linear ([begin] → [end]) or radial ([center], [radius]) gradient.

**Constructors:**

- `const LuminaUmgGradient({this.type = 'linear', required this.colors, this.stops, this.begin = Alignment.centerLeft, this.end = Alignment.centerRight, this.cente...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `type` | `final String type` | `linear` or `radial`. |
| `colors` | `final List<Color> colors` |  |
| `stops` | `final List<double>? stops` |  |
| `begin` | `final Alignment begin` |  |
| `end` | `final Alignment end` |  |
| `center` | `final Alignment center` |  |
| `radius` | `final double radius` |  |
| `toGradient` | `Gradient? toGradient()` | The Flutter gradient; null with fewer than two colours. |
| `fromJson` | `static LuminaUmgGradient? fromJson(Object? v)` | Reads the designer / element JSON: `{type, colors: [hex \| [r,g,b,a]], stops, begin: [x, y], end: [x, y], center: [x, y], radius}`. |

### `abstract final class LuminaUmgStyleJson`

JSON-plain readers for the UMG style props (designer values and element state alike).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `color` | `static Color? color(Object? v)` | `#RRGGBB` / `#RRGGBBAA` or `[r, g, b, a]` (0–1). |
| `number` | `static double? number(Object? v)` |  |
| `edgeInsets` | `static EdgeInsets? edgeInsets(Object? v)` | A number (all sides) or `[left, top, right, bottom]`. |
| `borderRadius` | `static BorderRadius? borderRadius(Object? v)` | A number (every corner) or `[topLeft, topRight, bottomRight, bottomLeft]`. |
| `alignment` | `static Alignment? alignment(Object? v)` | `[x, y]` in -1..1, or one of the nine names (`topLeft` … `bottomRight`). |
| `alignments` | `static const Map<String, Alignment> alignments` | The Container's nine child alignments. |
| `boxShadows` | `static List<BoxShadow>? boxShadows(Object? v)` | `[{color, offsetX, offsetY, blur, spread}]`. |
| `fit` | `static BoxFit? fit(Object? v)` |  |
| `keyboardKeys` | `static List<LogicalKeyboardKey> keyboardKeys(String text)` | The keys of a shortcut label such as `Ctrl+Shift+S` (the shadcn Kbd component); unknown names are skipped. |

### `class LuminaUmgContainerStyle`

The look of a UMG Container, Flutter `Container`'s styling: background colour / gradient / image, border (colour, width, sides), corner radius, padding, margin, box shadows, size limits and the child's alignment. The designer stores it as JSON-plain props ([fromProps]); `LuminaUmgElementBinding.containerStyle` lays the Blueprint-written element state over the designer style.

**Constructors:**

- `const LuminaUmgContainerStyle({this.backgroundColor = const Color(0x00000000), this.gradient, this.backgroundFit = BoxFit.cover, this.borderColor = const Color(...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `backgroundColor` | `final Color backgroundColor` |  |
| `gradient` | `final LuminaUmgGradient? gradient` |  |
| `backgroundFit` | `final BoxFit backgroundFit` |  |
| `borderColor` | `final Color borderColor` |  |
| `borderWidth` | `final double borderWidth` |  |
| `borderTop` | `final bool borderTop` |  |
| `borderRight` | `final bool borderRight` |  |
| `borderBottom` | `final bool borderBottom` |  |
| `borderLeft` | `final bool borderLeft` |  |
| `cornerRadius` | `final BorderRadius cornerRadius` |  |
| `padding` | `final EdgeInsets padding` |  |
| `margin` | `final EdgeInsets margin` |  |
| `shadows` | `final List<BoxShadow> shadows` |  |
| `width` | `final double? width` |  |
| `height` | `final double? height` |  |
| `minWidth` | `final double? minWidth` |  |
| `maxWidth` | `final double? maxWidth` |  |
| `minHeight` | `final double? minHeight` |  |
| `maxHeight` | `final double? maxHeight` |  |
| `alignment` | `final Alignment? alignment` | Where the child sits; null lets it fill the padded box. |
| `fromProps` | `static LuminaUmgContainerStyle fromProps(Map<String, Object?>? props, [LuminaUmgContainerStyle fallback = cons...` | The style [props] describe (designer props or an element's state), each missing or unreadable key keeping [fallback]'s value. |
| `border` | `Border? get border` | The border: each enabled side at [borderWidth] in [borderColor]; null when nothing shows. |
| `decoration` | `BoxDecoration decoration({ImageProvider? image})` | The `BoxDecoration` a Flutter `Container` paints; [image] is the loaded background texture, if any. |
| `constraints` | `BoxConstraints? get constraints` | The min/max limits, or null when none is set. |

### `class LuminaUmgContainer`

A UMG Container: a Flutter [Container] painting [style] (with the loaded background [image]) around one [child]. The designer, the PIE view and the generated widget all build this, so the styling is identical everywhere and whichever widget library the game uses.

**Constructors:**

- `const LuminaUmgContainer({super.key, this.style = const LuminaUmgContainerStyle(), this.image, this.child})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `style` | `final LuminaUmgContainerStyle style` |  |
| `image` | `final ImageProvider? image` |  |
| `child` | `final Widget? child` |  |

## `lib/src/umg/widget_layer.dart`

### `typedef LuminaWidgetBuilder`

Builds the compiled Flutter widget of one widget instance (the map `Create Widget` made) — what `widgets/widget_registry.g.dart` registers for every widget class of a game.

### `abstract final class LuminaWidgetBuilderRegistry`

The compiled widget classes of a running game: the generated `widgets/widget_registry.g.dart` registers each class's description (into [LuminaWidgetClassRegistry], so `Create Widget` seeds its elements) together with the builder that renders an instance of it in a [LuminaWidgetLayer].

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `register` | `static void register(String name, LuminaBlueprintWidgetClass cls, LuminaWidgetBuilder builder)` | Registers [cls] under [name] with the [builder] that renders it. |
| `builderFor` | `static LuminaWidgetBuilder? builderFor(String? className)` | The builder of [className], or null (an unknown class renders as a fallback card naming it). |
| `has` | `static bool has(String className)` |  |
| `unregister` | `static void unregister(String name)` |  |
| `clear` | `static void clear()` | Forgets every builder and every class. |

### `class LuminaWidgetLayer`

Renders the widgets a world's [LuminaWidgetSubsystem] shows: the game host stacks it over [LuminaGameWidget], the editor over its PIE viewport. Widgets are laid out full-screen in `zOrder` order; `Hidden` and `Collapsed` instances are skipped; each instance is built through [resolveBuilder], then [LuminaWidgetBuilderRegistry], and an unknown class renders as a small card naming it. Element nodes writing an instance's state refresh only the elements that changed.

**Constructors:**

- `const LuminaWidgetLayer({super.key, required this.world, this.resolveBuilder, this.fallbackBuilder})`: Renders the widgets of [world]; null renders nothing.
- `const LuminaWidgetLayer.forGame({super.key, required LuminaGame this.game, this.resolveBuilder, this.fallbackBuilder})`: Renders the widgets of [game]'s world, following the game as it mounts and stops (the world exists only after [LuminaGame.mountGame]).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `world` | `final LuminaWorld? world` |  |
| `game` | `final LuminaGame? game` |  |
| `resolveBuilder` | `final LuminaWidgetBuilder? Function(String className)? resolveBuilder` | Takes precedence over the registry: the editor renders a class from its designer document instead of a compiled Dart class. |
| `fallbackBuilder` | `final LuminaWidgetBuilder? fallbackBuilder` | Replaces the default fallback card for classes nobody can build. |

## `lib/src/umg/umg_media_widgets.dart`

### `class LuminaUmgVideoPlayer`

A UMG runtime widget embedding a video player in the game UI / HUD. Automatically coordinates with `LuminaVideoController` and `LuminaVideoPlayer`. Supports autoplay, looping, volume, box fit, error callbacks, and cleans up resources when removed from the widget tree.

**Constructors:**

- `const LuminaUmgVideoPlayer({super.key, this.filePath, this.assetPath, this.networkUrl, this.autoPlay = false, this.looping = false, this.volume = 1.0, this.fit = BoxFit.contain, this.preferHeadless = false, this.onInitialized, this.onError})`

### `class LuminaUmgAudioPlayer`

A UMG runtime widget for non-spatialized background audio, theme music, or cutscene dialog. Automatically coordinates with `LuminaAudioController`.

**Constructors:**

- `const LuminaUmgAudioPlayer({super.key, this.filePath, this.assetPath, this.networkUrl, this.autoPlay = false, this.looping = false, this.volume = 1.0, this.preferHeadless = false, this.onInitialized, this.onError})`

## `lib/src/umg/theme_document_colors.dart`

`lumina_core` stores a theme's colours as ARGB ints (`0xAARRGGBB`). These extensions give Flutter code `Color`s.

### `extension LuminaThemeDocumentColors on LuminaThemeDocument`

| Member | Signature | Description |
| :--- | :--- | :--- |
| `colorOf` | `Color colorOf(String token, {Color fallback = const Color(0xFF888888)})` | The colour of [token] from the theme palette, or [fallback] when the theme does not set it. |

### `extension LuminaComponentStyleColors on LuminaComponentStyle`

| Member | Signature | Description |
| :--- | :--- | :--- |
| `bgColor` | `Color? get bgColor` | `backgroundColor` as a `Color`, or null. |
| `fgColor` | `Color? get fgColor` | `foregroundColor` as a `Color`, or null. |
| `bColor` | `Color? get bColor` | `borderColor` as a `Color`, or null. |

---

[Previous: lumina_widgets](index.md) | [Up: lumina_widgets](index.md) | [Next: Media](media.md)
