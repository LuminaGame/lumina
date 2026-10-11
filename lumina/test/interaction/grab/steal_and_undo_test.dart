import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'grab_fixture.dart';

void main() {
  test('the left grabber takes the handle the right holds: the right lets go, both pulse', () {
    final r = GrabRun();
    final hand = r.handle('hand_r');
    final right = ScriptedGrabber('right', at: hand + Vector3(0, 0, 3))..gripValue = 1;
    final left = ScriptedGrabber('left', at: hand + Vector3(0, 3, 0));
    r.interactor
      ..registerGrabber(right)
      ..registerGrabber(left);
    r.tick();
    expect(r.interactor.heldBy(right)?.handle, 'hand_r');
    left.gripValue = 1;
    r.tick();
    expect(r.interactor.heldBy(left)?.handle, 'hand_r');
    expect(r.interactor.heldBy(right), isNull);
    expect(r.released, ['hand_r@right']);
    expect(r.grabbed, ['hand_r@right', 'hand_r@left']);
    expect(right.pulses, [(0.5, 0.03), (0.2, 0.015)]);
    expect(left.pulses, [(0.5, 0.03)]);
    // The left drags it now.
    left.position.add(Vector3(0, 10, 0));
    r.tick();
    expect(r.handle('hand_r').distanceTo(hand + Vector3(0, 10, 0)), lessThan(0.05));
  });

  test('undo restores the targets from before the last grab', () {
    final r = GrabRun();
    final g = ScriptedGrabber('right', at: r.handle('hand_r') + Vector3(0, 0, 3));
    r.interactor.registerGrabber(g);
    void dragBy(Vector3 by) {
      g.gripValue = 1;
      r.tick();
      g.position.add(by);
      r.tick();
      g.gripValue = 0;
      r.tick();
    }

    dragBy(Vector3(0, 12, 5));
    final before = r.poser.targetSnapshot();
    final placed = r.handle('hand_r');
    g.position.setFrom(placed + Vector3(0, 0, 3));
    dragBy(Vector3(-8, 6, 0));
    expect(r.handle('hand_r').distanceTo(placed), greaterThan(5));
    expect(r.interactor.undoLastGrab(), isTrue);
    final after = r.poser.targetSnapshot();
    for (final name in before.keys) {
      final a = before[name]!, b = after[name]!;
      expect(a.modelTarget == null, b.modelTarget == null, reason: name);
      if (a.modelTarget != null) expect(a.modelTarget!.distanceTo(b.modelTarget!), lessThan(1e-6), reason: name);
      expect(a.pendingWorldTarget == null, b.pendingWorldTarget == null, reason: name);
    }
    r.tick();
    expect(r.handle('hand_r').distanceTo(placed), lessThan(1e-6));
    // Undo again: before the first grab, no target at all.
    expect(r.interactor.undoLastGrab(), isTrue);
    r.tick();
    expect(r.poser.handles['hand_r']!.hasTarget, isFalse);
    expect(r.interactor.undoLastGrab(), isFalse);
  });

  test('the undo history keeps the last 32 steps', () {
    final poser = LuminaPoseAuthoringComponent()..setUp(LuminaPoseRig.detect(metahumanSkeleton()));
    for (var i = 0; i < 40; i++) {
      poser.pushUndo();
    }
    expect(poser.undoDepth, LuminaPoseAuthoringComponent.undoCapacity);
  });
}
