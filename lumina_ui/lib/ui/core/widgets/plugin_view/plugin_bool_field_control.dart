import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_view_scope.dart';

/// [PluginControlKind.boolField]: `value`; the Details panel's checkbox.
/// Sends `changed` with the new bool; the box shows it at once and follows
/// the plugin's `value` when that changes.
class PluginBoolFieldControl extends StatefulWidget {
  const PluginBoolFieldControl({super.key, required this.control});

  final PluginControl control;

  @override
  State<PluginBoolFieldControl> createState() => _PluginBoolFieldControlState();
}

class _PluginBoolFieldControlState extends State<PluginBoolFieldControl> {
  late bool _value = widget.control.flag('value') ?? false;

  @override
  void didUpdateWidget(PluginBoolFieldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.control.flag('value') ?? false;
    if (next != (oldWidget.control.flag('value') ?? false)) _value = next;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final box = Align(
      alignment: Alignment.centerLeft,
      child: Checkbox(
        state: _value ? CheckboxState.checked : CheckboxState.unchecked,
        enabled: c.enabled,
        onChanged: c.enabled
            ? (s) {
                final v = s == CheckboxState.checked;
                setState(() => _value = v);
                PluginViewScope.of(context).emit(c.id, 'changed', v);
              }
            : null,
      ),
    );
    return withPluginTooltip(c.tooltip, PluginFieldRow(label: c.label, child: box));
  }
}
