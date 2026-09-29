import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaAIController Tests', () {
    test('possess(pawn) sets isBotControlled to true and isPlayerControlled to false', () {
      final pawn = LuminaPawn();
      final ai = LuminaAIController();

      expect(pawn.isBotControlled(), isFalse);
      expect(pawn.isPlayerControlled(), isFalse);

      ai.possess(pawn);

      expect(ai.pawn, equals(pawn));
      expect(pawn.isBotControlled(), isTrue);
      expect(pawn.isPlayerControlled(), isFalse);

      ai.unpossess();
      expect(pawn.isBotControlled(), isFalse);
      expect(ai.pawn, isNull);
    });

    test('moveToLocation with pawn already at goal returns alreadyAtGoal and stays idle', () {
      final pawn = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final ai = LuminaAIController();
      ai.possess(pawn);

      bool completedFired = false;
      ai.onMoveCompleted = (result) => completedFired = true;

      final res = ai.moveToLocation(Vector3(10.0, 0.0, 0.0), acceptanceRadius: 50.0);
      expect(res, equals(PathFollowingRequestResult.alreadyAtGoal));
      expect(ai.moveStatus, equals(PathFollowingStatus.idle));
      expect(completedFired, isFalse);
      expect(ai.currentPath, isEmpty);
    });

    test('moveToLocation advances path and fires onMoveCompleted(success)', () {
      final pawn = LuminaPawn(location: Vector3.zero());
      final ai = LuminaAIController();
      ai.possess(pawn);

      PathFollowingResult? completionResult;
      int completionCount = 0;
      ai.onMoveCompleted = (result) {
        completionResult = result;
        completionCount++;
      };

      final req = ai.moveToLocation(Vector3(1000.0, 0.0, 0.0), acceptanceRadius: 50.0);
      expect(req, equals(PathFollowingRequestResult.requestSuccessful));
      expect(ai.moveStatus, equals(PathFollowingStatus.moving));
      expect(ai.currentPath.length, equals(1));

      // Simulate ticking and moving pawn
      const dt = 0.016;
      for (int i = 0; i < 150; i++) {
        ai.onTick(dt);
        final input = pawn.consumeMovementInputVector();
        if (input.length > 0) {
          pawn.actorLocation += input * (500.0 * dt); // 5 m/s in cm/s
        }
      }

      expect(pawn.actorLocation.x, closeTo(1000.0, 50.0));
      expect(completionResult, equals(PathFollowingResult.success));
      expect(completionCount, equals(1));
      expect(ai.moveStatus, equals(PathFollowingStatus.idle));
      expect(ai.currentPath, isEmpty);
    });

    test('Each moving tick accumulates unit-length input direction towards waypoint', () {
      final pawn = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final ai = LuminaAIController();
      ai.possess(pawn);

      ai.moveToLocation(Vector3(300.0, 0.0, 400.0)); // 3-4-5 triangle (cm)
      ai.onTick(0.016);

      final input = pawn.consumeMovementInputVector();
      expect(input.length, closeTo(1.0, 1e-5));
      expect(input.x, closeTo(3.0 / 5.0, 1e-5));
      expect(input.y, closeTo(0.0, 1e-5));
      expect(input.z, closeTo(4.0 / 5.0, 1e-5));
    });

    test('stopMovement mid-move resets to idle and fires onMoveCompleted(aborted)', () {
      final pawn = LuminaPawn(location: Vector3.zero());
      final ai = LuminaAIController();
      ai.possess(pawn);

      PathFollowingResult? completionResult;
      ai.onMoveCompleted = (result) => completionResult = result;

      ai.moveToLocation(Vector3(1000.0, 0.0, 0.0));
      expect(ai.moveStatus, equals(PathFollowingStatus.moving));

      ai.stopMovement();
      expect(ai.moveStatus, equals(PathFollowingStatus.idle));
      expect(completionResult, equals(PathFollowingResult.aborted));
      expect(ai.currentPath, isEmpty);
    });

    test('pauseMove and resumeMove toggle between paused and moving', () {
      final pawn = LuminaPawn(location: Vector3.zero());
      final ai = LuminaAIController();
      ai.possess(pawn);

      ai.moveToLocation(Vector3(1000.0, 0.0, 0.0));
      ai.pauseMove();
      expect(ai.moveStatus, equals(PathFollowingStatus.paused));

      // Tick while paused produces 0 input
      ai.onTick(0.016);
      expect(pawn.consumeMovementInputVector().length, equals(0.0));

      ai.resumeMove();
      expect(ai.moveStatus, equals(PathFollowingStatus.moving));
      ai.onTick(0.016);
      expect(pawn.consumeMovementInputVector().length, greaterThan(0.0));
    });

    test('Focus priority stack: highest priority wins', () {
      final ai = LuminaAIController();
      final focusActor = LuminaActor(location: Vector3(500.0, 0.0, 0.0));
      final pGameplay = Vector3(1000.0, 0.0, 0.0);

      ai.setFocalPoint(pGameplay, priority: FocusPriority.gameplay);
      ai.setFocus(focusActor, priority: FocusPriority.move);

      expect(ai.focalPoint, equals(pGameplay)); // gameplay > move

      ai.clearFocus(FocusPriority.gameplay);
      expect(ai.focalPoint, equals(Vector3(500.0, 0.0, 0.0))); // falls back to actor

      focusActor.actorLocation = Vector3(700.0, 0.0, 0.0);
      expect(ai.focalPoint, equals(Vector3(700.0, 0.0, 0.0))); // dynamic tracking

      ai.clearFocus(FocusPriority.move);
      expect(ai.focalPoint, isNull);
    });

    // The AI keeps its control rotation in the pawn / player
    // controller convention — degrees, yaw 0 facing −Z, positive yaw turning
    // right towards +X — not radians from +Z.
    test('Control rotation yaw faces the focal point in degrees, yaw 0 facing -Z', () {
      final pawn = LuminaPawn(location: Vector3.zero());
      final ai = LuminaAIController();
      ai.possess(pawn);

      ai.setFocalPoint(Vector3(0.0, 0.0, -1000.0)); // straight ahead (−Z)
      ai.onTick(0.016);
      expect(ai.controlRotation.y, closeTo(0.0, 1e-4));

      ai.setFocalPoint(Vector3(1000.0, 0.0, 0.0)); // to the right (+X)
      ai.onTick(0.016);
      expect(ai.controlRotation.y, closeTo(90.0, 1e-4));

      ai.setFocalPoint(Vector3(0.0, 0.0, 1000.0)); // behind (+Z)
      ai.onTick(0.016);
      expect(ai.controlRotation.y.abs(), closeTo(180.0, 1e-4));
    });

    test('an AI focusing a target at a known bearing yields the yaw and heading a player controller has for it', () {
      // Bearings in degrees, clockwise (seen from above) from −Z towards +X.
      for (final bearing in [0.0, 35.0, 90.0, 150.0, -60.0, -120.0]) {
        final b = bearing * math.pi / 180.0;
        final target = LuminaActor(location: Vector3(math.sin(b) * 800.0, 0.0, -math.cos(b) * 800.0));

        final aiCharacter = LuminaTemplateCharacter(thirdPerson: true);
        final ai = LuminaAIController()..possess(aiCharacter);
        ai.setFocus(target);
        ai.onTick(1 / 60);

        // The player controller turned to the same bearing.
        final pcCharacter = LuminaTemplateCharacter(thirdPerson: true);
        final pc = LuminaPlayerController()..possess(pcCharacter);
        pc.controlRotation.y = bearing;
        pc.onTick(1 / 60);

        var dYaw = (ai.controlRotation.y - pc.controlRotation.y) % 360.0;
        if (dYaw > 180.0) dYaw -= 360.0;
        expect(dYaw, closeTo(0.0, 1e-6), reason: 'bearing $bearing°: AI yaw ${ai.controlRotation.y}');

        // The AI turns its pawn to face the focus, as the player's pawn does.
        final aiForward = aiCharacter.actorRotation.rotateVector(Vector3(0.0, 0.0, -1.0));
        final pcForward = pcCharacter.actorRotation.rotateVector(Vector3(0.0, 0.0, -1.0));
        expect((aiForward - pcForward).length, lessThan(1e-6), reason: 'bearing $bearing°: same heading');
        final toTarget = target.actorLocation.normalized();
        expect(aiForward.dot(toTarget), closeTo(1.0, 1e-6), reason: 'bearing $bearing°: facing the target');

        // And a move along the control rotation's forward heads for it too.
        aiCharacter.onMove(LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 1.0, 0.0));
        final input = aiCharacter.characterMovement.inputVector.normalized();
        expect(input.dot(toTarget), closeTo(1.0, 1e-6), reason: 'bearing $bearing°: walking towards the target');
      }
    });

    test('the sight cone looks along the control rotation in the player convention (yaw 0 sees -Z, not +Z)', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);
      final viewer = LuminaPawn(location: Vector3.zero());
      final sight = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0, peripheralVisionAngleDegrees: 45.0),
        updateInterval: 0.05,
      );
      viewer.addComponent(sight);
      final ahead = LuminaActor(location: Vector3(0.0, 0.0, -600.0)); // −Z
      final behind = LuminaActor(location: Vector3(0.0, 0.0, 600.0)); // +Z
      final right = LuminaActor(location: Vector3(600.0, 0.0, 0.0)); // +X
      world.persistentLevel
        ..registerActor(viewer)
        ..registerActor(ahead)
        ..registerActor(behind)
        ..registerActor(right);
      for (final a in [ahead, behind, right]) {
        percepSys.registerSource(a);
      }
      final ai = LuminaAIController()..possess(viewer);
      world.beginPlay();

      Set<LuminaActor> seenAtYaw(double yaw) {
        ai.controlRotation.y = yaw;
        for (var i = 0; i < 6; i++) {
          world.tick(1 / 60);
        }
        return sight.getCurrentlyPerceivedActors(sense: AISenseType.sight).toSet();
      }

      expect(seenAtYaw(0.0), {ahead}, reason: 'yaw 0 looks down −Z');
      expect(seenAtYaw(90.0), {right}, reason: 'yaw 90 looks down +X');
      expect(seenAtYaw(180.0), {behind}, reason: 'yaw 180 looks down +Z');
      world.cleanup();
    });

    test('moveToActor repaths when goal actor moves beyond repath threshold', () {
      final pawn = LuminaPawn(location: Vector3.zero());
      final target = LuminaActor(location: Vector3(500.0, 0.0, 0.0));
      final ai = LuminaAIController();
      ai.possess(pawn);

      ai.moveToActor(target, acceptanceRadius: 50.0);
      expect(ai.currentPath.last.x, equals(500.0));

      target.actorLocation = Vector3(1000.0, 0.0, 0.0);
      ai.onTick(0.016);

      expect(ai.currentPath.last.x, equals(1000.0));
    });

    test('unpossess mid-move aborts move and clears focus', () {
      final pawn = LuminaPawn(location: Vector3.zero());
      final ai = LuminaAIController();
      ai.possess(pawn);

      ai.setFocalPoint(Vector3(100.0, 200.0, 300.0));
      ai.moveToLocation(Vector3(1000.0, 0.0, 0.0));

      ai.unpossess();
      expect(ai.moveStatus, equals(PathFollowingStatus.idle));
      expect(ai.focalPoint, isNull);

      // Safe to tick without pawn
      expect(() => ai.onTick(0.016), returnsNormally);
    });
  });
}
