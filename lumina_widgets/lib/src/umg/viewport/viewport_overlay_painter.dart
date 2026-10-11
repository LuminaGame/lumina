import 'package:flutter/widgets.dart';
import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import 'package:lumina_widgets/src/umg/viewport/gizmo/gizmo_controller.dart';
import 'package:lumina_widgets/src/umg/viewport/gizmo/transform_gizmo.dart';
import 'package:lumina_widgets/src/umg/viewport/gizmo/transform_gizmo_painter.dart';

/// The parts of a Viewport drawn over its 3D image, every rendered frame:
/// the skeleton overlays (bones, joints, ghost poses with their labels),
/// the markers (points, lines, arrows with labels) and the transform gizmo.
/// Everything is projected through the preview's camera; nothing reaches
/// the graph.
class LuminaViewportOverlayPainter extends CustomPainter {
  LuminaViewportOverlayPainter({required this.controller, required this.gizmo, this.activeHandle, this.dragging = false, super.repaint});

  final LuminaViewportController? controller;

  /// The gizmo to draw (null: hidden).
  final TransformGizmoModel? Function() gizmo;
  final String? activeHandle;
  final bool dragging;

  static Color colorOf(Object? v, Color fallback) {
    if (v is! List || v.length < 3) return fallback;
    double at(int i, double d) => i < v.length && v[i] is num ? (v[i] as num).toDouble().clamp(0.0, 1.0) : d;
    return Color.from(alpha: at(3, 1), red: at(0, 1), green: at(1, 1), blue: at(2, 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;
    final scene = c?.scene;
    if (c == null || scene == null) return;
    final runtime = c.runtime;
    for (final overlay in scene.skeletonOverlays) {
      final node = '${overlay['node']}';
      _skeleton(canvas, runtime, runtime.jointsOf(node), colorOf(overlay['color'], const Color(0xFFFFD933)), overlay['joints'] != false);
      final pose = overlay['ghostPose'];
      if (pose is Map<String, Object?>) {
        final ghost = runtime.ghostJointsOf(node, pose);
        final color = colorOf(overlay['ghostColor'], const Color(0x9966CCFF));
        _skeleton(canvas, runtime, ghost, color, false);
        final label = '${overlay['label'] ?? ''}';
        if (label.isNotEmpty && ghost.isNotEmpty) {
          final top = runtime.project(ghost.reduce((a, b) => a.position.y > b.position.y ? a : b).position);
          if (top != null) _label(canvas, Offset(top.$1, top.$2 - 18), label, color);
        }
      }
    }
    for (final m in scene.markers) {
      _marker(canvas, runtime, m);
    }
    final model = gizmo();
    if (model != null) {
      LuminaTransformGizmoPainter(model: model, activeHandle: activeHandle, dragging: dragging).paint(canvas, size);
    }
  }

  void _skeleton(Canvas canvas, LuminaViewportSceneRuntime runtime, List<LuminaViewportJoint> joints, Color color, bool dots) {
    if (joints.isEmpty) return;
    final points = [for (final j in joints) runtime.project(j.position)];
    final bone = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = color;
    for (var i = 0; i < joints.length; i++) {
      final p = points[i];
      if (p == null) continue;
      final parent = joints[i].parent;
      final q = parent >= 0 ? points[parent] : null;
      if (q != null) canvas.drawLine(Offset(q.$1, q.$2), Offset(p.$1, p.$2), bone);
      if (dots) canvas.drawCircle(Offset(p.$1, p.$2), 2.5, dot);
    }
  }

  void _marker(Canvas canvas, LuminaViewportSceneRuntime runtime, Map<String, Object?> m) {
    List<double> v(Object? o) => o is List && o.length >= 3 ? [for (final e in o.take(3)) (e as num).toDouble()] : const [0.0, 0.0, 0.0];
    final color = colorOf(m['color'], const Color(0xFFFF5555));
    final from = runtime.projectAuthoring(v(m['from']));
    if (from == null) return;
    final a = Offset(from.$1, from.$2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    switch (m['kind']) {
      case 'line':
      case 'arrow':
        final to = runtime.projectAuthoring(v(m['to']));
        if (to == null) break;
        final b = Offset(to.$1, to.$2);
        canvas.drawLine(a, b, paint);
        if (m['kind'] == 'arrow' && (b - a).distance > 1) {
          final u = (b - a) / (b - a).distance;
          final n = Offset(-u.dy, u.dx);
          final head = Path()
            ..moveTo(b.dx, b.dy)
            ..lineTo((b - u * 10 + n * 5).dx, (b - u * 10 + n * 5).dy)
            ..lineTo((b - u * 10 - n * 5).dx, (b - u * 10 - n * 5).dy)
            ..close();
          canvas.drawPath(head, Paint()..color = color);
        }
      default:
        canvas.drawCircle(a, 4.0, Paint()..color = color);
    }
    final label = '${m['label'] ?? ''}';
    if (label.isNotEmpty) _label(canvas, a + const Offset(6, -16), label, color);
  }

  void _label(Canvas canvas, Offset at, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 11, color: color, shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2)]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant LuminaViewportOverlayPainter oldDelegate) => true;
}

/// The gizmo of [controller]'s description as a [TransformGizmoModel] over
/// the preview's camera (authoring frame), or null when it is hidden or
/// its target is not drawn.
TransformGizmoModel? luminaViewportGizmoModel(LuminaViewportController? controller) {
  final target = controller?.gizmoTarget;
  final scene = controller?.scene;
  if (controller == null || target == null || scene == null) return null;
  final runtime = controller.runtime;
  final g = scene.gizmo!;
  Vector3? pivot;
  Quaternion rotation = Quaternion.identity();
  final bone = target.bone;
  if (bone != null) {
    for (final j in runtime.jointsOf(target.node)) {
      if (j.name == bone) {
        final a = LuminaAxes.toAuthoringLocation(j.position);
        pivot = Vector3(a[0], a[1], a[2]);
      }
    }
  } else {
    pivot = controller.locationOf(target.node);
    final t = runtime.transformOf(target.node);
    final r = t?['rotation'];
    if (r is List && g['space'] == 'local') {
      rotation = AuthoringRotation.quaternionToAuthoring(LuminaAxes.rotation([for (final e in r) e as num]));
    }
  }
  if (pivot == null) return null;
  final mode = switch (g['mode']) {
    'rotate' => GizmoMode.rotate,
    'scale' => GizmoMode.scale,
    _ => GizmoMode.translate,
  };
  final length = runtime.orbit.distance * 0.18;
  return TransformGizmoModel(
    mode: mode,
    space: g['space'] == 'local' ? GizmoSpace.local : GizmoSpace.world,
    pivot: pivot,
    rotation: rotation,
    axisLength: length,
    planeOffset: length * 0.3,
    project: (p) {
      final s = runtime.projectAuthoring([p.x, p.y, p.z]);
      return s == null ? null : Offset(s.$1, s.$2);
    },
  );
}
