import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'physics_fixture.dart';

const double _deg = math.pi / 180;

/// A static anchor body: a very heavy box that does not fall (gravity off,
/// huge mass, locked).
LuminaRigidBody _anchor(PhysicsWorld w, Vector3 at) {
  final box = w.box(at, Vector3.all(5), massKg: 1e9, spawn: true);
  box
    ..enableGravity = false
    ..lockPositionX = true
    ..lockPositionY = true
    ..lockPositionZ = true
    ..lockRotationX = true
    ..lockRotationY = true
    ..lockRotationZ = true;
  return box.physicsBody!;
}

LuminaCapsuleComponent _link(PhysicsWorld w, Vector3 center, {double halfHeight = 20, double radius = 4, double massKg = 2}) {
  final c = LuminaCapsuleComponent(location: center, radius: radius, halfHeight: halfHeight)
    ..simulatePhysics = true
    ..overrideMass = true
    ..massKg = massKg
    ..angularDamping = 0.0
    ..linearDamping = 0.0;
  w.world.persistentLevel.registerActor(LuminaActor(root: c));
  return c;
}

double _energy(Iterable<LuminaRigidBody> bodies, double g) {
  var e = 0.0;
  for (final b in bodies) {
    final iw = b.localInertiaWorld();
    e += 0.5 * b.mass * b.linearVelocity.length2 + 0.5 * b.angularVelocity.dot(iw.transformed(b.angularVelocity)) + b.mass * g * b.position.y;
  }
  return e;
}

void main() {
  test('swing-twist decomposition reads back the angles it was built from', () {
    final twist = Quaternion.axisAngle(Vector3(1, 0, 0), 25 * _deg);
    final swing = Quaternion.axisAngle(Vector3(0, 0.6, 0.8), 40 * _deg);
    final (t, s) = LuminaPhysicsJoint.swingTwist(swing * twist);
    expect(t / _deg, closeTo(25, 1e-6));
    expect(s.length / _deg, closeTo(40, 1e-6));
    expect(s.x, closeTo(0, 1e-9));
    expect(s.y / s.length, closeTo(0.6, 1e-6));
  });

  test('a ball joint keeps a hanging body at its anchor', () {
    final w = PhysicsWorld();
    final link = _link(w, Vector3(0, 500, 20), halfHeight: 20);
    w.begin();
    final anchor = _anchor(w, Vector3(0, 500, 0));
    final body = link.physicsBody!;
    // The capsule's axis is Y; turn it horizontal toward +Z: it swings down.
    body.setOriginTransform(Vector3(0, 500, 20), Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2));
    final joint = w.physics.addJoint(LuminaPhysicsJoint.atWorld(anchor, body, Vector3(0, 500, 0), Quaternion.identity(),
        limitsEnabled: false));
    var worst = 0.0;
    w.run(2.0, (_) => worst = math.max(worst, joint.anchorError));
    expect(worst, lessThan(0.5));
    // It hangs below the anchor.
    expect(body.position.y, lessThan(500 - 15));
    w.dispose();
  });

  test('a swing cone of 30° holds a pendulum released at 80°', () {
    final w = PhysicsWorld();
    final link = _link(w, Vector3(0, 480, 0));
    w.begin();
    final anchor = _anchor(w, Vector3(0, 500, 0));
    final body = link.physicsBody!;
    // Joint frame X points down (the rest direction of the link).
    final frame = Quaternion.axisAngle(Vector3(0, 0, 1), -math.pi / 2);
    final joint = w.physics.addJoint(LuminaPhysicsJoint.atWorld(anchor, body, Vector3(0, 500, 0), frame,
        swing1: 30 * _deg, swing2: 30 * _deg, twistMin: -10 * _deg, twistMax: 10 * _deg));
    // Release it at 80° from the vertical.
    final r = Quaternion.axisAngle(Vector3(0, 0, 1), 80 * _deg);
    final down = Vector3(0, -20, 0)..applyQuaternion(r);
    body.setOriginTransform(Vector3(0, 500, 0) + down, r);
    var worst = 0.0;
    w.run(3.0, (t) {
      if (t > 0.3) worst = math.max(worst, joint.angles.$1 / _deg);
    });
    expect(worst, lessThan(33));
    expect(joint.anchorError, lessThan(0.5));
    w.dispose();
  });

  test('a twist range of ±20° holds a spun body', () {
    final w = PhysicsWorld();
    final link = _link(w, Vector3(0, 480, 0));
    w.begin();
    final anchor = _anchor(w, Vector3(0, 500, 0));
    final body = link.physicsBody!;
    final frame = Quaternion.axisAngle(Vector3(0, 0, 1), -math.pi / 2);
    final joint = w.physics.addJoint(LuminaPhysicsJoint.atWorld(anchor, body, Vector3(0, 500, 0), frame,
        swing1: 20 * _deg, swing2: 20 * _deg, twistMin: -20 * _deg, twistMax: 20 * _deg));
    body.addAngularImpulse(Vector3(0, 30, 0), velocityChange: true);
    var worst = 0.0;
    w.run(2.0, (_) => worst = math.max(worst, joint.angles.$2.abs() / _deg));
    expect(worst, lessThan(23));
    w.dispose();
  });

  test('a hinge 0…140° never bends backward', () {
    final w = PhysicsWorld();
    final link = _link(w, Vector3(0, 480, 0));
    w.begin();
    final anchor = _anchor(w, Vector3(0, 500, 0));
    final body = link.physicsBody!;
    // Hinge axis X = world +X: positive twist swings the link's end toward +Z... and back.
    final joint = w.physics.addJoint(LuminaPhysicsJoint.atWorld(anchor, body, Vector3(0, 500, 0), Quaternion.identity(),
        kind: LuminaJointKind.hinge, twistMin: 0, twistMax: 140 * _deg));
    // Kick it the forbidden way, then sideways (the locked swing).
    body.addImpulseAtLocation(Vector3(0, 0, 400), Vector3(0, 470, 0));
    body.addImpulseAtLocation(Vector3(400, 0, 0), Vector3(0, 470, 0));
    var minTwist = 0.0, maxSwing = 0.0;
    w.run(2.0, (_) {
      final (swing, twist) = joint.angles;
      minTwist = math.min(minTwist, twist / _deg);
      maxSwing = math.max(maxSwing, swing / _deg);
    });
    expect(minTwist, greaterThan(-3));
    expect(maxSwing, lessThan(3));
    w.dispose();
  });

  test('a hanging 6-link chain stays connected, holds its limits and never gains energy', () {
    final w = PhysicsWorld();
    final links = [for (var i = 0; i < 6; i++) _link(w, Vector3(i * 40.0 + 20, 1000, 0))];
    w.begin();
    final anchor = _anchor(w, Vector3(0, 1000, 0));
    final bodies = [for (final l in links) l.physicsBody!];
    final horizontal = Quaternion.axisAngle(Vector3(0, 0, 1), -math.pi / 2);
    for (final b in bodies) {
      b.setOriginTransform(b.origin, horizontal);
    }
    final joints = <LuminaPhysicsJoint>[];
    for (var i = 0; i < 6; i++) {
      final parent = i == 0 ? anchor : bodies[i - 1];
      // The top joint's rest direction is 45° down, so both the horizontal
      // start and the hanging end are inside its cone.
      final frame = i == 0 ? Quaternion.axisAngle(Vector3(0, 0, 1), -math.pi / 4) : Quaternion.identity();
      joints.add(w.physics.addJoint(LuminaPhysicsJoint.atWorld(parent, bodies[i], Vector3(i * 40.0, 1000, 0), frame,
          swing1: 60 * _deg, swing2: 60 * _deg, twistMin: -30 * _deg, twistMax: 30 * _deg)));
    }
    // Only the joints act here: the links pass through each other.
    for (final x in [anchor, ...bodies]) {
      x.ignoredBodies.addAll([anchor, ...bodies].where((y) => !identical(x, y)));
    }
    final g = LuminaUnits.gravity;
    final start = _energy(bodies, g);
    var worstError = 0.0, worstEnergy = -double.infinity, worstExcess = 0.0;
    w.run(5.0, (t) {
      for (final j in joints) {
        worstError = math.max(worstError, j.anchorError);
      }
      var worstLimit = 0.0;
      for (final j in joints) {
        final (sw, tw) = j.angles;
        worstLimit = math.max(worstLimit, math.max(sw - 60 * _deg, tw.abs() - 30 * _deg));
      }
      worstExcess = math.max(worstExcess, worstLimit);
      worstEnergy = math.max(worstEnergy, _energy(bodies, g));
    });
    expect(worstError, lessThan(1.0));
    expect(worstExcess / _deg, lessThan(5.0));
    expect(worstEnergy, lessThanOrEqualTo(start + 1e-6 * start.abs() + 1.0));
    w.dispose();
  });

  test('joined bodies of one actor do not collide; free ones can opt in', () {
    final w = PhysicsWorld();
    final owner = LuminaActor(root: LuminaSceneComponent());
    w.world.persistentLevel.registerActor(owner);
    w.begin();
    LuminaSphereComponent ball(Vector3 at) {
      final s = LuminaSphereComponent(location: at, radius: 10)
        ..overrideMass = true
        ..massKg = 1;
      s.onRegister(owner);
      return s;
    }

    final a = ball(Vector3(0, 10, 0)), b = ball(Vector3(0, 40, 0));
    final ba = w.physics.addBody(a)!, bb = w.physics.addBody(b)!;
    // Same owner, not opted in: b falls through a onto the floor.
    w.run(1.5);
    expect(bb.position.y, lessThan(15));
    bb.setOriginTransform(Vector3(0, 40, 0), Quaternion.identity());
    ba.collidesWithOwnBodies = true;
    bb.collidesWithOwnBodies = true;
    w.run(1.5);
    expect(bb.position.y, greaterThan(25));
    w.dispose();
  });
}
