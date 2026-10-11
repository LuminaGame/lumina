import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'pose_fixture.dart';

void main() {
  // The mesh stands away from the origin and turned, so every target goes
  // through the world → model conversion.
  final mesh = meshAt(Vector3(120, 0, -60), rotation: Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 6));

  PoseRun run() => PoseRun(LuminaPoseRig.detect(metahumanSkeleton(upperArm: 0.30, lowerArm: 0.28)), mesh: mesh);

  test('upper 30 cm, lower 28 cm, a target 40 cm from the shoulder: the hand reaches it, the bones keep their lengths', () {
    final r = run();
    final shoulder = r.at('upperarm_l');
    final target = shoulder + (Vector3(0.6, -0.5, 0.62)..normalize()) * 40.0;
    expect(r.component.setHandleTarget('hand_l', target), isTrue);
    r.tick();
    final elbow = r.at('lowerarm_l'), hand = r.at('hand_l');
    expect(hand.distanceTo(target), lessThan(0.05));
    expect(r.at('upperarm_l').distanceTo(shoulder), lessThan(1e-9), reason: 'the shoulder does not move');
    expect(elbow.distanceTo(shoulder), closeTo(30, 1e-4));
    expect(hand.distanceTo(elbow), closeTo(28, 1e-4));
    // The handle reports where the hand is, in world units.
    expect(r.component.handleWorldLocation('hand_l')!.distanceTo(hand), lessThan(1e-6));
    // Holding: more frames change nothing.
    r.tick(10);
    expect(r.at('hand_l').distanceTo(target), lessThan(0.05));
  });

  test('a target 80 cm away is clamped to 58 cm along its direction', () {
    final r = run();
    final shoulder = r.at('upperarm_l');
    final direction = (Vector3(0.9, 0.2, 0.3)..normalize());
    r.component.setHandleTarget('hand_l', shoulder + direction * 80.0);
    r.tick();
    final hand = r.at('hand_l');
    expect(hand.distanceTo(shoulder + direction * 58.0), lessThan(0.05));
    expect(r.at('lowerarm_l').distanceTo(shoulder), closeTo(30, 1e-4));
  });

  test('a target closer than the elbow limit allows stops at the 150° bend', () {
    final r = run();
    final shoulder = r.at('upperarm_l');
    final direction = (Vector3(0.7, -0.7, 0.2)..normalize());
    r.component.setHandleTarget('hand_l', shoulder + direction * 5.0);
    r.tick();
    final elbow = r.at('lowerarm_l'), hand = r.at('hand_l');
    final bend = math.acos((elbow - shoulder).normalized().dot((hand - elbow).normalized())) * 180 / math.pi;
    expect(bend, closeTo(150, 0.01));
  });

  test("a hand handle's rotation turns the hand, and the forearm twist bones share its twist", () {
    final r = run();
    final hand = r.at('hand_l');
    final rest = r.rotationOf('hand_l');
    final forearm = (hand - r.at('lowerarm_l')).normalized();
    final turn = Quaternion.axisAngle(forearm, math.pi / 3);
    r.component.setHandleTarget('hand_l', hand, worldRotation: LuminaPoseQuat.qMul(turn, rest));
    r.tick();
    expect(angleBetween(r.rotationOf('hand_l'), LuminaPoseQuat.qMul(turn, rest)), lessThan(0.01));
    // twist_01 sits at 2/3 of the forearm, twist_02 at 1/3.
    final restLocal = LuminaPoseRig.detect(metahumanSkeleton()).restPoseCopy();
    Quaternion restOf(String bone) {
      final o = r.rig.slotNamed(bone) * 10;
      return Quaternion(restLocal[o + 3], restLocal[o + 4], restLocal[o + 5], restLocal[o + 6]);
    }

    expect(angleBetween(r.localRotation('lowerarm_twist_01_l'), restOf('lowerarm_twist_01_l')), closeTo(40, 0.05));
    expect(angleBetween(r.localRotation('lowerarm_twist_02_l'), restOf('lowerarm_twist_02_l')), closeTo(20, 0.05));
  });

  test('a foot keeps its world rotation (stays flat) while its leg bends', () {
    final r = run();
    final foot = r.at('foot_r');
    final flat = r.rotationOf('foot_r');
    r.component.setHandleTarget('foot_r', foot + Vector3(0, 25, 10));
    r.tick();
    expect(r.at('foot_r').distanceTo(foot + Vector3(0, 25, 10)), lessThan(0.05));
    expect(angleBetween(r.rotationOf('foot_r'), flat), lessThan(1e-6));
  });
}
