part of '../character_movement_component.dart';

/// Per-mode physics integration and the move pipeline.
mixin _CharacterMovementModes
    on _CharacterMovementState, _CharacterMovementSweeps, _CharacterMovementPhysicsInteraction {
  /// Physics integration for [MovementMode.walking].
  void physWalking(double dt, Vector3 input) {
    final colSys = owner?.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();

    if (updatedComponent != null && colSys != null) {
      findFloor(updatedComponent!, colSys, maxStepHeight, maxWalkSlopeAngle, skinWidth, currentFloor);
      if (!currentFloor.blockingHit || !currentFloor.isWalkable) {
        setMovementMode(MovementMode.falling);
        physFalling(dt, input);
        return;
      }
      // Walking velocity stays horizontal: a slide along a wall the character
      // pushes into must not build up a climb over the ticks.
      _velocity.y = 0.0;
    }

    calcVelocity(dt, input);

    // Ground snap if walking down ramps
    if (isGrounded && currentFloor.floorDistance > 1e-2 && currentFloor.floorDistance <= maxStepHeight) {
      safeMove(Vector3(0.0, -currentFloor.floorDistance, 0.0), HitResult());
    }

    final desired = (_velocity * dt) + _rootMotionDelta;
    _rootMotionDelta.setZero();

    if (desired.length2 > 1e-12) {
      final hit = HitResult();
      final completed = safeMove(desired, hit);

      if (!completed) {
        final remainingDelta = Vector3(desired.x, 0.0, desired.z) * (1.0 - hit.time);
        // A simulating body is pushed, not climbed.
        final didStep = remainingDelta.length2 > 1e-6 &&
            !(hit.component?.isSimulatingPhysics ?? false) &&
            stepUp(hit, remainingDelta);

        if (!didStep) {
          final hitNormals = <Vector3>[];
          slideAlongSurface(
            desired,
            hit.time,
            hit.impactNormal,
            hit,
            maxIterations: maxSlideIterations,
            outHitNormals: hitNormals,
            onGround: true,
          );

          for (final n in hitNormals) {
            final vDotN = _velocity.dot(n);
            if (vDotN < 0.0) {
              _velocity.sub(n * vDotN);
            }
          }
        }
      }
    }

    // Re-check floor after horizontal displacement to detect walk-off-ledge immediately
    if (updatedComponent != null && colSys != null) {
      findFloor(updatedComponent!, colSys, maxStepHeight, maxWalkSlopeAngle, skinWidth, currentFloor);
      if (!currentFloor.blockingHit || !currentFloor.isWalkable) {
        setMovementMode(MovementMode.falling);
      }
    }
  }

  /// Moves the capsule down onto [currentFloor] when it is above it, and
  /// measures the floor again.
  void _snapToFloor(LuminaCollisionSubsystem colSys) {
    if (currentFloor.floorDistance <= 1e-2 || currentFloor.floorDistance > maxStepHeight + skinWidth * 3.0) return;
    safeMove(Vector3(0.0, -currentFloor.floorDistance, 0.0), HitResult());
    findFloor(updatedComponent!, colSys, maxStepHeight, maxWalkSlopeAngle, skinWidth, currentFloor);
  }

  /// Physics integration for [MovementMode.falling].
  void physFalling(double dt, Vector3 input) {
    _velocity.y -= _gravity * gravityScale * dt;

    final vHoriz = Vector3(_velocity.x, 0.0, _velocity.z);
    if (input.length2 > 1e-6) {
      final dir = input.normalized();
      final airAcc = dir * (acceleration * airControl * dt);
      final newVHoriz = vHoriz + airAcc;
      if (newVHoriz.length > maxWalkSpeed) {
        newVHoriz.scale(maxWalkSpeed / newVHoriz.length);
      }
      _velocity.x = newVHoriz.x;
      _velocity.z = newVHoriz.z;
    }

    final desired = (_velocity * dt) + _rootMotionDelta;
    _rootMotionDelta.setZero();

    var blocked = false;
    if (desired.length2 > 1e-12) {
      final hit = HitResult();
      final completed = safeMove(desired, hit);

      if (!completed) {
        // Stopped by something it can stand on, not by a wall.
        blocked = hit.impactNormal.y >= math.cos(maxWalkSlopeAngle * math.pi / 180.0);
        final hitNormals = <Vector3>[];
        slideAlongSurface(
          desired,
          hit.time,
          hit.impactNormal,
          hit,
          maxIterations: maxSlideIterations,
          outHitNormals: hitNormals,
        );

        for (final n in hitNormals) {
          final vDotN = _velocity.dot(n);
          if (vDotN < 0.0) {
            _velocity.sub(n * vDotN);
          }
        }
      }
    }

    final colSys = owner?.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();
    if (updatedComponent != null && colSys != null) {
      findFloor(updatedComponent!, colSys, maxStepHeight, maxWalkSlopeAngle, skinWidth, currentFloor);
      // The floor sweep reaches a step's height below the capsule; a falling
      // capsule lands only once it touches the floor (or its fall was
      // stopped by a walkable surface this frame), so it never stands in
      // the air above it.
      final touching = currentFloor.floorDistance <= maxLandingDistance || blocked;
      if (currentFloor.blockingHit && currentFloor.isWalkable && _velocity.y <= 0.0 && touching) {
        setMovementMode(MovementMode.walking);
        if (isWalking) _snapToFloor(colSys);
      }
    }
  }

  /// Physics integration for [MovementMode.flying].
  void physFlying(double dt, Vector3 input) {
    if (input.length2 > 1e-6) {
      final dir = input.normalized();
      _velocity.add(dir * (acceleration * dt));
      if (_velocity.length > maxFlySpeed) {
        _velocity.scale(maxFlySpeed / _velocity.length);
      }
    } else {
      applyVelocityBraking3D(dt);
    }

    final desired = (_velocity * dt) + _rootMotionDelta;
    _rootMotionDelta.setZero();

    if (desired.length2 > 1e-12) {
      final hit = HitResult();
      final completed = safeMove(desired, hit);

      if (!completed) {
        slideAlongSurface(
          desired,
          hit.time,
          hit.impactNormal,
          hit,
          maxIterations: maxSlideIterations,
        );
      }
    }
  }

  /// Physics integration for [MovementMode.swimming].
  void physSwimming(double dt, Vector3 input) {
    // Effective gravity adjusted by buoyancy
    _velocity.y -= _gravity * gravityScale * (1.0 - buoyancy) * dt;

    if (input.length2 > 1e-6) {
      final dir = input.normalized();
      _velocity.add(dir * (acceleration * dt));
      if (_velocity.length > maxSwimSpeed) {
        _velocity.scale(maxSwimSpeed / _velocity.length);
      }
    }

    // Fluid drag
    if (fluidFriction > 0.0) {
      final drop = _velocity * (fluidFriction * dt);
      if (drop.length >= _velocity.length) {
        _velocity.setZero();
      } else {
        _velocity.sub(drop);
      }
    }

    final desired = (_velocity * dt) + _rootMotionDelta;
    _rootMotionDelta.setZero();

    if (desired.length2 > 1e-12) {
      final hit = HitResult();
      final completed = safeMove(desired, hit);

      if (!completed) {
        slideAlongSurface(
          desired,
          hit.time,
          hit.impactNormal,
          hit,
          maxIterations: maxSlideIterations,
        );
      }
    }
  }

  /// Physics integration for [MovementMode.custom].
  void physCustom(double dt, Vector3 input) {
    physCustomDelegate?.call(dt, customMovementModeIndex);

    final desired = (_velocity * dt) + _rootMotionDelta;
    _rootMotionDelta.setZero();

    if (desired.length2 > 1e-12) {
      final hit = HitResult();
      final completed = safeMove(desired, hit);

      if (!completed) {
        slideAlongSurface(
          desired,
          hit.time,
          hit.impactNormal,
          hit,
          maxIterations: maxSlideIterations,
        );
      }
    }
  }

  /// Dispatches physics integration per current movement mode.
  void startNewPhysics(double deltaTime) {
    if (updatedComponent == null && owner != null) {
      for (final comp in owner!.components) {
        if (comp is LuminaCapsuleComponent) {
          updatedComponent = comp;
          break;
        }
      }
    }

    final input = consumeInputVector();

    switch (_mode) {
      case MovementMode.walking:
        physWalking(deltaTime, input);
        break;
      case MovementMode.falling:
        physFalling(deltaTime, input);
        break;
      case MovementMode.flying:
        physFlying(deltaTime, input);
        break;
      case MovementMode.swimming:
        physSwimming(deltaTime, input);
        break;
      case MovementMode.custom:
        physCustom(deltaTime, input);
        break;
    }

    // Depenetration recovery for already-intersecting geometry
    if (owner != null) {
      final colSys = owner?.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();
      if (updatedComponent != null && colSys != null) {
        final overlaps = <LuminaCollisionComponent>[];
        colSys.overlapTest(
          updatedComponent!.worldShape,
          updatedComponent!.worldTransform,
          overlaps,
          ignore: updatedComponent,
        );

        for (final ov in overlaps) {
          if (ov == updatedComponent) continue;
          if (effectiveResponse(updatedComponent!, ov) == CollisionResponse.block) {
            _contactScratch.reset();
            if (testPair(
              updatedComponent!.worldShape,
              updatedComponent!.worldTransform,
              ov.worldShape,
              ov.worldTransform,
              _contactScratch,
            ) && _contactScratch.isColliding) {
              resolvePenetration(_contactScratch);
            }
          }
        }
      }
    }
  }

  /// Executes full kinematic move pipeline: input accumulation, per-mode physics, safeMove, slideAlongSurface, and resolvePenetration.
  void performMove(double deltaTime) {
    startNewPhysics(deltaTime);
    applyPhysicsInteraction(deltaTime);
  }
}
