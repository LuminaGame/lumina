import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'scrub_numeric_field.dart';

class SliderField extends StatefulWidget {
  final double value;
  final double defaultValue;
  final double min;
  final double max;

  /// The typed / scrubbed value's hard limits; the slider still spans
  /// [min]..[max]. Null keeps the slider's range (the old behaviour);
  /// [double.infinity] / [double.negativeInfinity] leave that side open.
  final double? hardMin;
  final double? hardMax;
  final String? unit;

  /// Digits after the decimal point in the number field; null keeps the
  /// field's default (2). Whole centimetres read better with 0.
  final int? fractionDigits;
  final bool isMixed;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;
  final VoidCallback onReset;

  const SliderField({
    super.key,
    required this.value,
    required this.defaultValue,
    required this.min,
    required this.max,
    this.hardMin,
    this.hardMax,
    this.unit,
    this.fractionDigits,
    this.isMixed = false,
    required this.onChanged,
    required this.onCommit,
    required this.onReset,
  });

  @override
  State<SliderField> createState() => _SliderFieldState();
}

class _SliderFieldState extends State<SliderField> {
  /// The last value a slider drag wrote live and has not committed yet.
  /// shadcn's Slider skips `onChangeEnd` when its value already equals the
  /// live-updated one, so the release is read from the pointer as well: a
  /// drag commits exactly once, on release.
  double? _pending;

  void _commitPending() {
    final v = _pending;
    _pending = null;
    if (v != null) widget.onCommit(v);
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Listener(
            onPointerUp: (_) => _commitPending(),
            onPointerCancel: (_) => _commitPending(),
            child: Slider(
              value: SliderValue.single(widget.value.clamp(widget.min, widget.max)),
              min: widget.min,
              max: widget.max,
              onChanged: (v) {
                _pending = v.value;
                widget.onChanged(v.value);
              },
              onChangeEnd: (v) {
                _pending = v.value;
                _commitPending();
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: ScrubNumericField(
            value: widget.value,
            defaultValue: widget.defaultValue,
            label: '',
            min: widget.hardMin == null ? widget.min : (widget.hardMin!.isFinite ? widget.hardMin : null),
            max: widget.hardMax == null ? widget.max : (widget.hardMax!.isFinite ? widget.hardMax : null),
            unit: widget.unit,
            fractionDigits: widget.fractionDigits ?? 2,
            isMixed: widget.isMixed,
            onChanged: (v) => widget.onChanged(v),
            onCommit: widget.onCommit,
            onReset: widget.onReset,
          ),
        ),
      ],
    );
  }
}
