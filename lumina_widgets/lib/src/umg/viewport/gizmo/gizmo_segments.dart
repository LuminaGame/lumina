import 'dart:math' as math;

import 'package:lumina/lumina_runtime.dart' show LuminaAxes, LuminaViewportSegment;
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_widgets/src/umg/viewport/gizmo/gizmo_controller.dart';
import 'package:lumina_widgets/src/umg/viewport/gizmo/transform_gizmo.dart';

/// The transform gizmo as 3D lines (runtime frame) for a Viewport's
/// Filament overlay: translate arrows with plane squares, rotate rings,
/// scale stems with cubes — the shapes [TransformGizmoModel] hit-tests. The
/// hovered or dragged handle is yellow; the others dim during a drag.
abstract final class LuminaGizmoSegments {
  static const List<double> _x = [1.0, 0.2, 0.2, 1.0];
  static const List<double> _y = [0.2, 1.0, 0.2, 1.0];
  static const List<double> _z = [0.2, 0.4, 1.0, 1.0];
  static const List<double> _highlight = [1.0, 0.92, 0.23, 1.0];

  static List<LuminaViewportSegment> of(TransformGizmoModel model, {String? activeHandle, bool dragging = false}) {
    final out = <LuminaViewportSegment>[];
    final p = model.pivot;
    final len = model.axisLength;
    Vector3 rt(Vector3 a) => LuminaAxes.location([a.x, a.y, a.z]);
    List<double> color(String handle) {
      if (handle == activeHandle) return _highlight;
      final base = switch (handle) {
        TransformGizmoModel.axisX || TransformGizmoModel.planeYZ => _x,
        TransformGizmoModel.axisY || TransformGizmoModel.planeXZ => _y,
        _ => _z,
      };
      return dragging && activeHandle != null ? [base[0], base[1], base[2], 0.35] : base;
    }

    void line(Vector3 a, Vector3 b, List<double> c) => out.add(LuminaViewportSegment(rt(a), rt(b), c));
    final dirs = {for (final a in TransformGizmoModel.axes) a: model.handleAxis(a).normalized()};
    Vector3 perp(Vector3 d) {
      final t = d.cross(d.z.abs() < 0.9 ? Vector3(0, 0, 1) : Vector3(1, 0, 0));
      return t..normalize();
    }

    switch (model.mode) {
      case GizmoMode.translate:
        for (final a in TransformGizmoModel.axes) {
          final d = dirs[a]!;
          final tip = p + d * len;
          final s = perp(d);
          final c = color(a);
          line(p, tip, c);
          line(tip, tip - d * (len * 0.15) + s * (len * 0.06), c);
          line(tip, tip - d * (len * 0.15) - s * (len * 0.06), c);
        }
        for (final (plane, u, v) in [
          (TransformGizmoModel.planeXY, TransformGizmoModel.axisX, TransformGizmoModel.axisY),
          (TransformGizmoModel.planeXZ, TransformGizmoModel.axisX, TransformGizmoModel.axisZ),
          (TransformGizmoModel.planeYZ, TransformGizmoModel.axisY, TransformGizmoModel.axisZ),
        ]) {
          final o = model.planeOffset;
          final a = p + dirs[u]! * o;
          final b = p + dirs[u]! * o + dirs[v]! * o;
          final c2 = p + dirs[v]! * o;
          final c = color(plane);
          line(a, b, c);
          line(b, c2, c);
        }
      case GizmoMode.rotate:
        for (final a in TransformGizmoModel.axes) {
          final n = dirs[a]!;
          final u = perp(n);
          final v = n.cross(u)..normalize();
          const steps = 40;
          for (var i = 0; i < steps; i++) {
            final t0 = i / steps * 2 * math.pi;
            final t1 = (i + 1) / steps * 2 * math.pi;
            line(p + (u * math.cos(t0) + v * math.sin(t0)) * len, p + (u * math.cos(t1) + v * math.sin(t1)) * len, color(a));
          }
        }
      case GizmoMode.scale:
        for (final a in TransformGizmoModel.axes) {
          final d = dirs[a]!;
          final tip = p + d * len;
          final c = color(a);
          line(p, tip, c);
          final h = len * 0.05;
          final u = perp(d) * h;
          final v = d.cross(perp(d))..normalize();
          final w = v * h;
          for (final (x, y) in [(u + w, u - w), (u - w, -u - w), (-u - w, -u + w), (-u + w, u + w)]) {
            line(tip + x, tip + y, c);
          }
        }
    }
    return out;
  }
}
