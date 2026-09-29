import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'physics_fixture.dart';

/// Physics bench (not a unit assertion): 200 awake boxes at 120 Hz. The
/// target is under 4 ms per 60 Hz frame on the development machine; the
/// measurement is printed for the task report.
void main() {
  test('bench: 200 awake boxes falling and piling at 120 Hz', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    for (var i = 0; i < 200; i++) {
      final x = (i % 10) * 70.0 - 315, z = ((i ~/ 10) % 10) * 70.0 - 315, layer = i ~/ 100;
      w.box(Vector3(x, 40.0 + layer * 60.0, z), Vector3.all(25));
    }
    // Keep every body awake: the worst case.
    w.physics.timeToSleep = double.infinity;
    w.begin();
    // Warm up the JIT on the landing, then time a second of busy frames.
    w.run(0.5);
    final awake = w.physics.bodies.where((b) => b.isAwake).length;
    final watch = Stopwatch()..start();
    const frames = 60;
    for (var i = 0; i < frames; i++) {
      w.physics.advance(1 / 60);
    }
    watch.stop();
    final msPerFrame = watch.elapsedMicroseconds / 1000 / frames;
    // ignore: avoid_print
    print('physics bench: 200 boxes ($awake awake at start), ${w.physics.contacts.length} contacts, '
        '${msPerFrame.toStringAsFixed(2)} ms per 60 Hz frame (2 steps at 120 Hz)');
    expect(msPerFrame.isFinite, isTrue);
  });
}
