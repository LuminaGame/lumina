import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'pose_fixture.dart';

void main() {
  double kneeBend(PoseRun r, String side) {
    final a = r.at('thigh_$side'), b = r.at('calf_$side'), c = r.at('foot_$side');
    return math.acos((b - a).normalized().dot((c - b).normalized())) * 180 / math.pi;
  }

  for (final (label, rig) in [
    ('a MetaHuman-named skeleton', () => LuminaPoseRig.detect(metahumanSkeleton())),
    ('the test-assets mannequin', () => LuminaPoseRig.detect(mannequinSkeleton)),
  ]) {
    test('$label: the pelvis 20 cm down with both feet set keeps the feet planted and bends the knees', () {
      final r = PoseRun(rig(), mesh: meshAt(Vector3(10, 0, -20), rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 1.1)));
      final feet = {for (final s in const ['l', 'r']) s: r.at('foot_$s')};
      final bends = {for (final s in const ['l', 'r']) s: kneeBend(r, s)};
      final pelvis = r.component.handleWorldLocation('pelvis')!;
      for (final s in const ['l', 'r']) {
        r.component.setHandleTarget('foot_$s', feet[s]!);
      }
      r.component.setHandleTarget('pelvis', pelvis - Vector3(0, 20, 0));
      r.tick();
      expect(r.at('pelvis').distanceTo(pelvis - Vector3(0, 20, 0)), lessThan(1e-6));
      for (final s in const ['l', 'r']) {
        expect(r.at('foot_$s').distanceTo(feet[s]!), lessThan(0.1), reason: 'foot_$s');
        expect(kneeBend(r, s), greaterThan(bends[s]! + 20), reason: 'knee_$s');
      }
    }, skip: label.contains('mannequin') ? mannequinSkip : false);
  }

  test('a foot without a target follows the pelvis', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()));
    final foot = r.at('foot_l');
    final pelvis = r.component.handleWorldLocation('pelvis')!;
    r.component.setHandleTarget('pelvis', pelvis + Vector3(15, 0, 0));
    r.tick();
    expect(r.at('foot_l').distanceTo(foot + Vector3(15, 0, 0)), lessThan(1e-6));
  });
}
