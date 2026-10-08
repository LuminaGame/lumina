import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ragdoll_fixture.dart';

void main() {
  group('mannequin ragdoll', () {
    test('built at rest: bodies sit on their bones and every joint is closed', () {
      final r = RagdollWorld(meshTransformAt(Vector3(0, 150, 0)));
      expect(r.ragdoll.bodies.length, r.asset.bodies.length);
      expect(r.ragdoll.joints.length, r.asset.constraints.length);
      expect(r.ragdoll.maxJointError, lessThan(1e-6));
      for (final b in r.ragdoll.bodies) {
        final bone = b.boneFrame();
        expect((bone.position - r.rest[b.bone]!.position).length, lessThan(1e-6), reason: b.bone);
      }
      for (final j in r.ragdoll.joints) {
        final (swing, twist) = j.angles;
        expect(swing, lessThan(1e-6), reason: j.name);
        expect(twist.abs(), lessThan(1e-6), reason: j.name);
      }
      expect(r.ragdoll.totalMass, closeTo(80, 1e-6));
      r.dispose();
    });

    test('dropped from 150 cm: stays on the floor and in one piece, never gains energy, settles', () {
      final r = RagdollWorld(meshTransformAt(Vector3(0, 150, 0)));
      final g = LuminaUnits.gravity;
      double potential() => r.ragdoll.bodies.fold(0.0, (e, b) => e + b.body.mass * g * b.body.position.y);
      final start = potential();
      var worstPenetration = 0.0, restingPenetration = 0.0, worstJoint = 0.0, worstEnergy = 0.0;
      double? settledAt;
      final watch = Stopwatch();
      var steps = 0;
      r.w.run(8.0, (t) {
        worstPenetration = math.max(worstPenetration, -r.lowest);
        if (t > 2.0) restingPenetration = math.max(restingPenetration, -r.lowest);
        worstJoint = math.max(worstJoint, r.ragdoll.maxJointError);
        // Total mechanical energy relative to the start.
        worstEnergy = math.max(worstEnergy, r.ragdoll.kineticEnergy + potential() - start);
        if (settledAt == null && t > 0.5 && r.ragdoll.isSettled(2.0)) settledAt = t;
      });
      watch.start();
      for (var i = 0; i < 120; i++) {
        r.w.physics.step(1 / 120);
        steps++;
      }
      watch.stop();
      // ignore: avoid_print
      print('ragdoll: penetration ${worstPenetration.toStringAsFixed(2)} cm (resting ${restingPenetration.toStringAsFixed(2)}), joint error ${worstJoint.toStringAsFixed(2)} cm, '
          'energy gain ${worstEnergy.toStringAsFixed(0)}, settled at $settledAt s, '
          '${(watch.elapsedMicroseconds / steps).toStringAsFixed(0)} µs per step (asleep)');
      // On impact a body moves ~5 cm per step at 120 Hz; resting contact holds.
      expect(worstPenetration, lessThan(7.0));
      expect(restingPenetration, lessThan(1.0));
      expect(worstJoint, lessThan(2.0));
      expect(worstEnergy, lessThan(0.01 * start.abs() + 1000));
      expect(settledAt, isNotNull);
      expect(settledAt!, lessThan(6.0));
      r.dispose();
    });

    test('a step of an awake 16-body ragdoll costs under 1.5 ms', () {
      final r = RagdollWorld(meshTransformAt(Vector3(0, 400, 0)));
      // Warm up, then time steps while it falls and tumbles.
      for (var i = 0; i < 30; i++) {
        r.w.physics.step(1 / 120);
      }
      r.ragdoll.addImpulse(Vector3(0, 0, 2000), bone: 'head');
      final watch = Stopwatch()..start();
      const n = 120;
      for (var i = 0; i < n; i++) {
        r.w.physics.step(1 / 120);
      }
      watch.stop();
      final us = watch.elapsedMicroseconds / n;
      // ignore: avoid_print
      print('ragdoll step: ${us.toStringAsFixed(0)} µs (${r.ragdoll.bodies.length} bodies, ${r.ragdoll.joints.length} joints)');
      expect(us, lessThan(1500));
      r.dispose();
    });

    test('an impulse on the hand moves the hand first', () {
      final r = RagdollWorld(meshTransformAt(Vector3(0, 150, 0)));
      for (final b in r.ragdoll.bodies) {
        b.body.enableGravity = false;
      }
      r.ragdoll.addImpulse(Vector3(0, 0, 500), bone: 'hand_l');
      r.w.physics.step(1 / 120);
      final hand = r.ragdoll.bodyOf('hand_l')!.body.linearVelocity.length;
      final pelvis = r.ragdoll.bodyOf('pelvis')!.body.linearVelocity.length;
      expect(hand, greaterThan(5 * pelvis));
      r.dispose();
    });

    test('powered joints keep the pose they are driven to while the ragdoll falls over', () {
      double meanDeviation(bool powered) {
        final r = RagdollWorld(meshTransformAt(Vector3(0, 2, 0)));
        var sum = 0.0, n = 0;
        r.w.run(3.0, (t) {
          r.ragdoll.driveToward(r.rest, maxTorque: powered ? 2e6 : 0, rate: 30);
          if (t < 2.0) return;
          for (final j in r.ragdoll.joints) {
            final d = (Quaternion.identity().conjugated() * j.relativeRotation())..normalize();
            sum += 2 * math.acos(d.w.abs().clamp(0.0, 1.0)) * 180 / math.pi;
            n++;
          }
        });
        r.dispose();
        return sum / n;
      }

      final powered = meanDeviation(true), limp = meanDeviation(false);
      // ignore: avoid_print
      print('mean joint deviation: powered ${powered.toStringAsFixed(1)}°, limp ${limp.toStringAsFixed(1)}°');
      expect(powered, lessThan(10.0));
      expect(limp, greaterThan(powered * 2));
    });
  }, skip: mannySkip);
}
