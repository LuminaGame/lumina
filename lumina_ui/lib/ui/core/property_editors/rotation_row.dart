import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/editor_theme.dart';
import 'vector_row.dart';

class RotationRow extends StatelessWidget {
  final List<double> value;
  final ValueChanged<List<double>> onChanged;
  final ValueChanged<List<double>> onCommit;
  final VoidCallback onReset;

  /// Passed straight through to the [VectorRow] this wraps.
  final List<Color> labelColors;

  const RotationRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
    required this.onReset,
    this.labelColors = const [
      EditorColors.axisX,
      EditorColors.axisY,
      EditorColors.axisZ,
    ],
  });

  double _normalizeAngle(double angle) {
    angle = angle % 360.0;
    if (angle > 180.0) angle -= 360.0;
    if (angle < -180.0) angle += 360.0;
    return angle;
  }

  void _handleChange(List<double> angles) {
    onChanged(angles.map(_normalizeAngle).toList());
  }

  void _handleCommit(List<double> angles) {
    onCommit(angles.map(_normalizeAngle).toList());
  }

  @override
  Widget build(BuildContext context) {
    return VectorRow(
      value: value.map(_normalizeAngle).toList(),
      defaultValue: const [0.0, 0.0, 0.0],
      onChanged: _handleChange,
      onCommit: _handleCommit,
      onReset: onReset,
      labels: const ['X', 'Y', 'Z'],
      labelColors: labelColors,
    );
  }
}
