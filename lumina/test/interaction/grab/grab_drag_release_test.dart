import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'grab_fixture.dart';

void main() {
  test('grip 0 → 0.8 → hold → up 20 cm over 30 ticks → 0.2: grabbed once, no jump, the hand rises 20 cm, released once, stays', () {
    final r = GrabRun();
    final hand = r.handle('hand_r');
    final g = ScriptedGrabber('right', at: hand + Vector3(3, -2, 4));
    r.interactor.registerGrabber(g);
    r.tick();
    expect(r.grabbed, isEmpty);
    g.gripValue = 0.8;
    r.tick();
    expect(r.grabbed, ['hand_r@right']);
    expect(r.handle('hand_r').distanceTo(hand), lessThan(1e-6), reason: 'the offset is kept: no jump at the grab');
    final start = g.position.clone();
    for (var i = 1; i <= 30; i++) {
      g.position.setFrom(start + Vector3(0, 20.0 * i / 30, 0));
      r.tick();
    }
    expect(r.handle('hand_r').distanceTo(hand + Vector3(0, 20, 0)), lessThan(0.05));
    g.gripValue = 0.2;
    r.tick();
    expect(r.released, ['hand_r@right']);
    expect(r.grabbed, hasLength(1));
    g.position.setFrom(start + Vector3(0, -30, 10));
    r.tick(60);
    expect(r.handle('hand_r').distanceTo(hand + Vector3(0, 20, 0)), lessThan(0.05), reason: 'the pose stays on release');
    expect(r.poser.handles['hand_r']!.hasTarget, isTrue);
  });

  test('hysteresis: 0.6 does not grab, 0.5 after a grab still holds, 0.25 lets go', () {
    final r = GrabRun();
    final g = ScriptedGrabber('right', at: r.handle('hand_r') + Vector3(0, 0, 3));
    r.interactor.registerGrabber(g);
    g.gripValue = 0.6;
    r.tick();
    expect(r.grabbed, isEmpty);
    g.gripValue = 0.75;
    r.tick();
    expect(r.grabbed, hasLength(1));
    g.gripValue = 0.5;
    r.tick();
    expect(r.released, isEmpty);
    g.gripValue = 0.25;
    r.tick();
    expect(r.released, hasLength(1));
    // Holding the grip down does not grab again without a new press.
    g.gripValue = 0.5;
    r.tick();
    expect(r.grabbed, hasLength(1));
  });

  test('the hand follows the grabber turning; an untracked grabber lets go', () {
    final r = GrabRun();
    final hand = r.handle('hand_l');
    final g = ScriptedGrabber('left', at: hand + Vector3(0, 0, 2))..gripValue = 1;
    r.interactor.registerGrabber(g);
    r.tick();
    final before = r.run.rotationOf('hand_l');
    final turn = Quaternion.axisAngle(Vector3(0, 1, 0), 0.3);
    g.rotation = turn;
    r.tick();
    expect(angleBetween(r.run.rotationOf('hand_l'), LuminaPoseQuat.qMul(turn, before)), lessThan(0.05));
    g.tracked = false;
    r.tick();
    expect(r.released, ['hand_l@left']);
  });
}
