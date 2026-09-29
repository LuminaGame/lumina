import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The world keeps the engine stats a Blueprint reads (frame
/// number, frame time, a smoothed frame rate, real time) and a time dilation
/// that scales gameplay time but not real time.
void main() {
  test('frame number, frame rate and frame time follow fixed steps', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();
    expect(world.frameNumber, 0);
    expect(world.frameRate, 0.0);
    for (var i = 0; i < 60; i++) {
      world.step(1 / 60);
    }
    expect(world.frameNumber, 60);
    expect(world.frameRate, closeTo(60.0, 1.0));
    expect(world.lastFrameTimeMs, closeTo(1000.0 / 60.0, 1e-6));
    expect(world.realTimeSeconds, closeTo(1.0, 1e-9));
    expect(world.timeSeconds, closeTo(1.0, 1e-9));
    // The average converges from the deltas, not the wall clock.
    for (var i = 0; i < 120; i++) {
      world.step(1 / 30);
    }
    expect(world.frameRate, closeTo(30.0, 1.0));
    expect(world.lastFrameTimeMs, closeTo(1000.0 / 30.0, 1e-6));
  });

  test('time dilation halves the delta actors receive while real time keeps its rate', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final deltas = <double>[];
    final actor = _TickRecorder(deltas);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    world.step(0.1);
    expect(world.timeDilation, 1.0);
    world.timeDilation = 0.5;
    world.step(0.1);
    world.step(0.1);
    expect(deltas, [closeTo(0.1, 1e-12), closeTo(0.05, 1e-12), closeTo(0.05, 1e-12)]);
    expect(world.realTimeSeconds, closeTo(0.3, 1e-12));
    expect(world.timeSeconds, closeTo(0.2, 1e-12));
    expect(world.lastFrameTimeMs, closeTo(100.0, 1e-9), reason: 'frame time is real time');
    expect(() => world.timeDilation = -1, throwsArgumentError);
  });

  test('a paused world advances neither clock through tick, but step still does', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();
    world.isPaused = true;
    world.tick(0.1);
    expect(world.frameNumber, 0);
    expect(world.realTimeSeconds, 0.0);
    world.step(0.1);
    expect(world.frameNumber, 1);
    expect(world.realTimeSeconds, closeTo(0.1, 1e-12));
  });
}

class _TickRecorder extends LuminaActor {
  final List<double> deltas;
  _TickRecorder(this.deltas);

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    deltas.add(deltaTime);
  }
}
