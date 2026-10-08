import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/collision/collision_component.dart';

/// What a traversal action does with an obstacle.
enum LuminaTraversalActionType {
  none,

  /// Over a low, thin obstacle onto the floor behind it.
  hurdle,

  /// Over a low, thin obstacle with no floor within reach behind it (the
  /// character falls after).
  vault,

  /// Up onto the obstacle's top.
  mantle;

  /// The Blueprint name ('None', 'Hurdle', 'Vault', 'Mantle').
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  static LuminaTraversalActionType parse(String? s) =>
      values.firstWhere((v) => v.name == s?.toLowerCase(), orElse: () => none);
}

/// What [LuminaTraversalCheck.run] measured (runtime axes, world units: Y up,
/// cm). Heights are above the character's feet.
class LuminaTraversalCheckResult {
  bool hasFrontLedge = false;
  bool hasBackLedge = false;
  bool hasBackFloor = false;

  /// Room to stand on the obstacle's top just behind the front ledge.
  bool hasRoomOnTop = false;

  /// The top front edge, at the top's height, on the face the character
  /// runs into; [frontLedgeNormal] points out of that face (horizontal).
  final Vector3 frontLedge = Vector3.zero();
  final Vector3 frontLedgeNormal = Vector3.zero();

  /// The top back edge (along −[frontLedgeNormal]).
  final Vector3 backLedge = Vector3.zero();

  /// Where the feet land behind the obstacle.
  final Vector3 backFloor = Vector3.zero();

  /// Top above the feet, top front-to-back depth, and top above the back
  /// floor.
  double obstacleHeight = 0.0;
  double obstacleDepth = 0.0;
  double backLedgeHeight = 0.0;

  /// The character's horizontal speed when checked.
  double speed = 0.0;

  LuminaCollisionComponent? obstacle;
  LuminaTraversalActionType actionType = LuminaTraversalActionType.none;

  /// Why no action fits, when [actionType] is none.
  String reason = '';

  /// The world yaw facing into the obstacle (0 = +Z, toward +X positive).
  double get facingYaw => math.atan2(-frontLedgeNormal.x, -frontLedgeNormal.z);

  @override
  String toString() => 'traversal ${actionType.label}${reason.isEmpty ? '' : ' ($reason)'}: '
      'height ${obstacleHeight.toStringAsFixed(1)}, depth ${obstacleDepth.toStringAsFixed(1)}, '
      'back ledge height ${backLedgeHeight.toStringAsFixed(1)}, front $hasFrontLedge, back $hasBackLedge, '
      'floor $hasBackFloor, room $hasRoomOnTop';
}

/// Finds and measures the obstacle in front of a character with collision
/// queries and classifies it:
///
/// 1. a capsule ([traceRadius], [traceHalfHeight]) swept forward from the
///    character (farther the faster it moves) hits a near-vertical face;
/// 2. a ray down from above finds the top: the front ledge and the obstacle
///    height ([minLedgeHeight]–[maxLedgeHeight] above the feet);
/// 3. the character's capsule must be able to rise in front of the ledge;
/// 4. rays marching down across the top find the back edge (the depth),
///    then the capsule must be able to cross the top;
/// 5. the capsule swept down behind the back ledge finds the back floor
///    (within [backFloorReach] below the character's floor);
/// 6. the rules: hurdle — back floor, depth < [thinDepth], back ledge
///    height ≥ [hurdleDrop]; mantle — back floor no more than
///    [mantleStepDrop] below the top, or depth ≥ [thinDepth]; vault — no
///    back floor and depth < [thinDepth]. A mantle needs room on top.
class LuminaTraversalCheck {
  double traceRadius = 30.0;
  double traceHalfHeight = 60.0;

  /// Forward trace length at rest and at [fastSpeed].
  double minTraceDistance = 75.0;
  double maxTraceDistance = 350.0;
  double fastSpeed = 500.0;

  double minLedgeHeight = 50.0;
  double maxLedgeHeight = 275.0;

  /// How far across the top the back edge is searched.
  double maxDepthScan = 150.0;

  double thinDepth = 59.0;
  double hurdleDrop = 50.0;
  double mantleStepDrop = 10.0;
  double backFloorReach = 20.0;

  /// The largest |normal.y| of a face that counts as a wall.
  double maxWallSlope = 0.5;

  /// The character's capsule.
  final double capsuleRadius;
  final double capsuleHalfHeight;

  LuminaTraversalCheck({required this.capsuleRadius, required this.capsuleHalfHeight});

  /// The forward trace length at horizontal [speed].
  double traceDistanceFor(double speed) {
    final a = (speed / fastSpeed).clamp(0.0, 1.0);
    return minTraceDistance + (maxTraceDistance - minTraceDistance) * a;
  }

  /// Checks the obstacle ahead of a character at [location] (its capsule
  /// centre) facing [forward] (horizontal) at horizontal [speed], ignoring
  /// [ignore] (its own capsule).
  LuminaTraversalCheckResult run(
    LuminaCollisionSubsystem collision, {
    required Vector3 location,
    required Vector3 forward,
    double speed = 0.0,
    LuminaCollisionComponent? ignore,
  }) {
    final r = LuminaTraversalCheckResult()..speed = speed;
    final f = Vector3(forward.x, 0.0, forward.z);
    if (f.length2 < 1e-9) return r..reason = 'no facing';
    f.normalize();
    final up = Vector3(0.0, 1.0, 0.0);
    final feetY = location.y - capsuleHalfHeight;
    final hit = HitResult();

    // 1. The face ahead.
    final probe = CapsuleShape(traceRadius, traceHalfHeight);
    final distance = traceDistanceFor(speed);
    if (!collision.sweep(probe, Matrix4.translation(location), f * distance, hit, ignore: ignore) || !hit.blockingHit) {
      return r..reason = 'nothing ahead';
    }
    if (hit.impactNormal.y.abs() > maxWallSlope) return r..reason = 'not a wall';
    final normal = Vector3(hit.impactNormal.x, 0.0, hit.impactNormal.z)..normalize();
    r.obstacle = hit.component;
    // The face precisely, with a ray into it at the contact height (clamped
    // to the probe's reach above the feet).
    final contactY = hit.impactPoint.y.clamp(feetY + 1.0, location.y + traceHalfHeight).toDouble();
    final rayStart = Vector3(location.x, contactY, location.z);
    final face = collision.raycast(rayStart, -normal, distance + traceRadius + capsuleRadius + 50.0, hit, ignore: ignore)
        ? hit.impactPoint.clone()
        : Vector3(hit.impactPoint.x, contactY, hit.impactPoint.z);

    // 2. The top.
    final tooHigh = Vector3(face.x + normal.x * 5.0, feetY + maxLedgeHeight + 5.0, face.z + normal.z * 5.0);
    if (collision.raycast(tooHigh, -normal, 10.0, hit, ignore: ignore)) return r..reason = 'higher than ${maxLedgeHeight.round()}';
    final above = Vector3(face.x - normal.x * 2.0, feetY + maxLedgeHeight + 25.0, face.z - normal.z * 2.0);
    if (!collision.raycast(above, -up, maxLedgeHeight + 25.0, hit, ignore: ignore) || hit.impactNormal.y < 0.7) {
      return r..reason = 'no top';
    }
    final topY = hit.impactPoint.y;
    r.obstacleHeight = topY - feetY;
    if (r.obstacleHeight < minLedgeHeight) return r..reason = 'lower than ${minLedgeHeight.round()}';
    r.frontLedge.setValues(face.x, topY, face.z);
    r.frontLedgeNormal.setFrom(normal);

    // 3. Room to rise in front of the ledge.
    final cr = capsuleRadius, chh = capsuleHalfHeight;
    final capsule = CapsuleShape(cr, chh);
    final frontRoom = r.frontLedge + normal * (cr + 2.0) + up * (chh + 2.0);
    if (collision.sweep(capsule, Matrix4.translation(location), frontRoom - location, hit, ignore: ignore) && hit.blockingHit) {
      return r..reason = 'no room to rise';
    }
    r.hasFrontLedge = true;

    // Room to stand on top just behind the ledge.
    final onTop = r.frontLedge - normal * (cr + 4.0) + up * (chh + 2.0);
    final overlaps = <LuminaCollisionComponent>[];
    collision.overlapTest(capsule, Matrix4.translation(onTop), overlaps, ignore: ignore);
    r.hasRoomOnTop = overlaps.every((c) => identical(c, ignore) || !c.collisionEnabled);

    // 4. The back edge.
    bool onTopAt(double s) {
      final from = r.frontLedge - normal * s + up * 30.0;
      return collision.raycast(from, -up, 60.0, hit, ignore: ignore) && (hit.impactPoint.y - topY).abs() < 8.0;
    }

    double? edge;
    var previous = 0.0;
    for (var s = 4.0; s <= maxDepthScan + 1e-9; s += 4.0) {
      if (!onTopAt(s)) {
        var lo = previous, hi = s;
        for (var i = 0; i < 6; i++) {
          final mid = (lo + hi) / 2;
          if (onTopAt(mid)) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        edge = (lo + hi) / 2;
        break;
      }
      previous = s;
    }
    if (edge == null) {
      r.obstacleDepth = maxDepthScan;
    } else {
      r.obstacleDepth = edge;
      r.backLedge.setFrom(r.frontLedge - normal * edge);
      final backRoom = r.backLedge - normal * (cr + 2.0) + up * (chh + 2.0);
      if (collision.sweep(capsule, Matrix4.translation(frontRoom), backRoom - frontRoom, hit, ignore: ignore) &&
          hit.blockingHit) {
        final at = frontRoom + (backRoom - frontRoom) * hit.time;
        r.obstacleDepth = math.max(0.0, Vector2(at.x - r.frontLedge.x, at.z - r.frontLedge.z).length - cr);
      } else {
        r.hasBackLedge = true;
        // 5. The back floor.
        final reach = r.obstacleHeight + 2.0 + backFloorReach;
        if (collision.sweep(capsule, Matrix4.translation(backRoom), -up * reach, hit, ignore: ignore) &&
            hit.blockingHit &&
            hit.impactNormal.y > 0.7) {
          final centre = backRoom - up * (reach * hit.time);
          r.hasBackFloor = true;
          r.backFloor.setValues(backRoom.x, centre.y - chh, backRoom.z);
          r.backLedgeHeight = topY - r.backFloor.y;
        }
      }
    }

    _classify(r);
    return r;
  }

  void _classify(LuminaTraversalCheckResult r) {
    final thin = r.obstacleDepth < thinDepth;
    LuminaTraversalActionType type;
    if (r.hasBackLedge && r.hasBackFloor && thin && r.backLedgeHeight >= hurdleDrop) {
      type = LuminaTraversalActionType.hurdle;
    } else if (r.hasBackLedge && r.hasBackFloor && thin && r.backLedgeHeight <= mantleStepDrop) {
      type = LuminaTraversalActionType.mantle;
    } else if (r.hasBackLedge && !r.hasBackFloor && thin) {
      type = LuminaTraversalActionType.vault;
    } else if (!thin) {
      type = LuminaTraversalActionType.mantle;
    } else {
      type = LuminaTraversalActionType.none;
      r.reason = 'no rule fits';
    }
    if (type == LuminaTraversalActionType.mantle && !r.hasRoomOnTop) {
      type = LuminaTraversalActionType.none;
      r.reason = 'no room on top';
    }
    r.actionType = type;
  }
}
