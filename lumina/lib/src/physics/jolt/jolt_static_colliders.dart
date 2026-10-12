import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/physics/jolt/jolt_body_shapes.dart';
import 'package:lumina/src/physics/jolt/jolt_collision_profiles.dart';
import 'package:lumina/src/physics/physical_material.dart';

class _Static {
  _Static(this.id, this.signature);
  final int id;
  List<Object?> signature;
  final Vector3 location = Vector3.zero();
  Quaternion rotation = Quaternion.identity();
  int profile = -1;
  LuminaPhysicalMaterial? material;
}

/// The world's non-simulating collision components (level geometry, a
/// character's capsule, the landscape heightfield) as static Jolt bodies:
/// created when they appear, moved when their component moves, rebuilt when
/// their shape changes, removed when they go.
class LuminaJoltStaticColliders {
  LuminaJoltStaticColliders(this.world, this.profiles, this.ownerId);

  final JoltWorld world;
  final LuminaJoltCollisionProfiles profiles;

  /// The owner group of an actor (0: none).
  final int Function(LuminaCollisionComponent component) ownerId;

  final Map<LuminaCollisionComponent, _Static> _bodies = {};

  /// Jolt body id → component.
  final Map<int, LuminaCollisionComponent> byBody = {};

  int get length => _bodies.length;

  /// Brings the static bodies in line with [colliders] (components that
  /// simulate are skipped: they are bodies themselves).
  void sync(List<LuminaCollisionComponent> colliders) {
    final seen = <LuminaCollisionComponent>{};
    for (final c in colliders) {
      if (c.physicsBody != null) continue;
      seen.add(c);
      final signature = _signature(c);
      var s = _bodies[c];
      if (s != null && !_same(s.signature, signature)) {
        _remove(c);
        s = null;
      }
      final location = c.worldLocation;
      final rotation = c.worldRotation;
      if (s == null) {
        final shape = LuminaJoltShapes.forCollider(c);
        if (shape == null) continue;
        shape.userData = 0;
        final id = world.createBody(
          shape,
          JoltBodySettings(
            motionType: JoltMotionType.static_,
            position: toJolt(location),
            rotation: rotation.normalized(),
            startActive: false,
          ),
        );
        shape.release();
        s = _Static(id, signature);
        s.location.setFrom(location);
        s.rotation = rotation.clone();
        _bodies[c] = s;
        byBody[id] = c;
        world.setBodyOwner(id, ownerId(c));
      } else if (location.distanceToSquared(s.location) > 1e-8 || !_sameRotation(rotation, s.rotation)) {
        world.setBodyTransform(s.id, toJolt(location), rotation.normalized(), activate: false);
        s.location.setFrom(location);
        s.rotation = rotation.clone();
      }
      final profile = profiles.profileOf(c);
      if (profile != s.profile) {
        world.setBodyProfiles(s.id, [profile]);
        s.profile = profile;
      }
      final material = c.effectivePhysicalMaterial;
      if (!identical(material, s.material) && material != s.material) {
        world.setBodyMaterial(
          s.id,
          friction: material.friction,
          staticFriction: material.effectiveStaticFriction,
          restitution: material.restitution,
          frictionMode: JoltCombineMode.values[material.frictionCombineMode.index],
          restitutionMode: JoltCombineMode.values[material.restitutionCombineMode.index],
        );
        s.material = material;
      }
    }
    for (final c in _bodies.keys.where((c) => !seen.contains(c)).toList()) {
      _remove(c);
    }
  }

  void _remove(LuminaCollisionComponent c) {
    final s = _bodies.remove(c);
    if (s == null) return;
    byBody.remove(s.id);
    world.destroyBody(s.id);
  }

  /// Removes every static body.
  void clear() {
    for (final c in _bodies.keys.toList()) {
      _remove(c);
    }
  }

  static bool _sameRotation(Quaternion a, Quaternion b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs() + (a.z - b.z).abs() + (a.w - b.w).abs() < 1e-7;

  static List<Object?> _signature(LuminaCollisionComponent c) {
    final s = c.relativeScale;
    final shape = c.worldShape;
    return [
      c.shapeType,
      c.radius,
      c.halfHeight,
      c.height,
      c.boxExtent.x,
      c.boxExtent.y,
      c.boxExtent.z,
      s.x,
      s.y,
      s.z,
      if (shape is ConvexHullShape || shape is HeightfieldShape) shape,
      if (shape is HeightfieldShape) shape.data,
    ];
  }

  static bool _same(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x is double || x is int || x is Enum) {
        if (x != y) return false;
      } else if (!identical(x, y)) {
        return false;
      }
    }
    return true;
  }
}
