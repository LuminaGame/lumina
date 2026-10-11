import 'package:lumina_widgets/viewport_gizmo.dart' show LuminaTransformGizmoPainter;

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

export 'package:lumina_widgets/viewport_gizmo.dart' show LuminaTransformGizmoPainter;

/// The shared gizmo painter (lumina_widgets) in the editor's axis and
/// foreground colours.
class SubEditorTransformGizmoPainter extends LuminaTransformGizmoPainter {
  const SubEditorTransformGizmoPainter({
    required super.model,
    super.activeHandle,
    super.dragging,
    super.locked,
  }) : super(axisX: EditorColors.axisX, axisY: EditorColors.axisY, axisZ: EditorColors.axisZ, foreground: EditorColors.foreground);

  /// The highlight the Filament manipulator uses (1, 1, 0).
  static const highlight = LuminaTransformGizmoPainter.highlight;
}
