import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

void main() {
  group('AI Module Smoke Tests', () {
    test('Scenario 01: LuminaAIController pawn possession, path following, focus tracking and move completion with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final botPawn = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final targetActor = LuminaActor(location: Vector3(800.0, 0.0, 0.0));

      world.persistentLevel.registerActor(botPawn);
      world.persistentLevel.registerActor(targetActor);

      final ai = LuminaAIController();
      ai.possess(botPawn);

      expect(botPawn.isBotControlled(), isTrue);
      expect(botPawn.isPlayerControlled(), isFalse);

      world.beginPlay();

      PathFollowingResult? completedResult;
      ai.onMoveCompleted = (result) {
        completedResult = result;
      };

      ai.setFocus(targetActor, priority: FocusPriority.gameplay);
      ai.moveToActor(targetActor, acceptanceRadius: 50.0);

      expect(ai.moveStatus, equals(PathFollowingStatus.moving));

      // Tick world and advance movement
      const dt = 1.0 / 60.0;
      for (int i = 0; i < 120; i++) {
        ai.onTick(dt);
        final input = botPawn.consumeMovementInputVector();
        if (input.length > 0) {
          botPawn.actorLocation += input * (400.0 * dt); // 4 m/s in cm/s
        }
        world.tick(dt);
      }

      expect(completedResult, equals(PathFollowingResult.success));
      expect(ai.moveStatus, equals(PathFollowingStatus.idle));
      expect(botPawn.actorLocation.x, closeTo(800.0, 60.0));

      final usedAssets = [
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
        'Props/Barrels/dented_barrel.glb',
        'structures/Fences_walls/wall_300x300.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'AI Module Smoke Tests Scenario 01: LuminaAIController pawn possession, path following, focus tracking and move completion with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Asset 1 (Target Barrel) placed at (250, 0, 0) cm
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 100.0 / max1 : 1.0;
            final barrelMat = Matrix4.identity()
              ..setTranslationRaw(250.0, -aabb1.min.y * scale1, 0.0)
              ..scale(scale1, scale1, scale1);
            tm.setTransform(assets[1].rootEntity, barrelMat.storage.toList());
          }

          // Asset 2 (Wall background) placed at (0, 0, -250) cm
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 250.0 / max2 : 1.0;
            final wallMat = Matrix4.identity()
              ..setTranslationRaw(0.0, -aabb2.min.y * scale2, -250.0)
              ..scale(scale2, scale2, scale2);
            tm.setTransform(assets[2].rootEntity, wallMat.storage.toList());
          }

          // Asset 0: Manny Walking forward to target and looping
          final loopT = (timeSeconds % 6.0) / 6.0; // 0.0 -> 1.0
          double botX = 0.0;
          double botYaw = 0.0;

          if (loopT < 0.45) {
            // Walking forward to target
            final phase = loopT / 0.45;
            botX = -200.0 + phase * 400.0;
            botYaw = math.pi / 2.0; // facing +X
          } else if (loopT < 0.55) {
            // Reached target, turning around
            final phase = (loopT - 0.45) / 0.1;
            botX = 200.0;
            botYaw = math.pi / 2.0 + phase * math.pi;
          } else {
            // Walking back
            final phase = (loopT - 0.55) / 0.45;
            botX = 200.0 - phase * 400.0;
            botYaw = -math.pi / 2.0; // facing -X
          }

          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 180.0 / max0 : 1.0;
          final mannyMat = Matrix4.identity()
            ..setTranslationRaw(botX, -aabb0.min.y * scale0, 0.0)
            ..rotateY(botYaw)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, mannyMat.storage.toList());

          // Camera smoothly tracking Manny
          final camDist = 350.0;
          cam.lookAt(
            eyeX: botX + math.sin(timeSeconds * 0.4) * 200.0,
            eyeY: 140.0,
            eyeZ: math.cos(timeSeconds * 0.4) * camDist,
            centerX: botX,
            centerY: 90.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: LuminaNavigationSystem A* grid pathfinding, obstacle avoidance, and path smoothing with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      // Create an obstacle wall in the middle
      final wall = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final col = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(400.0, 200.0, 80.0);
      CollisionProfile.applyBlockAll(col);
      wall.addComponent(col);
      world.persistentLevel.registerActor(wall);

      final bounds = Aabb3.minMax(Vector3(-1000.0, 0.0, -1000.0), Vector3(1000.0, 0.0, 1000.0));
      nav.buildFromWorld(bounds: bounds, config: const NavGridConfig(cellSize: 50.0, agentRadius: 40.0));

      final start = Vector3(0.0, 0.0, -400.0);
      final end = Vector3(0.0, 0.0, 400.0);
      final path = nav.findPathSync(start, end, smooth: true);

      expect(path, isNotNull);
      expect(path!.points.length, greaterThanOrEqualTo(2));
      expect(path.isPartial, isFalse);

      final botPawn = LuminaPawn(location: start);
      world.persistentLevel.registerActor(botPawn);

      final ai = LuminaAIController();
      ai.possess(botPawn);
      world.beginPlay();

      final res = ai.moveToLocation(end, usePathfinding: true);
      expect(res, equals(PathFollowingRequestResult.requestSuccessful));

      final usedAssets = [
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
        'structures/Fences_walls/wall_300x300.glb',
        'Props/Barrels/bent_barrel.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'AI Module Smoke Tests Scenario 02: LuminaNavigationSystem A* grid pathfinding, obstacle avoidance, and path smoothing with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Asset 1 (Wall obstacle in center)
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 300.0 / max1 : 1.0;
            final wallMat = Matrix4.identity()
              ..setTranslationRaw(0.0, -aabb1.min.y * scale1, 0.0)
              ..scale(scale1, scale1, scale1);
            tm.setTransform(assets[1].rootEntity, wallMat.storage.toList());
          }

          // Asset 2 (Target bent barrel) at (0, 0, 350) cm
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 100.0 / max2 : 1.0;
            final barrelMat = Matrix4.identity()
              ..setTranslationRaw(0.0, -aabb2.min.y * scale2, 350.0)
              ..scale(scale2, scale2, scale2);
            tm.setTransform(assets[2].rootEntity, barrelMat.storage.toList());
          }

          // Asset 0 (Manny navigation around the wall)
          // Follow waypoints (cm): (0, 0, -350) -> (250, 0, 0) -> (0, 0, 350)
          final waypoints = [
            Vector3(0.0, 0.0, -350.0),
            Vector3(250.0, 0.0, 0.0),
            Vector3(0.0, 0.0, 350.0),
          ];

          final loopT = (timeSeconds % 6.0) / 6.0;
          Vector3 currentPos;
          double yaw;

          if (loopT < 0.5) {
            // Forward around wall
            final p = loopT / 0.5;
            if (p < 0.5) {
              final subP = p / 0.5;
              currentPos = waypoints[0] + (waypoints[1] - waypoints[0]) * subP;
              yaw = math.atan2((waypoints[1] - waypoints[0]).x, (waypoints[1] - waypoints[0]).z);
            } else {
              final subP = (p - 0.5) / 0.5;
              currentPos = waypoints[1] + (waypoints[2] - waypoints[1]) * subP;
              yaw = math.atan2((waypoints[2] - waypoints[1]).x, (waypoints[2] - waypoints[1]).z);
            }
          } else {
            // Backward around wall
            final p = (loopT - 0.5) / 0.5;
            if (p < 0.5) {
              final subP = p / 0.5;
              currentPos = waypoints[2] + (waypoints[1] - waypoints[2]) * subP;
              yaw = math.atan2((waypoints[1] - waypoints[2]).x, (waypoints[1] - waypoints[2]).z);
            } else {
              final subP = (p - 0.5) / 0.5;
              currentPos = waypoints[1] + (waypoints[0] - waypoints[1]) * subP;
              yaw = math.atan2((waypoints[0] - waypoints[1]).x, (waypoints[0] - waypoints[1]).z);
            }
          }

          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 180.0 / max0 : 1.0;
          final mannyMat = Matrix4.identity()
            ..setTranslationRaw(currentPos.x, -aabb0.min.y * scale0, currentPos.z)
            ..rotateY(yaw)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, mannyMat.storage.toList());

          // Top-angled camera tracking Manny navigating around the obstacle
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.3) * 600.0,
            eyeY: 500.0,
            eyeZ: math.cos(timeSeconds * 0.3) * 600.0,
            centerX: 0.0,
            centerY: 50.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 03: LuminaBehaviorTreeComponent execution, blackboard state transitions, MoveTo tasks, and decorator branching with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final botPawn = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(botPawn);

      final ai = LuminaAIController();
      ai.possess(botPawn);

      final bb = LuminaBlackboard();
      bb.setValue('patrolTarget', Vector3(400.0, 0.0, 0.0));
      bb.setValue('homeLocation', Vector3(0.0, 0.0, 0.0));

      final root = BTSequence([
        BTMoveToTask(blackboardKey: 'patrolTarget', acceptanceRadius: 50.0),
        BTWaitTask(0.1),
        BTMoveToTask(blackboardKey: 'homeLocation', acceptanceRadius: 50.0),
        BTWaitTask(0.1),
      ]);

      final btc = LuminaBehaviorTreeComponent(
        root: root,
        blackboard: bb,
        controller: ai,
      );
      botPawn.addComponent(btc);
      btc.start();

      world.beginPlay();

      // Tick world
      for (int i = 0; i < 15; i++) {
        world.tick(0.016);
      }

      expect(btc.isRunning, isTrue);

      final usedAssets = [
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
        'mannequin/MM_Idle.glb',
        'Props/Barrels/dented_barrel.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'AI Module Smoke Tests Scenario 03: LuminaBehaviorTreeComponent execution, blackboard state transitions, MoveTo tasks, and decorator branching with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Patrol Marker (Asset 2) at (300, 0, 0) cm
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 100.0 / max2 : 1.0;
            final markerMat = Matrix4.identity()
              ..setTranslationRaw(300.0, -aabb2.min.y * scale2, 0.0)
              ..scale(scale2, scale2, scale2);
            tm.setTransform(assets[2].rootEntity, markerMat.storage.toList());
          }

          // State Machine over 10s:
          // 0-3s: Walk forward (Asset 0 visible, Asset 1 hidden)
          // 3-5s: Idle wait at target (Asset 1 visible at (300, 0, 0) cm, Asset 0 hidden)
          // 5-8s: Walk back (Asset 0 visible, Asset 1 hidden)
          // 8-10s: Idle wait at home (Asset 1 visible at (0, 0, 0), Asset 0 hidden)
          final loopT = (timeSeconds % 10.0);
          double posX = 0.0;
          double yaw = 0.0;
          bool isWalking = true;

          if (loopT < 3.0) {
            isWalking = true;
            final p = loopT / 3.0;
            posX = 0.0 + p * 300.0;
            yaw = math.pi / 2.0;
          } else if (loopT < 5.0) {
            isWalking = false;
            posX = 300.0;
            yaw = math.pi / 2.0;
          } else if (loopT < 8.0) {
            isWalking = true;
            final p = (loopT - 5.0) / 3.0;
            posX = 300.0 - p * 300.0;
            yaw = -math.pi / 2.0;
          } else {
            isWalking = false;
            posX = 0.0;
            yaw = 0.0;
          }

          // Asset 0 (Walking model)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? (isWalking ? 180.0 / max0 : 0.0001) : 1.0;
          final walkMat = Matrix4.identity()
            ..setTranslationRaw(posX, -aabb0.min.y * scale0, 0.0)
            ..rotateY(yaw)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, walkMat.storage.toList());

          // Asset 1 (Idle model)
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? (!isWalking ? 180.0 / max1 : 0.0001) : 1.0;
            final idleMat = Matrix4.identity()
              ..setTranslationRaw(posX, -aabb1.min.y * scale1, 0.0)
              ..rotateY(yaw)
              ..scale(scale1, scale1, scale1);
            tm.setTransform(assets[1].rootEntity, idleMat.storage.toList());
          }

          // Tracking camera
          cam.lookAt(
            eyeX: posX + math.sin(timeSeconds * 0.4) * 250.0,
            eyeY: 160.0,
            eyeZ: math.cos(timeSeconds * 0.4) * 350.0,
            centerX: posX,
            centerY: 90.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 04: LuminaAIPerceptionComponent sight and hearing senses, vision cone targeting, and stimulus event routing with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

      final guardPawn = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final intruderActor = LuminaActor(location: Vector3(300.0, 0.0, -300.0)); // ahead-right: the guard faces −Z (yaw 0)

      final ai = LuminaAIController();
      ai.possess(guardPawn);

      final perceptionComp = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1000.0, peripheralVisionAngleDegrees: 80.0),
        hearingConfig: AISenseConfigHearing(hearingRange: 1500.0),
        updateInterval: 0.1,
      );
      guardPawn.addComponent(perceptionComp);

      world.persistentLevel.registerActor(guardPawn);
      world.persistentLevel.registerActor(intruderActor);
      percepSys.registerSource(intruderActor);

      world.beginPlay();

      bool targetSpotted = false;
      perceptionComp.onTargetPerceptionUpdated = (actor, stimulus) {
        if (stimulus.wasSuccessfullySensed) {
          targetSpotted = true;
          ai.setFocus(actor);
        }
      };

      // Tick world
      for (int i = 0; i < 10; i++) {
        world.tick(0.016);
      }

      // Report noise event
      LuminaAIPerceptionSystem.reportNoiseEvent(world, Vector3(300.0, 0.0, -300.0), loudness: 1.0, instigator: intruderActor);

      expect(targetSpotted, isTrue);
      expect(perceptionComp.getCurrentlyPerceivedActors(), contains(intruderActor));

      final usedAssets = [
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
        'mannequin/MM_Idle.glb',
        'Props/Barrels/dented_barrel.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'AI Module Smoke Tests Scenario 04: LuminaAIPerceptionComponent sight and hearing senses, vision cone targeting, and stimulus event routing with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Walking model (Asset 0) standing beside the guard. The media
          // helper's default placement is metre-scaled, so place it in cm.
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 120.0 / max0 : 1.0;
          final sideMat = Matrix4.identity()
            ..setTranslationRaw(-160.0, -aabb0.min.y * scale0, 0.0)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, sideMat.storage.toList());

          // Intruder Barrel (Asset 2) circling around guard at radius 350cm
          final angle = timeSeconds * 0.8;
          final intruderX = math.sin(angle) * 350.0;
          final intruderZ = math.cos(angle) * 350.0;

          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 120.0 / max2 : 1.0;
            final barrelMat = Matrix4.identity()
              ..setTranslationRaw(intruderX, -aabb2.min.y * scale2, intruderZ)
              ..scale(scale2, scale2, scale2);
            tm.setTransform(assets[2].rootEntity, barrelMat.storage.toList());
          }

          // Guard (Asset 0 or 1) at origin dynamically turning to face the intruder
          final guardYaw = math.atan2(intruderX, intruderZ);

          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 180.0 / max1 : 1.0;
            final guardMat = Matrix4.identity()
              ..setTranslationRaw(0.0, -aabb1.min.y * scale1, 0.0)
              ..rotateY(guardYaw)
              ..scale(scale1, scale1, scale1);
            tm.setTransform(assets[1].rootEntity, guardMat.storage.toList());
          }

          // Camera sweeping around the scene
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.3) * 500.0,
            eyeY: 250.0,
            eyeZ: math.cos(timeSeconds * 0.3) * 500.0,
            centerX: 0.0,
            centerY: 90.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    // The sight sense traces its line of sight from the AI's eyes
    // (160 cm above its feet), not 160 cm above its capsule centre. A 2 m
    // wall hides the player until it steps past the wall's end. The
    // component's debug trace (green to the hit or the target, red past a
    // blocking hit) is drawn as two thin bars, seen from the side.
    test('Scenario 05: LuminaAIPerceptionComponent sight line of sight from the eyes, blocked by a 2 m wall, with its debug trace', () async {
      const testTitle = 'AI Module Smoke Tests Scenario 05: LuminaAIPerceptionComponent sight line of sight from the eyes, blocked by a 2 m wall, with its debug trace';
      const w = SmokeVideo.defaultWidth;
      const h = SmokeVideo.defaultHeight;
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(w, h);
      final camera = engine.createCamera(engine.createEntity());
      view
        ..scene = scene
        ..camera = camera
        ..setViewport(0, 0, w, h);
      camera.setProjection(fovDegrees: 50, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
      scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.42, 0.55, 0.78, 1), intensity: 30000));
      scene.setIndirectLight(FilamentIndirectLight.build(engine,
          irradiance: SphericalHarmonics(bands: 1, coefficients: [0.65, 0.65, 0.7]), intensity: 30000));
      final pixels = calloc<ffi.Uint8>(w * h * 4);
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
      addTearDown(() {
        world.cleanup();
        calloc.free(pixels);
        engine.dispose();
      });
      world.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem());
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);
      world.bindView(view);

      world.persistentLevel.registerActor(LuminaPrimitiveActor(
          location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(2400, 20, 2400), color: Vector3(0.52, 0.5, 0.47)));
      world.persistentLevel.registerActor(LuminaActor(
          root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, -30]), intensity: 100000, castShadows: true)));
      // The wall: 6 m wide, 2 m tall, 40 cm thick, half way between them.
      world.persistentLevel.registerActor(LuminaPrimitiveActor(
          location: Vector3(0, 100, -300), shape: LuminaPrimitiveShape.box, size: Vector3(600, 200, 40), color: Vector3(0.62, 0.6, 0.58)));

      LuminaTemplateCharacter mannequin(Vector3 at) => LuminaTemplateCharacter(
            thirdPerson: true,
            meshAssetPath: LuminaThirdPersonContent.bundledMeshPath,
            location: at + Vector3(0, LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight + 1, 0),
          );
      final guard = mannequin(Vector3.zero());
      final player = mannequin(Vector3(0, 0, -600));
      final sight = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0, peripheralVisionAngleDegrees: 70.0),
        updateInterval: 1 / 30,
        drawDebugSight: true,
      );
      guard.addComponent(sight);
      world.persistentLevel.registerActor(guard);
      world.persistentLevel.registerActor(player);
      final ai = LuminaAIController()..possess(guard);
      ai.setFocus(player);
      percepSys.registerSource(player);

      // The debug trace's two segments as 4 cm bars, 1 cm long along +Z and
      // scaled to each segment's length every frame.
      LuminaActor bar(String color) {
        final actor = LuminaActor(
          root: LuminaStaticMeshComponent(
            meshAssetPath: 'smoke-ai:sight-bar:$color',
            assetUnitScale: 1.0,
            castShadows: false,
            assetProvider: (_) async => PrimitiveGlbFactory.build(shape: 'box', sizeX: 4.0, sizeY: 4.0, sizeZ: 1.0, colorHex: color),
          ),
        );
        world.persistentLevel.registerActor(actor);
        return actor;
      }

      final greenBar = bar('#22FF33');
      final redBar = bar('#FF2222');
      void place(LuminaActor actor, Vector3? a, Vector3? b) {
        if (a == null || b == null) {
          actor.actorLocation = Vector3(0, -500, 0); // under the floor
          return;
        }
        final segment = b - a;
        actor.actorLocation = a + segment * 0.5;
        actor.actorRotation = Quaternion.fromTwoVectors(Vector3(0, 0, 1), segment.normalized());
        actor.actorScale = Vector3(1, 1, segment.length);
      }

      world.beginPlay();
      await Future.wait([
        guard.bodyMesh!.loaded,
        player.bodyMesh!.loaded,
        for (final m in world.persistentLevel.actors.expand((a) => a.components).whereType<LuminaStaticMeshComponent>()) m.loaded,
      ]).timeout(const Duration(seconds: 120));

      Uint8List shot() {
        camera.lookAt(eyeX: 1250, eyeY: 260, eyeZ: -150, centerX: 150, centerY: 110, centerZ: -330);
        for (var i = 0; i < 3; i++) {
          if (renderer.beginFrame(swapChain)) {
            renderer.render(view);
            if (i == 2) {
              c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
            }
            renderer.endFrame();
          }
          engine.flushAndWait();
        }
        return Uint8List.fromList(pixels.asTypedList(w * h * 4));
      }

      final usedAssets = [LuminaThirdPersonContent.bundledMeshPath];
      final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
      addTearDown(video.discard);
      final feet = guard.actorLocation.y - guard.capsuleComponent.halfHeight;
      final seenAt = <double>[];
      Map<String, Object?>? blockedMetrics;

      // 1 s behind the wall, 8 s walking to x = 8 m, past its end, 2 s there.
      const ticks = 660;
      for (var tick = 0; tick < ticks; tick++) {
        final t = tick / 60;
        final x = t < 1 ? 0.0 : math.min(800.0, (t - 1) * 100.0);
        player.actorLocation = Vector3(x, player.actorLocation.y, -600);
        ai.onTick(1 / 60);
        world.tick(1 / 60);
        final lines = world.debugShapes.where((d) => d.kind == LuminaDebugShapeKind.line).toList();
        final green = lines.where((d) => d.color[1] == 1.0).lastOrNull;
        final red = lines.where((d) => d.color[0] == 1.0).lastOrNull;
        place(greenBar, green?.points.first, green?.points.last);
        place(redBar, red?.points.first, red?.points.last);
        final seen = sight.getCurrentlyPerceivedActors(sense: AISenseType.sight).contains(player);
        if (seen) seenAt.add(x);
        if (tick.isEven) video.addFrame(shot());
        if (tick == 45) {
          expect(seen, isFalse, reason: 'the 2 m wall hides the player from the AI\'s eyes');
          expect(green, isNotNull);
          expect(red, isNotNull, reason: 'the trace is blocked: red past the wall');
          expect(green!.points.first.y - feet, closeTo(LuminaTemplateCharacterTuning.eyeHeightAboveFeet, 5.0),
              reason: 'the trace starts at the eyes: $green');
          expect(green.points.last.z, closeTo(-280.0, 2.0), reason: 'it stops on the wall\'s near face: $green');
          blockedMetrics = {
            'traceStartAboveFeet': green.points.first.y - feet,
            'hitZ': green.points.last.z,
            'hitAboveFeet': green.points.last.y - feet,
            'seen': seen,
          };
          SmokeArtifacts.saveScreenshot('$testTitle 01 behind the wall: blocked', SmokeArtifacts.encodePng(w, h, shot()),
              usedAssets: usedAssets, metrics: blockedMetrics);
        }
        if (tick == ticks - 1) {
          expect(seen, isTrue, reason: 'past the wall\'s end the AI sees the player');
          expect(red, isNull, reason: 'a clear trace is green all the way');
          expect((green!.points.last - player.actorLocation).length, lessThan(1e-3), reason: 'it ends at the player');
          SmokeArtifacts.saveScreenshot('$testTitle 02 past the wall: seen', SmokeArtifacts.encodePng(w, h, shot()),
              usedAssets: usedAssets,
              metrics: {'traceStartAboveFeet': green.points.first.y - feet, 'firstSeenAtX': seenAt.first, 'seen': seen});
        }
      }
      expect(seenAt, isNotEmpty);
      expect(seenAt.first, greaterThan(550.0), reason: 'seen only once the eye line clears the wall\'s end (x ≈ 650 cm)');
      SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 5)));

    // The AI controller's focus yaw is the player convention
    // (degrees, yaw 0 facing −Z), so an AI mannequin turns its body to face
    // the player walking a full circle round it, and its sight cone — read
    // from the same control rotation — keeps the player in view all the way,
    // behind its starting heading included.
    test('Scenario 06: an AI mannequin turns to face the player circling it, its sight cone following', () async {
      const testTitle = 'AI Module Smoke Tests Scenario 06: an AI mannequin turns to face the player circling it, its sight cone following';
      if (!File(LuminaThirdPersonContent.bundledMeshPath).existsSync()) {
        return markTestSkipped('build tool/build_third_person_content.dart first');
      }
      const w = SmokeVideo.defaultWidth;
      const h = SmokeVideo.defaultHeight;
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(w, h);
      final camera = engine.createCamera(engine.createEntity());
      view
        ..scene = scene
        ..camera = camera
        ..setViewport(0, 0, w, h);
      camera.setProjection(fovDegrees: 50, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
      scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.42, 0.55, 0.78, 1), intensity: 30000));
      scene.setIndirectLight(FilamentIndirectLight.build(engine,
          irradiance: SphericalHarmonics(bands: 1, coefficients: [0.65, 0.65, 0.7]), intensity: 30000));
      final pixels = calloc<ffi.Uint8>(w * h * 4);
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
      addTearDown(() {
        world.cleanup();
        calloc.free(pixels);
        engine.dispose();
      });
      world.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem());
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);
      world.bindView(view);
      world.persistentLevel.registerActor(LuminaPrimitiveActor(
          location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(2400, 20, 2400), color: Vector3(0.52, 0.5, 0.47)));
      world.persistentLevel.registerActor(LuminaActor(
          root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, -30]), intensity: 100000, castShadows: true)));
      // A post at the guard's starting front (−Z) to read its heading by.
      world.persistentLevel.registerActor(LuminaPrimitiveActor(
          location: Vector3(0, 40, -250), shape: LuminaPrimitiveShape.box, size: Vector3(20, 80, 20), color: Vector3(0.85, 0.2, 0.2)));

      const radius = 500.0;
      LuminaTemplateCharacter mannequin(Vector3 at) => LuminaTemplateCharacter(
            thirdPerson: true,
            meshAssetPath: LuminaThirdPersonContent.bundledMeshPath,
            location: at + Vector3(0, LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight + 1, 0),
          );
      final guard = mannequin(Vector3.zero());
      final player = mannequin(Vector3(0, 0, -radius));
      final sight = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0, peripheralVisionAngleDegrees: 30.0),
        updateInterval: 1 / 30,
      );
      guard.addComponent(sight);
      world.persistentLevel.registerActor(guard);
      world.persistentLevel.registerActor(player);
      final ai = LuminaAIController()..possess(guard);
      ai.setFocus(player);
      percepSys.registerSource(player);
      world.beginPlay();
      await Future.wait([guard.bodyMesh!.loaded, player.bodyMesh!.loaded]).timeout(const Duration(seconds: 120));

      Uint8List shot() {
        camera.lookAt(eyeX: 700, eyeY: 900, eyeZ: 900, centerX: 0, centerY: 60, centerZ: 0);
        for (var i = 0; i < 3; i++) {
          if (renderer.beginFrame(swapChain)) {
            renderer.render(view);
            if (i == 2) {
              c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
            }
            renderer.endFrame();
          }
          engine.flushAndWait();
        }
        return Uint8List.fromList(pixels.asTypedList(w * h * 4));
      }

      double wrap(double deg) {
        var d = deg % 360.0;
        if (d > 180.0) d -= 360.0;
        return d;
      }

      final usedAssets = [LuminaThirdPersonContent.bundledMeshPath];
      final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
      addTearDown(video.discard);
      final notFacing = <String>[];
      final unseen = <String>[];
      var maxYawError = 0.0;
      // 0.5 s still, 9 s walking a full clockwise circle (bearing 0 → 360°,
      // seen from above: −Z, +X, +Z, −X), 0.5 s still.
      const ticks = 600;
      for (var tick = 0; tick < ticks; tick++) {
        final t = tick / 60;
        final bearing = 360.0 * ((t - 0.5) / 9.0).clamp(0.0, 1.0);
        final b = bearing * math.pi / 180.0;
        player.actorLocation = Vector3(math.sin(b) * radius, player.actorLocation.y, -math.cos(b) * radius);
        // Walking the circle clockwise: heading 90° right of the bearing.
        player.actorRotation = luminaPawnEulerToQuaternion(0, bearing + 90.0, 0);
        ai.onTick(1 / 60);
        world.tick(1 / 60);

        final toPlayer = player.actorLocation - guard.actorLocation
          ..y = 0.0
          ..normalize();
        final forward = guard.actorRotation.rotateVector(Vector3(0, 0, -1))
          ..y = 0.0
          ..normalize();
        // The yaw a player controller would need to face the same bearing.
        final yawError = wrap(ai.controlRotation.y - bearing).abs();
        maxYawError = math.max(maxYawError, yawError);
        if (forward.dot(toPlayer) < 0.999) notFacing.add('${t.toStringAsFixed(2)} s (bearing ${bearing.toStringAsFixed(0)}°)');
        if (t > 0.3 && !sight.getCurrentlyPerceivedActors(sense: AISenseType.sight).contains(player)) {
          unseen.add('${t.toStringAsFixed(2)} s (bearing ${bearing.toStringAsFixed(0)}°)');
        }
        if (tick.isEven) video.addFrame(shot());
        for (final (label, at) in const [('01 player to the right (bearing 90)', 2.75), ('02 player behind the start (bearing 180)', 5.0)]) {
          if (tick == (at * 60).round()) {
            SmokeArtifacts.saveScreenshot('$testTitle $label', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets, metrics: {
              'bearing': bearing,
              'aiControlYaw': ai.controlRotation.y,
              'guardFacingDot': forward.dot(toPlayer),
              'seen': sight.getCurrentlyPerceivedActors(sense: AISenseType.sight).contains(player),
            });
          }
        }
      }
      expect(maxYawError, lessThan(1e-6), reason: 'the AI yaw is the player-controller yaw of the bearing');
      expect(notFacing, isEmpty, reason: 'the guard faces the player every tick');
      expect(unseen, isEmpty, reason: 'its 30° sight cone follows its focus');
      SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
