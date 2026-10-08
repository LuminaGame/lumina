import 'package:lumina/src/physics/physics_joint.dart';

/// The joints of one physics step whose bodies are awake (a joint with one
/// awake body wakes the other), solved next to the contacts: velocity passes
/// alternating direction (a chain's ends both hear of an impulse within one
/// pass pair), then position passes after integration.
class LuminaJointBatch {
  final List<LuminaPhysicsJoint> joints;
  LuminaJointBatch._(this.joints);

  factory LuminaJointBatch.awake(List<LuminaPhysicsJoint> all) {
    final out = <LuminaPhysicsJoint>[];
    for (final j in all) {
      if (!j.bodyA.isAwake && !j.bodyB.isAwake) continue;
      j.bodyA.wake();
      j.bodyB.wake();
      out.add(j);
    }
    return LuminaJointBatch._(out);
  }

  void prepare(double dt) {
    for (final j in joints) {
      j.prepare(dt);
    }
  }

  /// Velocity pass [i]: forward on even passes, backward on odd ones.
  void velocityPass(int i) {
    if (i.isEven) {
      for (final j in joints) {
        j.solveVelocities();
      }
    } else {
      for (var k = joints.length - 1; k >= 0; k--) {
        joints[k].solveVelocities();
      }
    }
  }

  /// [count] joint-only passes, then the impulses kept for the next step.
  void velocityPasses(int count) {
    for (var i = 0; i < count && joints.isNotEmpty; i++) {
      velocityPass(i);
    }
    for (final j in joints) {
      j.storeImpulses();
    }
  }

  void positionPasses(int count) {
    if (joints.isEmpty) return;
    for (var i = 0; i < count; i++) {
      for (final j in joints) {
        j.solvePosition();
      }
    }
    for (final j in joints) {
      j.bodyA.updateWorld();
      j.bodyB.updateWorld();
    }
  }
}
