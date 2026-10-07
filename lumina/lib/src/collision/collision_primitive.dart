import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/math/axes.dart';

/// The kinds of authored primitive simple collision.
enum LuminaCollisionPrimitiveKind { box, sphere, capsule }

/// One authored primitive of a static mesh's simple collision (box, sphere
/// or capsule), as the
/// Static Mesh editor authors it: in the mesh's model space, **centimetres,
/// Z up** (the frame of `metadata.actors`). The generated level
/// carries these as constants and Play-In-Editor builds the same values from
/// the mesh asset; [LuminaAxes] turns them into the runtime's Y-up frame.
class LuminaCollisionPrimitive {
  final LuminaCollisionPrimitiveKind kind;

  /// Centre, cm, Z up.
  final List<double> center;

  /// A box's half extents along the mesh's X, Y, Z (the box is axis-aligned
  /// in the mesh frame). Empty for the other kinds.
  final List<double> halfExtents;

  /// A sphere's or capsule's radius, cm.
  final double radius;

  /// Half a capsule's cylinder, between its caps, cm.
  final double halfLength;

  /// A capsule's axis in the mesh frame: `X`, `Y` or `Z`.
  final String axis;

  const LuminaCollisionPrimitive.box({required this.center, required this.halfExtents})
      : kind = LuminaCollisionPrimitiveKind.box,
        radius = 0,
        halfLength = 0,
        axis = 'Z';

  const LuminaCollisionPrimitive.sphere({required this.center, required this.radius})
      : kind = LuminaCollisionPrimitiveKind.sphere,
        halfExtents = const [],
        halfLength = 0,
        axis = 'Z';

  const LuminaCollisionPrimitive.capsule({
    required this.center,
    required this.radius,
    required this.halfLength,
    this.axis = 'Z',
  })  : kind = LuminaCollisionPrimitiveKind.capsule,
        halfExtents = const [];

  /// [center] in the runtime frame (cm, Y up), unscaled.
  Vector3 get runtimeCenter => LuminaAxes.location(center);

  /// A collision component for this primitive, sized for [runtimeScale] (the
  /// owning actor's scale, runtime axes).
  LuminaCollisionComponent createComponent(Vector3 runtimeScale) {
    final shape = switch (kind) {
      LuminaCollisionPrimitiveKind.box => CollisionShapeType.box,
      LuminaCollisionPrimitiveKind.sphere => CollisionShapeType.sphere,
      LuminaCollisionPrimitiveKind.capsule => CollisionShapeType.capsule,
    };
    final component = LuminaCollisionComponent(shapeType: shape);
    applyTo(component, runtimeScale);
    return component;
  }

  /// Sizes and places [component] for [runtimeScale], scaling
  /// simple collision: a box per axis, a sphere by the smallest |scale|, a
  /// capsule's radius by the smaller cross-axis scale and its length by its
  /// own axis. Child scene components do not inherit their parent's scale,
  /// so the offset is scaled here too.
  void applyTo(LuminaCollisionComponent component, Vector3 runtimeScale) {
    final s = Vector3(runtimeScale.x.abs(), runtimeScale.y.abs(), runtimeScale.z.abs());
    component.relativeLocation = runtimeCenter..multiply(runtimeScale);
    switch (kind) {
      case LuminaCollisionPrimitiveKind.box:
        component.boxExtent = LuminaAxes.scale(halfExtents)..multiply(s);
      case LuminaCollisionPrimitiveKind.sphere:
        component.radius = radius * math.min(s.x, math.min(s.y, s.z));
      case LuminaCollisionPrimitiveKind.capsule:
        // Authored X, Y, Z are runtime x, z, y; lumina's capsule runs along
        // its local +Y.
        final runtimeAxis = switch (axis.toUpperCase()) { 'X' => 0, 'Y' => 2, _ => 1 };
        final cross = [for (var i = 0; i < 3; i++) if (i != runtimeAxis) s[i]];
        final r = radius * math.min(cross[0], cross[1]);
        component.radius = r;
        component.halfHeight = halfLength * s[runtimeAxis] + r;
        component.relativeRotation = switch (runtimeAxis) {
          0 => Quaternion.axisAngle(Vector3(0, 0, 1), -math.pi / 2), // +Y → +X
          2 => Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2), // +Y → +Z
          _ => Quaternion.identity(),
        };
    }
    component.markCollisionDirty();
  }
}
