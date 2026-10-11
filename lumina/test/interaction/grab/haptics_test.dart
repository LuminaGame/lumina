import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'grab_fixture.dart';

void main() {
  test('grab pulses 0.5 for 30 ms, release 0.2 for 15 ms; a grabber without haptics grabs without error', () {
    final r = GrabRun();
    final g = ScriptedGrabber('right', at: r.handle('hand_r') + Vector3(0, 2, 0));
    r.interactor.registerGrabber(g);
    g.gripValue = 1;
    r.tick();
    expect(g.pulses, [(0.5, 0.03)]);
    g.gripValue = 0;
    r.tick();
    expect(g.pulses, [(0.5, 0.03), (0.2, 0.015)]);

    final quiet = ScriptedGrabber('left', at: r.handle('hand_l') + Vector3(0, 2, 0), hasHaptics: false);
    r.interactor.registerGrabber(quiet);
    quiet.gripValue = 1;
    r.tick();
    quiet.gripValue = 0;
    r.tick();
    expect(r.grabbed.last, 'hand_l@left');
    expect(r.released.last, 'hand_l@left');
    expect(quiet.pulses, isEmpty);
  });
}
