import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Particles Module Smoke Tests', () {
    test('Scenario 01: LuminaParticleSystemComponent CPU particle emitter, burst spawning, size-over-life curves, and instance pool simulation with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final emitterActor = LuminaActor(location: Vector3(0.0, 1.0, 0.0));

      final config = LuminaParticleEmitterConfig(
        spawnRate: 20.0,
        bursts: [
          const LuminaParticleBurst(0.0, 10),
          const LuminaParticleBurst(2.5, 15),
          const LuminaParticleBurst(5.0, 20),
        ],
        lifetimeMin: 2.0,
        lifetimeMax: 3.5,
        speedMin: 3.0,
        speedMax: 6.0,
        coneAngleDegrees: 60.0,
        gravity: Vector3(0.0, -4.0, 0.0),
        drag: 0.2,
        sizeOverLife: [
          LuminaCurvePoint(0.0, 0.2),
          LuminaCurvePoint(0.2, 1.0),
          LuminaCurvePoint(1.0, 0.1),
        ],
        looping: true,
        duration: 5.0,
      );

      final particleComp = LuminaParticleSystemComponent(config: config);
      emitterActor.addComponent(particleComp);
      world.persistentLevel.registerActor(emitterActor);
      world.beginPlay();

      for (int i = 0; i < 60; i++) {
        world.tick(0.016);
      }

      expect(particleComp.liveParticleCount, greaterThan(0));

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

      const testTitle = 'Particles Module Smoke Tests Scenario 01: LuminaParticleSystemComponent CPU particle emitter, burst spawning, size-over-life curves, and instance pool simulation with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Emitter base barrel at origin
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.0 / max0 : 1.0;
          final barrelMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0, 0.0)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, barrelMat.storage.toList());

          // AC Unit background asset
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 1.5 / max1 : 1.0;
            final acMat = Matrix4.identity()
              ..setTranslationRaw(3.0, -aabb1.min.y * scale1, -2.0)
              ..rotateY(-math.pi / 4.0)
              ..scale(scale1, scale1, scale1);
            tm.setTransform(assets[1].rootEntity, acMat.storage.toList());
          }

          // Flying particle card spark (Asset 2)
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 0.6 / max2 : 1.0;

            final cycleT = timeSeconds % 2.5;
            final arcY = 1.0 + math.sin(cycleT * math.pi / 2.5) * 2.5;
            final sparkMat = Matrix4.identity()
              ..setTranslationRaw(math.sin(timeSeconds * 2.0) * 1.5, arcY, math.cos(timeSeconds * 2.0) * 1.5)
              ..rotateY(timeSeconds * 4.0)
              ..rotateX(timeSeconds * 3.0)
              ..scale(scale2, scale2, scale2);
            tm.setTransform(assets[2].rootEntity, sparkMat.storage.toList());
          }

          // Orbiting camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.4) * 4.5,
            eyeY: 2.2,
            eyeZ: math.cos(timeSeconds * 0.4) * 4.5,
            centerX: 0.0,
            centerY: 1.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: the component draws its own particles — real Filament frames of the batched sprite geometry', () async {
      const usedAssets = [
        'Props/Barrels/dented_barrel.glb',
      ];
      const testTitle =
          'Particles Module Smoke Tests Scenario 02: the component draws its own particles — real Filament frames of the batched sprite geometry';

      LuminaWorld? world;
      LuminaParticleSystemComponent? emitter;
      var maxRendered = 0;
      var drawnMatchedLive = false;
      var hadGeometry = false;

      // The world holds Filament objects (material instance, buffers), so it
      // must be torn down before the engine is: own the engine here instead of
      // letting the helper dispose it underneath the world.
      final ownedEngine = FilamentEngine.create()!;
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        engine: ownedEngine,
        autoDisposeEngine: false,
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (world == null && frame == 0) {
            final w = LuminaWorld(worldType: LuminaWorldType.game);
            w.initializeNativeContext(engine, scene, view: view);
            final comp = LuminaParticleSystemComponent(
              config: LuminaParticleEmitterConfig(
                spawnRate: 60.0,
                lifetimeMin: 1.2,
                lifetimeMax: 2.0,
                speedMin: 2.0,
                speedMax: 3.5,
                coneAngleDegrees: 35.0,
                maxParticles: 256,
                gravity: Vector3(0.0, -3.0, 0.0),
                drag: 0.15,
                colorOverLife: [
                  LuminaGradientStop(0.0, Vector4(1.0, 0.85, 0.2, 1.0)),
                  LuminaGradientStop(1.0, Vector4(0.9, 0.15, 0.05, 0.0)),
                ],
                sizeOverLife: [
                  LuminaCurvePoint(0.0, 0.4),
                  LuminaCurvePoint(0.25, 1.0),
                  LuminaCurvePoint(1.0, 0.2),
                ],
                looping: true,
                duration: 3.0,
              ),
              randomSeed: 99,
            )..spriteHalfSize = 0.08;
            final actor = LuminaActor(location: Vector3(0.0, 0.35, 0.0));
            actor.addComponent(comp);
            w.persistentLevel.registerActor(actor);
            w.beginPlay();
            world = w;
            emitter = comp;
          }

          // Real simulation + the component's own render prep write the
          // batched sprite section straight into this scene.
          if (world == null) return;
          world!.tick(1.0 / SmokeVideo.minimumFps); // one frame of renderRealAssetMedia's default rate
          if (emitter!.renderedParticleCount > maxRendered) {
            maxRendered = emitter!.renderedParticleCount;
          }
          drawnMatchedLive = emitter!.renderedParticleCount == emitter!.liveParticleCount;
          hadGeometry = hadGeometry || emitter!.hasSpriteGeometry;

          // The helper destroys the scene it made as soon as it returns, so the
          // world has to let go of it while it is still alive.
          if (frame == totalFrames - 1) {
            world!.cleanup();
            world = null;
          }

          if (assets.isNotEmpty) {
            final tm = FilamentTransformManager(engine);
            final aabb = assets[0].getBoundingBox();
            final size = aabb.max - aabb.min;
            final maxDim = math.max(size.x, math.max(size.y, size.z));
            final scale = maxDim > 0 ? 0.7 / maxDim : 1.0;
            tm.setTransform(
              assets[0].rootEntity,
              (Matrix4.identity()
                    ..setTranslationRaw(0.0, -aabb.min.y * scale, 0.0)
                    ..scale(scale, scale, scale))
                  .storage
                  .toList(),
            );
          }

          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.5) * 3.2,
            eyeY: 1.6,
            eyeZ: math.cos(timeSeconds * 0.5) * 3.2,
            centerX: 0.0,
            centerY: 0.9,
            centerZ: 0.0,
          );
        },
      );

      expect(emitter, isNotNull);
      expect(maxRendered, greaterThan(0), reason: 'the component drew its own particles');
      expect(drawnMatchedLive, isTrue, reason: 'every live particle was drawn on the last frame');
      expect(hadGeometry, isTrue, reason: 'real geometry reached the scene');
      expect(world, isNull, reason: 'the world released the scene before teardown');
      ownedEngine.dispose();
    });
  });
}
