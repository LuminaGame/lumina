import 'package:vector_math/vector_math_64.dart';
import '../../collision/collision_subsystem.dart';
import '../../math/units.dart';
import '../base/actor_component.dart';
import '../base/scene_component.dart';
import '../collision/collision_component.dart';
import '../../math/euler.dart';

/// Actor component that updates an actor's position along a simulated ballistic projectile trajectory.
class LuminaProjectileMovementComponent extends LuminaActorComponent {
  double initialSpeed;
  double maxSpeed;
  double projectileGravityScale;
  bool bRotationFollowsVelocity;
  bool bShouldBounce;
  double bounciness;
  double friction;
  double bounceVelocityStopSimulatingThreshold;
  bool bInitialVelocityInLocalSpace;

  LuminaSceneComponent? homingTargetComponent;
  double homingAccelerationMagnitude;

  Vector3 velocity = Vector3.zero();
  bool _isSimulating = true;
  bool _stopFired = false;

  void Function(HitResult hit, Vector3 impactVelocity)? onProjectileBounce;
  void Function(HitResult hit)? onProjectileStop;

  LuminaProjectileMovementComponent({
    this.initialSpeed = 1000.0, // cm/s
    this.maxSpeed = 0.0,
    this.projectileGravityScale = 1.0,
    this.bRotationFollowsVelocity = false,
    this.bShouldBounce = false,
    this.bounciness = 0.6,
    this.friction = 0.2,
    this.bounceVelocityStopSimulatingThreshold = 50.0, // cm/s
    this.bInitialVelocityInLocalSpace = true,
    this.homingTargetComponent,
    this.homingAccelerationMagnitude = 0.0,
  });

  bool get isSimulating => _isSimulating;

  void setVelocity(Vector3 v) {
    velocity.setFrom(v);
  }

  void setVelocityInLocalSpace(Vector3 v) {
    if (owner != null) {
      velocity.setFrom(owner!.actorRotation.rotateVector(v));
    } else {
      velocity.setFrom(v);
    }
  }

  /// Calculates post-bounce velocity using restitution and tangential friction.
  Vector3 calculateBounceVelocity(Vector3 inVelocity, Vector3 normal) {
    final n = normal.normalized();
    final vn = inVelocity.dot(n);
    final vnVector = n * vn;
    final vtVector = inVelocity - vnVector;

    final newVn = -vnVector * bounciness;
    final newVt = vtVector * (1.0 - friction).clamp(0.0, 1.0);

    return newVn + newVt;
  }

  /// Stops projectile simulation and fires onProjectileStop callback.
  void stopSimulating({HitResult? hit}) {
    if (!_isSimulating && _stopFired) return;
    _isSimulating = false;
    velocity.setZero();

    if (!_stopFired) {
      _stopFired = true;
      onProjectileStop?.call(hit ?? HitResult());
    }
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    if (velocity.length2 < 1e-9 && initialSpeed > 0.0) {
      if (bInitialVelocityInLocalSpace && owner != null) {
        // Forward vector (+Z in standard forward convention)
        velocity = owner!.actorRotation.rotateVector(Vector3(0.0, 0.0, 1.0)) * initialSpeed;
      } else {
        velocity = Vector3(initialSpeed, 0.0, 0.0);
      }
    }

    if (maxSpeed > 0.0 && velocity.length > maxSpeed) {
      velocity = velocity.normalized() * maxSpeed;
    }
  }

  @override
  void onTick(double deltaTime) {
    if (!_isSimulating || owner == null || deltaTime <= 0.0) return;
    final currentOwner = owner!;

    // 1. Acceleration integration (gravity + homing)
    final gravity = -(currentOwner.world?.gravityZ ?? -LuminaUnits.gravity);
    var acc = Vector3(0.0, -gravity * projectileGravityScale, 0.0);

    if (homingTargetComponent != null && homingAccelerationMagnitude > 0.0) {
      final targetLoc = homingTargetComponent!.worldLocation;
      final dir = targetLoc - currentOwner.actorLocation;
      if (dir.length > 1e-6) {
        acc += dir.normalized() * homingAccelerationMagnitude;
      }
    }

    velocity += acc * deltaTime;
    if (maxSpeed > 0.0 && velocity.length > maxSpeed) {
      velocity = velocity.normalized() * maxSpeed;
    }

    // 2. Swept collision movement
    final delta = velocity * deltaTime;
    final colSys = currentOwner.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();

    HitResult? blockingHit;
    if (colSys != null) {
      final hit = HitResult();
      final ownerCol = currentOwner.getComponent<LuminaCollisionComponent>();

      bool hasHit = false;
      if (ownerCol != null && ownerCol.collisionEnabled) {
        hasHit = colSys.sweep(
          ownerCol.worldShape,
          ownerCol.worldTransform,
          delta,
          hit,
          ignore: ownerCol,
        );
      } else {
        hasHit = colSys.lineTraceSingle(
          start: currentOwner.actorLocation,
          end: currentOwner.actorLocation + delta,
          out: hit,
          ignoreActors: [currentOwner],
        );
      }

      if (hasHit && hit.blockingHit) {
        blockingHit = hit;
      }
    }

    if (blockingHit == null) {
      currentOwner.actorLocation += delta;
    } else {
      // Move to hit impact point with small normal pullback
      currentOwner.actorLocation = blockingHit.impactPoint + (blockingHit.impactNormal * 0.1);

      if (bShouldBounce) {
        final impactVelocity = velocity.clone();
        velocity = calculateBounceVelocity(velocity, blockingHit.impactNormal);
        onProjectileBounce?.call(blockingHit, impactVelocity);

        if (velocity.length < bounceVelocityStopSimulatingThreshold) {
          stopSimulating(hit: blockingHit);
        }
      } else {
        stopSimulating(hit: blockingHit);
      }
    }

    // 3. Rotation alignment
    if (bRotationFollowsVelocity && velocity.length2 > 1e-12) {
      final dir = velocity.normalized();
      currentOwner.actorRotation = Quaternion.fromTwoVectors(Vector3(0.0, 0.0, 1.0), dir);
    }
  }
}
