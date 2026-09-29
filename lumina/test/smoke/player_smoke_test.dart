import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

class PlayerSmokePawn extends LuminaPawn {
  int jumpCount = 0;
  double lastAxisValue = 0.0;

  @override
  void setupPlayerInputComponent(LuminaPlayerComponent playerInput) {
    super.setupPlayerInputComponent(playerInput);
    playerInput.bindAction('Jump', () => jumpCount++);
    playerInput.bindAxis('MoveForward', (v) => lastAxisValue = v);
  }
}

void main() {
  group('Player Module Smoke Tests', () {
    test('Scenario 01: PlayerComponent binding, state dispatch, axis handling, and unbind', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final pawn = PlayerSmokePawn();
      final controller = LuminaPlayerController();

      world.persistentLevel.registerActor(pawn);
      controller.possess(pawn);
      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      final pic = pawn.getComponent<LuminaPlayerComponent>();
      expect(pic, isNotNull);

      pic!.triggerAction('Jump', InputTriggerState.triggered);
      pic.triggerAxis('MoveForward', 1.0);

      expect(pawn.jumpCount, equals(1));
      expect(pawn.lastAxisValue, equals(1.0));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Access_cards/access_card_red.glb',
      ];

      const testTitle = 'Player Module Smoke Tests Scenario 01: PlayerComponent binding, state dispatch, axis handling, and unbind';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      controller.unpossess();
      world.cleanup();
    });

    test('Scenario 02: PlayerState notifications, score tracking, and match reset', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final pawn = PlayerSmokePawn();
      final controller = LuminaPlayerController(playerName: 'SmokeHero');

      world.persistentLevel.registerActor(pawn);
      controller.possess(pawn);
      world.beginPlay();

      int stateChangeCount = 0;
      controller.playerState.addListener(() => stateChangeCount++);

      controller.playerState.addScore(100.0);
      controller.playerState.health = 50.0;

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(controller.playerState.score, equals(100.0));
      expect(controller.playerState.health, equals(50.0));
      expect(controller.playerState.isAlive, isTrue);
      expect(stateChangeCount, equals(2));

      controller.playerState.reset();
      expect(controller.playerState.score, equals(0.0));
      expect(controller.playerState.health, equals(100.0));
      expect(stateChangeCount, equals(3));

      final usedAssets = [
        'Props/Banana Bunch/banana_bunch_short.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = 'Player Module Smoke Tests Scenario 02: PlayerState notifications, score tracking, and match reset';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      controller.unpossess();
      world.cleanup();
    });
  });
}
