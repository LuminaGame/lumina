import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Line-segment helpers shared by the shape collision components'
/// `buildWireframe`: every loop is closed (its last segment
/// ends on its first point).
abstract final class LuminaShapeWireframes {
  /// A closed ring of [segments] around [center] in the plane of [u] and [v]
  /// (unit axes), radius [radius], as segment pairs appended to [out].
  static void ring(List<Vector3> out, Vector3 center, Vector3 u, Vector3 v, double radius, int segments) {
    final step = (2.0 * math.pi) / segments;
    for (var i = 0; i < segments; i++) {
      final a = i * step;
      final b = (i + 1) * step;
      out.add(center + u * (math.cos(a) * radius) + v * (math.sin(a) * radius));
      out.add(center + u * (math.cos(b) * radius) + v * (math.sin(b) * radius));
    }
  }

  /// One segment from [a] to [b].
  static void line(List<Vector3> out, Vector3 a, Vector3 b) {
    out.add(a);
    out.add(b);
  }
}
