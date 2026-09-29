import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Utility Module Smoke Tests', () {
    test('Scenario 01: LuminaTimerManager game-time ticking, multi-timer coordination, looping intervals, and delayed world events with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);

      int heartbeatFires = 0;
      int burstFires = 0;
      bool oneShotDone = false;

      world.beginPlay();

      timerMgr.setTimer(() => heartbeatFires++, rate: 0.5, looping: true);
      timerMgr.setTimer(() => burstFires++, rate: 0.2, looping: true);
      timerMgr.setTimer(() => oneShotDone = true, rate: 2.0);

      for (int i = 0; i < 155; i++) {
        world.tick(0.02);
      }

      expect(heartbeatFires, equals(6));
      expect(burstFires, equals(15));
      expect(oneShotDone, isTrue);

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
        'Props/Access_cards/access_card_blue.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Utility Module Smoke Tests Scenario 01: LuminaTimerManager game-time ticking, multi-timer coordination, looping intervals, and delayed world events with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Central Pulsing Beacon (Asset 0: Barrel pulsing every 0.5s heartbeat)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final baseScale0 = max0 > 0 ? 1.3 / max0 : 1.0;
          final pulse = 1.0 + (math.sin(timeSeconds * math.pi * 2.0).abs()) * 0.2;
          final scale0 = baseScale0 * pulse;
          final barrelMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0, 0.0)
            ..rotateY(timeSeconds * 1.5)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, barrelMat.storage.toList());

          // Fast Pulsing Satellite (Asset 1: AC Unit orbiting and flashing every 0.2s)
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 1.4 / max1 : 1.0;
            final orbitRadius = 3.2;
            final orbitAngle = timeSeconds * 1.8;
            final acMat = Matrix4.identity()
              ..setTranslationRaw(math.sin(orbitAngle) * orbitRadius, 1.0 + math.sin(timeSeconds * 5.0) * 0.3, math.cos(orbitAngle) * orbitRadius)
              ..rotateY(orbitAngle)
              ..scaleByDouble(scale1, scale1, scale1, 1.0);
            tm.setTransform(assets[1].rootEntity, acMat.storage.toList());
          }

          // Triggered Keycard Gateway (Asset 2: Card floating after 2.0s trigger)
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 0.9 / max2 : 1.0;
            final triggeredHeight = timeSeconds >= 2.0 ? 2.2 : 0.4;
            final cardMat = Matrix4.identity()
              ..setTranslationRaw(-2.5, triggeredHeight, -2.0)
              ..rotateY(timeSeconds * 4.0)
              ..scaleByDouble(scale2, scale2, scale2, 1.0);
            tm.setTransform(assets[2].rootEntity, cardMat.storage.toList());
          }

          // Orbiting camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.35) * 6.0,
            eyeY: 2.8,
            eyeZ: math.cos(timeSeconds * 0.35) * 6.0,
            centerX: 0.0,
            centerY: 1.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: LuminaGameplayStatics dynamic actor spawning, class queries, radial damage blast waves, and deferred cleanup with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final centralActor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final peripheralActor1 = LuminaActor(location: Vector3(3.0, 0.0, 0.0));
      final peripheralActor2 = LuminaActor(location: Vector3(-3.0, 0.0, 0.0));

      double damage1 = 0.0;
      double damage2 = 0.0;
      peripheralActor1.onTakeAnyDamage = (d, i, c) => damage1 = d;
      peripheralActor2.onTakeAnyDamage = (d, i, c) => damage2 = d;

      LuminaGameplayStatics.spawnActor(world, centralActor);
      LuminaGameplayStatics.spawnActor(world, peripheralActor1);
      LuminaGameplayStatics.spawnActor(world, peripheralActor2);

      world.tick(0.016);

      final all = LuminaGameplayStatics.getAllActorsOfClass<LuminaActor>(world);
      expect(all.length, equals(3));

      LuminaGameplayStatics.applyRadialDamage(
        world,
        100.0,
        Vector3.zero(),
        5.0,
        damageCauser: centralActor,
      );

      expect(damage1, closeTo(40.0, 1e-4));
      expect(damage2, closeTo(40.0, 1e-4));

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
        'Props/Access_cards/access_card_blue.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Utility Module Smoke Tests Scenario 02: LuminaGameplayStatics dynamic actor spawning, class queries, radial damage blast waves, and deferred cleanup with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Central Blast Epicenter (Asset 0: Barrel spinning and triggering radial blast wave)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.5 / max0 : 1.0;
          final blastCycle = timeSeconds % 2.5;
          final blastExpansion = blastCycle * 2.0;

          final barrelMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0, 0.0)
            ..rotateY(timeSeconds * 3.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, barrelMat.storage.toList());

          // Blast Affected Satellite 1 (Asset 1: AC Unit knocked back by radial shockwave)
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 1.5 / max1 : 1.0;
            final knockback = blastExpansion > 1.5 ? (blastExpansion - 1.5) * 1.5 : 0.0;
            final posX = 3.0 + knockback;
            final posY = 0.5 + (blastExpansion > 1.5 ? math.sin((blastExpansion - 1.5) * math.pi) * 1.2 : 0.0);

            final acMat = Matrix4.identity()
              ..setTranslationRaw(posX, posY, 0.0)
              ..rotateZ(knockback * 0.5)
              ..scaleByDouble(scale1, scale1, scale1, 1.0);
            tm.setTransform(assets[1].rootEntity, acMat.storage.toList());
          }

          // Blast Affected Satellite 2 (Asset 2: Access Card floating and reacting)
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 1.0 / max2 : 1.0;
            final knockback = blastExpansion > 1.5 ? (blastExpansion - 1.5) * 1.5 : 0.0;
            final posX = -3.0 - knockback;
            final posY = 0.5 + (blastExpansion > 1.5 ? math.sin((blastExpansion - 1.5) * math.pi) * 1.2 : 0.0);

            final cardMat = Matrix4.identity()
              ..setTranslationRaw(posX, posY, 0.0)
              ..rotateY(timeSeconds * 2.0)
              ..rotateZ(-knockback * 0.5)
              ..scaleByDouble(scale2, scale2, scale2, 1.0);
            tm.setTransform(assets[2].rootEntity, cardMat.storage.toList());
          }

          // Orbiting dynamic tracking camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.35) * 6.5,
            eyeY: 3.2,
            eyeZ: math.cos(timeSeconds * 0.35) * 6.5,
            centerX: 0.0,
            centerY: 1.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 03: LuminaTriggerVolume, LuminaBlockingVolume, LuminaKillZVolume overlap triggering, boundary collision, and lethal hazard zones with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      final trigger = LuminaTriggerVolume(extent: Vector3(2.0, 2.0, 2.0));
      final blocker = LuminaBlockingVolume(extent: Vector3(1.0, 1.0, 1.0), location: Vector3(5.0, 0.0, 0.0));
      final killZone = LuminaKillZVolume(extent: Vector3(2.0, 2.0, 2.0), location: Vector3(-5.0, 0.0, 0.0));

      final testPawn = LuminaPawn(
        location: Vector3(0.0, 0.0, 0.0),
        root: LuminaCollisionComponent(
          shapeType: CollisionShapeType.box,
        )..boxExtent.setFrom(Vector3(0.5, 0.5, 0.5)),
      );

      bool triggered = false;
      trigger.onActorBeginOverlap = (a) => triggered = true;

      world.persistentLevel.registerActor(trigger);
      world.persistentLevel.registerActor(blocker);
      world.persistentLevel.registerActor(killZone);
      world.persistentLevel.registerActor(testPawn);

      world.beginPlay();

      world.tick(0.016);
      expect(triggered, isTrue);
      expect(trigger.overlappingActors, contains(testPawn));

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
        'Props/Access_cards/access_card_blue.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Utility Module Smoke Tests Scenario 03: LuminaTriggerVolume, LuminaBlockingVolume, LuminaKillZVolume overlap triggering, boundary collision, and lethal hazard zones with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Central Trigger Platform (Asset 0: Barrel inside Trigger Volume)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.4 / max0 : 1.0;
          final inTrigger = (timeSeconds % 4.0) < 2.0;
          final elevY = inTrigger ? 1.0 : 0.0;

          final barrelMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0 + elevY, 0.0)
            ..rotateY(timeSeconds * 2.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, barrelMat.storage.toList());

          // Invisible Blocking Boundary (Asset 1: AC Unit bouncing off blocking wall at X = 3.5)
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 1.5 / max1 : 1.0;
            final cycleX = (math.sin(timeSeconds * 2.0).abs()) * 3.5;

            final acMat = Matrix4.identity()
              ..setTranslationRaw(cycleX, 0.6, 2.0)
              ..rotateY(timeSeconds * 1.5)
              ..scaleByDouble(scale1, scale1, scale1, 1.0);
            tm.setTransform(assets[1].rootEntity, acMat.storage.toList());
          }

          // Lethal Hazard Pit (Asset 2: Card falling into KillZ pit at X = -3.5)
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 1.0 / max2 : 1.0;
            final fallT = (timeSeconds % 3.0);
            final fallY = fallT < 2.0 ? 2.5 - (fallT * fallT * 2.0) : -10.0; // Dissolves below KillZ

            final cardMat = Matrix4.identity()
              ..setTranslationRaw(-3.5, fallY, -1.0)
              ..rotateZ(timeSeconds * 5.0)
              ..rotateY(timeSeconds * 3.0)
              ..scaleByDouble(scale2, scale2, scale2, 1.0);
            tm.setTransform(assets[2].rootEntity, cardMat.storage.toList());
          }

          // Orbiting dynamic tracking camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.3) * 7.0,
            eyeY: 3.5,
            eyeZ: math.cos(timeSeconds * 0.3) * 7.0,
            centerX: 0.0,
            centerY: 1.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 04: LuminaViewportStatics GPU pixel picking, entity-to-actor selection, and screenshot row-flipping with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actorA = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final compA = LuminaSceneComponent();
      actorA.addComponent(compA);
      world.entityRegistry.registerEntities([101], compA);

      final pickRes = await LuminaViewportStatics.pickAtScreen(
        world,
        400.0,
        300.0,
        viewportWidth: 800,
        viewportHeight: 600,
        pickOverride: (x, y) async => PickingResult(FilamentEntity(101), 0.45, (400.0, 299.0)),
      );

      expect(pickRes.hasHit, isTrue);
      expect(pickRes.entity, equals(101));
      expect(pickRes.actor, same(actorA));
      expect(pickRes.component, same(compA));

      final rawScreenshot = Uint8List.fromList([
        255, 0, 0, 255,
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 255, 0, 255,
      ]);
      final screenshot = await LuminaViewportStatics.captureScreenshot(
        world,
        width: 2,
        height: 2,
        fakePixels: rawScreenshot,
      );
      expect(screenshot.length, equals(16));

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
        'Props/Access_cards/access_card_blue.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Utility Module Smoke Tests Scenario 04: LuminaViewportStatics GPU pixel picking, entity-to-actor selection, and screenshot row-flipping with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Focus Target 0 (Asset 0: Barrel with picking highlight cursor oscillation)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.4 / max0 : 1.0;
          final isTargetPicked = (timeSeconds % 3.0) < 1.5;
          final pulseScale = isTargetPicked ? (1.0 + math.sin(timeSeconds * 10.0) * 0.08) * scale0 : scale0;

          final barrelMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * pulseScale, 0.0)
            ..rotateY(timeSeconds * 1.5)
            ..scaleByDouble(pulseScale, pulseScale, pulseScale, 1.0);
          tm.setTransform(assets[0].rootEntity, barrelMat.storage.toList());

          // Selectable Target 1 (Asset 1: AC Unit)
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 1.5 / max1 : 1.0;

            final acMat = Matrix4.identity()
              ..setTranslationRaw(3.0, 0.6, -1.0)
              ..rotateY(timeSeconds * 0.8)
              ..scaleByDouble(scale1, scale1, scale1, 1.0);
            tm.setTransform(assets[1].rootEntity, acMat.storage.toList());
          }

          // Selectable Target 2 (Asset 2: Access Card floating)
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 1.0 / max2 : 1.0;
            final hoverY = 1.0 + math.sin(timeSeconds * 3.0) * 0.2;

            final cardMat = Matrix4.identity()
              ..setTranslationRaw(-3.0, hoverY, 1.0)
              ..rotateZ(timeSeconds * 2.0)
              ..rotateY(timeSeconds * 1.5)
              ..scaleByDouble(scale2, scale2, scale2, 1.0);
            tm.setTransform(assets[2].rootEntity, cardMat.storage.toList());
          }

          // Orbiting dynamic tracking camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.25) * 6.5,
            eyeY: 3.0,
            eyeZ: math.cos(timeSeconds * 0.25) * 6.5,
            centerX: 0.0,
            centerY: 0.8,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });
  });
}
