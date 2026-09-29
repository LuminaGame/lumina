import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// LuminaWorld.spawnActor must register the actor exactly once.
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

class _ThrowingComponent extends LuminaSceneComponent {
  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    if (ownerActor.world != null) throw StateError('boom');
  }
}

void main() {
  group('spawnActor registration', () {
    test('a spawned component receives onRegister exactly once', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final comp = _CountingComponent();
      world.spawnActor(LuminaActor(root: comp));
      world.beginPlay();
      world.tick(1 / 60);
      expect(comp.registerCalls, 1);
      expect(world.persistentLevel.actors.length, 1);
      world.cleanup();
    });

    test('a spawned sky component does not throw and the spawn buffer drains once', () {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
      world.beginPlay();
      world.spawnActor(LuminaActor(root: LuminaSkyComponent.color(color: Vector4(0.3, 0.5, 0.8, 1))));
      expect(() => world.tick(1 / 60), returnsNormally);
      expect(() => world.tick(1 / 60), returnsNormally);
      expect(() => world.tick(1 / 60), returnsNormally, reason: 'buffer must not replay');
      expect(world.persistentLevel.actors.length, 1);
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('a throwing actor does not block later spawns', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();
      world.spawnActor(LuminaActor(root: _ThrowingComponent()));
      final good = _CountingComponent();
      world.spawnActor(LuminaActor(root: good));
      try {
        world.tick(1 / 60);
      } catch (_) {}
      world.tick(1 / 60);
      world.tick(1 / 60);
      expect(good.registerCalls, 1, reason: 'the good actor spawns once even if a sibling threw');
      world.cleanup();
    });
  });
}
