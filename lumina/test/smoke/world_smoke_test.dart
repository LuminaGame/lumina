import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class WorldSmokeActor extends LuminaActor {
  WorldSmokeActor({super.key});

  int tickCount = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
  }
}

void main() {
  group('World Module Smoke Tests', () {
    test('Scenario 01: 5-phase deterministic tick pipeline and deferred commands', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      // Placed actors carry the engine's own key, as generated levels mount them.
      final actor = WorldSmokeActor(key: const LuminaObjectKey('act_tick'));
      world.persistentLevel.registerActor(actor);

      // Explicit beginPlay
      world.beginPlay();

      expect(actor.isInitialized, isTrue);
      expect(actor.hasBegunPlay, isTrue);

      // Tick 3 frames
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(actor.tickCount, equals(3));

      // Test deferred spawn
      final dynamicActor = WorldSmokeActor(key: const LuminaObjectKey('act_spawned'));
      world.spawnActor(dynamicActor);

      // Before tick, dynamicActor is not yet registered or ticked
      expect(world.persistentLevel.actors.contains(dynamicActor), isFalse);

      world.tick(1.0 / 60.0);
      // After tick, dynamicActor is registered and initialized in phase 5, ready to tick on next frame
      expect(world.persistentLevel.actors.contains(dynamicActor), isTrue);
      expect(dynamicActor.tickCount, equals(0));

      world.tick(1.0 / 60.0);
      expect(dynamicActor.tickCount, equals(1));
      // Both are found by key, the spawned one once the tick registered it.
      LuminaActor? byKey(String id) => world.actors.where((a) => a.key == LuminaObjectKey(id)).singleOrNull;
      expect(byKey('act_tick'), same(actor));
      expect(byKey('act_spawned'), same(dynamicActor));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = 'World Module Smoke Tests Scenario 01: 5-phase deterministic tick pipeline and deferred commands';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
      expect(world.persistentLevel.actors.isEmpty, isTrue);
    });

    test('Scenario 02: Subsystem collection registration, beginPlay, and tick execution', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final physics = LuminaPhysicsWorldSubsystem();
      world.registerSubsystem(physics);

      expect(world.getSubsystem<LuminaPhysicsWorldSubsystem>(), equals(physics));

      world.beginPlay();
      expect(physics.isInitialized, isTrue);

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(physics.stepCount, equals(3));
      expect(physics.totalSimulatedTime, closeTo(0.05, 0.001));

      final usedAssets = [
        'Props/Access_cards/access_card_red.glb',
        'Props/Banana Bunch/banana_bunch_short.glb',
      ];

      const testTitle = 'World Module Smoke Tests Scenario 02: Subsystem collection registration, beginPlay, and tick execution';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
      expect(world.getSubsystem<LuminaPhysicsWorldSubsystem>(), isNull);
    });

    test('Scenario 03: World type gating and safe Filament native context ownership', () async {
      final editorWorld = LuminaWorld(worldType: LuminaWorldType.editor);
      final gameWorld = LuminaWorld(worldType: LuminaWorldType.game);

      expect(editorWorld.worldType.runsGameplay, isFalse);
      expect(gameWorld.worldType.runsGameplay, isTrue);

      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      if (engine != null) {
        final scene = engine.createScene();
        gameWorld.initializeNativeContext(engine, scene);

        expect(gameWorld.hasNativeContext, isTrue);
        expect(gameWorld.filamentEngine, equals(engine));
        expect(gameWorld.filamentScene, equals(scene));

        gameWorld.cleanup();
        expect(gameWorld.hasNativeContext, isFalse);
        expect(gameWorld.isCleanedUp, isTrue);

        engine.destroyScene(scene);
        engine.dispose();
      }

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];

      const testTitle = 'World Module Smoke Tests Scenario 03: World type gating and safe Filament native context ownership';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      editorWorld.cleanup();
    });

    test('Scenario 04: LuminaFrameDriver vsync pacing, target FPS, frame skipping, and stats stream with 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = WorldSmokeActor();
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      if (engine != null) {
        final scene = engine.createScene();
        final view = engine.createView();
        final renderer = engine.createRenderer();
        final swapChain = engine.createHeadlessSwapChain(1, 1);
        world.initializeNativeContext(engine, scene);

        final driver = LuminaFrameDriver(
          world,
          renderer: renderer,
          swapChain: swapChain,
          view: view,
          useFramePacer: false,
        );

        final receivedStats = <LuminaFrameStats>[];
        final sub = driver.frameStats.listen(receivedStats.add);

        driver.targetFrameRate = 60.0;
        expect(driver.targetFrameRate, equals(60.0));

        int vsyncNs = 1000000000;
        for (int i = 0; i < 5; i++) {
          driver.onVsync(vsyncNs);
          vsyncNs += 16666667;
        }

        expect(actor.tickCount, equals(5));

        driver.paused = true;
        driver.onVsync(vsyncNs);
        expect(actor.tickCount, equals(5));

        driver.paused = false;
        vsyncNs += 5000000000;
        driver.onVsync(vsyncNs);
        expect(actor.tickCount, equals(6));

        await sub.cancel();
        driver.dispose();
        world.cleanup();

        renderer.dispose();
        swapChain.dispose();
        view.dispose();
        engine.destroyScene(scene);
        engine.dispose();
      } else {
        world.cleanup();
      }

      final usedAssets = [
        'Props/AC_units/roof_aircon_unit_150x150_b.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = 'World Module Smoke Tests Scenario 04: LuminaFrameDriver vsync pacing, target FPS, frame skipping, and stats stream with 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );
    });

    // Two worlds (two viewports: each its own view, scene, camera,
    // renderer and swap chain) on the process's shared engine draw the same
    // real textured meshes; each mesh is uploaded once.
    test('World: two worlds share one engine and one upload of a mesh', () async {
      const testTitle = 'World: two worlds share one engine and one upload of a mesh';
      const usedAssets = ['fixtures/YVO3D_44368.glb', 'Props/Barrels/dented_barrel.glb'];
      final assetsDir = SmokeArtifacts.testAssetsDir.path;
      final lease = FilamentEngineHost.acquire(owner: 'world smoke')!;
      final engine = lease.engine;
      // The cache's own objects (the ubershader provider's dummy texture)
      // live as long as the engine: count from after they exist.
      final cache = LuminaMeshAssetCache.forEngine(engine);
      final baseline = engine.resourceCounts;
      const w = 512, h = 768;

      final viewports = <({LuminaWorld world, FilamentScene scene, FilamentView view, FilamentCamera camera,
          int cameraEntity, FilamentRenderer renderer, FilamentSwapChain swapChain, int sun, FilamentIndirectLight ibl})>[];
      final meshes = <List<LuminaStaticMeshComponent>>[];
      for (var i = 0; i < 2; i++) {
        final scene = engine.createScene();
        final view = engine.createView();
        final cameraEntity = engine.createEntity();
        final camera = engine.createCamera(cameraEntity);
        view
          ..scene = scene
          ..camera = camera
          ..setViewport(0, 0, w, h);
        camera.setProjection(fovDegrees: 45, aspect: w / h, near: 5, far: 20000, direction: FovDirection.vertical);
        final sun = engine.createEntity();
        LightBuilder(LightType.directional)
            .color(1.0, 0.98, 0.95)
            .intensity(100000)
            .direction(-0.4, -0.8, -0.6)
            .castShadows(true)
            .build(engine, sun);
        scene.addEntity(sun);
        final ibl = FilamentIndirectLight.build(engine,
            irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]), intensity: 35000);
        scene.setIndirectLight(ibl);
        final world = LuminaWorld(worldType: LuminaWorldType.editor)..initializeNativeContext(engine, scene, view: view);
        final placed = <LuminaStaticMeshComponent>[];
        for (var k = 0; k < usedAssets.length; k++) {
          final mesh = LuminaStaticMeshComponent(
            meshAssetPath: '$assetsDir/${usedAssets[k]}',
            location: Vector3((k - 0.5) * 90.0, 0, 0),
          );
          world.persistentLevel.registerActor(LuminaActor(root: mesh));
          placed.add(mesh);
        }
        for (final m in placed) {
          await m.loaded.timeout(const Duration(seconds: 90));
        }
        world.tick(1 / 60);
        meshes.add(placed);
        viewports.add((
          world: world,
          scene: scene,
          view: view,
          camera: camera,
          cameraEntity: cameraEntity,
          renderer: engine.createRenderer(),
          swapChain: engine.createHeadlessSwapChain(w, h),
          sun: sun,
          ibl: ibl,
        ));
        if (i == 0) {
          final afterFirst = engine.resourceCounts;
          expect((afterFirst - baseline).textures, greaterThanOrEqualTo(3), reason: 'the first world uploads the textures');
        }
      }
      expect(cache.uploadCount, usedAssets.length, reason: 'each mesh uploaded once for both worlds');
      expect(cache.entries.every((e) => e.handles == 2), isTrue, reason: '${cache.entries}');
      expect(FilamentEngineHost.liveEngineCount, 1);

      // Frame both meshes: the union of their bounds, as placed.
      var lo = Vector3.all(double.infinity), hi = Vector3.all(-double.infinity);
      for (final m in meshes.first) {
        final b = m.localBounds!;
        final at = m.relativeLocation;
        lo = Vector3(math.min(lo.x, b.min.x + at.x), math.min(lo.y, b.min.y + at.y), math.min(lo.z, b.min.z + at.z));
        hi = Vector3(math.max(hi.x, b.max.x + at.x), math.max(hi.y, b.max.y + at.y), math.max(hi.z, b.max.z + at.z));
      }
      final centre = (lo + hi) * 0.5;
      final radius = (hi - lo).length / 2;
      final orbit = radius * 2.4;

      final frames = (SmokeArtifacts.minimumVideoSeconds * 30).round();
      final recorder = SmokeVideoRecorder(width: w * 2, height: h, fps: 30, testName: testTitle);
      final nativeBuf = Uint8List(w * h * 4);
      final composite = Uint8List(w * 2 * h * 4);
      Uint8List? middle;
      try {
        for (var f = 0; f < frames; f++) {
          final t = f / frames;
          for (var i = 0; i < 2; i++) {
            final vp = viewports[i];
            final angle = 2 * math.pi * t + i * math.pi;
            vp.camera.lookAt(
              eyeX: centre.x + math.sin(angle) * orbit,
              eyeY: centre.y + radius * 0.8,
              eyeZ: centre.z + math.cos(angle) * orbit,
              centerX: centre.x,
              centerY: centre.y,
              centerZ: centre.z,
            );
            vp.world.tick(1 / 30);
            for (var attempt = 0; attempt < 50; attempt++) {
              if (vp.renderer.beginFrame(vp.swapChain)) {
                vp.renderer.render(vp.view);
                vp.renderer.readPixels(x: 0, y: 0, width: w, height: h, outPixels: nativeBuf);
                vp.renderer.endFrame();
                break;
              }
              engine.flushAndWait();
            }
            engine.flushAndWait();
            for (var y = 0; y < h; y++) {
              composite.setRange((y * w * 2 + i * w) * 4, (y * w * 2 + i * w + w) * 4, nativeBuf, y * w * 4);
            }
          }
          recorder.addFrame(composite);
          if (f == frames ~/ 2) middle = Uint8List.fromList(composite);
        }
        SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w * 2, h, middle!, flipY: false),
            usedAssets: usedAssets);
        SmokeArtifacts.saveVideo(testTitle, recorder.finish(), extension: 'webm', usedAssets: usedAssets);
      } finally {
        recorder.discard();
      }

      // Cleaning up one world keeps the meshes for the other; the second
      // releases them; nothing of either viewport is left.
      viewports[0].world.cleanup();
      expect(cache.liveAssetCount, usedAssets.length);
      viewports[1].world.cleanup();
      expect(cache.liveAssetCount, 0);
      for (final vp in viewports) {
        vp.scene.setIndirectLight(null);
        vp.ibl.dispose();
        vp.view.dispose();
        vp.scene.dispose();
        engine.destroyEntityComponents(vp.sun);
        engine.destroyEntity(vp.sun);
        vp.camera.dispose();
        engine.destroyEntity(vp.cameraEntity);
        vp.renderer.dispose();
        vp.swapChain.dispose();
      }
      final left = engine.resourceCounts - baseline;
      for (final (name, value) in [
        ('textures', left.textures),
        ('renderables', left.renderables),
        ('lights', left.lights),
        ('views', left.views),
        ('scenes', left.scenes),
        ('swapChains', left.swapChains),
      ]) {
        expect(value, 0, reason: '$name left behind: ${left.nonZero}');
      }
      lease.release();
      expect(engine.isDisposed, isTrue);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
