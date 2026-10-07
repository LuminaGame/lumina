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

void main() {
  test('a second mountGame is ignored with a warning; after disposeGame the game mounts again', () {
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    try {
      final game = _CountingGame();
      expect(game.mountGame(engine, scene), isTrue);
      final world = game.world;
      late bool second;
      final logged = EngineLoggerService().captureLogs(() => second = game.mountGame(engine, scene));
      expect(second, isFalse);
      expect(identical(game.world, world), isTrue, reason: 'the running world is kept');
      expect(logged.single.message, contains('already mounted'));
      expect(logged.single.level, 'warning');
      game.disposeGame();
      expect(game.mountGame(engine, scene), isTrue, reason: 'a disposed game can be mounted again');
      expect(game.mounts, 2);
      game.disposeGame();
    } finally {
      scene.dispose();
      engine.dispose();
    }
  });
}
