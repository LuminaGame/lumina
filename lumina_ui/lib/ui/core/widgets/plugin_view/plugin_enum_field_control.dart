import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/enum_field.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// [PluginControlKind.enumField]: `value` and `options` (`{"value","label"}`),
/// shown with the Details panel's [EnumField] by label. Sends `changed` with
/// the chosen option's value.
class PluginEnumFieldControl extends StatefulWidget {
  const PluginEnumFieldControl({super.key, required this.control});

  final PluginControl control;

  /// `(value, label)` per option; a bare string option is its own label.
  static List<(String, String)> optionsOf(PluginControl c) => [
        for (final o in c.list('options') ?? const [])
          if (o is Map && o['value'] != null)
            ('${o['value']}', '${o['label'] ?? o['value']}')
          else if (o is String)
            (o, o),
      ];

  @override
  State<PluginEnumFieldControl> createState() => _PluginEnumFieldControlState();
}

class _PluginEnumFieldControlState extends State<PluginEnumFieldControl> {
  late String _value = widget.control.string('value') ?? '';

  @override
  void didUpdateWidget(PluginEnumFieldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.control.string('value') ?? '';
    if (next != (oldWidget.control.string('value') ?? '')) _value = next;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final options = PluginEnumFieldControl.optionsOf(c);
    // Labels must tell options apart; repeated labels fall back to values.
    final labels = options.map((o) => o.$2).toList();
    final useLabels = labels.toSet().length == labels.length;
    String shown((String, String) o) => useLabels ? o.$2 : o.$1;
    final current = options.where((o) => o.$1 == _value).map(shown).firstOrNull ?? _value;
    final field = EnumField(
      value: current,
      enumValues: [for (final o in options) shown(o)],
      onCommit: (picked) {
        if (!c.enabled) return;
        final option = options.firstWhere((o) => shown(o) == picked, orElse: () => (picked, picked));
        setState(() => _value = option.$1);
        PluginViewScope.of(context).emit(c.id, 'changed', option.$1);
      },
    );
    return withPluginTooltip(
      c.tooltip,
      PluginFieldRow(label: c.label, child: Align(alignment: Alignment.centerLeft, child: withPluginEnabled(c.enabled, field))),
    );
  }
}
