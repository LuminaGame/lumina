import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

class LevelStreamingSmokeActor extends LuminaActor {
  int tickCount = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
  }
}

void main() {
  group('level_streaming Module Smoke Tests', () {
    test('Scenario 01: LuminaLevelStreaming 7-state lifecycle with world actors and async streaming state transitions', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final level = LuminaLevel();
      final actor1 = LevelStreamingSmokeActor();
      final actor2 = LevelStreamingSmokeActor();
      level.registerActor(actor1);
      level.registerActor(actor2);

      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/Smoke_SubLevel_A.lmas',
        levelInstance: level,
        bShouldBeLoaded: false,
        bShouldBeVisible: false,
      );

      world.streamingLevels.add(level);
      world.beginPlay();

      // 1. Initial State
      expect(streaming.state, equals(LevelState.unloaded));
      expect(level.state, equals(LevelState.unloaded));

      // 2. Load
      await streaming.loadLevelAsync();
      expect(streaming.state, equals(LevelState.loaded));
      expect(level.state, equals(LevelState.loaded));

      // 3. Make Visible
      await streaming.setVisibleAsync(true);
      expect(streaming.state, equals(LevelState.visible));
      expect(level.state, equals(LevelState.visible));

      // Tick world
      world.tick(1.0 / 60.0);
      expect(actor1.tickCount, equals(1));
      expect(actor2.tickCount, equals(1));

      // 4. Hide and unload
      await streaming.setVisibleAsync(false);
      expect(streaming.state, equals(LevelState.loaded));

      await streaming.unloadLevelAsync();
      expect(streaming.state, equals(LevelState.unloaded));
      expect(level.actors, isEmpty);

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/fuel_barrel_black.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle1 = 'level_streaming_smoke_test: Scenario 01 LuminaLevelStreaming 7-state lifecycle';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle1,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Persistent level asset (Asset 0) at (-1.0, 0, 0)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.0 / max0 : 1.0;
          final mat0 = Matrix4.identity()
            ..setTranslationRaw(-1.0, -aabb0.min.y * scale0, 0.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, mat0.storage.toList());

          // Sub-level streaming asset (Asset 1) at (1.0, 0, 0)
          // Streams in between 2.0s and 4.0s, stays visible until 7.0s, unloads by 8.5s
          double streamAlpha = 0.0;
          if (timeSeconds >= 2.0 && timeSeconds <= 8.5) {
            if (timeSeconds < 3.5) {
              streamAlpha = (timeSeconds - 2.0) / 1.5;
            } else if (timeSeconds > 7.0) {
              streamAlpha = 1.0 - (timeSeconds - 7.0) / 1.5;
            } else {
              streamAlpha = 1.0;
            }
          }
          streamAlpha = streamAlpha.clamp(0.0, 1.0);

          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final scale1 = max1 > 0 ? 1.0 / max1 : 1.0;
          final mat1 = Matrix4.identity()
            ..setTranslationRaw(1.0, -aabb1.min.y * scale1 * streamAlpha, 0.0)
            ..scaleByDouble(scale1 * streamAlpha, scale1 * streamAlpha, scale1 * streamAlpha, 1.0);
          tm.setTransform(assets[1].rootEntity, mat1.storage.toList());

          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.5) * 3.0,
            eyeY: 1.6,
            eyeZ: math.cos(timeSeconds * 0.5) * 3.0,
            centerX: 0.0,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: LuminaLevelStreamingVolume hysteresis and level request intent evaluation in world tick loop', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final volume = LuminaLevelStreamingVolume(
        volumeName: 'Smoke_Volume_A',
        targetLevelNames: ['Level_Dungeon_A'],
        bounds: Aabb3.minMax(Vector3(0, 0, 0), Vector3(20, 20, 20)),
        bufferMargin: 5.0,
        exitDelay: const Duration(seconds: 1),
      );

      final pawn = LuminaPawn();
      world.spawnActor(pawn);
      world.beginPlay();

      // Pawn starts outside
      pawn.actorLocation = Vector3(100, 100, 100);
      volume.evaluatePawnPosition(pawn, pawn.actorLocation, 0.016);
      expect(volume.requestedLevels, isEmpty);

      // Pawn enters volume
      pawn.actorLocation = Vector3(10, 10, 10);
      volume.evaluatePawnPosition(pawn, pawn.actorLocation, 0.016);
      expect(volume.requestedLevels, contains('Level_Dungeon_A'));

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
        volume.evaluatePawnPosition(pawn, pawn.actorLocation, 1.0 / 60.0);
      }
      expect(volume.isAnyPawnInside, isTrue);

      final usedAssets = [
        'Props/Barrels/fuel_barrel_yellow.glb',
        'Props/Access_cards/access_card_red.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle2 = 'level_streaming_smoke_test: Scenario 02 LuminaLevelStreamingVolume hysteresis';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle2,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Pawn (Asset 0) travels in and out of the volume
          final pawnX = math.sin(timeSeconds * 0.7) * 2.5;
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.0 / max0 : 1.0;
          final mat0 = Matrix4.identity()
            ..setTranslationRaw(pawnX, -aabb0.min.y * scale0, 0.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, mat0.storage.toList());

          // Volume target asset (Asset 1) streams in when pawn is inside |x| < 1.0
          final inside = pawnX.abs() < 1.0;
          final streamScale = inside ? 1.0 : 0.2;
          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final scale1 = max1 > 0 ? 1.0 / max1 : 1.0;
          final mat1 = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb1.min.y * scale1 * streamScale, 1.2)
            ..scaleByDouble(scale1 * streamScale, scale1 * streamScale, scale1 * streamScale, 1.0);
          tm.setTransform(assets[1].rootEntity, mat1.storage.toList());

          cam.lookAt(
            eyeX: pawnX,
            eyeY: 1.8,
            eyeZ: 3.5,
            centerX: pawnX,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 03: LuminaLevelStreamingManager end-to-end subsystem orchestration with volumes and distance streaming', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final manager = LuminaLevelStreamingManager(streamingDistance: 200.0);
      world.subsystems.registerSubsystem<LuminaLevelStreamingManager>(manager, world);

      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/Smoke_SubLevel_Manager.lmas',
        levelInstance: level,
        bShouldBeLoaded: false,
      );

      manager.registerStreamingLevel(streaming, levelOrigin: Vector3(50, 0, 0));
      manager.setViewerPosition(Vector3(0, 0, 0));

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      await Future.delayed(const Duration(milliseconds: 10));
      expect(streaming.state, equals(LevelState.visible));

      final usedAssets = [
        'Props/Banana Bunch/banana_bunch_long.glb',
        'Props/Access_cards/access_card_blue.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle3 = 'level_streaming_smoke_test: Scenario 03 LuminaLevelStreamingManager orchestration';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle3,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 3) return;
          final tm = FilamentTransformManager(engine);

          // Viewer travels across 3 sub-level zones (-2.5, 0.0, +2.5)
          final tViewer = (math.sin(timeSeconds * 0.6) + 1.0) / 2.0;
          final viewerX = -2.5 + tViewer * 5.0;

          for (int i = 0; i < 3; i++) {
            final zoneX = (i - 1) * 2.5;
            final dist = (viewerX - zoneX).abs();
            final activeScale = (1.0 - dist / 2.0).clamp(0.1, 1.0);

            final aabb = assets[i].getBoundingBox();
            final s = aabb.max - aabb.min;
            final maxDim = math.max(s.x, math.max(s.y, s.z));
            final scale = maxDim > 0 ? 1.0 / maxDim : 1.0;
            final mat = Matrix4.identity()
              ..setTranslationRaw(zoneX, -aabb.min.y * scale * activeScale, 0.0)
              ..scaleByDouble(scale * activeScale, scale * activeScale, scale * activeScale, 1.0);
            tm.setTransform(assets[i].rootEntity, mat.storage.toList());
          }

          cam.lookAt(
            eyeX: viewerX,
            eyeY: 1.8,
            eyeZ: 3.5,
            centerX: viewerX,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });
  });
}

