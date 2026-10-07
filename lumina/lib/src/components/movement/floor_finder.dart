import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/collision/capsule_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';

/// Holds the results of a character floor finding sweep.
class FloorResult {
  bool blockingHit = false;
  bool isWalkable = false;
  double floorDistance = 0.0;
  final Vector3 impactNormal = Vector3(0.0, 1.0, 0.0);
  final Vector3 impactPoint = Vector3.zero();
  LuminaCollisionComponent? floorComponent;

  void reset() {
    blockingHit = false;
    isWalkable = false;
    floorDistance = 0.0;
    impactNormal.setValues(0.0, 1.0, 0.0);
    impactPoint.setZero();
    floorComponent = null;
  }

  void copyFrom(FloorResult other) {
    blockingHit = other.blockingHit;
    isWalkable = other.isWalkable;
    floorDistance = other.floorDistance;
    impactNormal.setFrom(other.impactNormal);
    impactPoint.setFrom(other.impactPoint);
    floorComponent = other.floorComponent;
  }
}

/// Sweeps [capsule] downwards to locate and test the floor surface underfoot.
bool findFloor(
  LuminaCapsuleComponent capsule,
  LuminaCollisionSubsystem collisionSubsystem,
  double maxStepHeight,
  double maxWalkSlopeAngle,
  double skinWidth,
  FloorResult out,
) {
  out.reset();

  final start = capsule.worldTransform.clone();
  final startLoc = capsule.worldLocation + Vector3(0.0, skinWidth, 0.0);
  start.setTranslation(startLoc);

  final totalSweepLength = maxStepHeight + (skinWidth * 3.0);
  final sweepDelta = Vector3(0.0, -totalSweepLength, 0.0);

  var hit = HitResult();
  var didHit = collisionSubsystem.sweep(
    capsule.worldShape,
    start,
    sweepDelta,
    hit,
    ignore: capsule,
  );

  // A hit at the rim of the capsule is a wall it is touching (a cliff it
  // walks into), not the ground under it. Sweep again with a slightly
  // thinner capsule that clears that wall; a steep face under the capsule's bottom is still found.
  final atRim = didHit && hit.blockingHit && !_withinEdgeTolerance(capsule, hit.impactPoint);
  if (atRim) {
    final thinner = HitResult();
    final thinHit = collisionSubsystem.sweep(
      CapsuleShape(math.max(0.0, capsule.radius - _edgeShrink), capsule.halfHeight),
      start,
      sweepDelta,
      thinner,
      ignore: capsule,
    );
    if (!thinHit || !thinner.blockingHit || _slopeDegrees(thinner.impactNormal) < _slopeDegrees(hit.impactNormal)) {
      hit = thinner;
      didHit = thinHit;
    }
  }

  if (didHit && hit.blockingHit) {
    out.blockingHit = true;
    out.floorComponent = hit.component;
    out.impactNormal.setFrom(hit.impactNormal);
    out.impactPoint.setFrom(hit.impactPoint);

    final sweepDist = totalSweepLength * hit.time;
    out.floorDistance = math.max(0.0, sweepDist - skinWidth);

    out.isWalkable = _slopeDegrees(hit.impactNormal) <= maxWalkSlopeAngle;
    if (!out.isWalkable && atRim) {
      // A face that leans away as it rises (a heightfield cliff) still meets
      // the thinner capsule lower down: then trace a line
      // down the capsule's axis and stand on what it finds when walkable.
      _lineTraceFloor(capsule, collisionSubsystem, startLoc, totalSweepLength, maxWalkSlopeAngle, skinWidth, out);
    }
    return true;
  }

  return false;
}

/// Replaces [out] with a walkable floor straight under [capsule]'s axis, if
/// a line trace from [startLoc] (the capsule centre lifted by [skinWidth])
/// finds one within the floor sweep's reach below the capsule's bottom.
void _lineTraceFloor(
  LuminaCapsuleComponent capsule,
  LuminaCollisionSubsystem collisionSubsystem,
  Vector3 startLoc,
  double sweepLength,
  double maxWalkSlopeAngle,
  double skinWidth,
  FloorResult out,
) {
  final bottom = capsule.halfHeight; // unscaled, like the sweep's `worldShape`
  final hit = HitResult();
  final found = collisionSubsystem.lineTraceSingle(
    start: startLoc,
    end: startLoc - Vector3(0.0, bottom + sweepLength, 0.0),
    out: hit,
    ignoreComponents: [capsule],
  );
  if (!found || !hit.blockingHit || _slopeDegrees(hit.impactNormal) > maxWalkSlopeAngle) return;
  out.blockingHit = true;
  out.isWalkable = true;
  out.floorComponent = hit.component;
  out.impactNormal.setFrom(hit.impactNormal);
  out.impactPoint.setFrom(hit.impactPoint);
  out.floorDistance = math.max(0.0, (startLoc.y - hit.impactPoint.y) - bottom - skinWidth);
}

/// How far inside the capsule's rim a floor hit must lie, and how much
/// thinner the retry capsule is (cm), enough to cover the character's skin
/// width.
const double _edgeTolerance = 0.5;
const double _edgeShrink = 1.0;

/// Whether [impactPoint] lies under the capsule rather than at its rim.
bool _withinEdgeTolerance(LuminaCapsuleComponent capsule, Vector3 impactPoint) {
  final centre = capsule.worldLocation;
  final dx = impactPoint.x - centre.x;
  final dz = impactPoint.z - centre.z;
  final reach = math.max(0.0, capsule.radius - _edgeTolerance);
  return dx * dx + dz * dz <= reach * reach;
}

double _slopeDegrees(Vector3 normal) {
  final norm = normal.length2 > 1e-12 ? normal.normalized() : Vector3(0.0, 1.0, 0.0);
  return math.acos(norm.dot(Vector3(0.0, 1.0, 0.0)).clamp(-1.0, 1.0)) * (180.0 / math.pi);
}
