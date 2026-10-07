import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/collision/gjk_epa.dart';
import 'package:lumina/src/collision/narrow_phase.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/physics/contact_generation.dart';
import 'package:lumina/src/physics/rigid_body.dart';
import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/collision/capsule_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/movement/floor_finder.dart';
import 'package:lumina/src/components/movement/kinematic_move_solver.dart';

export 'floor_finder.dart';
export 'kinematic_move_solver.dart';

enum MovementMode { walking, falling, swimming, flying, custom }

/// Kinematic movement component for character actors supporting sweeping, sliding, floor finding, slopes, steps, and movement modes.
class LuminaCharacterMovementComponent extends LuminaActorComponent {
  MovementMode _mode = MovementMode.walking;
  int customMovementModeIndex = 0;
  bool _inModeTransition = false;

  void Function(MovementMode previous, MovementMode current)? onMovementModeChanged;
  void Function(double dt, int customModeIndex)? physCustomDelegate;

  // Tunables
  // Lengths are world units: centimetres.
  double maxWalkSpeed = 600.0; // cm/s
  double maxFlySpeed = 1200.0; // cm/s
  double maxSwimSpeed = 300.0; // cm/s
  double acceleration = 2000.0; // cm/s^2
  double groundFriction = 8.0;
  double brakingDeceleration = 2500.0; // cm/s^2
  double gravityScale = 1.0;
  double buoyancy = 1.0;
  double fluidFriction = 2.0;
  double jumpZVelocity = 500.0; // cm/s
  double airControl = 0.35;
  double maxWalkSlopeAngle = 44.0; // Degrees
  double maxStepHeight = 30.0; // cm

  // Kinematic sweep configurations
  double skinWidth = 0.1; // cm
  double maxDepenetrationPerFrame = 20.0; // cm
  int maxSlideIterations = 3;

  LuminaCapsuleComponent? updatedComponent;

  // Physics interaction.

  /// Whether walking into a simulating body pushes it, and standing on one
  /// weighs it down. The capsule itself never simulates.
  bool enablePhysicsInteraction = true;

  /// The character's mass for pushing and standing on bodies, kg: a push shares the character's momentum with the body, so a light
  /// box flies, a heavy crate barely moves and stops the character.
  double mass = 100.0;

  /// The largest force the character pushes with, kg·cm/s²
  /// (20 000 = 200 N, a person's steady shove). A push
  /// shares the character's momentum with the body up to this force per
  /// second of contact, so a light box is shoved and tips when hit high but
  /// slides when hit low, while a heavy crate (friction above this force)
  /// holds and slows the character.
  double pushForceFactor = 20000.0;

  /// Scales the character's weight on a simulating body it stands on.
  double standingDownwardForceScale = 1.0;

  final List<(HitResult, Vector3)> _impacts = [];

  /// Below this horizontal speed (cm/s) braking stops the character.
  static const double _stopSpeed = 1.0;

  /// Gravity's pull (cm/s²): the world's, set from the project manifest.
  double get _gravity => -(owner?.world?.gravityZ ?? -LuminaUnits.gravity);

  final Vector3 _velocity = Vector3.zero();
  final Vector3 _rootMotionDelta = Vector3.zero();
  final Vector3 _inputVector = Vector3.zero();
  final FloorResult currentFloor = FloorResult();

  // Scratch memory for zero GC
  final Vector3 _slideVec = Vector3.zero();
  final Vector3 _consumedInputScratch = Vector3.zero();
  final ContactResult _contactScratch = ContactResult();

  LuminaCharacterMovementComponent({super.key});

  MovementMode get movementMode => _mode;
  MovementMode get mode => _mode;

  bool get isFalling => _mode == MovementMode.falling;
  bool get isWalking => _mode == MovementMode.walking;
  bool get isFlying => _mode == MovementMode.flying;
  bool get isSwimming => _mode == MovementMode.swimming;
  bool get isCustom => _mode == MovementMode.custom;
  bool get isGrounded => _mode == MovementMode.walking && (updatedComponent == null || (currentFloor.blockingHit && currentFloor.isWalkable));

  Vector3 get velocity => _velocity;
  Vector3 get rootMotionDelta => _rootMotionDelta;
  Vector3 get inputVector => _inputVector;

  /// Changes movement mode with enter/exit logic and notification callback.
  void setMovementMode(MovementMode newMode, {int customModeIndex = 0}) {
    if (newMode != MovementMode.falling) _isJumpHeld = false;
    if (_mode == newMode && (_mode != MovementMode.custom || customMovementModeIndex == customModeIndex)) {
      return;
    }
    if (_inModeTransition) return;

    _inModeTransition = true;
    final previousMode = _mode;

    // Exit old mode logic
    if (previousMode == MovementMode.walking) {
      currentFloor.reset();
    }

    // Enter new mode logic
    if (newMode == MovementMode.walking) {
      final colSys = owner?.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();
      if (updatedComponent != null && colSys != null) {
        findFloor(updatedComponent!, colSys, maxStepHeight, maxWalkSlopeAngle, skinWidth, currentFloor);
        if (currentFloor.blockingHit && currentFloor.isWalkable) {
          _mode = MovementMode.walking;
          _velocity.y = 0.0;
        } else {
          _mode = MovementMode.falling;
        }
      } else {
        _mode = MovementMode.walking;
        _velocity.y = 0.0;
      }
    } else if (newMode == MovementMode.falling) {
      _mode = MovementMode.falling;
    } else if (newMode == MovementMode.flying) {
      _mode = MovementMode.flying;
    } else if (newMode == MovementMode.swimming) {
      _mode = MovementMode.swimming;
    } else if (newMode == MovementMode.custom) {
      _mode = MovementMode.custom;
      customMovementModeIndex = customModeIndex;
    }

    _inModeTransition = false;
    onMovementModeChanged?.call(previousMode, _mode);
  }

  /// Accumulates world space input displacement for this tick.
  void addInputVector(Vector3 worldDirection, [double scale = 1.0]) {
    _inputVector.add(worldDirection * scale);
  }

  /// Consumes and clears the accumulated input vector.
  Vector3 consumeInputVector() {
    _consumedInputScratch.setFrom(_inputVector);
    _inputVector.setZero();
    return _consumedInputScratch;
  }

  /// Accumulates root motion displacement to be consumed during the next [performMove].
  void addRootMotionDelta(Vector3 delta) {
    _rootMotionDelta.add(delta);
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    if (updatedComponent == null) {
      for (final comp in ownerActor.components) {
        if (comp is LuminaCapsuleComponent) {
          updatedComponent = comp;
          break;
        }
      }
    }
  }

  /// Calculates horizontal acceleration and turning friction from [inputDir].
  void calcVelocity(double dt, Vector3 inputDir) {
    final vHoriz = Vector3(_velocity.x, 0.0, _velocity.z);

    if (isGrounded) {
      if (inputDir.length2 > 1e-6) {
        final dir = inputDir.normalized();
        final desiredAcc = dir * (acceleration * dt);

        // Ground friction applied to velocity perpendicular to input direction
        final vParallel = dir * (vHoriz.dot(dir));
        final vPerp = vHoriz - vParallel;
        final frictionDrop = vPerp * (groundFriction * dt);

        if (frictionDrop.length > vPerp.length) {
          vPerp.setZero();
        } else {
          vPerp.sub(frictionDrop);
        }

        final newVHoriz = vParallel + vPerp + desiredAcc;
        final cap = effectiveMaxWalkSpeed;
        if (newVHoriz.length > cap) {
          newVHoriz.scale(cap / newVHoriz.length);
        }

        _velocity.x = newVHoriz.x;
        _velocity.z = newVHoriz.z;
      } else {
        applyVelocityBraking(dt);
      }
    } else {
      // Airborne input authority scaled by airControl
      if (inputDir.length2 > 1e-6) {
        final dir = inputDir.normalized();
        final airAcc = dir * (acceleration * airControl * dt);
        final newVHoriz = vHoriz + airAcc;

        if (newVHoriz.length > maxWalkSpeed) {
          newVHoriz.scale(maxWalkSpeed / newVHoriz.length);
        }

        _velocity.x = newVHoriz.x;
        _velocity.z = newVHoriz.z;
      }
    }
  }

  /// Applies braking deceleration when input is zero on the ground.
  void applyVelocityBraking(double dt) {
    final speed = math.sqrt(_velocity.x * _velocity.x + _velocity.z * _velocity.z);
    if (speed < _stopSpeed) {
      _velocity.x = 0.0;
      _velocity.z = 0.0;
      return;
    }

    final drop = brakingDeceleration * dt;
    final newSpeed = math.max(0.0, speed - drop);

    if (newSpeed <= _stopSpeed) {
      _velocity.x = 0.0;
      _velocity.z = 0.0;
    } else {
      final scale = newSpeed / speed;
      _velocity.x *= scale;
      _velocity.z *= scale;
    }
  }

  /// Applies 3D braking deceleration across all three axes.
  void applyVelocityBraking3D(double dt) {
    final speed = _velocity.length;
    if (speed < _stopSpeed) {
      _velocity.setZero();
      return;
    }

    final drop = brakingDeceleration * dt;
    final newSpeed = math.max(0.0, speed - drop);

    if (newSpeed <= _stopSpeed) {
      _velocity.setZero();
    } else {
      _velocity.scale(newSpeed / speed);
    }
  }

  /// Walk speed while crouched, cm/s.
  double maxWalkSpeedCrouched = 300.0;

  bool _isCrouched = false;

  /// Whether the character is crouching ([crouch] / [unCrouch]).
  bool get isCrouched => _isCrouched;

  /// Crouches: walking is capped at [maxWalkSpeedCrouched] until [unCrouch].
  void crouch() => _isCrouched = true;

  void unCrouch() => _isCrouched = false;

  /// The walk speed cap that applies now.
  double get effectiveMaxWalkSpeed => _isCrouched ? maxWalkSpeedCrouched : maxWalkSpeed;

  /// Launch Character: [launchVelocity] (runtime axes, cm/s) is
  /// added to the velocity, or replaces its horizontal / vertical part when
  /// [xyOverride] / [zOverride] is set; the character starts falling.
  void launch(Vector3 launchVelocity, {bool xyOverride = false, bool zOverride = false}) {
    if (xyOverride) {
      _velocity.x = launchVelocity.x;
      _velocity.z = launchVelocity.z;
    } else {
      _velocity.x += launchVelocity.x;
      _velocity.z += launchVelocity.z;
    }
    if (zOverride) {
      _velocity.y = launchVelocity.y;
    } else {
      _velocity.y += launchVelocity.y;
    }
    _isJumpHeld = false;
    if (_mode == MovementMode.walking) setMovementMode(MovementMode.falling);
  }

  /// Zeroes the velocity and the pending input.
  void stopMovementImmediately() {
    _velocity.setZero();
    _inputVector.setZero();
  }

  /// Fraction of the remaining upward velocity kept when the jump input is
  /// released early (see [stopJumping]). 1.0 disables variable jump height.
  double jumpCutMultiplier = 0.5;

  bool _isJumpHeld = false;

  /// Whether a jump initiated by [jump] is still being held.
  bool get isJumpHeld => _isJumpHeld;

  /// Initiates a jump if walking and grounded.
  bool jump() {
    if (_mode == MovementMode.walking) {
      _velocity.y = jumpZVelocity;
      _isJumpHeld = true;
      setMovementMode(MovementMode.falling);
      return true;
    }
    return false;
  }

  /// Releases the jump input. If the character is still rising from a held
  /// jump, the remaining upward velocity is scaled by [jumpCutMultiplier] so
  /// a short tap produces a lower hop than a held press (variable jump height).
  void stopJumping() {
    if (!_isJumpHeld) return;
    _isJumpHeld = false;
    if (_mode == MovementMode.falling && _velocity.y > 0.0 && jumpCutMultiplier < 1.0) {
      _velocity.y *= jumpCutMultiplier.clamp(0.0, 1.0);
    }
  }

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

    if (desired.length2 > 1e-12) {
      final hit = HitResult();
      final completed = safeMove(desired, hit);

      if (!completed) {
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
      if (currentFloor.blockingHit && currentFloor.isWalkable && _velocity.y <= 0.0) {
        setMovementMode(MovementMode.walking);
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

  /// Pushes the simulating bodies this tick's moves ran into, keeps the
  /// character moving at the speed it shares with each (slowed by a heavy
  /// one instead of stopped dead), and weighs down a body it stands on.
  void applyPhysicsInteraction(double deltaTime) {
    if (!enablePhysicsInteraction) {
      _impacts.clear();
      return;
    }
    final pushed = <LuminaRigidBody>{};
    for (final (hit, velocity) in _impacts) {
      final body = hit.component?.physicsBody;
      if (body == null || !pushed.add(body)) continue;
      final n = _pushNormal(hit, body);
      if (n == null) continue;
      final remaining = applyImpactPhysics(hit, velocity, deltaTime);
      // Still moving into the body at the speed it now moves away with.
      final into = -_velocity.dot(n);
      if (remaining > into) _velocity.sub(n * (remaining - into));
    }
    _impacts.clear();
    final floor = currentFloor.floorComponent?.physicsBody;
    final capsule = updatedComponent;
    if (floor != null && capsule != null && isGrounded && standingDownwardForceScale > 0) {
      final feet = capsule.worldLocation - capsule.upVector * capsule.halfHeight;
      floor.addForceAtLocation(Vector3(0.0, -_gravity * gravityScale * mass * standingDownwardForceScale, 0.0), feet);
    }
  }

  /// The horizontal push direction of [hit] (from the body towards the
  /// character); null for a hit from above or below (standing, landing).
  Vector3? _pushNormal(HitResult hit, LuminaRigidBody body) {
    var n = hit.impactNormal.clone();
    if (n.length2 < 1e-12) {
      final capsule = updatedComponent;
      if (capsule == null) return null;
      n = capsule.worldLocation - body.position;
    }
    n.y = 0.0;
    final len = n.length;
    if (len < 0.3 * math.max(hit.impactNormal.length, 1e-9) || len < 1e-9) return null;
    return n..scale(1.0 / len);
  }

  /// Pushes [hit]'s simulating body the way the character hit it moving at
  /// [velocity]: an inelastic push at the contact point (so a body hit high
  /// tips and one hit low slides), at most [pushForceFactor] × [deltaTime].
  /// Returns the character's speed towards the body afterwards (cm/s).
  double applyImpactPhysics(HitResult hit, Vector3 velocity, double deltaTime) {
    final component = hit.component;
    final body = component?.physicsBody;
    if (component == null || body == null) return 0.0;
    final n = _pushNormal(hit, body);
    if (n == null) return 0.0;
    final approach = -velocity.dot(n);
    if (approach <= 0) return 0.0;
    final capsule = updatedComponent;
    final Vector3 point;
    if (capsule != null) {
      final points = LuminaContactGenerator.touchPoints(
          capsule.worldShape, capsule.worldTransform, component.worldShape, component.worldTransform, -n);
      point = Vector3.zero();
      for (final p in points) {
        point.add(p);
      }
      point.scale(1.0 / points.length);
    } else {
      point = hit.impactPoint.clone();
    }
    final dir = -n;
    final r = point - body.position;
    final lf = body.linearFactor;
    final ang = body.inverseInertiaWorld.transformed(r.cross(dir))..multiply(body.angularFactor);
    final k = body.inverseMass * (dir.x * dir.x * lf.x + dir.y * dir.y * lf.y + dir.z * dir.z * lf.z) +
        ang.cross(r).dot(dir) +
        1.0 / math.max(mass, 1e-3);
    final rel = approach - body.velocityAt(point).dot(dir);
    if (rel <= 0) return approach;
    final impulse = math.min(rel / k, pushForceFactor * deltaTime);
    body.applyImpulse(dir * impulse, r);
    body.wake();
    return math.max(0.0, math.min(approach, body.velocityAt(point).dot(dir)));
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    performMove(deltaTime);
  }
}
