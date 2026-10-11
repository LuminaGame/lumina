import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'pose_fixture.dart';

void main() {
  final turn = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 5);
  final mesh = meshAt(Vector3(30, 5, 80), rotation: turn);
  final forward = LuminaPoseQuat.qRotate(turn, Vector3(0, 0, 1));
  const spine = ['spine_01', 'spine_02', 'spine_03', 'spine_04', 'spine_05'];

  double spineLength(PoseRun r) {
    final points = [for (final b in spine) r.at(b), r.at('neck_01')];
    var sum = 0.0;
    for (var i = 0; i + 1 < points.length; i++) {
      sum += points[i].distanceTo(points[i + 1]);
    }
    return sum;
  }

  test('a chest handle 15 cm forward bends the 5-bone spine within its joint limits, keeps its length, and the head follows', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final rest = {for (final b in spine) b: r.localRotation(b).clone()};
    final restNeck = {for (final b in const ['neck_01', 'neck_02', 'head']) b: r.localRotation(b).clone()};
    final length = spineLength(r);
    final head = r.at('head');
    final chest = r.component.handleWorldLocation('chest')!;
    expect(chest.distanceTo(r.at('neck_01')), lessThan(1e-9));
    r.component.setHandleTarget('chest', chest + forward * 15.0);
    r.tick();
    final limit = r.rig.limits.spineBend;
    for (final b in spine) {
      expect(angleBetween(r.localRotation(b), rest[b]!), lessThanOrEqualTo(limit + 1e-6), reason: b);
    }
    expect((spineLength(r) - length).abs() / length, lessThan(0.001));
    // A straight spine cannot keep its length and reach 15 cm straight
    // forward: the chest goes as far as it can along the way.
    final reached = r.at('neck_01');
    expect((reached - chest).dot(forward), greaterThan(12));
    expect(reached.distanceTo(chest + forward * 15.0), lessThan(3));
    // The head follows the chest: its neck keeps the incoming pose.
    expect(r.at('head').distanceTo(head), greaterThan(10));
    for (final b in restNeck.keys) {
      expect(angleBetween(r.localRotation(b), restNeck[b]!), lessThan(1e-6), reason: b);
    }
  });

  test('with the head handle set, the neck turns the head back towards it after the spine bends', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final head = r.component.handleWorldLocation('head')!;
    final chest = r.component.handleWorldLocation('chest')!;
    r.component.setHandleTarget('chest', chest + forward * 15.0);
    r.tick();
    final pivot = r.at('neck_01');
    final followed = (r.component.handleWorldLocation('head')! - pivot).normalized();
    r.component.setHandleTarget('head', head);
    r.tick();
    // The head now faces closer to its handle's direction from the neck.
    final wanted = (head - pivot).normalized();
    final facing = (r.component.handleWorldLocation('head')! - pivot).normalized();
    expect(facing.dot(wanted), greaterThan(followed.dot(wanted)));
  });

  test('a chest handle out of reach bends every joint to its limit at most', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final rest = {for (final b in spine) b: r.localRotation(b).clone()};
    final chest = r.component.handleWorldLocation('chest')!;
    r.component.setHandleTarget('chest', chest + forward * 80.0 - Vector3(0, 40, 0));
    r.tick();
    for (final b in spine) {
      expect(angleBetween(r.localRotation(b), rest[b]!), lessThanOrEqualTo(r.rig.limits.spineBend + 1e-6), reason: b);
    }
  });
}
