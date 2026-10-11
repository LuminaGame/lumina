import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'pose_fixture.dart';

void main() {
  final mesh = meshAt(Vector3(-40, 0, 25), rotation: Quaternion.axisAngle(Vector3(0, 1, 0), -math.pi / 4));

  /// How far the elbow lies from the shoulder–hand line towards [side].
  double towards(PoseRun r, String upper, String lower, String end, Vector3 side) {
    final a = r.at(upper), b = r.at(lower), c = r.at(end);
    final axis = (c - a).normalized();
    final offset = LuminaPoseQuat.across(b - a, axis);
    return offset.dot(LuminaPoseQuat.across(side, axis).normalized());
  }

  test('moving the elbow handle 20 cm down swings the arm plane about the shoulder–hand axis; the hand stays', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    // Bend the arm first so it has a plane to swing.
    final shoulder = r.at('upperarm_l');
    r.component.setHandleTarget('hand_l', shoulder + Vector3(20, -10, 30));
    r.tick();
    final hand = r.at('hand_l');
    final elbow = r.at('lowerarm_l');
    final handle = elbow + Vector3(0, -20, 0);
    expect(r.component.setHandleTarget('elbow_l', handle), isTrue);
    r.tick();
    expect(r.at('hand_l').distanceTo(hand), lessThan(0.05));
    expect(r.at('lowerarm_l').distanceTo(r.at('upperarm_l')), closeTo(30, 1e-4));
    expect(towards(r, 'upperarm_l', 'lowerarm_l', 'hand_l', handle - r.at('upperarm_l')), greaterThan(0));
    // The elbow lies in the plane of the shoulder, the hand and the handle.
    final a = r.at('upperarm_l'), c = r.at('hand_l');
    final normal = (c - a).cross(handle - a).normalized();
    expect((r.at('lowerarm_l') - a).dot(normal).abs(), lessThan(1e-6));
  });

  test('an elbow handle alone keeps the hand where the animation put it', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final hand = r.at('hand_r');
    final elbow = r.at('lowerarm_r');
    r.component.setHandleTarget('elbow_r', elbow + Vector3(0, -20, 0));
    r.tick();
    expect(r.at('hand_r').distanceTo(hand), lessThan(0.05));
    expect(r.at('lowerarm_r').distanceTo(elbow), greaterThan(1.0));
  });

  test('a knee handle swings the leg plane; the foot stays', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final foot = r.at('foot_l');
    r.component.setHandleTarget('foot_l', foot + Vector3(0, 30, 0));
    r.tick();
    final placed = r.at('foot_l');
    final knee = r.at('calf_l');
    final handle = knee + mesh.getRotation().transformed(Vector3(1, 0, 0)).normalized() * 20.0;
    r.component.setHandleTarget('knee_l', handle);
    r.tick();
    expect(r.at('foot_l').distanceTo(placed), lessThan(0.05));
    expect(towards(r, 'thigh_l', 'calf_l', 'foot_l', handle - r.at('thigh_l')), greaterThan(0));
  });
}
