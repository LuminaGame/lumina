import 'package:flutter/widgets.dart';
import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import 'package:lumina_widgets/src/umg/viewport/gizmo/gizmo_controller.dart';
import 'package:lumina_widgets/src/umg/viewport/gizmo/transform_gizmo.dart';
import 'package:lumina_widgets/src/umg/viewport/skeleton_painter.dart';

/// The labels of a Viewport's overlays: marker labels and ghost-pose
/// badges. The overlays themselves (bones, ghosts, markers, the gizmo) are
/// Filament lines in the preview's overlay view
/// ([LuminaViewportOverlayLines]); only text is painted by Flutter, and it
/// repaints when the camera or the description changes, never per animated
/// frame.
class LuminaViewportOverlayPainter extends CustomPainter {
  LuminaViewportOverlayPainter({required this.controller, super.repaint});

  final LuminaViewportController? controller;

  static Color colorOf(Object? v, Color fallback) {
    if (v is! List || v.length < 3) return fallback;
    double at(int i, double d) => i < v.length && v[i] is num ? (v[i] as num).toDouble().clamp(0.0, 1.0) : d;
    return Color.from(alpha: at(3, 1), red: at(0, 1), green: at(1, 1), blue: at(2, 1));
  }

  /// Whether [scene] shows any label.
  static bool hasLabels(LuminaViewportScene? scene) {
    if (scene == null) return false;
    if (scene.markers.any((m) => '${m['label'] ?? ''}'.isNotEmpty)) return true;
    for (final o in scene.skeletonOverlays) {
      if ('${o['label'] ?? ''}'.isNotEmpty) return true;
      final ghosts = o['ghosts'];
      if (ghosts is List && ghosts.any((g) => g is Map && '${g['label'] ?? ''}'.isNotEmpty)) return true;
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;
    final scene = c?.scene;
    if (c == null || scene == null) return;
    final runtime = c.runtime;
    for (final overlay in scene.skeletonOverlays) {
      final node = '${overlay['node']}';
      void ghostLabel(Map<String, Object?>? pose, Object? color, String label) {
        if (pose == null || label.isEmpty) return;
        final joints = runtime.ghostJointsOf(node, pose);
        if (joints.isEmpty) return;
        final top = runtime.project(joints.reduce((a, b) => a.position.y > b.position.y ? a : b).position);
        if (top != null) LuminaSkeletonPainter.paintBadge(canvas, Offset(top.$1, top.$2), label, colorOf(color, const Color(0xFF66CCFF)));
      }

      ghostLabel(runtime.ghostPoseFor(node, overlay), overlay['ghostColor'], '${overlay['label'] ?? ''}');
      for (final g in overlay['ghosts'] is List ? overlay['ghosts']! as List : const []) {
        if (g is Map && g['pose'] is Map<String, Object?>) ghostLabel(g['pose']! as Map<String, Object?>, g['color'], '${g['label'] ?? ''}');
      }
    }
    for (final m in scene.markers) {
      final label = '${m['label'] ?? ''}';
      final from = m['from'];
      if (label.isEmpty || from is! List || from.length < 3) continue;
      final p = runtime.projectAuthoring([for (final e in from.take(3)) (e as num).toDouble()]);
      if (p == null) continue;
      final color = colorOf(m['color'], const Color(0xFFFF5555));
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 11, color: color, shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.$1 + 6, p.$2 - 16));
    }
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
