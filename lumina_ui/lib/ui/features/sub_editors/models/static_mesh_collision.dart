import 'dart:math' as math;

import 'package:lumina_editor_data/lumina_editor.dart' show ConvexHullShape;
import 'package:vector_math/vector_math_64.dart' show Vector3;

enum StaticMeshCollisionShapeType {
  box,
  sphere,
  capsule,
  convex,
}

class StaticMeshCollisionShape {
  final StaticMeshCollisionShapeType type;
  final List<double> center;
  final List<double>? extents; // [halfX, halfY, halfZ] for box
  final double? radius; // for sphere, capsule
  final double? halfHeight; // for capsule
  final String? axis; // 'X', 'Y', 'Z' for capsule
  final List<List<double>>? points; // for convex hull

  const StaticMeshCollisionShape({
    required this.type,
    required this.center,
    this.extents,
    this.radius,
    this.halfHeight,
    this.axis,
    this.points,
  });

  /// The shape as a line list, in its own frame (the editor authors cm, Z
  /// up): `positions` are x, y, z triples, `indices` pairs of them
  /// Circles use [segments] segments.
  ({List<double> positions, List<int> indices}) lineSegments({int segments = 32}) {
    final positions = <double>[];
    final indices = <int>[];
    int add(double x, double y, double z) {
      positions
        ..add(x)
        ..add(y)
        ..add(z);
      return positions.length ~/ 3 - 1;
    }

    final c = center.length >= 3 ? center : const [0.0, 0.0, 0.0];
    // A circle of [r] around [o] in the plane of axes [u] and [v] (0..2),
    // from angle [from] over [sweep] radians.
    void arc(List<double> o, double r, int u, int v, {double from = 0, double sweep = 2 * math.pi, int? steps}) {
      final n = steps ?? segments;
      final closed = sweep >= 2 * math.pi - 1e-9;
      final first = positions.length ~/ 3;
      final count = closed ? n : n + 1;
      for (var i = 0; i < count; i++) {
        final a = from + sweep * i / n;
        final p = [...o];
        p[u] += r * math.cos(a);
        p[v] += r * math.sin(a);
        add(p[0], p[1], p[2]);
      }
      for (var i = 0; i < n; i++) {
        indices
          ..add(first + i)
          ..add(closed ? first + (i + 1) % n : first + i + 1);
      }
    }

    switch (type) {
      case StaticMeshCollisionShapeType.box:
        final e = extents ?? const [0.0, 0.0, 0.0];
        for (var i = 0; i < 8; i++) {
          add(c[0] + (i & 1 == 0 ? -e[0] : e[0]), c[1] + (i & 2 == 0 ? -e[1] : e[1]), c[2] + (i & 4 == 0 ? -e[2] : e[2]));
        }
        for (var i = 0; i < 8; i++) {
          for (final bit in const [1, 2, 4]) {
            if (i & bit == 0) indices.addAll([i, i | bit]);
          }
        }
      case StaticMeshCollisionShapeType.sphere:
        final r = radius ?? 0.0;
        arc(c, r, 0, 1);
        arc(c, r, 0, 2);
        arc(c, r, 1, 2);
      case StaticMeshCollisionShapeType.capsule:
        final r = radius ?? 0.0;
        final hl = halfHeight ?? 0.0;
        final ax = switch ((axis ?? 'Z').toUpperCase()) { 'X' => 0, 'Y' => 1, _ => 2 };
        final others = [for (var i = 0; i < 3; i++) if (i != ax) i];
        final top = [...c]..[ax] += hl;
        final bottom = [...c]..[ax] -= hl;
        arc(top, r, others[0], others[1]);
        arc(bottom, r, others[0], others[1]);
        for (final o in others) {
          for (final sign in const [-1.0, 1.0]) {
            final a = [...bottom]..[o] += sign * r;
            final b = [...top]..[o] += sign * r;
            indices.addAll([add(a[0], a[1], a[2]), add(b[0], b[1], b[2])]);
          }
          // The two hemispheres' arcs in the (other, axis) plane.
          arc(top, r, o, ax, sweep: math.pi, steps: segments ~/ 2);
          arc(bottom, r, o, ax, from: math.pi, sweep: math.pi, steps: segments ~/ 2);
        }
      case StaticMeshCollisionShapeType.convex:
        final pts = [for (final p in points ?? const <List<double>>[]) if (p.length >= 3) Vector3(p[0], p[1], p[2])];
        if (pts.isEmpty) break;
        final hull = ConvexHullShape(pts);
        for (final v in hull.vertices) {
          add(v.x, v.y, v.z);
        }
        final seen = <int>{};
        for (var t = 0; t + 2 < hull.triangles.length; t += 3) {
          for (var k = 0; k < 3; k++) {
            final u = hull.triangles[t + k], v = hull.triangles[t + (k + 1) % 3];
            if (seen.add(math.min(u, v) * 1000003 + math.max(u, v))) indices.addAll([u, v]);
          }
        }
    }
    return (positions: positions, indices: indices);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'center': center,
      if (extents != null) 'extents': extents,
      if (radius != null) 'radius': radius,
      if (halfHeight != null) 'halfHeight': halfHeight,
      if (axis != null) 'axis': axis,
      if (points != null) 'points': points,
    };
  }

  factory StaticMeshCollisionShape.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'box';
    final type = StaticMeshCollisionShapeType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => StaticMeshCollisionShapeType.box,
    );

    final centerRaw = (json['center'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0];
    final extentsRaw = (json['extents'] as List?)?.map((e) => (e as num).toDouble()).toList();
    final radiusRaw = (json['radius'] as num?)?.toDouble();
    final halfHeightRaw = (json['halfHeight'] as num?)?.toDouble();
    final axisRaw = json['axis']?.toString();
    final pointsRaw = (json['points'] as List?)
        ?.map((p) => (p as List).map((c) => (c as num).toDouble()).toList())
        .toList();

    return StaticMeshCollisionShape(
      type: type,
      center: centerRaw,
      extents: extentsRaw,
      radius: radiusRaw,
      halfHeight: halfHeightRaw,
      axis: axisRaw,
      points: pointsRaw,
    );
  }

  static StaticMeshCollisionShape createBox(List<double> minBounds, List<double> maxBounds) {
    final center = [
      (minBounds[0] + maxBounds[0]) * 0.5,
      (minBounds[1] + maxBounds[1]) * 0.5,
      (minBounds[2] + maxBounds[2]) * 0.5,
    ];
    final extents = [
      ((maxBounds[0] - minBounds[0]) * 0.5).abs().clamp(0.01, double.infinity),
      ((maxBounds[1] - minBounds[1]) * 0.5).abs().clamp(0.01, double.infinity),
      ((maxBounds[2] - minBounds[2]) * 0.5).abs().clamp(0.01, double.infinity),
    ];
    return StaticMeshCollisionShape(type: StaticMeshCollisionShapeType.box, center: center, extents: extents);
  }

  static StaticMeshCollisionShape createSphere(List<double> minBounds, List<double> maxBounds) {
    final center = [
      (minBounds[0] + maxBounds[0]) * 0.5,
      (minBounds[1] + maxBounds[1]) * 0.5,
      (minBounds[2] + maxBounds[2]) * 0.5,
    ];
    final halfX = (maxBounds[0] - minBounds[0]) * 0.5;
    final halfY = (maxBounds[1] - minBounds[1]) * 0.5;
    final halfZ = (maxBounds[2] - minBounds[2]) * 0.5;
    final radius = math.sqrt(halfX * halfX + halfY * halfY + halfZ * halfZ).clamp(0.01, double.infinity);
    return StaticMeshCollisionShape(type: StaticMeshCollisionShapeType.sphere, center: center, radius: radius);
  }

  static StaticMeshCollisionShape createCapsule(List<double> minBounds, List<double> maxBounds) {
    final center = [
      (minBounds[0] + maxBounds[0]) * 0.5,
      (minBounds[1] + maxBounds[1]) * 0.5,
      (minBounds[2] + maxBounds[2]) * 0.5,
    ];
    final sizeX = (maxBounds[0] - minBounds[0]).abs();
    final sizeY = (maxBounds[1] - minBounds[1]).abs();
    final sizeZ = (maxBounds[2] - minBounds[2]).abs();

    String domAxis = 'Z';
    double capRadius = math.max(sizeX, sizeY) * 0.5;
    double capHalfHeight = (sizeZ * 0.5 - capRadius).clamp(0.01, double.infinity);

    if (sizeY >= sizeX && sizeY >= sizeZ) {
      domAxis = 'Y';
      capRadius = math.max(sizeX, sizeZ) * 0.5;
      capHalfHeight = (sizeY * 0.5 - capRadius).clamp(0.01, double.infinity);
    } else if (sizeX >= sizeY && sizeX >= sizeZ) {
      domAxis = 'X';
      capRadius = math.max(sizeY, sizeZ) * 0.5;
      capHalfHeight = (sizeX * 0.5 - capRadius).clamp(0.01, double.infinity);
    }

    return StaticMeshCollisionShape(
      type: StaticMeshCollisionShapeType.capsule,
      center: center,
      radius: capRadius.clamp(0.01, double.infinity),
      halfHeight: capHalfHeight,
      axis: domAxis,
    );
  }

  static StaticMeshCollisionShape createConvexHull(List<double> minBounds, List<double> maxBounds, {List<List<double>>? samplePoints}) {
    final center = [
      (minBounds[0] + maxBounds[0]) * 0.5,
      (minBounds[1] + maxBounds[1]) * 0.5,
      (minBounds[2] + maxBounds[2]) * 0.5,
    ];

    // If no sample points provided, construct 8-vertex bounding box points as convex hull base
    final points = samplePoints ?? [
      [minBounds[0], minBounds[1], minBounds[2]],
      [maxBounds[0], minBounds[1], minBounds[2]],
      [maxBounds[0], maxBounds[1], minBounds[2]],
      [minBounds[0], maxBounds[1], minBounds[2]],
      [minBounds[0], minBounds[1], maxBounds[2]],
      [maxBounds[0], minBounds[1], maxBounds[2]],
      [maxBounds[0], maxBounds[1], maxBounds[2]],
      [minBounds[0], maxBounds[1], maxBounds[2]],
    ];

    return StaticMeshCollisionShape(type: StaticMeshCollisionShapeType.convex, center: center, points: points);
  }
}
