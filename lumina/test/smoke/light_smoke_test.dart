import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('Light Module Smoke Tests', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('Scenario 01: Directional sun, point light, and spot light illumination lifecycle with real 3D assets and shadow casting', () async {
      final assetsDir = SmokeArtifacts.testAssetsDir;
      final usedAssets = [
        'structures/excavator_cabins/excavator_cabin_a.glb',
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      // 1. Sun Directional Light
      final sunLight = LuminaDirectionalLightComponent(
        intensity: 120000.0,
        color: Vector3(1.0, 0.95, 0.9),
        castShadows: true,
        // 60° down in the drawn convention the light follows.
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 3.0),
      );
      final sunActor = LuminaActor(root: sunLight);
      world.persistentLevel.registerActor(sunActor);

      // 2. Point Light
      final pointLight = LuminaPointLightComponent(
        location: Vector3(5.0, 10.0, 5.0),
        intensity: 8000.0,
        color: Vector3(0.2, 0.8, 1.0),
        falloffRadius: 15.0,
      );
      final pointActor = LuminaActor(root: pointLight);
      world.persistentLevel.registerActor(pointActor);

      // 3. Spot Light
      final spotLight = LuminaSpotLightComponent(
        location: Vector3(0.0, 20.0, 0.0),
        intensity: 15000.0,
        color: Vector3(1.0, 0.6, 0.2),
        innerConeAngleDegrees: 25.0,
        outerConeAngleDegrees: 45.0,
        falloffRadius: 30.0,
      );
      final spotActor = LuminaActor(root: spotLight);
      world.persistentLevel.registerActor(spotActor);

      world.beginPlay();

      final lm = FilamentLightManager(engine);
      expect(sunLight.lightEntity, isNotNull);
      expect(pointLight.lightEntity, isNotNull);
      expect(spotLight.lightEntity, isNotNull);

      expect(lm.hasComponent(sunLight.lightEntity!), isTrue);
      expect(lm.hasComponent(pointLight.lightEntity!), isTrue);
      expect(lm.hasComponent(spotLight.lightEntity!), isTrue);

      // Run 3 world ticks with dynamic property mutations
      for (int i = 0; i < 3; i++) {
        pointLight.relativeLocation = Vector3(5.0 + i * 2.0, 10.0, 5.0 + i);
        spotLight.color = Vector3(1.0 - i * 0.1, 0.6 + i * 0.1, 0.2);
        world.tick(1.0 / 60.0);
      }

      // Assert transform updates pushed to FilamentLightManager
      final pos = lm.getPosition(pointLight.lightEntity!);
      expect(pos[0], closeTo(9.0, 1e-4));
      expect(pos[1], closeTo(10.0, 1e-4));
      expect(pos[2], closeTo(7.0, 1e-4));

      const testTitle = 'light_smoke_test: Scenario 01 Directional sun, point light, and spot light illumination lifecycle';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          // Camera slow cinematic pan around assets
          final camDist = 3.8;
          final camX = math.sin(timeSeconds * 0.3) * camDist;
          final camZ = math.cos(timeSeconds * 0.3) * camDist;

          cam.lookAt(
            eyeX: camX,
            eyeY: 1.8,
            eyeZ: camZ,
            centerX: 0.0,
            centerY: 0.6,
            centerZ: 0.0,
          );
        },
        engine: engine,
        autoDisposeEngine: false,
      );
    });
  });

  // The templates' sun, stored 50° down, must light the floor from
  // above. Rendered with only that light (no sky, no IBL), next to the same
  // scene lit along the old mirrored `forwardVector`.
  test('Scenario 02: the template sun lights the floor from above', () async {
    const w = 640, h = 360;
    Future<Uint8List> render({required bool oldDirection}) async {
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
      camera.setProjection(fovDegrees: 45, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
      camera.lookAt(eyeX: 0, eyeY: 500, eyeZ: 900, centerX: 0, centerY: 0, centerZ: 0);
      final pixels = calloc<ffi.Uint8>(w * h * 4);
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
      try {
        final stored = GameTemplateCatalog.thirdPerson.levelActors
            .firstWhere((a) => a['type'] == 'DirectionalLight')['rotation'] as List;
        final sun = LuminaDirectionalLightComponent(
          intensity: 100000,
          castShadows: true,
          rotation: LuminaAxes.rotation(stored.cast<num>()),
        );
        final floor = LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(3000, 0, 3000), color: Vector3(0.6, 0.6, 0.6));
        final crate = LuminaPrimitiveActor(
            shape: LuminaPrimitiveShape.box, size: Vector3.all(150), color: Vector3(0.7, 0.5, 0.3), location: Vector3(0, 75, 0));
        world.persistentLevel
          ..registerActor(floor)
          ..registerActor(crate);
        if (!oldDirection) world.persistentLevel.registerActor(LuminaActor(root: sun));
        world.beginPlay();
        await Future.wait([floor.meshComponent.loaded, crate.meshComponent.loaded]);
        if (oldDirection) {
          // What the component used before: the older
          // forwardVector, vector_math's Quaternion.rotate (the inverse of the
          // drawn rotation). `forwardVector` itself is the drawn −Z now.
          final d = sun.worldRotation.rotated(Vector3(0, 0, -1)).normalized();
          final e = engine.createEntity();
          LightBuilder(LightType.sun).intensity(100000).castShadows(true).direction(d.x, d.y, d.z).build(engine, e);
          scene.addEntity(e);
        }
        world.tick(1 / 60);
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
      } finally {
        world.cleanup();
        calloc.free(pixels);
        engine.dispose();
      }
    }

    // Mean luminance of the floor in front of the crate (bottom band).
    double floorLuma(Uint8List rgba) {
      var sum = 0.0;
      var n = 0;
      for (var y = 20; y < 70; y++) {
        for (var x = 120; x < 520; x++) {
          final i = (y * w + x) * 4;
          sum += 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
          n++;
        }
      }
      return sum / n;
    }

    final fixed = await render(oldDirection: false);
    final old = await render(oldDirection: true);
    SmokeArtifacts.saveScreenshot('light_smoke_test: Scenario 02 template sun from above', SmokeArtifacts.encodePng(w, h, fixed));
    SmokeArtifacts.saveScreenshot('light_smoke_test: Scenario 02 template sun from above 01 old mirrored direction', SmokeArtifacts.encodePng(w, h, old));
    final lit = floorLuma(fixed);
    final dark = floorLuma(old);
    // ignore: avoid_print
    print('MEASURE sun direction floor luma: fixed $lit, old mirrored $dark');
    expect(lit, greaterThan(40), reason: 'the floor faces the sun');
    expect(lit, greaterThan(dark * 3), reason: 'the old direction lit the floor from below: fixed $lit vs old $dark');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
