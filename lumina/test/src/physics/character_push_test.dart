import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'physics_fixture.dart';

/// The character pushes simulating bodies — a tall box hit high
/// tips over, hit low slides, a heavy crate barely moves and slows the
/// character, a ball rolls away, and the character can stand on a body.
void main() {
  /// A character on the floor at [x], walking +x every tick.
  LuminaCharacter walker(PhysicsWorld w, double x, {double radius = 40, double halfHeight = 80}) {
    final c = LuminaCharacter(location: Vector3(x, halfHeight + 0.5, 0));
    c.capsuleComponent
      ..capsuleRadius = radius
      ..capsuleHalfHeight = halfHeight;
    w.world.persistentLevel.registerActor(c);
    return c;
  }

  void walk(PhysicsWorld w, LuminaCharacter c, double seconds, [void Function(double t)? each]) {
    w.run(seconds, (t) {
      c.characterMovement.addInputVector(Vector3(1, 0, 0));
      each?.call(t);
    });
  }

  group('character pushes physics bodies', () {
    test('a 60 × 60 × 120 cm box hit by the character at its top tips over', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final box = w.box(Vector3(150, 60.2, 0), Vector3(30, 60, 30));
      final c = walker(w, 0);
      w.begin();
      w.run(0.3); // settle
      walk(w, c, 2.5);
      expect(tiltDegrees(box.worldRotation), greaterThan(60), reason: 'tipped (tilt ${tiltDegrees(box.worldRotation)}°)');
    });

    test('hit at its base (a small pawn) the same box slides instead', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final box = w.box(Vector3(150, 60.2, 0), Vector3(30, 60, 30));
      final c = walker(w, 0, radius: 20, halfHeight: 25);
      w.begin();
      w.run(0.3);
      final start = box.worldLocation;
      var maxTilt = 0.0;
      // One second of shoving at its base: it slides along the floor upright.
      walk(w, c, 1.0, (_) => maxTilt = math.max(maxTilt, tiltDegrees(box.worldRotation)));
      expect(box.worldLocation.x - start.x, greaterThan(50), reason: 'pushed along the floor');
      expect(maxTilt, lessThan(15), reason: 'slid upright (max tilt $maxTilt°)');
    });

    test('a 1000 kg crate moves less than 5 cm when walked into and the character is slowed', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final crate = w.box(Vector3(200, 50.2, 0), Vector3.all(50), massKg: 1000);
      final c = walker(w, 0);
      w.begin();
      w.run(0.3);
      final start = crate.worldLocation;
      final speeds = <double>[];
      walk(w, c, 2.5, (t) {
        if (t > 1.5) speeds.add(c.characterMovement.velocity.x);
      });
      expect(crate.worldLocation.distanceTo(start), lessThan(5), reason: 'moved ${crate.worldLocation.distanceTo(start)} cm');
      final meanSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
      expect(meanSpeed, lessThan(100), reason: 'the character is slowed to $meanSpeed cm/s against the crate');
      expect(c.actorLocation.x, lessThan(start.x - 50 - 40 + 2), reason: 'not inside the crate');
    });

    test('a ball walked into rolls away', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final ball = w.sphere(Vector3(150, 25.2, 0), 25, massKg: 2);
      final c = walker(w, 0);
      w.begin();
      w.run(0.2);
      walk(w, c, 1.0);
      w.run(0.5);
      final body = ball.physicsBody!;
      expect(ball.worldLocation.x, greaterThan(300), reason: 'the ball rolled ahead of the character');
      expect(body.angularVelocity.z.abs() * 25, closeTo(body.linearVelocity.x.abs(), body.linearVelocity.x.abs() * 0.25 + 5),
          reason: 'rolling, not sliding');
    });

    test('the character stands on a simulating box and weighs it down', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final box = w.box(Vector3(0, 25.2, 0), Vector3(60, 25, 60), massKg: 20);
      final c = LuminaCharacter(location: Vector3(0, 50 + 80 + 20, 0));
      w.world.persistentLevel.registerActor(c);
      w.begin();
      w.run(2);
      expect(c.characterMovement.isGrounded, isTrue);
      expect(c.actorLocation.y, closeTo(50 + 80, 3), reason: 'standing on top of the box');
      expect(box.worldLocation.y, closeTo(25, 1));
      expect(w.physics.contacts.where((m) => identical(m.a, box.physicsBody)).expand((m) => m.points).fold<double>(
              0, (s, p) => s + p.normalImpulse),
          greaterThan(20 * 980 / 120 * 2), reason: 'the floor carries the box and the character');
    });
  });
}
