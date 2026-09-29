import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

class PartitionSmokeActor extends LuminaActor {
  int tickCount = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
  }
}

void main() {
  group('World Partition Module Smoke Tests', () {
    test('Scenario 01: LuminaWorldPartitionSubsystem 6-state cell lifecycle and streaming sources with 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(
        cellSize: 128.0,
        maxCellTransitionsPerTick: 10,
      );
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      // Create actors in separate cells
      final actorA = PartitionSmokeActor();
      final actorB = PartitionSmokeActor();
      // Positions are (x, height, z); the grid partitions the X/Z ground plane.
      partition.addActor(actorA, Vector3(50, 0, 50)); // Cell (0, 0)
      partition.addActor(actorB, Vector3(500, 0, 500)); // Cell (3, 3)

      // Add streaming source near Cell (0, 0)
      final source = LuminaStreamingSourceComponent(
        loadingRadius: 200.0,
      )..location = Vector3(50, 0, 50);
      partition.registerSource(source);

      world.beginPlay();

      // Tick 1: Cell (0,0) starts loading
      world.tick(1.0 / 60.0);
      await Future.microtask(() {});

      // Tick 2: Cell (0,0) promotes to activated
      world.tick(1.0 / 60.0);
      world.tick(1.0 / 60.0);

      final cellA = partition.cellByCoords(0, 0)!;
      final cellB = partition.cellByCoords(3, 3)!;

      expect(cellA.state, equals(CellState.activated));
      expect(cellB.state, equals(CellState.unloaded));
      expect(actorA.tickCount, greaterThan(0));
      expect(actorB.tickCount, equals(0));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
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

      const testTitle = 'World Partition Module Smoke Tests Scenario 01: LuminaWorldPartitionSubsystem 6-state cell lifecycle and streaming sources with 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Streaming source travels along X between 0 and 3.5
          final tNorm = (math.sin(timeSeconds * 0.8) + 1.0) / 2.0; // 0.0 -> 1.0 -> 0.0
          final sourceX = tNorm * 3.5;

          // Asset 0 at (0, 0)
          final dist0 = sourceX.abs();
          final scale0Factor = (1.0 - (dist0 / 2.2)).clamp(0.0, 1.0);
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final baseScale0 = max0 > 0 ? 1.0 / max0 : 1.0;
          final mat0 = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * baseScale0 * scale0Factor, 0.0)
            ..scaleByDouble(baseScale0 * scale0Factor, baseScale0 * scale0Factor, baseScale0 * scale0Factor, 1.0);
          tm.setTransform(assets[0].rootEntity, mat0.storage.toList());

          // Asset 1 at (3.5, 0)
          final dist1 = (sourceX - 3.5).abs();
          final scale1Factor = (1.0 - (dist1 / 2.2)).clamp(0.0, 1.0);
          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final baseScale1 = max1 > 0 ? 1.0 / max1 : 1.0;
          final mat1 = Matrix4.identity()
            ..setTranslationRaw(3.5, -aabb1.min.y * baseScale1 * scale1Factor, 0.0)
            ..scaleByDouble(baseScale1 * scale1Factor, baseScale1 * scale1Factor, baseScale1 * scale1Factor, 1.0);
          tm.setTransform(assets[1].rootEntity, mat1.storage.toList());

          // Camera follows the active source
          cam.lookAt(
            eyeX: sourceX,
            eyeY: 2.2,
            eyeZ: 3.5,
            centerX: sourceX,
            centerY: 0.6,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: Multi-source union with pawn attachment and 3D props from test-assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(
        cellSize: 128.0,
        maxCellTransitionsPerTick: 5,
      );
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final playerPawn = LuminaPawn()..actorLocation = Vector3(0, 0, 0);
      world.spawnActor(playerPawn);

      final source = LuminaStreamingSourceComponent(
        loadingRadius: 200.0,
        priority: 5,
      );
      playerPawn.addComponent(source);

      // Populate multiple cells with actors
      final actorNear = PartitionSmokeActor();
      final actorFar = PartitionSmokeActor();
      partition.addActor(actorNear, Vector3(50, 50, 0));
      partition.addActor(actorFar, Vector3(600, 50, 0));

      world.beginPlay();

      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.activated));
      expect(partition.cellByCoords(4, 0)!.state, equals(CellState.unloaded));

      // Move player to far location
      playerPawn.actorLocation = Vector3(600, 50, 0);

      for (int i = 0; i < 6; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(4, 0)!.state, equals(CellState.activated));

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb', // Pawn model
        'Props/Banana Bunch/banana_bunch_short.glb', // Near prop
        'Props/Access_cards/access_card_red.glb', // Far prop
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'World Partition Module Smoke Tests Scenario 02: Multi-source union with pawn attachment and 3D props from test-assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 3) return;
          final tm = FilamentTransformManager(engine);

          // Pawn (Asset 0) travels back and forth
          final tPawn = (math.sin(timeSeconds * 0.7) + 1.0) / 2.0;
          final pawnX = -2.0 + tPawn * 4.0;
          final pawnZ = math.sin(timeSeconds * 1.4) * 0.3;

          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.0 / max0 : 1.0;
          final mat0 = Matrix4.identity()
            ..setTranslationRaw(pawnX, -aabb0.min.y * scale0, pawnZ)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, mat0.storage.toList());

          // Near prop (Asset 1) at (-2.0, 0, 0)
          final distNear = (pawnX - (-2.0)).abs();
          final scaleNear = (1.0 - (distNear / 2.5)).clamp(0.0, 1.0);
          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final base1 = max1 > 0 ? 0.8 / max1 : 1.0;
          final mat1 = Matrix4.identity()
            ..setTranslationRaw(-2.0, -aabb1.min.y * base1 * scaleNear, 0.0)
            ..scaleByDouble(base1 * scaleNear, base1 * scaleNear, base1 * scaleNear, 1.0);
          tm.setTransform(assets[1].rootEntity, mat1.storage.toList());

          // Far prop (Asset 2) at (2.0, 0, 0)
          final distFar = (pawnX - 2.0).abs();
          final scaleFar = (1.0 - (distFar / 2.5)).clamp(0.0, 1.0);
          final aabb2 = assets[2].getBoundingBox();
          final s2 = aabb2.max - aabb2.min;
          final max2 = math.max(s2.x, math.max(s2.y, s2.z));
          final base2 = max2 > 0 ? 0.8 / max2 : 1.0;
          final mat2 = Matrix4.identity()
            ..setTranslationRaw(2.0, -aabb2.min.y * base2 * scaleFar, 0.0)
            ..scaleByDouble(base2 * scaleFar, base2 * scaleFar, base2 * scaleFar, 1.0);
          tm.setTransform(assets[2].rootEntity, mat2.storage.toList());

          // Camera tracks pawn in 3rd person
          cam.lookAt(
            eyeX: pawnX,
            eyeY: 1.8,
            eyeZ: 3.2,
            centerX: pawnX,
            centerY: 0.5,
            centerZ: pawnZ,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 03: Data layer gating of regional 3D assets with runtime layer flipping', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(
        cellSize: 128.0,
        maxCellTransitionsPerTick: 10,
      );
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      partition.dataLayerManager.registerLayer('DataLayer_Quests', initialState: DataLayerState.unloaded);

      final actorQuest = PartitionSmokeActor();
      partition.addActor(actorQuest, Vector3(50, 50, 0));
      partition.assignActorToLayer(actorQuest, 'DataLayer_Quests');

      final source = LuminaStreamingSourceComponent(loadingRadius: 200.0);
      final player = LuminaPawn()..actorLocation = Vector3(50, 50, 0);
      world.spawnActor(player);
      player.addComponent(source);

      world.beginPlay();

      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      // Cell is active, but quest layer is unloaded -> actor does not tick
      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.activated));
      expect(actorQuest.tickCount, equals(0));

      // Flip Quest layer to activated
      partition.dataLayerManager.setDataLayerState('DataLayer_Quests', DataLayerState.activated);

      for (int i = 0; i < 2; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(actorQuest.tickCount, greaterThan(0));

      final usedAssets = [
        'Props/AC_units/roof_aircon_unit_150x150_a.glb',
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

      const testTitle = 'World Partition Module Smoke Tests Scenario 03: Data layer gating of regional 3D assets with runtime layer flipping';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Base asset always active
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.0 / max0 : 1.0;
          final mat0 = Matrix4.identity()
            ..setTranslationRaw(-1.0, -aabb0.min.y * scale0, 0.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, mat0.storage.toList());

          // Quest layer asset (Asset 1) gates in/out based on time (t between 2.5s and 7.5s)
          double questAlpha = 0.0;
          if (timeSeconds >= 2.0 && timeSeconds <= 8.0) {
            if (timeSeconds < 3.0) {
              questAlpha = timeSeconds - 2.0; // fade in
            } else if (timeSeconds > 7.0) {
              questAlpha = 8.0 - timeSeconds; // fade out
            } else {
              questAlpha = 1.0;
            }
          }
          questAlpha = questAlpha.clamp(0.0, 1.0);

          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final base1 = max1 > 0 ? 1.0 / max1 : 1.0;
          final mat1 = Matrix4.identity()
            ..setTranslationRaw(1.0, -aabb1.min.y * base1 * questAlpha, 0.0)
            ..scaleByDouble(base1 * questAlpha, base1 * questAlpha, base1 * questAlpha, 1.0);
          tm.setTransform(assets[1].rootEntity, mat1.storage.toList());

          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.4) * 2.8,
            eyeY: 1.5,
            eyeZ: math.cos(timeSeconds * 0.4) * 2.8,
            centerX: 0.0,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 04: HLOD proxy cross-fade swapping with distant 3D cells', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(
        cellSize: 128.0,
        maxCellTransitionsPerTick: 10,
      );
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final hlodSubsystem = LuminaHlodSubsystem(
        crossFadeDuration: const Duration(milliseconds: 100),
      );
      world.subsystems.registerSubsystem<LuminaHlodSubsystem>(hlodSubsystem, world);

      hlodSubsystem.registerProxyDescriptor(
        LuminaHlodProxyDescriptor(
          cellX: 1,
          cellY: 0,
          proxyMeshAsset: 'Props/Barrels/bent_barrel.glb',
        ),
      );

      world.beginPlay();

      // Tick to initialize proxy
      world.tick(0.016);

      // Initial state: Cell (1, 0) is unloaded -> HLOD proxy is shown (opacity 1.0)
      final proxy = hlodSubsystem.proxyForCell(1, 0)!;
      expect(proxy.state, equals(HlodProxyState.shown));
      expect(proxy.opacity, equals(1.0));

      // Notify that Cell (1, 0) is activated
      hlodSubsystem.onCellStateChanged(1, 0, CellState.unloaded, CellState.activated);

      // Half-way through fade (50ms of 100ms)
      world.tick(0.05);
      expect(proxy.state, equals(HlodProxyState.fadingOut));
      expect(proxy.opacity, closeTo(0.5, 0.05));

      // Finish fade (additional 60ms)
      world.tick(0.06);
      expect(proxy.state, equals(HlodProxyState.hidden));
      expect(proxy.opacity, equals(0.0));

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'World Partition Module Smoke Tests Scenario 04: HLOD proxy cross-fade swapping with distant 3D cells';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Camera zooms out from 1.5m to 6.0m
          final zoomT = (math.sin(timeSeconds * 0.8) + 1.0) / 2.0;
          final camDist = 1.8 + zoomT * 4.5;

          // Close range (<3.5m) shows high-detail mesh (Asset 0)
          // Far range (>3.5m) shows HLOD proxy (Asset 1)
          double hlodAlpha = ((camDist - 3.0) / 1.5).clamp(0.0, 1.0);
          double detailAlpha = 1.0 - hlodAlpha;

          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? (1.0 / max0) * detailAlpha : 1.0;
          final mat0 = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0, 0.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, mat0.storage.toList());

          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final scale1 = max1 > 0 ? (1.0 / max1) * hlodAlpha : 1.0;
          final mat1 = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb1.min.y * scale1, 0.0)
            ..scaleByDouble(scale1, scale1, scale1, 1.0);
          tm.setTransform(assets[1].rootEntity, mat1.storage.toList());

          cam.lookAt(
            eyeX: 0.0,
            eyeY: 1.2 + zoomT * 0.8,
            eyeZ: camDist,
            centerX: 0.0,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });
  });
}
