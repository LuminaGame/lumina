import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../property_editors/color_field.dart';
import 'plugin_view_scope.dart';

/// [PluginControlKind.colorField]: `value` as `#RRGGBB` or `#AARRGGBB`, edited
/// with the Details panel's [ColorField] (swatch + picker + hex). An
/// `#AARRGGBB` value edits the alpha too. Sends `changed` with the colour in
/// the value's own form when an edit is committed.
class PluginColorFieldControl extends StatefulWidget {
  const PluginColorFieldControl({super.key, required this.control});

  final PluginControl control;

  /// `#AARRGGBB` → `#RRGGBBAA` (the field's form); other values unchanged.
  static String toField(String v) =>
      _hex8.hasMatch(v) ? '#${v.substring(3, 9)}${v.substring(1, 3)}'.toUpperCase() : v.toUpperCase();

  /// The field's `#RRGGBBAA` back to `#AARRGGBB`.
  static String fromField(String v) => _hex8.hasMatch(v) ? '#${v.substring(7, 9)}${v.substring(1, 7)}'.toUpperCase() : v;

  static final RegExp _hex8 = RegExp(r'^#[0-9A-Fa-f]{8}$');
  static final RegExp _hex6 = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// The spec's value, or white when it is not a colour.
  static String specValue(PluginControl c) {
    final v = c.string('value') ?? '';
    return _hex6.hasMatch(v) || _hex8.hasMatch(v) ? v.toUpperCase() : '#FFFFFF';
  }

  @override
  State<PluginColorFieldControl> createState() => _PluginColorFieldControlState();
}

class _PluginColorFieldControlState extends State<PluginColorFieldControl> {
  late String _value;

  /// What was last sent or received: an unchanged commit sends nothing.
  late String _committed;

  @override
  void initState() {
    super.initState();
    _value = PluginColorFieldControl.specValue(widget.control);
    _committed = _value;
  }

  @override
  void didUpdateWidget(PluginColorFieldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = PluginColorFieldControl.specValue(widget.control);
    if (next != PluginColorFieldControl.specValue(oldWidget.control)) {
      _value = next;
      _committed = next;
    }
  }

  bool get _alpha => PluginColorFieldControl._hex8.hasMatch(_value);

  void _commit(String fieldValue) {
    if (!widget.control.enabled) return;
    final v = PluginColorFieldControl.fromField(fieldValue);
    setState(() => _value = v);
    if (v == _committed) return;
    _committed = v;
    PluginViewScope.of(context).emit(widget.control.id, 'changed', v);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final spec = PluginColorFieldControl.specValue(c);
    final field = ColorField(
      value: PluginColorFieldControl.toField(_value),
      defaultValue: PluginColorFieldControl.toField(spec),
      showAlpha: _alpha,
      onChanged: (v) {
        if (c.enabled) setState(() => _value = PluginColorFieldControl.fromField(v));
      },
      onCommit: _commit,
      onReset: () => _commit(PluginColorFieldControl.toField(spec)),
    );
    return withPluginTooltip(c.tooltip, PluginFieldRow(label: c.label, child: withPluginEnabled(c.enabled, field)));
  }
}
