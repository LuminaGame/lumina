import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

class TestGame extends LuminaGame {
  @override
  LuminaObject build(LuminaBuildContext context) {
    return LuminaWorld(
      initialLevel: LuminaLevel(
        children: [
          LuminaActor(location: Vector3(0, 5, 0)),
          LuminaActor(location: Vector3(10, 0, 0)),
        ],
      ),
    );
  }
}

void main() {
  group('Lumina Declarative World & Actor Tree Tests', () {
    test('Should instantiate TestGame and register spawned actors', () {
      final game = TestGame();
      expect(game, isNotNull);

      final world = LuminaWorld();
      final actor1 = LuminaActor(location: Vector3(0, 5, 0));
      final actor2 = LuminaActor(location: Vector3(10, 0, 0));

      world.spawnActor(actor1);
      world.spawnActor(actor2);
      world.beginPlay();
      world.tick(0.016);

      expect(world.persistentLevel.actors.length, equals(2));
      expect(actor1.actorLocation.y, equals(5.0));
      expect(actor2.actorLocation.x, equals(10.0));
    });
  });
}
