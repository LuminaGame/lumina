import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'grab_fixture.dart';

void main() {
  /// A point [toHand] cm from the hand and [toElbow] cm from the elbow.
  Vector3 between(GrabRun r, double toHand, double toElbow) {
    final hand = r.handle('hand_r'), elbow = r.handle('elbow_r');
    final axis = hand - elbow;
    final length = axis.length;
    axis.normalize();
    final along = (toElbow * toElbow - toHand * toHand + length * length) / (2 * length);
    final side = math.sqrt(math.max(0.0, toElbow * toElbow - along * along));
    final across = axis.cross(Vector3(0, 1, 0)).normalized();
    return elbow + axis * along + across * side;
  }

  test('a grabber 6 cm from hand_r and 10 cm from elbow_r hovers hand_r; 9 cm from both hovers nothing (radius 8)', () {
    final r = GrabRun(lowerArm: 0.12);
    final g = ScriptedGrabber('right');
    r.interactor.registerGrabber(g);
    g.position.setFrom(between(r, 6, 10));
    expect(g.position.distanceTo(r.handle('hand_r')), closeTo(6, 1e-9));
    expect(g.position.distanceTo(r.handle('elbow_r')), closeTo(10, 1e-9));
    r.tick();
    expect(r.interactor.hoveredBy(g)?.handle, 'hand_r');
    expect(r.hovered, ['hand_r@right']);

    g.position.setFrom(between(r, 9, 9));
    r.tick();
    expect(r.interactor.hoveredBy(g), isNull);
    expect(r.hovered.last, 'null@right');
  });

  test('a ray 2° off the head handle at 1.5 m hovers the head; 4° off hovers nothing', () {
    final r = GrabRun();
    final g = ScriptedGrabber('right');
    r.interactor.registerGrabber(g);
    final head = r.handle('head');
    final origin = head + Vector3(0, 30, 150 - 3);
    final toHead = (head - origin).normalized();
    final side = toHead.cross(Vector3(1, 0, 0)).normalized();
    g.position.setFrom(origin);
    g.rayValue = LuminaGrabRay(origin, LuminaPoseQuat.qRotate(Quaternion.axisAngle(side, 2 * math.pi / 180), toHead));
    r.tick();
    expect(r.interactor.hoveredBy(g)?.handle, 'head');
    g.rayValue = LuminaGrabRay(origin, LuminaPoseQuat.qRotate(Quaternion.axisAngle(side, 4 * math.pi / 180), toHead));
    r.tick();
    expect(r.interactor.hoveredBy(g), isNull);
  });

  test('the head and the pelvis have larger grab radii', () {
    final r = GrabRun();
    expect(r.interactor.radiusOf('head'), 12);
    expect(r.interactor.radiusOf('pelvis'), 15);
    expect(r.interactor.radiusOf('hand_l'), 8);
    final g = ScriptedGrabber('left', at: r.handle('pelvis') + Vector3(0, 0, 14));
    r.interactor.registerGrabber(g);
    r.tick();
    expect(r.interactor.hoveredBy(g)?.handle, 'pelvis');
  });
}
