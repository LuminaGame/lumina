part of '../character_movement_component.dart';

/// Pushing and standing on simulating bodies.
mixin _CharacterMovementPhysicsInteraction on _CharacterMovementState {
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
}
