import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lumina/lumina_runtime.dart' show LuminaComboBoxOption, LuminaComboBoxOptions, LuminaComboBoxSelection;

import 'package:lumina_widgets/src/umg/umg_widgets.dart';

/// Reads and watches the per-element runtime state of a widget instance.
/// A widget instance is the JSON-plain map `Create Widget` builds:
/// `{'class', 'owner', 'inViewport', 'zOrder', 'visibility',
/// 'elements': {name: {'type', 'name', 'visibility', 'isEnabled',
/// 'renderOpacity', ...designer props, ...values the element nodes wrote}}}`
/// (the placeholder in angle brackets is the element name).
///
/// The element setters (`Set Text (Text)`, `Set Percent`, …) write into that
/// map and call [LuminaWidgetSubsystem.notifyChanged]; a [LuminaWidgetLayer]
/// turns that into a [LuminaUmgInstanceBinding] refresh, and every
/// [LuminaUmgElement] bound to the instance rebuilds only when its own
/// element's state changed.
abstract final class LuminaUmgElementBinding {
  /// Runtime keys the element nodes write, and the designer key the same
  /// value was seeded under (`Set Is Checked` writes `isChecked`, the
  /// designer stored `checked`). A read of the runtime key falls back to the
  /// designer key. The text shadow and outline keys
  /// (`shadowEnabled`, `shadowColor`, `shadowOffsetX`, `shadowOffsetY`,
  /// `shadowBlur`, `outlineSize`, `outlineColor`) are the same in both, so
  /// they need no entry.
  static const Map<String, String> designerKeys = {
    'isChecked': 'checked',
    'hintText': 'hint',
    'selectedOption': 'selected',
    'fillColor': 'color',
  };

  /// The elements map of [instance], or null.
  static Map<String, Object?>? elements(Map<String, Object?>? instance) {
    final e = instance?['elements'];
    return e is Map<String, Object?> ? e : null;
  }

  /// The state map of element [elementName] of [instance], or null when the
  /// instance has no such element (an unregistered class, or a stale name).
  static Map<String, Object?>? element(Map<String, Object?>? instance, String elementName) {
    final e = elements(instance)?[elementName];
    return e is Map<String, Object?> ? e : null;
  }

  /// `instance.elements[elementName][key]` as a [T], or [fallback] (the
  /// designer's value the generated code carries) when the element or the key
  /// is missing or of another type. Numbers coerce between `int` and `double`.
  static T elementValue<T>(Map<String, Object?>? instance, String elementName, String key, T fallback) =>
      value<T>(element(instance, elementName), key, fallback);

  /// [elementValue] on an element state map that was already looked up.
  static T value<T>(Map<String, Object?>? element, String key, T fallback) {
    if (element == null) return fallback;
    var v = element[key];
    final designerKey = designerKeys[key];
    if (v == null && designerKey != null) v = element[designerKey];
    if (v == null) return fallback;
    if (v is T) return v as T;
    if (v is num) {
      if (T == double) return v.toDouble() as T;
      if (T == int) return v.toInt() as T;
    }
    if (T == String) return v.toString() as T;
    return fallback;
  }

  /// A colour of [element]: `[r, g, b, a]` (0–1, what `Set Color and
  /// Opacity` writes), a `#RRGGBB` / `#RRGGBBAA` string (what the designer
  /// stored), or [fallback].
  static Color color(Map<String, Object?>? element, String key, Color fallback) {
    if (element == null) return fallback;
    var v = element[key];
    final designerKey = designerKeys[key];
    if (v == null && designerKey != null) v = element[designerKey];
    return parseColor(v) ?? fallback;
  }

  /// [color] as `Color?`: null when nothing usable is stored.
  /// `#RRGGBB`, or `#RRGGBBAA` with the alpha last (the
  /// Blueprint colour literal's order).
  static Color? parseColor(Object? v) => LuminaUmgStyleJson.color(v);

  /// Padding / margin of [element] under [key] (a number or `[l, t, r, b]`,
  /// what `Set Padding` writes), or [fallback].
  static EdgeInsets edgeInsets(Map<String, Object?>? element, String key, EdgeInsets fallback) =>
      LuminaUmgStyleJson.edgeInsets(element?[key]) ?? fallback;

  /// Corner radius of [element] under [key] (a number, what `Set Corner
  /// Radius` writes, or `[tl, tr, br, bl]`), or [fallback].
  static BorderRadius borderRadius(Map<String, Object?>? element, String key, BorderRadius fallback) =>
      LuminaUmgStyleJson.borderRadius(element?[key]) ?? fallback;

  /// The Container style of [element]: every Container key
  /// the element state holds (`backgroundColor`, `gradient`, `borderColor`,
  /// `borderWidth`, `borderSides`, `cornerRadius`, `padding`, `margin`,
  /// `shadows`, sizes, `alignment`, `backgroundFit`) over [fallback], the
  /// designer's style the generated code carries.
  static LuminaUmgContainerStyle containerStyle(Map<String, Object?>? element, LuminaUmgContainerStyle fallback) =>
      LuminaUmgContainerStyle.fromProps(element, fallback);

  /// The drop shadow of a text-bearing element: each of
  /// `shadowEnabled`, `shadowColor`, `shadowOffsetX`, `shadowOffsetY` and
  /// `shadowBlur` [element] holds overrides [fallback] (the designer's
  /// shadow, which the generated code carries).
  static LuminaUmgTextShadow shadow(Map<String, Object?>? element, LuminaUmgTextShadow fallback) {
    if (element == null) return fallback;
    return LuminaUmgTextShadow(
      enabled: value<bool>(element, 'shadowEnabled', fallback.enabled),
      color: color(element, 'shadowColor', fallback.color),
      offsetX: value<double>(element, 'shadowOffsetX', fallback.offsetX),
      offsetY: value<double>(element, 'shadowOffsetY', fallback.offsetY),
      blur: value<double>(element, 'shadowBlur', fallback.blur),
    );
  }

  /// The outline of a text-bearing element: `outlineSize`
  /// and `outlineColor` of [element] override [fallback].
  static LuminaUmgTextOutline outline(Map<String, Object?>? element, LuminaUmgTextOutline fallback) {
    if (element == null) return fallback;
    return LuminaUmgTextOutline(
      size: value<double>(element, 'outlineSize', fallback.size),
      color: color(element, 'outlineColor', fallback.color),
    );
  }

  /// The option labels of a Combo Box element: its list (what `Add Option`
  /// writes: labels, or `{label, value}` maps) or the designer's stored
  /// options, else [fallback].
  static List<String> options(Map<String, Object?>? element, List<String> fallback) {
    final v = element?['options'];
    if (v is List || v is String) return LuminaComboBoxOptions.labels(v);
    return fallback;
  }

  /// The options (label + value) of a Combo Box element, else those of
  /// [fallback] (the designer's stored options, in any stored form).
  static List<LuminaComboBoxOption> comboOptions(Map<String, Object?>? element, [Object? fallback]) {
    final v = element?['options'];
    return LuminaComboBoxOptions.parse(v is List || v is String ? v : fallback);
  }

  /// The player picked [label] (the first option with that label, or option
  /// [index] when given) in Combo Box [elementName] of [instance]: writes
  /// `selectedOption` and `selectedIndex` and returns the selection On
  /// Selection Changed delivers ([selectType] `OnMouseClick` by default).
  /// Without an instance (a preview) the selection comes from
  /// [fallbackOptions].
  static LuminaComboBoxSelection selectComboOption(Map<String, Object?>? instance, String elementName, String? label,
      {int? index, Object? fallbackOptions, String selectType = LuminaComboBoxOptions.onMouseClick}) {
    final e = element(instance, elementName);
    final all = comboOptions(e, fallbackOptions);
    final i = index ?? LuminaComboBoxOptions.indexOfLabel(all, label ?? '');
    if (instance != null) {
      write(instance, elementName, LuminaComboBoxOptions.selectedKey, i >= 0 && i < all.length ? all[i].label : (label ?? ''));
      write(instance, elementName, LuminaComboBoxOptions.selectedIndexKey, i >= 0 && i < all.length ? i : -1);
    }
    if (i < 0 || i >= all.length) return LuminaComboBoxSelection(label ?? '', null, -1, selectType);
    return LuminaComboBoxSelection(all[i].label, all[i].value, i, selectType);
  }

  /// `Visible` / `Hidden` / `Collapsed` (with
  /// `HitTestInvisible` / `SelfHitTestInvisible` rendering as visible).
  static String visibility(Map<String, Object?>? element) => value<String>(element, 'visibility', 'Visible');

  static bool isVisible(Map<String, Object?>? element) {
    final v = visibility(element);
    return v != 'Hidden' && v != 'Collapsed';
  }

  static bool isEnabled(Map<String, Object?>? element) => value<bool>(element, 'isEnabled', true);

  static double renderOpacity(Map<String, Object?>? element) => value<double>(element, 'renderOpacity', 1.0).clamp(0.0, 1.0);

  /// Writes [key] of element [elementName] (what an interactive widget does
  /// when the player moves a slider or types), so `Get Slider Value` and
  /// friends read what is on screen. Creates the element state when the
  /// instance has none for that name. Returns false without an instance.
  static bool write(Map<String, Object?>? instance, String elementName, String key, Object? newValue) {
    if (instance == null) return false;
    final all = instance.putIfAbsent('elements', () => <String, Object?>{});
    if (all is! Map<String, Object?>) return false;
    final e = all.putIfAbsent(elementName, () => <String, Object?>{'type': 'unknown', 'name': elementName, 'visibility': 'Visible', 'isEnabled': true, 'renderOpacity': 1.0});
    if (e is! Map<String, Object?>) return false;
    e[key] = newValue;
    return true;
  }

  /// The binding of the instance a [LuminaWidgetLayer] is rendering above
  /// [context], or null outside a layer (a designer preview, a bare test).
  /// Does not register a dependency: elements subscribe themselves.
  static LuminaUmgInstanceBinding? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LuminaUmgInstanceScope>()?.binding;
}

/// One widget instance as a [ValueListenable]: [value] is the instance map
/// itself (mutated in place by the element nodes) and [refresh] is what the
/// [LuminaWidgetLayer] calls when the widget subsystem notified.
class LuminaUmgInstanceBinding extends ChangeNotifier implements ValueListenable<Map<String, Object?>> {
  LuminaUmgInstanceBinding(this.instance);

  final Map<String, Object?> instance;

  @override
  Map<String, Object?> get value => instance;

  /// Tells every bound element to compare its state and rebuild if it changed.
  void refresh() => notifyListeners();
}

/// Makes a [LuminaUmgInstanceBinding] available to the compiled widget class
/// built for that instance.
class LuminaUmgInstanceScope extends InheritedWidget {
  const LuminaUmgInstanceScope({super.key, required this.binding, required super.child});

  final LuminaUmgInstanceBinding binding;

  @override
  bool updateShouldNotify(LuminaUmgInstanceScope oldWidget) => !identical(oldWidget.binding, binding);
}

/// Builds the state of one element of [instance], rebuilding only when that
/// element's state changed, and applying the common element properties:
/// `Collapsed` takes the element out of layout, `Hidden` keeps its space,
/// `renderOpacity` below 1 draws it through an [Opacity], and a disabled
/// element ignores pointers and is dimmed.
///
/// Generated widget classes (umg_widget_codegen) wrap every designer element
/// in one of these; without an [instance] (a preview) the builder sees `null`
/// and the designer's defaults apply.
class LuminaUmgElement extends StatefulWidget {
  const LuminaUmgElement({
    super.key,
    required this.instance,
    required this.name,
    required this.builder,
  });

  final Map<String, Object?>? instance;
  final String name;
  final Widget Function(BuildContext context, Map<String, Object?>? element) builder;

  @override
  State<LuminaUmgElement> createState() => _LuminaUmgElementState();
}

class _LuminaUmgElementState extends State<LuminaUmgElement> {
  LuminaUmgInstanceBinding? _binding;
  Map<String, Object?>? _snapshot;
  Widget? _built;

  Map<String, Object?>? get _element => LuminaUmgElementBinding.element(widget.instance, widget.name);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final binding = LuminaUmgElementBinding.maybeOf(context);
    if (!identical(binding, _binding)) {
      _binding?.removeListener(_onRefresh);
      _binding = binding;
      _binding?.addListener(_onRefresh);
    }
  }

  @override
  void didUpdateWidget(LuminaUmgElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.instance, widget.instance) || oldWidget.name != widget.name || oldWidget.builder != widget.builder) {
      _built = null;
    }
  }

  @override
  void dispose() {
    _binding?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    if (!mounted) return;
    final now = _element;
    if (_changed(_snapshot, now)) {
      setState(() => _built = null);
    }
  }

  static bool _changed(Map<String, Object?>? a, Map<String, Object?>? b) {
    if (a == null || b == null) return !(a == null && b == null);
    if (a.length != b.length) return true;
    for (final entry in b.entries) {
      if (!a.containsKey(entry.key)) return true;
      final v = a[entry.key];
      final w = entry.value;
      if (v is List && w is List) {
        if (!listEquals(v, w)) return true;
      } else if (v != w) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final element = _element;
    if (_built == null) {
      _snapshot = element == null ? null : Map<String, Object?>.of(element);
      _built = widget.builder(context, element);
    }
    var child = _built!;
    if (element == null) return child;
    final visibility = LuminaUmgElementBinding.visibility(element);
    if (visibility == 'Collapsed') return const SizedBox.shrink();
    final enabled = LuminaUmgElementBinding.isEnabled(element);
    var opacity = LuminaUmgElementBinding.renderOpacity(element);
    if (!enabled) {
      opacity *= 0.5;
      child = IgnorePointer(child: child);
    } else if (visibility == 'HitTestInvisible' || visibility == 'SelfHitTestInvisible') {
      // Drawn, but taps pass through (not hit-testable).
      child = IgnorePointer(child: child);
    }
    if (opacity < 1.0) child = Opacity(opacity: opacity, child: child);
    if (visibility == 'Hidden') {
      child = Visibility(visible: false, maintainState: true, maintainAnimation: true, maintainSize: true, child: child);
    }
    return child;
  }
}
