import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'pose_fixture.dart';

void main() {
  final mesh = meshAt(Vector3(-15, 0, 40), rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.7));
  final up = Vector3(0, 1, 0);
  const chain = ['neck_01', 'neck_02', 'head'];

  /// Each chain bone's own yaw (degrees, about world up) over its parent's.
  List<double> yawShares(PoseRun r, Map<String, Quaternion> before) {
    var parent = Quaternion.identity();
    final out = <double>[];
    for (final b in chain) {
      final d = LuminaPoseQuat.qMul(r.rotationOf(b), LuminaPoseQuat.qConj(before[b]!))..normalize();
      final own = LuminaPoseQuat.qMul(d, LuminaPoseQuat.qConj(parent))..normalize();
      out.add(LuminaPoseQuat.twistAngle(own, up) * 180 / math.pi);
      parent = d;
    }
    return out;
  }

  Vector3 lookLeft(PoseRun r, double degrees) {
    final pivot = r.at('neck_01');
    final handle = r.component.handleWorldLocation('head')!;
    return pivot + LuminaPoseQuat.qRotate(Quaternion.axisAngle(up, degrees * math.pi / 180), handle - pivot);
  }

  test('a look target 45° to the left splits the yaw 0.25 / 0.35 / 0.4 over neck_01, neck_02 and head', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final before = {for (final b in chain) b: r.rotationOf(b)};
    r.component.setHandleTarget('head', lookLeft(r, 45));
    r.tick();
    final shares = yawShares(r, before);
    expect(shares[0], closeTo(0.25 * 45, 0.5));
    expect(shares[1], closeTo(0.35 * 45, 0.5));
    expect(shares[2], closeTo(0.4 * 45, 0.5));
  });

  test('a look target 120° to the left stops at the neck yaw limit', () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final before = {for (final b in chain) b: r.rotationOf(b)};
    r.component.setHandleTarget('head', lookLeft(r, 120));
    r.tick();
    final shares = yawShares(r, before);
    final limit = r.rig.limits.neckYaw;
    expect(shares.fold(0.0, (a, b) => a + b), closeTo(limit, 0.5));
    expect(shares[2], closeTo(0.4 * limit, 0.5));
  });

  test("the head handle's rotation adds roll; pitch follows a target above", () {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final head = r.component.handleWorldLocation('head')!;
    final rest = r.rotationOf('head');
    final pivot = r.at('neck_01');
    final facing = LuminaPoseQuat.qRotate(Quaternion.axisAngle(up, 0.7), Vector3(0, 0, 1));
    final rolled = LuminaPoseQuat.qMul(Quaternion.axisAngle(facing, 20 * math.pi / 180), rest);
    r.component.setHandleTarget('head', head, worldRotation: rolled);
    r.tick();
    expect(angleBetween(r.rotationOf('head'), rolled), lessThan(0.5));
    // Looking 30° down.
    final r2 = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: mesh);
    final side = facing.cross(up).normalized();
    final down = pivot + LuminaPoseQuat.qRotate(Quaternion.axisAngle(side, -30 * math.pi / 180), head - pivot);
    r2.component.setHandleTarget('head', down);
    r2.tick();
    final d = r2.component.handleWorldLocation('head')! - pivot;
    expect(d.normalized().dot(up), lessThan((head - pivot).normalized().dot(up)));
  });
}
