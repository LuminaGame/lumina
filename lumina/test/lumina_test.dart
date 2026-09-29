import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

class MyChar extends LuminaPlayerComponent {
  bool isJumpBound = false;

  @override
  void onInitialize() {
    super.onInitialize();
    bindAction('Jump', () {
      isJumpBound = true;
    });
  }
}

class MyLevel1 extends LuminaLevel {
  MyLevel1({super.key})
      : super(children: [
          LuminaActor(components: [MyChar()]),
        ]);
}

class MyWorld extends LuminaWorld {
  MyWorld({super.key, required List<LuminaObject> children})
      : super(initialLevel: LuminaLevel(children: children));
}

class MyGame extends LuminaGame {
  @override
  LuminaObject build(LuminaBuildContext context) {
    return MyWorld(
      children: [
        MyLevel1(),
      ],
    );
  }
}

void main() {
  test('Lumina Game Tree Mounting & Actor Registration', () {
    final game = MyGame();
    expect(game, isNotNull);
    final world = LuminaWorld();
    final actor = LuminaActor(location: Vector3(0, 10, 0));

    world.spawnActor(actor);
    world.beginPlay();
    world.tick(0.016);

    expect(world.persistentLevel.actors.length, equals(1));
    expect(actor.actorLocation.y, equals(10.0));
  });

  test('LuminaPawn Possession', () {
    final pawn = LuminaPawn();
    final controller = LuminaPlayerController();

    controller.possess(pawn);
    expect(pawn.isPlayerControlled(), isTrue);
    expect(pawn.controller, equals(controller));

    controller.unpossess();
    expect(pawn.isPlayerControlled(), isFalse);
  });
}
