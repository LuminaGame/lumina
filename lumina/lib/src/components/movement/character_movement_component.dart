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

export 'package:lumina/src/components/movement/floor_finder.dart';
export 'package:lumina/src/components/movement/kinematic_move_solver.dart';

part 'character_movement_component/sweeps.dart';
part 'character_movement_component/physics_interaction.dart';
part 'character_movement_component/modes.dart';

enum MovementMode { walking, falling, swimming, flying, custom }

/// The state and basic controls of [LuminaCharacterMovementComponent]: modes,
/// tunables, input, velocity, braking, crouching and jumping.
abstract class _CharacterMovementState extends LuminaActorComponent {
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

  _CharacterMovementState({super.key});

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

  final Vector3 _lastInputVector = Vector3.zero();

  /// The input the last move consumed (world space): what the player asked
  /// for in the last frame, after [consumeInputVector] cleared it — what a
  /// motion matching trajectory prediction steers toward.
  Vector3 get lastInputVector => _lastInputVector;

  /// Consumes and clears the accumulated input vector.
  Vector3 consumeInputVector() {
    _consumedInputScratch.setFrom(_inputVector);
    _lastInputVector.setFrom(_inputVector);
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
}

/// Kinematic movement component for character actors supporting sweeping, sliding, floor finding, slopes, steps, and movement modes.
class LuminaCharacterMovementComponent extends _CharacterMovementState
    with _CharacterMovementSweeps, _CharacterMovementPhysicsInteraction, _CharacterMovementModes {
  LuminaCharacterMovementComponent({super.key});

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    performMove(deltaTime);
  }
}
