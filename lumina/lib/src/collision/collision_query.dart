import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/object/actor.dart';

/// Container describing a raycast or geometric sweep impact.
class HitResult {
  bool blockingHit = false;

  /// Fraction [0, 1] of the sweep completed before impact, or distance along ray for raycast.
  double time = 1.0;

  /// Location of the swept object or ray start at impact.
  final Vector3 location = Vector3.zero();

  /// Point of impact in world space.
  final Vector3 impactPoint = Vector3.zero();

  /// Surface normal at impact pointing away from the hit surface.
  final Vector3 impactNormal = Vector3.zero();

  /// Penetration depth for initial overlap or sweep resolution.
  double penetrationDepth = 0.0;

  /// The component that was struck.
  LuminaCollisionComponent? component;

  /// Distance from the trace start to [impactPoint] along the trace, in
  /// world units; 0 when nothing was hit.
  double distance = 0.0;

  /// The normal impulse of a physics contact (kg·cm/s); 0 for
  /// traces and overlap hits.
  double normalImpulse = 0.0;

  /// The actor owning [component].
  LuminaActor? get actor => component?.owner;

  /// Resets this container to default state for pool reuse.
  void reset() {
    blockingHit = false;
    time = 1.0;
    location.setZero();
    impactPoint.setZero();
    impactNormal.setZero();
    penetrationDepth = 0.0;
    distance = 0.0;
    normalImpulse = 0.0;
    component = null;
  }
}
