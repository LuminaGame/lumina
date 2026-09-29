import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../collision/shapes.dart';
import '../math/axes.dart';

/// What a static mesh asset says about its body: the
/// Static Mesh editor's `metadata.physics = {massKg, centerOfMassOffset}`.
/// [centerOfMassOffset] is authoring space (cm, Z up). A collision component
/// inherits it from its actor's static mesh unless it overrides the mass.
class LuminaMeshPhysics {
  final double? massKg;

  /// Authoring `[x, y, z]`, cm, Z up.
  final List<double> centerOfMassOffset;

  const LuminaMeshPhysics({this.massKg, this.centerOfMassOffset = const [0.0, 0.0, 0.0]});

  /// Reads `{massKg, centerOfMassOffset}`; null when [json] is not a map.
  static LuminaMeshPhysics? fromJson(Object? json) {
    if (json is! Map) return null;
    final mass = json['massKg'];
    final com = json['centerOfMassOffset'];
    return LuminaMeshPhysics(
      massKg: mass is num && mass > 0 ? mass.toDouble() : null,
      centerOfMassOffset: com is List && com.length >= 3 && com.every((e) => e is num)
          ? [for (final e in com.take(3)) (e as num).toDouble()]
          : const [0.0, 0.0, 0.0],
    );
  }

  Map<String, dynamic> toJson() => {
        if (massKg != null) 'massKg': massKg,
        'centerOfMassOffset': centerOfMassOffset,
      };

  /// [centerOfMassOffset] in the runtime frame (cm, Y up).
  Vector3 get runtimeCenterOfMassOffset => LuminaAxes.location(centerOfMassOffset);
}

/// Volume, centroid and inertia of one convex shape at unit density: the
/// inertia is **per unit mass** (kg·cm² per kg) about [centroid], in the
/// shape's own frame, so any mass scales it.
class LuminaShapeMass {
  /// cm³.
  final double volume;
  final Vector3 centroid;

  /// Inertia per unit mass about [centroid] (cm²).
  final Matrix3 unitInertia;

  const LuminaShapeMass(this.volume, this.centroid, this.unitInertia);

  static Matrix3 _diag(double x, double y, double z) => Matrix3(x, 0, 0, 0, y, 0, 0, 0, z);

  /// A box of half extents [h] (cm).
  factory LuminaShapeMass.box(Vector3 h) {
    final a = h.x.abs(), b = h.y.abs(), c = h.z.abs();
    return LuminaShapeMass(8 * a * b * c, Vector3.zero(), _diag((b * b + c * c) / 3, (a * a + c * c) / 3, (a * a + b * b) / 3));
  }

  factory LuminaShapeMass.sphere(double r) {
    final i = 0.4 * r * r;
    return LuminaShapeMass(4 / 3 * math.pi * r * r * r, Vector3.zero(), _diag(i, i, i));
  }

  /// A capsule along local +Y: [halfHeight] includes the caps.
  factory LuminaShapeMass.capsule(double r, double halfHeight) {
    final len = 2 * math.max(0.0, halfHeight - r);
    final vc = math.pi * r * r * len;
    final vs = 4 / 3 * math.pi * r * r * r;
    final v = vc + vs;
    final iyy = (vc * r * r / 2 + vs * 0.4 * r * r) / v;
    final ixx = (vc * (len * len / 12 + r * r / 4) + vs * (0.4 * r * r + len * len / 4 + 3 * len * r / 8)) / v;
    return LuminaShapeMass(v, Vector3.zero(), _diag(ixx, iyy, ixx));
  }

  /// A cylinder along local +Y of full [height].
  factory LuminaShapeMass.cylinder(double r, double height) {
    final ixx = (3 * r * r + height * height) / 12;
    return LuminaShapeMass(math.pi * r * r * height, Vector3.zero(), _diag(ixx, r * r / 2, ixx));
  }

  /// A cone along local +Y: base at −[height]/2, apex at +[height]/2.
  factory LuminaShapeMass.cone(double r, double height) {
    final ixx = 3 * r * r / 20 + 3 * height * height / 80;
    return LuminaShapeMass(math.pi * r * r * height / 3, Vector3(0, -height / 4, 0), _diag(ixx, 0.3 * r * r, ixx));
  }

  /// A convex hull, its vertices scaled by [scale]: summed over the
  /// tetrahedra its triangles make with an inner point.
  factory LuminaShapeMass.convex(ConvexHullShape hull, [Vector3? scale]) {
    final s = scale ?? Vector3(1, 1, 1);
    final verts = [for (final v in hull.vertices) Vector3(v.x * s.x, v.y * s.y, v.z * s.z)];
    if (verts.length < 4 || hull.triangles.length < 12) {
      final lo = Vector3.copy(hull.localMin)..multiply(s);
      final hi = Vector3.copy(hull.localMax)..multiply(s);
      final m = LuminaShapeMass.box((hi - lo)..scale(0.5));
      return LuminaShapeMass(m.volume, (lo + hi)..scale(0.5), m.unitInertia);
    }
    final o = Vector3.zero();
    for (final v in verts) {
      o.add(v);
    }
    o.scale(1 / verts.length);
    var volume = 0.0;
    final firstMoment = Vector3.zero();
    final cov = Matrix3.zero();
    void addOuter(Vector3 a, Vector3 b, double w) {
      final st = cov.storage;
      st[0] += w * a.x * b.x;
      st[1] += w * a.y * b.x;
      st[2] += w * a.z * b.x;
      st[3] += w * a.x * b.y;
      st[4] += w * a.y * b.y;
      st[5] += w * a.z * b.y;
      st[6] += w * a.x * b.z;
      st[7] += w * a.y * b.z;
      st[8] += w * a.z * b.z;
    }

    for (var t = 0; t + 2 < hull.triangles.length; t += 3) {
      final a = verts[hull.triangles[t]] - o;
      final b = verts[hull.triangles[t + 1]] - o;
      final c = verts[hull.triangles[t + 2]] - o;
      final v = a.dot(b.cross(c)) / 6;
      volume += v;
      firstMoment.add((a + b + c)..scale(v / 4));
      final sum = a + b + c;
      final w = v / 20;
      addOuter(sum, sum, w);
      addOuter(a, a, w);
      addOuter(b, b, w);
      addOuter(c, c, w);
    }
    if (volume < 0) {
      volume = -volume;
      firstMoment.negate();
      cov.scale(-1.0);
    }
    if (volume < 1e-9) return LuminaShapeMass.box(Vector3.all(1));
    final centroidRel = firstMoment / volume;
    // Second moment about the centroid, then inertia = tr(C)·E − C.
    final st = cov.storage;
    final d = centroidRel;
    st[0] -= volume * d.x * d.x;
    st[1] -= volume * d.y * d.x;
    st[2] -= volume * d.z * d.x;
    st[3] -= volume * d.x * d.y;
    st[4] -= volume * d.y * d.y;
    st[5] -= volume * d.z * d.y;
    st[6] -= volume * d.x * d.z;
    st[7] -= volume * d.y * d.z;
    st[8] -= volume * d.z * d.z;
    final tr = st[0] + st[4] + st[8];
    final inertia = Matrix3(tr - st[0], -st[1], -st[2], -st[3], tr - st[4], -st[5], -st[6], -st[7], tr - st[8])
      ..scale(1 / volume);
    return LuminaShapeMass(volume, o + centroidRel, inertia);
  }
}

/// Mass, centre of mass and inertia of a whole body (kg, cm, kg·cm²), in the
/// body's frame.
class LuminaMassProperties {
  final double mass;
  final Vector3 centerOfMass;

  /// About [centerOfMass], body frame.
  final Matrix3 inertia;

  /// cm³, of all shapes together.
  final double volume;

  const LuminaMassProperties(this.mass, this.centerOfMass, this.inertia, this.volume);

  /// Combines [parts] (each with its pose in the body frame) sharing one
  /// uniform density: [mass] kg in total, the centre of mass moved by
  /// [centerOfMassOffset] (body frame).
  static LuminaMassProperties combine(
    List<({LuminaShapeMass mass, Vector3 position, Quaternion rotation})> parts, {
    required double mass,
    Vector3? centerOfMassOffset,
  }) {
    var volume = 0.0;
    for (final p in parts) {
      volume += p.mass.volume;
    }
    if (parts.isEmpty || volume <= 0) {
      final i = mass * 100.0;
      return LuminaMassProperties(mass, centerOfMassOffset?.clone() ?? Vector3.zero(), Matrix3(i, 0, 0, 0, i, 0, 0, 0, i), 0);
    }
    final com = Vector3.zero();
    final centroids = <Vector3>[];
    for (final p in parts) {
      final c = p.position + p.rotation.asRotationMatrix().transformed(p.mass.centroid);
      centroids.add(c);
      com.add(c * (p.mass.volume / volume));
    }
    final inertia = Matrix3.zero();
    for (var k = 0; k < parts.length; k++) {
      final p = parts[k];
      final m = mass * p.mass.volume / volume;
      final r = p.rotation.asRotationMatrix();
      // R · (m Î) · Rᵀ
      final rotated = r.multiplied(p.mass.unitInertia.scaled(m))..multiply(r.transposed());
      inertia.add(rotated);
      final d = centroids[k] - com;
      final d2 = d.length2;
      inertia.add(Matrix3(
        m * (d2 - d.x * d.x), -m * d.x * d.y, -m * d.x * d.z,
        -m * d.y * d.x, m * (d2 - d.y * d.y), -m * d.y * d.z,
        -m * d.z * d.x, -m * d.z * d.y, m * (d2 - d.z * d.z),
      ));
    }
    if (centerOfMassOffset != null && centerOfMassOffset.length2 > 0) {
      // The offset moves the point the body turns about; the inertia is
      // kept about it (only the centre of mass shifts).
      com.add(centerOfMassOffset);
    }
    return LuminaMassProperties(mass, com, inertia, volume);
  }
}
