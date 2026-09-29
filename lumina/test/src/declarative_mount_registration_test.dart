import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// An actor mounted by the declarative tree must be registered with
/// the world exactly once — the level already registers it.
class _CountingComponent extends LuminaSceneComponent {
  int registerCalls = 0;
  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    // addComponent() registers with the owner before any world exists; only
    // count registrations that carry a world.
    if (ownerActor.world != null) registerCalls++;
  }
}

class _Level extends LuminaLevel {
  _Level(List<LuminaObject> actors) : super(name: 'L_Test', children: actors);
}

/// Mounts its level the way a generated game's `main.dart` does.
class _Game extends LuminaGame {
  _Game(this.actors);
  final List<LuminaObject> actors;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    context.world?.gameMode ??= LuminaGameMode();
    return LuminaNodeGroup(children: [...?_Level(actors).build(context)?.children]);
  }
}

void main() {
  group('declarative mount registration', () {
    test('a mounted component receives onRegister exactly once', () {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final comp = _CountingComponent();
      final game = _Game([LuminaActor(root: comp)]);
      game.mountGame(engine, scene);
      expect(comp.registerCalls, 1);
      expect(game.world!.persistentLevel.actors.whereType<LuminaActor>().where((a) => a.rootComponent == comp), hasLength(1));
      game.disposeGame();
      scene.dispose();
      engine.dispose();
    });

    test('a game whose level carries a sky mounts on a native world and sets the skybox', () async {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final after = _CountingComponent();
      final game = _Game([
        LuminaActor(root: LuminaSkyComponent.color(color: Vector4(0.35, 0.53, 0.78, 1))),
        LuminaActor(root: after),
      ]);
      expect(() => game.mountGame(engine, scene), returnsNormally);
      await Future<void>.delayed(Duration.zero);
      expect(scene.skybox, isNotNull);
      expect(scene.indirectLight, isNotNull);
      expect(after.registerCalls, 1, reason: 'actors after the sky must still mount');
      game.disposeGame();
      scene.dispose();
      engine.dispose();
    });
  });
}
