import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// A game that counts how often it is mounted.
class _CountingGame extends LuminaGame {
  int mounts = 0;

  @override
  bool mountGame(FilamentEngine engine, FilamentScene scene, {FilamentView? view}) {
    final mounted = super.mountGame(engine, scene, view: view);
    if (mounted) mounts++;
    return mounted;
  }

  @override
  LuminaObject? build(LuminaBuildContext context) => LuminaNodeGroup(children: [LuminaActor()]);
}

/// The generated game host's tree (code_generator_service.dart): the
/// 3D view with the widget layer stacked over it.
Widget _host(LuminaGame game) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 320,
        height: 180,
        child: KeyedSubtree(
          key: ObjectKey(game),
          child: Stack(
            fit: StackFit.expand,
            children: [
              LuminaGameWidget(game: game),
              LuminaWidgetLayer.forGame(game: game),
            ],
          ),
        ),
      ),
    );

void main() {
  // The widget layer read `game.world` before the scene existed, so
  // the host subtree failed to build; its orphaned FilamentWidget still
  // mounted the game, and the rebuilt one mounted it again: "Field
  // 'gameInstance' has already been initialized".
  testWidgets('the generated host tree mounts its game once and never throws', (tester) async {
    final game = _CountingGame();
    expect(game.world, isNull, reason: 'no world before the scene exists, and no throw');
    final printed = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message ?? '');
    try {
      await tester.pumpWidget(_host(game));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      // The host rebuilds (a window resize, a focus change): same game.
      await tester.pumpWidget(_host(game));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final exception = tester.takeException();
      final running = game.playState != LuminaPlayState.stopped;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      if (!running && game.mounts == 0 && exception == null) {
        markTestSkipped('FilamentWidget did not create a scene in the test binding');
        return;
      }
      expect(exception, isNull, reason: 'building the host tree must not throw');
      expect(printed.where((l) => l.contains('Filament Engine Init Exception')), isEmpty, reason: printed.join('\n'));
      expect(game.mounts, 1, reason: 'the game must be mounted exactly once');
      expect(game.playState, LuminaPlayState.stopped, reason: 'the widget disposed the game');
    } finally {
      debugPrint = previous;
    }
  });

  test('a second mountGame is ignored with a warning; after disposeGame the game mounts again', () {
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final printed = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message ?? '');
    try {
      final game = _CountingGame();
      expect(game.mountGame(engine, scene), isTrue);
      final world = game.world;
      expect(game.mountGame(engine, scene), isFalse);
      expect(identical(game.world, world), isTrue, reason: 'the running world is kept');
      expect(printed.single, contains('already mounted'));
      game.disposeGame();
      expect(game.mountGame(engine, scene), isTrue, reason: 'a disposed game can be mounted again');
      expect(game.mounts, 2);
      game.disposeGame();
    } finally {
      debugPrint = previous;
      scene.dispose();
      engine.dispose();
    }
  });
}
