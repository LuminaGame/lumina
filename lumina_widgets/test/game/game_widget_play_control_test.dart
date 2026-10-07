import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

class CountingActor extends LuminaActor {
  int tickCount = 0;
  final List<double> deltas = [];
  CountingActor({super.key});

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
    deltas.add(deltaTime);
  }
}

/// A game whose declarative tree contributes one [CountingActor] to the persistent level.
class PlayControlGame extends LuminaGame {
  CountingActor? lastBuiltActor;
  int buildCount = 0;

  PlayControlGame({super.gameInstanceFactory});

  @override
  LuminaObject? build(LuminaBuildContext context) {
    buildCount++;
    lastBuiltActor = CountingActor();
    return LuminaNodeGroup(children: [lastBuiltActor!]);
  }
}

void main() {
  group('LuminaGameWidget play control', () {
    testWidgets('paused flag and onPlayStateChanged are wired to the game', (tester) async {
      final game = PlayControlGame();
      final states = <LuminaPlayState>[];

      Widget build(bool paused) => Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 64,
              height: 64,
              child: LuminaGameWidget(
                game: game,
                paused: paused,
                useHeadlessSwapChain: false,
                onPlayStateChanged: states.add,
              ),
            ),
          );

      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pump();

      if (game.playState == LuminaPlayState.stopped) {
        // FilamentWidget could not create a scene in this test binding.
        await tester.pumpWidget(const SizedBox.shrink());
        markTestSkipped('FilamentWidget did not create a scene in the test binding');
        return;
      }

      expect(game.isPaused, isTrue);
      expect(states.first, LuminaPlayState.playing);
      expect(states.last, LuminaPlayState.paused);

      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(game.isPaused, isFalse);
      expect(states.last, LuminaPlayState.playing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(game.playState, LuminaPlayState.stopped);
    });
  });
}
