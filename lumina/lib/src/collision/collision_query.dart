import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/object/actor.dart';

/// Container describing a raycast or geometric sweep impact.
///
/// For a line trace (a ray) [location] equals [impactPoint] and [normal]
/// equals [impactNormal]. For a shape sweep [location] is the shape's centre
/// when it touched, [impactPoint] the contact on the hit surface and [normal]
/// the direction from the contact back to the shape's core.
class HitResult {
  bool blockingHit = false;

  /// Fraction [0, 1] of the trace from [traceStart] to [traceEnd] completed
  /// before impact (1 when nothing was hit).
  double time = 1.0;

  /// Where the traced ray or swept shape's centre stopped: the impact point
  /// for a line trace, the shape's centre at contact for a sweep.
  final Vector3 location = Vector3.zero();

  /// Point of impact in world space.
  final Vector3 impactPoint = Vector3.zero();

  /// Surface normal at impact pointing away from the hit surface.
  final Vector3 impactNormal = Vector3.zero();

  /// The swept shape's normal at the contact (from [impactPoint] towards the
  /// shape's core); equals [impactNormal] for a line trace.
  final Vector3 normal = Vector3.zero();

  /// Where the trace or sweep started (its centre for a sweep).
  final Vector3 traceStart = Vector3.zero();

  /// Where the trace or sweep would have ended without a hit.
  final Vector3 traceEnd = Vector3.zero();

  /// Penetration depth for initial overlap or sweep resolution.
  double penetrationDepth = 0.0;

  /// The component that was struck.
  LuminaCollisionComponent? component;

  /// Distance from [traceStart] to [location] along the trace, in world
  /// units (to [impactPoint] for a line trace); 0 when nothing was hit.
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
    normal.setZero();
    traceStart.setZero();
    traceEnd.setZero();
    penetrationDepth = 0.0;
    distance = 0.0;
    normalImpulse = 0.0;
    component = null;
  }

  /// Copies every field of [other] into this container.
  void copyFrom(HitResult other) {
    blockingHit = other.blockingHit;
    time = other.time;
    location.setFrom(other.location);
    impactPoint.setFrom(other.impactPoint);
    impactNormal.setFrom(other.impactNormal);
    normal.setFrom(other.normal);
    traceStart.setFrom(other.traceStart);
    traceEnd.setFrom(other.traceEnd);
    penetrationDepth = other.penetrationDepth;
    distance = other.distance;
    normalImpulse = other.normalImpulse;
    component = other.component;
  }
}
