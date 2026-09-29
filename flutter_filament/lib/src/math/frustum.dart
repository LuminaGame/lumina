import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'box.dart';

/// Frustum plane indices in Filament's exact order:
/// [left], [right], [bottom], [top], [far], [near].
enum FrustumPlane {
  left,
  right,
  bottom,
  top,
  far,
  near,
}

/// A viewing frustum defined by six normalized planes.
///
/// Direct pure-Dart reimplementation of `filament::Frustum` and `filament::Culler`.
///
/// Filament convention:
/// - Inside is the negative half-space (`dot(plane.xyz, p) + plane.w <= 0`).
/// - Planes are extracted via the Gil Gribb & Klaus Hartmann algorithm.
class Frustum {
  final List<Vector4> _planes = List.generate(6, (_) => Vector4.zero());

  /// Creates a frustum from a composite projection * view matrix [projViewMatrix].
  Frustum(Matrix4 projViewMatrix) {
    setProjection(projViewMatrix);
  }

  /// Sets the frustum planes from the given [projViewMatrix].
  void setProjection(Matrix4 projViewMatrix) {
    final row0 = Vector4(
      projViewMatrix.entry(0, 0),
      projViewMatrix.entry(0, 1),
      projViewMatrix.entry(0, 2),
      projViewMatrix.entry(0, 3),
    );
    final row1 = Vector4(
      projViewMatrix.entry(1, 0),
      projViewMatrix.entry(1, 1),
      projViewMatrix.entry(1, 2),
      projViewMatrix.entry(1, 3),
    );
    final row2 = Vector4(
      projViewMatrix.entry(2, 0),
      projViewMatrix.entry(2, 1),
      projViewMatrix.entry(2, 2),
      projViewMatrix.entry(2, 3),
    );
    final row3 = Vector4(
      projViewMatrix.entry(3, 0),
      projViewMatrix.entry(3, 1),
      projViewMatrix.entry(3, 2),
      projViewMatrix.entry(3, 3),
    );

    // Gil Gribb & Klaus Hartmann plane extraction
    Vector4 l = -row3 - row0;
    Vector4 r = -row3 + row0;
    Vector4 b = -row3 - row1;
    Vector4 t = -row3 + row1;
    Vector4 f = -row3 + row2;
    Vector4 n = -row3 - row2;

    _normalizePlane(l);
    _normalizePlane(r);
    _normalizePlane(b);
    _normalizePlane(t);
    _normalizePlane(f);
    _normalizePlane(n);

    _planes[0] = l;
    _planes[1] = r;
    _planes[2] = b;
    _planes[3] = t;
    _planes[4] = f;
    _planes[5] = n;
  }

  static void _normalizePlane(Vector4 plane) {
    final len = math.sqrt(plane.x * plane.x + plane.y * plane.y + plane.z * plane.z);
    if (len > 0) {
      final invLen = 1.0 / len;
      plane.x *= invLen;
      plane.y *= invLen;
      plane.z *= invLen;
      plane.w *= invLen;
    }
  }

  /// Returns the normalized plane equation for [plane].
  Vector4 getNormalizedPlane(FrustumPlane plane) => _planes[plane.index];

  /// Returns all six normalized frustum planes in `left, right, bottom, top, far, near` order.
  List<Vector4> getNormalizedPlanes() => List.unmodifiable(_planes);

  /// Conservative intersection test of an axis-aligned [Box] against the frustum.
  ///
  /// Uses Filament's branch-light p-vertex algorithm from `filament::Culler`.
  /// Never returns false negatives for visible objects.
  bool intersects(Box box) {
    final cx = box.center.x;
    final cy = box.center.y;
    final cz = box.center.z;
    final ex = box.halfExtent.x;
    final ey = box.halfExtent.y;
    final ez = box.halfExtent.z;

    for (int j = 0; j < 6; j++) {
      final p = _planes[j];
      final dot = p.x * cx - p.x.abs() * ex +
                  p.y * cy - p.y.abs() * ey +
                  p.z * cz - p.z.abs() * ez +
                  p.w;
      if (dot > 0) return false;
    }
    return true;
  }

  /// Conservative intersection test of a bounding [sphere] (.xyz center, .w radius) against the frustum.
  bool intersectsSphere(Vector4 sphere) {
    final sx = sphere.x;
    final sy = sphere.y;
    final sz = sphere.z;
    final sr = sphere.w;

    for (int j = 0; j < 6; j++) {
      final p = _planes[j];
      final dot = p.x * sx + p.y * sy + p.z * sz + p.w - sr;
      if (dot > 0) return false;
    }
    return true;
  }

  /// Tests whether [point] is inside or on all 6 frustum planes.
  bool contains(Vector3 point) {
    final px = point.x;
    final py = point.y;
    final pz = point.z;

    for (int j = 0; j < 6; j++) {
      final p = _planes[j];
      final dot = p.x * px + p.y * py + p.z * pz + p.w;
      if (dot > 1e-6) return false;
    }
    return true;
  }

  /// Returns the maximum signed distance of [point] to the frustum (negative if inside).
  double containsDistance(Vector3 point) {
    final px = point.x;
    final py = point.y;
    final pz = point.z;
    double maxDist = -double.infinity;

    for (int j = 0; j < 6; j++) {
      final p = _planes[j];
      final dot = p.x * px + p.y * py + p.z * pz + p.w;
      if (dot > maxDist) maxDist = dot;
    }
    return maxDist;
  }
}
