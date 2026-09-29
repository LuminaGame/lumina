import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

class PawnSmokeActor extends LuminaPawn {
  int tickCount = 0;
  bool isSetupInputCalled = false;

  @override
  void setupPlayerInputComponent(LuminaPlayerComponent playerInput) {
    super.setupPlayerInputComponent(playerInput);
    isSetupInputCalled = true;
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
  }
}

void main() {
  group('Pawn Module Smoke Tests', () {
    test('Scenario 01: Pawn possession lifecycle, controller binding, and tick execution', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final pawn = PawnSmokeActor();
      final controller = LuminaPlayerController();

      world.persistentLevel.registerActor(pawn);
      controller.possess(pawn);

      expect(pawn.controller, equals(controller));
      expect(controller.pawn, equals(pawn));
      expect(pawn.isPlayerControlled(), isTrue);
      expect(pawn.isSetupInputCalled, isTrue);

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(pawn.tickCount, equals(3));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/fuel_barrel_black.glb',
      ];

      const testTitle = 'Pawn Module Smoke Tests Scenario 01: Pawn possession lifecycle, controller binding, and tick execution';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      controller.unpossess();
      expect(pawn.controller, isNull);
      expect(controller.pawn, isNull);
      expect(pawn.isPawnControlled(), isFalse);

      world.cleanup();
    });

    test('Scenario 02: Input accumulation, consume-once semantics, and controller rotation update', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final pawn = PawnSmokeActor()..bUseControllerRotationYaw = true;
      final controller = LuminaPlayerController();

      world.persistentLevel.registerActor(pawn);
      controller.possess(pawn);
      world.beginPlay();

      // Accumulate movement input from multiple sources
      pawn.addMovementInput(Vector3(1.0, 0.0, 0.0), 0.5);
      pawn.addMovementInput(Vector3(1.0, 0.0, 0.0), 0.5);
      pawn.addControllerYawInput(90.0);

      expect(pawn.getPendingMovementInputVector(), equals(Vector3(1.0, 0.0, 0.0)));

      // Controller tick applies rotation
      controller.onTick(1.0 / 60.0);

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      final consumed = pawn.consumeMovementInputVector();
      expect(consumed, equals(Vector3(1.0, 0.0, 0.0)));
      expect(pawn.getPendingMovementInputVector(), equals(Vector3.zero()));

      final usedAssets = [
        'Props/Access_cards/access_card_red.glb',
        'Props/Banana Bunch/banana_bunch_short.glb',
      ];

      const testTitle = 'Pawn Module Smoke Tests Scenario 02: Input accumulation, consume-once semantics, and controller rotation update';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
    });

    test('Scenario 03: Pawn viewpoint, eye height offset, and controller viewpoint hand-off', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final character = LuminaCharacter(location: Vector3(10.0, 0.0, 20.0));
      final controller = LuminaPlayerController();

      world.persistentLevel.registerActor(character);
      controller.possess(character);
      controller.controlRotation = Vector3(15.0, 45.0, 0.0);

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      final viewPoint = controller.getPlayerViewPoint();
      expect(viewPoint.location.x, closeTo(10.0, 1e-4));
      expect(viewPoint.location.y, closeTo(character.baseEyeHeight, 1e-4));
      expect(viewPoint.location.z, closeTo(20.0, 1e-4));
      expect(viewPoint.rotation, equals(Vector3(15.0, 45.0, 0.0)));

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];

      const testTitle = 'Pawn Module Smoke Tests Scenario 03: Pawn viewpoint, eye height offset, and controller viewpoint hand-off';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
    });
  });
}
