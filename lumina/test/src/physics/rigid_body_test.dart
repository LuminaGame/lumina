import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'physics_fixture.dart';

/// Rigid bodies fall, rest, slide, roll, stack, bounce and sleep.
void main() {
  group('rigid body simulation', () {
    test('a 10 kg box dropped from 200 cm lands after √(2·200/980) s and rests without jitter, then sleeps', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      // Bottom face 200 cm above the floor.
      final box = w.box(Vector3(0, 225, 0), Vector3.all(25));
      w.begin();
      final body = box.physicsBody!;
      expect(body.mass, 10.0);
      double? landed;
      w.run(1.5, (t) {
        if (landed == null && box.worldLocation.y - 25 < 0.5) landed = t;
      });
      final expected = math.sqrt(2 * 200 / 980);
      expect(landed, isNotNull);
      expect((landed! - expected).abs(), lessThanOrEqualTo(1 / 60 + 1e-9), reason: 'landed at $landed s, expected $expected s');
      // At rest: less than 0.1 cm of drift over 5 s, level, then asleep.
      final start = box.worldLocation;
      var maxDrift = 0.0;
      w.run(5, (_) => maxDrift = math.max(maxDrift, box.worldLocation.distanceTo(start)));
      expect(maxDrift, lessThan(0.1), reason: 'drift $maxDrift cm');
      expect(box.worldLocation.y, closeTo(25, 0.5));
      expect(tiltDegrees(box.worldRotation), lessThan(0.5));
      expect(body.isAwake, isFalse, reason: 'asleep after resting');
    });

    test('a box on a 20° slope with friction 0.7 stays; at 40° it slides', () {
      for (final (angle, slides) in [(20.0, false), (40.0, true)]) {
        final w = PhysicsWorld();
        final slope = w.slope(angle);
        final n = Vector3(0, 1, 0)..applyQuaternion(slope.worldRotation);
        final box = w.box(PhysicsWorld.slopeOrigin + n * 25.3, Vector3.all(25), rotation: slope.worldRotation);
        w.begin();
        final start = box.worldLocation;
        w.run(2);
        final moved = box.worldLocation.distanceTo(start);
        if (slides) {
          expect(moved, greaterThan(100), reason: '$angle°: moved $moved cm');
          // Downhill is −x.
          expect(box.worldLocation.x, lessThan(start.x - 50));
        } else {
          expect(moved, lessThan(1.0), reason: '$angle°: moved $moved cm');
        }
        expect(tiltDegrees(box.worldRotation) - angle, lessThan(2.0), reason: 'it slides flat on its face, not tumbling');
        w.dispose();
      }
    });

    test('a sphere on a 10° slope rolls: its angular speed matches v / r', () {
      final w = PhysicsWorld();
      final slope = w.slope(10);
      final n = Vector3(0, 1, 0)..applyQuaternion(slope.worldRotation);
      final ball = w.sphere(PhysicsWorld.slopeOrigin + n * 20.2, 20);
      addTearDown(w.dispose);
      w.begin();
      w.run(1.5);
      final body = ball.physicsBody!;
      final v = body.linearVelocity.length;
      final omega = body.angularVelocity.length;
      expect(v, greaterThan(100), reason: 'it gathers speed downhill');
      expect(omega * 20, closeTo(v, v * 0.05), reason: 'rolling without slipping: ω·r = $omega·20, v = $v');
      // (5/7) g sin θ for a solid sphere.
      final a = 5 / 7 * 980 * math.sin(10 * math.pi / 180);
      expect(v, closeTo(a * 1.5, a * 1.5 * 0.1));
    });

    test('five stacked 50 cm boxes stay standing for 10 s (drift under 1 cm)', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final boxes = [for (var i = 0; i < 5; i++) w.box(Vector3(0, 25.0 + 50.0 * i + 0.05 * i, 0), Vector3.all(25))];
      w.begin();
      final starts = [for (final b in boxes) b.worldLocation];
      var drift = 0.0;
      w.run(10, (_) {
        for (var i = 0; i < 5; i++) {
          drift = math.max(drift, boxes[i].worldLocation.distanceTo(starts[i]));
        }
      });
      expect(drift, lessThan(1.0), reason: 'max drift $drift cm');
      for (final b in boxes) {
        expect(tiltDegrees(b.worldRotation), lessThan(1.0));
      }
    });

    test('restitution 0.5 dropped from 100 cm bounces to about 25 cm', () {
      const bouncy = LuminaPhysicalMaterial(restitution: 0.5);
      final w = PhysicsWorld(floorMaterial: bouncy);
      addTearDown(w.dispose);
      final ball = w.sphere(Vector3(0, 120, 0), 20, material: bouncy);
      w.begin();
      var landed = false;
      var peak = 0.0;
      w.run(1.5, (_) {
        final h = ball.worldLocation.y - 20;
        if (!landed && h < 3) landed = true;
        if (landed) peak = math.max(peak, h);
      });
      expect(peak, closeTo(25, 25 * 0.15), reason: 'bounced to $peak cm');
    });

    test('a sleeping body wakes when hit, and on an impulse', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final box = w.box(Vector3(0, 25.2, 0), Vector3.all(25));
      w.begin();
      w.run(2);
      final body = box.physicsBody!;
      expect(body.isAwake, isFalse);
      var woke = 0, slept = 0;
      box.onComponentWake = (_) => woke++;
      box.onComponentSleep = (_) => slept++;
      box.addImpulse(Vector3(0, 3000, 0));
      expect(body.isAwake, isTrue);
      expect(woke, 1);
      w.run(3);
      expect(slept, 1, reason: 'asleep again once it came back to rest');
      // A second box dropped onto it wakes it.
      final falling = w.box(Vector3(0, 150, 0), Vector3.all(25), spawn: true);
      falling.onComponentHit = null;
      var woken = false;
      box.onComponentWake = (_) => woken = true;
      w.run(1);
      expect(falling.physicsBody, isNotNull);
      expect(woken, isTrue);
    });

    test('add_impulse of 1000 kg·cm/s on a 10 kg body changes its velocity by 100 cm/s; switching simulation off freezes it', () {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final box = w.box(Vector3(0, 500, 0), Vector3.all(25))..enableGravity = false;
      w.begin();
      final body = box.physicsBody!;
      final before = body.linearVelocity.clone();
      box.addImpulse(Vector3(1000, 0, 0));
      expect(body.linearVelocity.x - before.x, closeTo(100, 1e-9));
      w.run(0.5);
      final at = box.worldLocation;
      box.simulatePhysics = false;
      expect(box.physicsBody, isNull);
      w.run(1);
      expect(box.worldLocation.distanceTo(at), lessThan(1e-9), reason: 'frozen where it was');
    });

    test('the same inputs twice give identical transforms after 600 steps', () {
      List<double> simulate() {
        final w = PhysicsWorld();
        final boxes = [
          for (var i = 0; i < 4; i++)
            w.box(Vector3(i * 12.0, 60.0 + i * 55, i * 7.0), Vector3(20, 15 + i * 2.0, 25),
                rotation: Quaternion.axisAngle(Vector3(1, 0.3, 0.2).normalized(), 0.3 * i)),
        ];
        final ball = w.sphere(Vector3(-80, 300, 10), 18);
        w.begin();
        for (var i = 0; i < 600; i++) {
          w.physics.advance(w.physics.fixedTimeStep);
        }
        final out = <double>[
          for (final c in [...boxes, ball]) ...[...c.worldLocation.storage, ...c.worldRotation.storage],
        ];
        w.dispose();
        return out;
      }

      final a = simulate();
      final b = simulate();
      expect(b, a);
      expect(a.any((v) => v.isNaN), isFalse);
    });
  });
}
