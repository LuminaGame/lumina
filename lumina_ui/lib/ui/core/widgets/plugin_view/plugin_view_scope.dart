import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// What every control of one rendered [PluginViewSpec] reads from above:
/// the view id, the project directory and where events go. The renderer
/// owns one host for its lifetime, so a control widget built once keeps
/// sending to the renderer's current `onEvent` even when the parent passes a
/// new callback.
class PluginViewHost {
  PluginViewHost({required this.viewId, required this.projectDir, required this.sink});

  final String viewId;
  final String? projectDir;

  /// The renderer's current event callback.
  final void Function(PluginViewEvent event) sink;

  /// Sends [kind] (`changed`, `pressed`, `picked`) for [controlId].
  void emit(String controlId, String kind, [Object? value]) =>
      sink(PluginViewEvent(viewId: viewId, controlId: controlId, kind: kind, value: value));

  /// The key of [controlId]'s widget: `<viewId>/<controlId>`.
  ValueKey<String> keyOf(String controlId) => pluginControlKey(viewId, controlId);
}

/// The key a rendered control carries: `<viewId>/<controlId>`.
ValueKey<String> pluginControlKey(String viewId, String controlId) => ValueKey('$viewId/$controlId');

/// Makes a [PluginViewHost] available to the controls below.
class PluginViewScope extends InheritedWidget {
  const PluginViewScope({super.key, required this.host, required super.child});

  final PluginViewHost host;

  static PluginViewHost of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PluginViewScope>();
    assert(scope != null, 'A plugin control was built outside a PluginViewRenderer.');
    return scope!.host;
  }

  @override
  bool updateShouldNotify(PluginViewScope oldWidget) => host != oldWidget.host;
}

/// Typed readers for a control's props: a prop of the wrong type reads as
/// absent, never throws.
extension PluginControlProps on PluginControl {
  String? string(String prop) {
    final v = props[prop];
    return v is String ? v : null;
  }

  num? number(String prop) {
    final v = props[prop];
    return v is num ? v : null;
  }

  bool? flag(String prop) {
    final v = props[prop];
    return v is bool ? v : null;
  }

  List<Object?>? list(String prop) {
    final v = props[prop];
    return v is List ? v : null;
  }

  Map<String, Object?>? map(String prop) {
    final v = props[prop];
    return v is Map ? v.cast<String, Object?>() : null;
  }

  /// `enabled` (inputs and buttons); true when absent.
  bool get enabled => flag('enabled') ?? true;

  String? get label {
    final l = string('label');
    return l == null || l.isEmpty ? null : l;
  }

  String? get tooltip {
    final t = string('tooltip');
    return t == null || t.isEmpty ? null : t;
  }
}

/// Whether [a] and [b] would render the same: same kind, id, props (deep)
/// and children (deep). The renderer reuses a control's widget when it is.
bool pluginControlEquals(PluginControl a, PluginControl b) {
  if (identical(a, b)) return true;
  if (a.kind != b.kind || a.id != b.id) return false;
  if (!pluginValueEquals(a.props, b.props)) return false;
  if (a.children.length != b.children.length) return false;
  for (var i = 0; i < a.children.length; i++) {
    if (!pluginControlEquals(a.children[i], b.children[i])) return false;
  }
  return true;
}

/// Deep equality of JSON-like values (maps, lists, scalars).
bool pluginValueEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !pluginValueEquals(e.value, b[e.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!pluginValueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

/// The Details panel's property row: a 100 px muted label column, then the
/// editor. Without a label the editor fills the row.
class PluginFieldRow extends StatelessWidget {
  const PluginFieldRow({super.key, required this.label, required this.child, this.unit, this.alignTop = false});

  final String? label;
  final String? unit;
  final Widget child;
  final bool alignTop;

  static const double labelWidth = 100;

  @override
  Widget build(BuildContext context) {
    if (label == null) return child;
    return Row(
      crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Row(
            children: [
              Expanded(
                child: Text(label!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              ),
              if (unit != null)
                Text(' ($unit)', style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
            ],
          ),
        ),
        const SizedBox(width: EditorDensity.gutter),
        Expanded(child: child),
      ],
    );
  }
}

/// Wraps [child] in the editor tooltip when [text] is set.
Widget withPluginTooltip(String? text, Widget child) {
  if (text == null) return child;
  return Tooltip(
    tooltip: (context) => TooltipContainer(child: Text(text).small()),
    child: child,
  );
}

/// A disabled input: drawn faded and ignoring the pointer.
Widget withPluginEnabled(bool enabled, Widget child) {
  if (enabled) return child;
  return IgnorePointer(child: Opacity(opacity: 0.45, child: child));
}
