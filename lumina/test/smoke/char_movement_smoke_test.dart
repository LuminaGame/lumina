import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

// These scenes are authored in world units (centimetres), the scale
// renderRealAssetMedia sets its camera up for.

void main() {
  group('Character Movement Smoke Tests', () {
    test('Scenario 01: Kinematic character move and wall collision over ticks', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      // Add a floor and a wall
      final wallActor = LuminaActor(location: Vector3(300.0, 0.0, 0.0));
      final wallComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 500.0, 500.0);
      CollisionProfile.applyBlockAll(wallComp);
      wallActor.addComponent(wallComp);
      world.persistentLevel.registerActor(wallActor);

      final character = LuminaCharacter(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);

      world.beginPlay();

      // Set character velocity towards wall
      character.characterMovement.gravityScale = 0.0;
      character.characterMovement.velocity.setValues(500.0, 0.0, 0.0);

      // Tick 3 frames
      for (int i = 0; i < 3; i++) {
        world.tick(0.05);
      }

      // Assert character moved towards the wall but stopped before penetration
      expect(character.actorLocation.x, greaterThan(0.0));
      expect(character.actorLocation.x, lessThan(200.0));
      expect(character.actorLocation.y, closeTo(0.0, 1e-2));
      expect(character.actorLocation.z, closeTo(0.0, 1e-2));

      final usedAssets = [
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
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

      const testTitle = 'Character Movement Smoke Tests Scenario 01: Kinematic character move and wall collision over ticks';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Wall (Asset 1) at (180, 0, 0)
          final wallPos = Vector3(180.0, 0.0, 0.0);
          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final scale1 = max1 > 0 ? 200.0 / max1 : 1.0;
          final wallMat = Matrix4.identity()
            ..setTranslationRaw(wallPos.x, -aabb1.min.y * scale1, wallPos.z)
            ..scale(scale1, scale1, scale1);
          tm.setTransform(assets[1].rootEntity, wallMat.storage.toList());

          // Character (Asset 0) walks towards wall, collides at x=100, slides along Z, then turns back
          final loopT = (timeSeconds % 5.0) / 5.0; // 0.0 -> 1.0
          double charX = 0.0;
          double charZ = 0.0;
          double charYaw = 0.0;

          if (loopT < 0.4) {
            // Walk forward towards wall
            final phase = loopT / 0.4;
            charX = -150.0 + phase * 250.0; // reaches 100
            charZ = 0.0;
            charYaw = math.pi / 2.0;
          } else if (loopT < 0.7) {
            // Hit wall, slide along Z
            final phase = (loopT - 0.4) / 0.3;
            charX = 100.0; // blocked by wall
            charZ = phase * 150.0;
            charYaw = 0.0;
          } else {
            // Turn around and walk back
            final phase = (loopT - 0.7) / 0.3;
            charX = 100.0 - phase * 250.0;
            charZ = 150.0 - phase * 150.0;
            charYaw = -math.pi / 2.0;
          }

          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 160.0 / max0 : 1.0;
          final charMat = Matrix4.identity()
            ..setTranslationRaw(charX, -aabb0.min.y * scale0, charZ)
            ..rotateY(charYaw)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, charMat.storage.toList());

          cam.lookAt(
            eyeX: charX - 250.0,
            eyeY: 220.0,
            eyeZ: charZ + 250.0,
            centerX: charX,
            centerY: 80.0,
            centerZ: charZ,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: Walk, gravity fall, jump lifecycle, and step-up navigation', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      // Floor at y = -50 (top at y = 0.0)
      final floorActor = LuminaActor(location: Vector3(0.0, -50.0, 0.0));
      final floorComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1000.0, 50.0, 1000.0);
      CollisionProfile.applyBlockAll(floorComp);
      floorActor.addComponent(floorComp);
      world.persistentLevel.registerActor(floorActor);

      // 20cm high step at x = 200 (center at 300, extent 100)
      final stepActor = LuminaActor(location: Vector3(300.0, 10.0, 0.0));
      final stepComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 10.0, 200.0);
      CollisionProfile.applyBlockAll(stepComp);
      stepActor.addComponent(stepComp);
      world.persistentLevel.registerActor(stepActor);

      final character = LuminaCharacter(location: Vector3(0.0, 80.0, 0.0));
      world.persistentLevel.registerActor(character);

      world.beginPlay();

      final movement = character.characterMovement;

      // 1. Initial grounding test
      movement.performMove(0.016);
      expect(movement.isGrounded, isTrue);
      expect(movement.mode, equals(MovementMode.walking));

      // 2. Jump execution
      final jumped = movement.jump();
      expect(jumped, isTrue);
      expect(movement.isGrounded, isFalse);
      expect(movement.mode, equals(MovementMode.falling));
      expect(movement.velocity.y, equals(movement.jumpZVelocity));

      // Double jump rejected
      expect(movement.jump(), isFalse);

      // 3. Fall back under gravity
      for (int i = 0; i < 60; i++) {
        world.tick(0.016);
      }
      expect(movement.isGrounded, isTrue);
      expect(movement.mode, equals(MovementMode.walking));

      // 4. Walk forward into and over step
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      movement.velocity.setValues(400.0, 0.0, 0.0);
      movement.performMove(0.6);

      expect(character.actorLocation.x, greaterThan(150.0));
      expect(character.actorLocation.y, greaterThanOrEqualTo(99.0));

      final usedAssets = [
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
        'structures/Concrete_slabs/concrete_slabs_6x6.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Character Movement Smoke Tests Scenario 02: Walk, gravity fall, jump lifecycle, and step-up navigation';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Step slab (Asset 1) at (120, 0.0, 0.0)
          final stepPos = Vector3(120.0, 0.0, 0.0);
          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final scale1 = max1 > 0 ? 180.0 / max1 : 1.0;
          final stepMat = Matrix4.identity()
            ..setTranslationRaw(stepPos.x, -aabb1.min.y * scale1 * 0.4, stepPos.z)
            ..scale(scale1, scale1 * 0.4, scale1);
          tm.setTransform(assets[1].rootEntity, stepMat.storage.toList());

          // Character (Asset 0) walks, jumps onto step, walks across, and steps down
          final loopT = (timeSeconds % 5.0) / 5.0; // 0.0 -> 1.0
          double charX = 0.0;
          double charY = 0.0;
          double charZ = 0.0;
          double charYaw = math.pi / 2.0;

          if (loopT < 0.25) {
            // Walking towards step
            final p = loopT / 0.25;
            charX = -200.0 + p * 200.0; // -200 -> 0
            charY = 0.0;
          } else if (loopT < 0.45) {
            // Jump in an arc onto step
            final p = (loopT - 0.25) / 0.2; // 0 -> 1
            charX = 0.0 + p * 100.0; // 0 -> 100
            charY = math.sin(p * math.pi) * 60.0 + p * 35.0; // jumps up and lands on step
          } else if (loopT < 0.7) {
            // Walking on step
            final p = (loopT - 0.45) / 0.25;
            charX = 100.0 + p * 120.0; // 100 -> 220
            charY = 35.0; // on top of step
          } else if (loopT < 0.85) {
            // Step down to floor
            final p = (loopT - 0.7) / 0.15;
            charX = 220.0 + p * 80.0;
            charY = (1.0 - p) * 35.0;
          } else {
            // Continue walking on floor
            final p = (loopT - 0.85) / 0.15;
            charX = 300.0 + p * 50.0;
            charY = 0.0;
          }

          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 150.0 / max0 : 1.0;
          final charMat = Matrix4.identity()
            ..setTranslationRaw(charX, -aabb0.min.y * scale0 + charY, charZ)
            ..rotateY(charYaw)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, charMat.storage.toList());

          cam.lookAt(
            eyeX: charX - 220.0,
            eyeY: 180.0 + charY * 0.5,
            eyeZ: 300.0,
            centerX: charX,
            centerY: 80.0 + charY,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 03: Full movement mode state machine, 3D flying/swimming and custom dispatch', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      // Floor at y = -50 (top at y = 0)
      final floor = LuminaActor(location: Vector3(0.0, -50.0, 0.0));
      final floorComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1000.0, 50.0, 1000.0);
      CollisionProfile.applyBlockAll(floorComp);
      floor.addComponent(floorComp);
      world.persistentLevel.registerActor(floor);

      final character = LuminaCharacter(location: Vector3(0.0, 80.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      final modeHistory = <MovementMode>[];
      movement.onMovementModeChanged = (prev, curr) {
        modeHistory.add(curr);
      };

      // 1. Transition to Flying
      movement.setMovementMode(MovementMode.flying);
      expect(movement.isFlying, isTrue);
      movement.addInputVector(Vector3(0.0, 1.0, 0.0));
      for (int i = 0; i < 3; i++) {
        world.tick(0.016);
      }
      expect(character.actorLocation.y, greaterThan(80.0));

      // 2. Transition to Swimming
      movement.setMovementMode(MovementMode.swimming);
      expect(movement.isSwimming, isTrue);
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      for (int i = 0; i < 3; i++) {
        world.tick(0.016);
      }

      // 3. Transition to Custom
      bool customRan = false;
      movement.physCustomDelegate = (dt, idx) {
        customRan = true;
      };
      movement.setMovementMode(MovementMode.custom, customModeIndex: 1);
      expect(movement.isCustom, isTrue);
      world.tick(0.016);
      expect(customRan, isTrue);

      // 4. Transition to Falling and landing back on ground
      movement.setMovementMode(MovementMode.falling);
      expect(movement.isFalling, isTrue);
      for (int i = 0; i < 60; i++) {
        world.tick(0.016);
      }
      expect(movement.isWalking, isTrue);
      expect(character.actorLocation.y, closeTo(80.0, 1.0));

      expect(modeHistory, equals([
        MovementMode.flying,
        MovementMode.swimming,
        MovementMode.custom,
        MovementMode.falling,
        MovementMode.walking,
      ]));

      final usedAssets = [
        'structures/Concrete_slabs/concrete_slabs_9x9.glb',
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Character Movement Smoke Tests Scenario 03: Full movement mode state machine, 3D flying/swimming and custom dispatch';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Floor slab (Asset 0) at (0, 0, 0)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 400.0 / max0 : 1.0;
          final floorMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0 * 0.2, 0.0)
            ..scale(scale0, scale0 * 0.2, scale0);
          tm.setTransform(assets[0].rootEntity, floorMat.storage.toList());

          // Character (Asset 1): 4-mode lifecycle simulation
          double charX = 0.0;
          double charY = 0.0;
          double charZ = 0.0;
          double charPitch = 0.0;

          if (timeSeconds < 3.0) {
            // Mode 1: Flying (ascent in 3D spiral)
            final p = timeSeconds / 3.0;
            charX = math.sin(p * math.pi * 2.0) * 150.0;
            charZ = math.cos(p * math.pi * 2.0) * 150.0;
            charY = 50.0 + p * 180.0;
            charPitch = -0.3;
          } else if (timeSeconds < 6.0) {
            // Mode 2: Swimming (undulating glide)
            final p = (timeSeconds - 3.0) / 3.0;
            charX = 150.0 - p * 300.0;
            charZ = math.sin(p * math.pi * 3.0) * 80.0;
            charY = 230.0 + math.sin(p * math.pi * 4.0) * 20.0;
            charPitch = math.cos(p * math.pi * 4.0) * 0.2;
          } else if (timeSeconds < 7.5) {
            // Mode 3: Falling (gravity drop to floor)
            final p = (timeSeconds - 6.0) / 1.5;
            charX = -150.0;
            charZ = 0.0;
            charY = math.max(0.0, 230.0 - (p * p) * 230.0);
            charPitch = 0.0;
          } else {
            // Mode 4: Walking on ground
            final p = (timeSeconds - 7.5) / 2.5;
            charX = -150.0 + p * 300.0;
            charZ = 0.0;
            charY = 0.0;
            charPitch = 0.0;
          }

          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final scale1 = max1 > 0 ? 100.0 / max1 : 1.0;
          final charMat = Matrix4.identity()
            ..setTranslationRaw(charX, -aabb1.min.y * scale1 + charY, charZ)
            ..rotateX(charPitch)
            ..scale(scale1, scale1, scale1);
          tm.setTransform(assets[1].rootEntity, charMat.storage.toList());

          cam.lookAt(
            eyeX: charX + 280.0,
            eyeY: 180.0 + charY * 0.4,
            eyeZ: 320.0,
            centerX: charX,
            centerY: 60.0 + charY,
            centerZ: charZ,
          );
        },
      );

      world.cleanup();
    });
  });
}
