import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

class _TickCounter extends LuminaActor {
  int ticks = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    ticks++;
  }
}

class _PacingGame extends LuminaGame {
  final _TickCounter counter = _TickCounter();

  @override
  LuminaObject? build(LuminaBuildContext context) => LuminaNodeGroup(children: [counter]);
}

/// The game widget paces the world tick and the view by what is in force:
/// the project's Target FPS / VSync until the player applies their own.
void main() {
  const refresh = Duration(microseconds: 16667);

  setUp(LuminaGameFramePacing.resetForTesting);
  tearDown(LuminaGameFramePacing.resetForTesting);

  testWidgets('the project settings are the defaults; Apply Scalability Settings changes the pacing at once', (tester) async {
    final game = _PacingGame();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 64,
        height: 64,
        child: LuminaGameWidget(game: game, useHeadlessSwapChain: false, targetFps: 60, vsyncEnabled: true),
      ),
    ));
    expect(LuminaGameFramePacing.targetFps, 60);
    expect(LuminaGameFramePacing.vsyncEnabled, isTrue);
    FilamentWidget view() => tester.widget<FilamentWidget>(find.byType(FilamentWidget));
    expect(view().targetFps, 60);
    expect(view().vsyncEnabled, isTrue);

    for (var i = 0; i < 5; i++) {
      await tester.pump(refresh);
    }
    if (game.playState == LuminaPlayState.stopped) {
      await tester.pumpWidget(const SizedBox.shrink());
      markTestSkipped('FilamentWidget did not create a scene in the test binding');
      return;
    }

    Future<int> ticksOver(int refreshes) async {
      final before = game.counter.ticks;
      for (var i = 0; i < refreshes; i++) {
        await tester.pump(refresh);
      }
      return game.counter.ticks - before;
    }

    expect(await ticksOver(120), inInclusiveRange(119, 120));

    final settings = game.world!.userSettings;
    expect(settings.targetFps, 60, reason: 'Get returns the project default in force');
    settings
      ..setTargetFps(30)
      ..setVsyncEnabled(false)
      ..applySettings();
    await tester.pump(refresh);
    expect(view().targetFps, 30);
    expect(view().vsyncEnabled, isFalse);
    expect(await ticksOver(120), inInclusiveRange(59, 61));

    settings
      ..setTargetFps(0)
      ..applySettings();
    await tester.pump(refresh);
    expect(view().targetFps, isNull, reason: 'unlimited');
    expect(await ticksOver(120), inInclusiveRange(119, 120));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
