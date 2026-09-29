import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../../object/actor.dart';
import '../base/actor_component.dart';
import '../../math/euler.dart';

/// Actor component that continuously spins an actor at a constant angular rate about an optional pivot.
class LuminaRotatingMovementComponent extends LuminaActorComponent {
  Vector3 rotationRate;
  Vector3 pivotTranslation;
  bool bRotationInLocalSpace;

  LuminaRotatingMovementComponent({
    Vector3? rotationRate,
    Vector3? pivotTranslation,
    this.bRotationInLocalSpace = true,
  })  : rotationRate = rotationRate ?? Vector3(0.0, 180.0, 0.0),
        pivotTranslation = pivotTranslation ?? Vector3.zero();

  @override
  void onTick(double deltaTime) {
    if (owner == null || deltaTime <= 0.0) return;
    final currentOwner = owner!;

    final rateRad = rotationRate * (math.pi / 180.0);
    final angularSpeed = rateRad.length;
    if (angularSpeed < 1e-9) return;

    final axis = rateRad / angularSpeed;
    final angle = angularSpeed * deltaTime;
    final dq = Quaternion.axisAngle(axis, angle);

    final initialRot = currentOwner.actorRotation.clone();
    final initialPos = currentOwner.actorLocation.clone();

    // Apply rotation with normalization to prevent drift
    final newRot = bRotationInLocalSpace ? (initialRot * dq) : (dq * initialRot);
    newRot.normalize();
    currentOwner.actorRotation = newRot;

    // Apply pivot translation if set
    if (pivotTranslation.length2 > 1e-9) {
      final pivot = initialPos + initialRot.rotateVector(pivotTranslation);
      currentOwner.actorLocation = pivot - newRot.rotateVector(pivotTranslation);
    }
  }
}
