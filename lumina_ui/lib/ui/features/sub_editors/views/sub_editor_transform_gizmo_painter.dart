import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../../main_editor/services/gizmo_controller.dart';
import '../../main_editor/services/transform_gizmo.dart';

/// Draws a [TransformGizmoModel] over a sub-editor viewport:
/// translate arrows with plane quads, rotate rings
/// with a screen ring, scale stems with cubes and a centre cube — the level
/// viewport's manipulator, on the canvas. The hovered or dragged handle is
/// yellow (`FilamentTransformGizmo.highlightColor`), the others dim during a
/// drag, and a locked target draws the whole gizmo dimmed.
class SubEditorTransformGizmoPainter extends CustomPainter {
  final TransformGizmoModel model;
  final String? activeHandle;
  final bool dragging;
  final bool locked;

  const SubEditorTransformGizmoPainter({
    required this.model,
    this.activeHandle,
    this.dragging = false,
    this.locked = false,
  });

  /// The highlight the Filament manipulator uses (1, 1, 0).
  static const Color highlight = Color(0xFFFFEB3B);

  static const Map<String, Color> _axisColors = {
    TransformGizmoModel.axisX: EditorColors.axisX,
    TransformGizmoModel.axisY: EditorColors.axisY,
    TransformGizmoModel.axisZ: EditorColors.axisZ,
  };

  Color _colorFor(String handle) {
    if (handle == activeHandle) return highlight;
    var base = _axisColors[handle] ?? EditorColors.foreground;
    if (TransformGizmoModel.planes.contains(handle)) {
      // A plane quad in the colour of the axis it is perpendicular to.
      base = _axisColors[handle == TransformGizmoModel.planeXY
          ? TransformGizmoModel.axisZ
          : handle == TransformGizmoModel.planeXZ
              ? TransformGizmoModel.axisY
              : TransformGizmoModel.axisX]!;
    }
    final dim = locked || (dragging && activeHandle != null);
    return dim ? base.withValues(alpha: 0.35) : base;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final handles = model.handleScreenPositions();
    if (handles == null) return;
    final centre = handles[TransformGizmoModel.center]!;

    switch (model.mode) {
      case GizmoMode.translate:
        for (final plane in TransformGizmoModel.planes) {
          _paintPlaneQuad(canvas, plane, handles);
        }
        for (final axis in TransformGizmoModel.axes) {
          _paintArrow(canvas, centre, handles[axis]!, _colorFor(axis));
        }
        _paintCentre(canvas, centre, _colorFor(TransformGizmoModel.center), radius: 5.0);
      case GizmoMode.rotate:
        for (final axis in TransformGizmoModel.axes) {
          _paintRing(canvas, model.ringPoints(axis, segments: 48), _colorFor(axis));
        }
        final radius = (handles[TransformGizmoModel.axisX]! - centre).distance;
        final screenRing = Paint()
          ..color = EditorColors.foreground.withValues(alpha: locked ? 0.25 : 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(centre, math.max(radius * 1.18, 18.0), screenRing);
      case GizmoMode.scale:
        for (final axis in TransformGizmoModel.axes) {
          _paintStem(canvas, centre, handles[axis]!, _colorFor(axis));
        }
        _paintCube(canvas, centre, _colorFor(TransformGizmoModel.uniform), half: 5.0);
    }
  }

  void _paintArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final dir = to - from;
    if (dir.distance < 1e-3) return;
    final unit = dir / dir.distance;
    final normal = Offset(-unit.dy, unit.dx);
    const headLength = 11.0;
    const headWidth = 4.5;
    final base = to - unit * headLength;
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(base.dx + normal.dx * headWidth, base.dy + normal.dy * headWidth)
      ..lineTo(base.dx - normal.dx * headWidth, base.dy - normal.dy * headWidth)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  void _paintPlaneQuad(Canvas canvas, String plane, Map<String, Offset> handles) {
    final centre = handles[TransformGizmoModel.center]!;
    final (a, b) = switch (plane) {
      TransformGizmoModel.planeXY => (TransformGizmoModel.axisX, TransformGizmoModel.axisY),
      TransformGizmoModel.planeXZ => (TransformGizmoModel.axisX, TransformGizmoModel.axisZ),
      _ => (TransformGizmoModel.axisY, TransformGizmoModel.axisZ),
    };
    // The quad spans the plane-offset distance along both axes, its far corner
    // being the handle position.
    final ratio = model.planeOffset / model.axisLength;
    final pa = centre + (handles[a]! - centre) * ratio;
    final pb = centre + (handles[b]! - centre) * ratio;
    final corner = handles[plane]!;
    final color = _colorFor(plane);
    final quad = Path()
      ..moveTo(centre.dx, centre.dy)
      ..lineTo(pa.dx, pa.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(pb.dx, pb.dy)
      ..close();
    canvas.drawPath(quad, Paint()..color = color.withValues(alpha: plane == activeHandle ? 0.55 : 0.22));
    canvas.drawPath(
      quad,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _paintRing(Canvas canvas, List<Offset?> points, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    Offset? prev;
    for (final p in points) {
      if (p != null && prev != null) canvas.drawLine(prev, p, paint);
      prev = p;
    }
  }

  void _paintStem(Canvas canvas, Offset from, Offset to, Color color) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    _paintCube(canvas, to, color, half: 4.5);
  }

  void _paintCube(Canvas canvas, Offset at, Color color, {required double half}) {
    canvas.drawRect(Rect.fromCenter(center: at, width: half * 2, height: half * 2), Paint()..color = color);
  }

  void _paintCentre(Canvas canvas, Offset at, Color color, {required double radius}) {
    canvas.drawCircle(at, radius, Paint()..color = color);
    canvas.drawCircle(
      at,
      radius + 3.0,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant SubEditorTransformGizmoPainter oldDelegate) => true;
}
