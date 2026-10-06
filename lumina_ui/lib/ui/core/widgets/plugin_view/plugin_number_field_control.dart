import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../property_editors/scrub_numeric_field.dart';
import '../../property_editors/slider_field.dart';
import 'plugin_view_scope.dart';

/// [PluginControlKind.numberField]: `value`, `min`, `max`, `step`, `unit`.
/// The Details panel's fields: a slider plus a scrub field when both `min`
/// and `max` are set, else the scrub field alone. Sends `changed` with the
/// committed number (snapped to `step`; an integer when `step` and `value`
/// are whole numbers), never on every scrub tick.
class PluginNumberFieldControl extends StatefulWidget {
  const PluginNumberFieldControl({super.key, required this.control});

  final PluginControl control;

  @override
  State<PluginNumberFieldControl> createState() => _PluginNumberFieldControlState();
}

class _PluginNumberFieldControlState extends State<PluginNumberFieldControl> {
  late double _value = _specValue(widget.control);

  static double _specValue(PluginControl c) => (c.number('value') ?? 0).toDouble();

  @override
  void didUpdateWidget(PluginNumberFieldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _specValue(widget.control);
    if (next != _specValue(oldWidget.control)) _value = next;
  }

  /// Whether the field edits whole numbers.
  bool get _integral {
    final step = widget.control.number('step');
    final value = widget.control.number('value');
    if (step != null) return step == step.roundToDouble() && (value == null || value is int || value == value.roundToDouble());
    return value is int;
  }

  int get _fractionDigits {
    if (_integral) return 0;
    final step = widget.control.number('step');
    if (step == null || step <= 0) return 2;
    var digits = 0;
    var s = step.toDouble();
    while (digits < 6 && (s - s.roundToDouble()).abs() > 1e-9) {
      s *= 10;
      digits++;
    }
    return digits;
  }

  num _snap(double v) {
    final c = widget.control;
    final min = c.number('min')?.toDouble();
    final max = c.number('max')?.toDouble();
    final step = c.number('step')?.toDouble();
    var out = v;
    if (step != null && step > 0) {
      final base = min ?? 0;
      out = base + ((out - base) / step).roundToDouble() * step;
    }
    if (min != null && out < min) out = min;
    if (max != null && out > max) out = max;
    return _integral ? out.round() : out;
  }

  void _commit(double v) {
    if (!widget.control.enabled) return;
    final snapped = _snap(v);
    setState(() => _value = snapped.toDouble());
    PluginViewScope.of(context).emit(widget.control.id, 'changed', snapped);
  }

  void _live(double v) {
    if (!widget.control.enabled) return;
    setState(() => _value = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final min = c.number('min')?.toDouble();
    final max = c.number('max')?.toDouble();
    final unit = c.string('unit');
    final spec = _specValue(c);
    void reset() => _commit(spec);
    final Widget editor = min != null && max != null && max > min
        ? SliderField(
            value: _value,
            defaultValue: spec,
            min: min,
            max: max,
            unit: unit,
            fractionDigits: _fractionDigits,
            onChanged: _live,
            onCommit: _commit,
            onReset: reset,
          )
        : ScrubNumericField(
            value: _value,
            defaultValue: spec,
            label: '',
            min: min,
            max: max,
            unit: unit,
            fractionDigits: _fractionDigits,
            onChanged: _live,
            onCommit: _commit,
            onReset: reset,
          );
    return withPluginTooltip(
      c.tooltip,
      PluginFieldRow(label: c.label, child: withPluginEnabled(c.enabled, editor)),
    );
  }
}
