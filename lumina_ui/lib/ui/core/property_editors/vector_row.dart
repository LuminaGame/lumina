import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';

class VectorRow extends StatelessWidget {
  final List<double> value;
  final List<double> defaultValue;
  final ValueChanged<List<double>> onChanged;
  final ValueChanged<List<double>> onCommit;
  final VoidCallback onReset;
  final List<bool>? isMixedPerAxis;
  final List<String> labels;
  final String? unit;

  /// Per-axis edits, for rows whose axes do not share one vector (a
  /// multi-selection). When set, a typed value or a reset of one
  /// axis reaches [onAxisCommit] alone instead of [onCommit], and a scrub
  /// reaches [onAxisScrub] as the distance dragged (live, then with
  /// `end: true`) instead of [onChanged] / [onCommit], so the caller can apply
  /// it to each actor's own value. The row's [value] is never written back
  /// for the other axes.
  final void Function(int axis, double value)? onAxisCommit;
  final void Function(int axis, double delta, bool end)? onAxisScrub;

  /// One colour per component. The design prototype paints the axis letters of
  /// a transform field in the manipulator's own axis colours, so the default
  /// is exactly [EditorColors.axisX] / [EditorColors.axisY] /
  /// [EditorColors.axisZ], which are pinned to
  /// `FilamentTransformGizmo.defaultHandleColor`.
  final List<Color> labelColors;
  final String? keyPrefix;
  final int? revision;

  const VectorRow({
    super.key,
    required this.value,
    this.defaultValue = const [0.0, 0.0, 0.0],
    required this.onChanged,
    required this.onCommit,
    required this.onReset,
    this.isMixedPerAxis,
    this.onAxisCommit,
    this.onAxisScrub,
    this.labels = const ['X', 'Y', 'Z'],
    this.unit,
    this.labelColors = const [
      EditorColors.axisX,
      EditorColors.axisY,
      EditorColors.axisZ,
    ],
    this.keyPrefix,
    this.revision,
  });

  void _updateComponent(int index, double newValue, bool commit) {
    if (commit && onAxisCommit != null) {
      onAxisCommit!(index, newValue);
      return;
    }
    final newList = List<double>.from(value);
    newList[index] = newValue;
    if (commit) {
      onCommit(newList);
    } else {
      onChanged(newList);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: ScrubNumericField(
              isMixed: isMixedPerAxis != null ? isMixedPerAxis![i] : false,
              value: value[i],
              defaultValue: defaultValue[i],
              label: labels[i],
              labelColor: labelColors[i],
              unit: unit,
              textFieldKey: keyPrefix != null ? ValueKey('$keyPrefix.$i${revision != null ? ".$revision" : ""}') : null,
              initialValue: keyPrefix != null ? value[i].toStringAsFixed(1) : null,
              onChanged: (v) => _updateComponent(i, v, false),
              onCommit: (v) => _updateComponent(i, v, true),
              onReset: () {
                _updateComponent(i, defaultValue[i], true);
              },
              onScrubDelta: onAxisScrub == null ? null : (delta, end) => onAxisScrub!(i, delta, end),
            ),
          ),
          if (i < 2) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
