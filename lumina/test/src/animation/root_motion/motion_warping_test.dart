import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Scale warping of a root path: a clip root moving 100 cm forward (+Z at
/// yaw 0) in 1 s, linearly.
void main() {
  LuminaRootDelta forward(double a, double b) => (x: 0.0, y: 0.0, z: (b - a) * 100.0, yaw: 0.0);

  test('a window brings the root exactly onto its target, keeping the clip direction, then the clip goes on', () {
    final warper = LuminaMotionWarper(
      const [LuminaWarpWindow(target: 'Ledge', start: 0.2, end: 0.8)],
      {'Ledge': LuminaWarpTarget(Vector3(10, 30, 140), 0)},
    );
    var p = Vector3.zero();
    var yaw = 0.0;
    var t = 0.0;
    var lastZ = -1.0;
    const dt = 1 / 60;
    while (t < 1.0 - 1e-9) {
      final next = math.min(1.0, t + dt);
      final (np, ny) = warper.advance(t, next, p, yaw, forward);
      expect(np.z, greaterThan(lastZ), reason: 'monotonic along the clip direction at $t');
      lastZ = np.z;
      if (t < 0.8 - 1e-9 && next >= 0.8 - 1e-9) {
        // The step that ends the window is split there: check by replaying to 0.8.
        final (atEnd, _) = warper.advance(t, 0.8, p, yaw, forward);
        expect(atEnd.x, closeTo(10, 1e-6));
        expect(atEnd.y, closeTo(30, 1e-6));
        expect(atEnd.z, closeTo(140, 1e-6));
      }
      if (next <= 0.2 + 1e-9) expect(np.z, closeTo(next * 100, 1e-9), reason: 'unwarped before the window');
      p = np;
      yaw = ny;
      t = next;
    }
    expect(p.z, closeTo(160, 1e-6), reason: 'after the window: 140 + the clip\'s last 20 cm');
    expect(p.x, closeTo(10, 1e-6));
  });

  test('one big step equals many small ones (split at the window bounds)', () {
    final warper = LuminaMotionWarper(
      const [LuminaWarpWindow(target: 'A', start: 0.1, end: 0.5)],
      {'A': LuminaWarpTarget(Vector3(0, 0, 80), 0)},
    );
    final (big, _) = warper.advance(0, 1, Vector3.zero(), 0, forward);
    var p = Vector3.zero();
    var y = 0.0;
    for (var i = 0; i < 100; i++) {
      (p, y) = warper.advance(i / 100, (i + 1) / 100, p, y, forward);
    }
    expect(big.z, closeTo(p.z, 1e-6));
    expect(big.z, closeTo(80 + 50, 1e-6));
  });

  test('the yaw turns to the target over a rotation window; the clip step follows the new facing', () {
    final warper = LuminaMotionWarper(
      const [LuminaWarpWindow(target: 'T', start: 0.0, end: 0.5, warpTranslation: false, warpRotation: true)],
      {'T': LuminaWarpTarget(Vector3.zero(), 0.6)},
    );
    var p = Vector3.zero();
    var yaw = 0.0;
    for (var i = 0; i < 30; i++) {
      (p, yaw) = warper.advance(i / 60, (i + 1) / 60, p, yaw, forward);
    }
    expect(yaw, closeTo(0.6, 1e-9));
    final (q, _) = warper.advance(0.5, 0.6, p, yaw, forward);
    expect(q.x - p.x, closeTo(10 * math.sin(0.6), 1e-9));
    expect(q.z - p.z, closeTo(10 * math.cos(0.6), 1e-9));
  });

  test('a warp point offset puts that point, not the root, on the target; a missing target plays unwarped', () {
    final warper = LuminaMotionWarper(
      [LuminaWarpWindow(target: 'Ledge', start: 0.0, end: 0.5, warpPointOffset: Vector3(0, 100, 40))],
      {'Ledge': LuminaWarpTarget(Vector3(0, 120, 200), 0)},
    );
    final (p, _) = warper.advance(0, 0.5, Vector3.zero(), 0, forward);
    expect(p.y, closeTo(20, 1e-6));
    expect(p.z, closeTo(160, 1e-6));
    final unwarped = LuminaMotionWarper(const [LuminaWarpWindow(target: 'Gone', start: 0, end: 1)], {});
    final (u, _) = unwarped.advance(0, 1, Vector3.zero(), 0, forward);
    expect(u.z, closeTo(100, 1e-9));
  });

  test('windows round-trip through JSON', () {
    final w = LuminaWarpWindow(
        target: 'FrontLedge', start: 0.5, end: 0.7, warpRotation: true, warpPointOffset: Vector3(1, 2, 3), warpPointBone: 'attach');
    final back = LuminaWarpWindow.fromJson(w.toJson());
    expect(back.target, 'FrontLedge');
    expect(back.end, 0.7);
    expect(back.warpRotation, isTrue);
    expect(back.warpPointOffset!.z, 3);
    expect(back.warpPointBone, 'attach');
  });
}
