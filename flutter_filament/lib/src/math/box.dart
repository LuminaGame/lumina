import 'dart:math' as math;
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';

/// An axis-aligned 3D box represented by its [center] and [halfExtent].
///
/// Direct pure-Dart reimplementation of `filament::Box`.
class Box {
  /// Center coordinates of the box.
  Vector3 center;

  /// Half extent from the center along each of the 3 axes.
  Vector3 halfExtent;

  Box({Vector3? center, Vector3? halfExtent})
      : center = center ?? Vector3.zero(),
        halfExtent = halfExtent ?? Vector3.zero();

  /// Constructs a [Box] from minimum and maximum corner points.
  factory Box.fromMinMax(Vector3 min, Vector3 max) {
    final box = Box();
    box.set(min, max);
    return box;
  }

  /// Whether the box is empty (i.e. its extents are zero).
  bool get isEmpty => halfExtent.length2 == 0;

  /// Computes the lowest coordinate corner of the box (`center - halfExtent`).
  Vector3 get min => center - halfExtent;

  /// Computes the highest coordinate corner of the box (`center + halfExtent`).
  Vector3 get max => center + halfExtent;

  /// Initializes the 3D box from its [min] and [max] coordinates on each axis.
  Box set(Vector3 min, Vector3 max) {
    center = (max + min) * 0.5;
    halfExtent = (max - min) * 0.5;
    return this;
  }

  /// In-place computes the bounding box of the union of this box and [box].
  Box unionSelf(Box box) {
    final newMin = Vector3(
      math.min(min.x, box.min.x),
      math.min(min.y, box.min.y),
      math.min(min.z, box.min.z),
    );
    final newMax = Vector3(
      math.max(max.x, box.max.x),
      math.max(max.y, box.max.y),
      math.max(max.z, box.max.z),
    );
    return set(newMin, newMax);
  }

  /// Translates the box to a given [center] position, preserving extents.
  Box translateTo(Vector3 center) {
    return Box(center: center.clone(), halfExtent: halfExtent.clone());
  }

  /// Computes the smallest bounding sphere of the box.
  ///
  /// Returns a [Vector4] with (.xyz) as center and (.w) as radius.
  Vector4 getBoundingSphere() {
    return Vector4(center.x, center.y, center.z, halfExtent.length);
  }

  /// Transforms a [Box] by a linear 3x3 transform [m] and translation [t].
  static Box transform(Matrix3 m, Vector3 t, Box box) {
    final newCenter = m * box.center + t;
    final absM = Matrix3(
      m.entry(0, 0).abs(), m.entry(1, 0).abs(), m.entry(2, 0).abs(),
      m.entry(0, 1).abs(), m.entry(1, 1).abs(), m.entry(2, 1).abs(),
      m.entry(0, 2).abs(), m.entry(1, 2).abs(), m.entry(2, 2).abs(),
    );
    final newHalfExtent = absM * box.halfExtent;
    return Box(center: newCenter, halfExtent: newHalfExtent);
  }

  /// Rigidly transforms a [box] by a 4x4 matrix [m].
  static Box rigidTransform(Box box, Matrix4 m) {
    final upperLeft = Matrix3.zero();
    for (int col = 0; col < 3; col++) {
      for (int row = 0; row < 3; row++) {
        upperLeft.setEntry(row, col, m.entry(row, col));
      }
    }
    final t = Vector3(m.entry(0, 3), m.entry(1, 3), m.entry(2, 3));
    return transform(upperLeft, t, box);
  }

  /// Serializes center and halfExtent into a 6-float buffer for FFI marshalling.
  Float32List toFloat32List() {
    final list = Float32List(6);
    list[0] = center.x;
    list[1] = center.y;
    list[2] = center.z;
    list[3] = halfExtent.x;
    list[4] = halfExtent.y;
    list[5] = halfExtent.z;
    return list;
  }

  /// Deserializes a [Box] from a 6-float buffer.
  factory Box.fromFloat32List(Float32List list) {
    return Box(
      center: Vector3(list[0], list[1], list[2]),
      halfExtent: Vector3(list[3], list[4], list[5]),
    );
  }

  @override
  String toString() => 'Box(center: $center, halfExtent: $halfExtent)';
}

/// An axis-aligned bounding box represented by its [min] and [max] coordinates.
///
/// Direct pure-Dart reimplementation of `filament::Aabb`.
class Aabb {
  /// Minimum coordinate corner.
  Vector3 min;

  /// Maximum coordinate corner.
  Vector3 max;

  /// Creates an [Aabb]. Defaults to the empty sentinel (+∞ min, -∞ max).
  Aabb({Vector3? min, Vector3? max})
      : min = min ?? Vector3.all(double.infinity),
        max = max ?? Vector3.all(-double.infinity);

  /// Computes the center of the box `(max + min) * 0.5`.
  Vector3 get center => (max + min) * 0.5;

  /// Computes the half-extent of the box `(max - min) * 0.5`.
  Vector3 get extent => (max - min) * 0.5;

  /// Whether the box is empty (i.e. its volume is null or negative).
  bool get isEmpty =>
      min.x >= max.x || min.y >= max.y || min.z >= max.z;

  /// Returns the 8 corner vertices of the AABB in Filament's exact order:
  ///
  /// `[---, +--, -+-, ++-, --+, +-+, -++, +++]`
  List<Vector3> getCorners() {
    return [
      Vector3(min.x, min.y, min.z),
      Vector3(max.x, min.y, min.z),
      Vector3(min.x, max.y, min.z),
      Vector3(max.x, max.y, min.z),
      Vector3(min.x, min.y, max.z),
      Vector3(max.x, min.y, max.z),
      Vector3(min.x, max.y, max.z),
      Vector3(max.x, max.y, max.z),
    ];
  }

  /// Computes the maximum signed distance from [p] to the box.
  ///
  /// Returns a negative value if [p] is strictly inside the box.
  double contains(Vector3 p) {
    double d = min.x - p.x;
    if (min.y - p.y > d) d = min.y - p.y;
    if (min.z - p.z > d) d = min.z - p.z;
    if (p.x - max.x > d) d = p.x - max.x;
    if (p.y - max.y > d) d = p.y - max.y;
    if (p.z - max.z > d) d = p.z - max.z;
    return d;
  }

  /// Transforms this [Aabb] by an affine transformation using Jim Arvo's method.
  Aabb transform(Matrix3 m, Vector3 t) {
    if (isEmpty) {
      return Aabb();
    }
    final resultMin = t.clone();
    final resultMax = t.clone();
    for (int col = 0; col < 3; ++col) {
      for (int row = 0; row < 3; ++row) {
        final entry = m.entry(row, col);
        final a = entry * min[col];
        final b = entry * max[col];
        resultMin[row] += a < b ? a : b;
        resultMax[row] += a < b ? b : a;
      }
    }
    return Aabb(min: resultMin, max: resultMax);
  }

  /// Transforms this [Aabb] by a 4x4 matrix [m].
  Aabb transformMat4(Matrix4 m) {
    if (isEmpty) {
      return Aabb();
    }
    final upperLeft = Matrix3.zero();
    for (int col = 0; col < 3; col++) {
      for (int row = 0; row < 3; row++) {
        upperLeft.setEntry(row, col, m.entry(row, col));
      }
    }
    final t = Vector3(m.entry(0, 3), m.entry(1, 3), m.entry(2, 3));
    return transform(upperLeft, t);
  }

  @override
  String toString() => 'Aabb(min: $min, max: $max)';
}
