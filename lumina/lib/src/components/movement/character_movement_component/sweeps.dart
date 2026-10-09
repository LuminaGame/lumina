part of '../character_movement_component.dart';

/// Capsule sweeps: stepping up, moving up to contact, sliding along
/// surfaces and depenetration.
mixin _CharacterMovementSweeps on _CharacterMovementState {
  /// Attempts to step up over obstacles lower than [maxStepHeight].
  bool stepUp(HitResult wallHit, Vector3 delta) {
    if (updatedComponent == null || owner == null) return false;
    final colSys = owner?.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();
    if (colSys == null) return false;

    final originalLocation = owner!.actorLocation.clone();

    // 1. Sweep Up
    final upDelta = Vector3(0.0, maxStepHeight, 0.0);
    final upHit = HitResult();
    safeMove(upDelta, upHit);

    // 2. Sweep Forward
    final fwdHit = HitResult();
    safeMove(delta, fwdHit);

    // 3. Sweep Down to step surface
    final downDelta = Vector3(0.0, -(maxStepHeight + skinWidth), 0.0);
    final downHit = HitResult();
    safeMove(downDelta, downHit);

    // Check step landing walkability
    if (downHit.blockingHit) {
      final norm = downHit.impactNormal.normalized();
      final cosTheta = norm.dot(Vector3(0.0, 1.0, 0.0)).clamp(-1.0, 1.0);
      final angleDeg = math.acos(cosTheta) * (180.0 / math.pi);

      if (angleDeg <= maxWalkSlopeAngle && owner!.actorLocation.y > originalLocation.y + 0.5) {
        return true;
      }
    }

    // Rollback if step failed
    owner!.actorLocation = originalLocation;
    return false;
  }

  /// Sweeps the character's collision capsule by [delta] and moves the owner up to contact.
  bool safeMove(Vector3 delta, HitResult outHit) {
    final collisionSubsystem = owner?.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();

    if (updatedComponent == null || collisionSubsystem == null) {
      if (owner != null) {
        owner!.actorLocation = owner!.actorLocation + delta;
      }
      outHit.reset();
      return true;
    }

    final shape = updatedComponent!.worldShape;
    final start = updatedComponent!.worldTransform;

    final hit = collisionSubsystem.sweep(
      shape,
      start,
      delta,
      outHit,
      ignore: updatedComponent,
    );

    if (!hit || !outHit.blockingHit) {
      owner?.actorLocation = owner!.actorLocation + delta;
      return true;
    }

    double travelTime = outHit.time;
    final deltaLen = delta.length;
    if (deltaLen > 1e-9) {
      final skinFraction = skinWidth / deltaLen;
      travelTime = math.max(0.0, travelTime - skinFraction);
    }

    final actualStep = delta * travelTime;
    owner?.actorLocation = owner!.actorLocation + actualStep;
    if (enablePhysicsInteraction && (outHit.component?.isSimulatingPhysics ?? false)) {
      final copy = HitResult()
        ..blockingHit = true
        ..time = outHit.time
        ..component = outHit.component;
      copy.impactNormal.setFrom(outHit.impactNormal);
      copy.impactPoint.setFrom(outHit.impactPoint);
      _impacts.add((copy, _velocity.clone()));
    }
    return false;
  }

  /// Deflects movement along blocking surface normals and resolves corners iteratively.
  double slideAlongSurface(
    Vector3 delta,
    double time,
    Vector3 normal,
    HitResult hit, {
    int maxIterations = 3,
    List<Vector3>? outHitNormals,
    bool onGround = false,
  }) {
    var currentDelta = delta;
    var currentTime = time;
    // On the ground an unwalkable face above step height would push the
    // slide up it: treat it as a vertical wall while
    // moving on ground. A face touched within
    // [maxStepHeight] of the feet is a step — a heightfield draws a ledge as
    // one steep cell — and is still ridden.
    final capsule = updatedComponent;
    final feetY = capsule == null ? double.negativeInfinity : capsule.worldLocation.y - capsule.halfHeight;
    Vector3 wallNormal(Vector3 n, Vector3 impactPoint) {
      final unit = n.normalized();
      if (!onGround || unit.y <= 0.0 || unit.y >= math.cos(maxWalkSlopeAngle * math.pi / 180.0)) return unit;
      if (impactPoint.y - feetY <= maxStepHeight) return unit;
      final flat = Vector3(unit.x, 0.0, unit.z);
      return flat.length2 > 1e-12 ? flat.normalized() : unit;
    }

    var firstNormal = wallNormal(normal, hit.impactPoint);
    Vector3? secondNormal;
    var latestNormal = firstNormal;
    var totalConsumedFraction = time;

    outHitNormals?.add(firstNormal);

    for (int iter = 0; iter < maxIterations; iter++) {
      // Two-wall adjust: only a corner of 90° or less (normals facing
      // apart) confines the move to the crease line; a wider crease — a
      // slope steepening under the capsule, cell by cell on a heightfield —
      // slides along the newest surface. Projected onto the crease of two
      // almost parallel ground planes, a move up the slope was lost.
      final creased = secondNormal != null && firstNormal.dot(secondNormal) <= 0.0;
      computeSlideVector(currentDelta, currentTime, creased ? firstNormal : latestNormal, _slideVec);

      if (creased) {
        final crease = firstNormal.cross(secondNormal).normalized();
        if (crease.length2 > 1e-6) {
          final proj = _slideVec.dot(crease);
          _slideVec.setFrom(crease * proj);
        }
      } else if (secondNormal != null && _slideVec.dot(currentDelta) <= 0.0) {
        break; // the new surface turns the move back: stop
      }

      if (_slideVec.length2 < 1e-12) {
        break;
      }

      final slideHit = HitResult();
      final completed = safeMove(_slideVec, slideHit);

      if (completed) {
        totalConsumedFraction = 1.0;
        break;
      } else {
        final newNorm = wallNormal(slideHit.impactNormal, slideHit.impactPoint);
        latestNormal = newNorm;
        outHitNormals?.add(newNorm);
        totalConsumedFraction += (1.0 - totalConsumedFraction) * slideHit.time;
        if (secondNormal == null) {
          secondNormal = newNorm;
        } else {
          firstNormal = newNorm;
        }
        currentDelta = _slideVec;
        currentTime = slideHit.time;
      }
    }

    return totalConsumedFraction;
  }

  /// Pushes the character out of intersecting blocking geometry.
  bool resolvePenetration(ContactResult contact) {
    if (contact.penetrationDepth > 1e-2) {
      final push = math.min(contact.penetrationDepth, maxDepenetrationPerFrame);
      owner?.actorLocation = owner!.actorLocation + (contact.normal * push);
      return true;
    }
    return false;
  }
}
