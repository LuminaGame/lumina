import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/camera/spring_arm_component.dart';
import 'package:lumina/src/components/camera/camera_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/collision/capsule_component.dart';

import 'package:lumina/src/world/subsystem/world_subsystem.dart';

// Stub for LuminaWorld and CollisionSubsystem
class StubCollisionSubsystem extends LuminaCollisionSubsystem {
  int sweepCalls = 0;
  double? forcedSweepTime;
  LuminaCollisionComponent? hitComponent;

  @override
  bool sweep(
    CollisionShape shape,
    Matrix4 start,
    Vector3 delta,
    HitResult out, {
    int layerMask = 0xFFFFFFFF,
    LuminaCollisionComponent? ignore,
  }) {
    sweepCalls++;
    if (forcedSweepTime != null) {
      out.blockingHit = true;
      out.time = forcedSweepTime!;
      out.component = hitComponent;
      return true;
    }
    out.time = 1.0;
    return false;
  }
}

class StubWorld extends LuminaWorld {
  final StubCollisionSubsystem collisionStub = StubCollisionSubsystem();
  @override
  T? getSubsystem<T extends LuminaWorldSubsystem>() {
    if (T == LuminaCollisionSubsystem) {
      return collisionStub as T;
    }
    return super.getSubsystem<T>();
  }
}

void main() {
  group('LuminaSpringArmComponent Collision Probe', () {
    late LuminaSpringArmComponent arm;
    late LuminaCameraComponent child;
    late StubWorld world;
    late LuminaActor actor;

    setUp(() {
      world = StubWorld();
      actor = LuminaActor();
      actor.onRegister(world);
      
      arm = LuminaSpringArmComponent();
      arm.targetArmLength = 3.0;
      child = LuminaCameraComponent();
      
      arm.onRegister(actor);
      arm.attachToComponent(actor.rootComponent);
      child.attachToComponent(arm);
    });

    test('Clear path, targetArmLength: 3 -> currentArmLength == 3.0, isCollisionAdjusted == false', () {
      arm.onTick(0.016);
      expect(arm.currentArmLength, 3.0);
      expect(arm.isCollisionAdjusted, false);
      expect(world.collisionStub.sweepCalls, 1);
    });

    test('Wall at 40% of arm -> instant snap to 1.2, isCollisionAdjusted == true', () {
      world.collisionStub.forcedSweepTime = 0.4;
      arm.onTick(0.016);
      
      expect(arm.currentArmLength, closeTo(1.2, 1e-5));
      expect(arm.isCollisionAdjusted, true);
      // forward is -Z, arm extends to +Z.
      // Socket location should be exactly 1.2 on +Z
      expect(child.worldLocation.z, closeTo(1.2, 1e-5));
      expect(arm.unfixedSocketWorldLocation.z, closeTo(3.0, 1e-5));
    });

    test('Wall removed, armRecoverySpeed: 5, deltaTime: 0.1 -> alpha=0.5 -> currentArmLength=2.1', () {
      // First hit
      world.collisionStub.forcedSweepTime = 0.4;
      arm.onTick(0.016);
      expect(arm.currentArmLength, closeTo(1.2, 1e-5));

      // Now wall removed
      world.collisionStub.forcedSweepTime = null;
      arm.armRecoverySpeed = 5.0;
      arm.onTick(0.1);
      
      expect(arm.currentArmLength, closeTo(2.1, 1e-5)); // 1.2 + (3.0 - 1.2) * 0.5
      expect(arm.isCollisionAdjusted, true);
    });
    
    test('Recovery through second wall caps expansion', () {
      // First hit
      world.collisionStub.forcedSweepTime = 0.4; // 1.2
      arm.onTick(0.016);
      
      // Now new hit at distance 2.0. The sweep goes from 0 to targetArmLength.
      // 2.0 / 3.0 = 0.6666
      world.collisionStub.forcedSweepTime = 2.0 / 3.0;
      arm.armRecoverySpeed = 100.0; // huge recovery speed -> wants to go to 3.0
      arm.onTick(0.1);
      
      expect(arm.currentArmLength, closeTo(2.0, 1e-5));
    });

    test('Closer obstacle while shortened snaps instantly', () {
      world.collisionStub.forcedSweepTime = 2.0 / 3.0; // 2.0
      arm.onTick(0.016);
      
      world.collisionStub.forcedSweepTime = 0.8 / 3.0; // 0.8
      arm.onTick(0.016);
      
      expect(arm.currentArmLength, closeTo(0.8, 1e-5));
    });

    test('bDoCollisionTest: false ignores sweep', () {
      world.collisionStub.forcedSweepTime = 0.4;
      arm.bDoCollisionTest = false;
      arm.onTick(0.016);
      
      expect(arm.currentArmLength, 3.0);
      expect(world.collisionStub.sweepCalls, 0);
    });

    test('Owning actor ignored', () {
      final ownCollider = LuminaCapsuleComponent();
      ownCollider.onRegister(actor);
      ownCollider.attachToComponent(actor.rootComponent);
      world.collisionStub.forcedSweepTime = 0.4;
      world.collisionStub.hitComponent = ownCollider;
      
      // The implementation should ignore the owner actor's components.
      arm.onTick(0.016);
      expect(arm.currentArmLength, 3.0);
    });
    
    test('Zero allocations during steady state ticking', () {
      // Not easily testable without a profiler, but we can verify no new instances by checking identity
      // of `arm.unfixedSocketWorldLocation`.
      world.collisionStub.forcedSweepTime = 0.4;
      arm.onTick(0.016);
      final loc1 = arm.unfixedSocketWorldLocation;
      arm.onTick(0.016);
      final loc2 = arm.unfixedSocketWorldLocation;
      // We expect the Vector3 instance to be modified in place, not replaced.
      expect(identical(loc1, loc2), isTrue);
    });
  });
}
