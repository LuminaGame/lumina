import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('Environment Module Smoke Tests', () {
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

    test('Scenario 01: LuminaSkyComponent ambient illumination, day-night cycle rotation, and derived sun with real 3D assets', () async {
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

      // 1. Sky Component (color mode with 3-band ambient SH)
      final shCoeffs = List<double>.filled(27, 0.0);
      shCoeffs[0] = 0.8;
      shCoeffs[1] = 0.9;
      shCoeffs[2] = 1.0;
      shCoeffs[5] = 1.5;

      final sky = LuminaSkyComponent.color(
        color: Vector4(0.2, 0.5, 0.9, 1.0),
        ambientSh: SphericalHarmonics(bands: 3, coefficients: shCoeffs),
        skyIntensity: 35000.0,
        iblIntensity: 30000.0,
      );
      final skyActor = LuminaActor(root: sky);
      world.persistentLevel.registerActor(skyActor);

      // 2. Static Mesh Component placed under the ambient sky
      final mesh = LuminaStaticMeshComponent(
        meshAssetPath: '${assetsDir.path}/structures/excavator_cabins/excavator_cabin_a.glb',
        location: Vector3(0.0, 0.0, 0.0),
      );
      final meshActor = LuminaActor(root: mesh);
      world.persistentLevel.registerActor(meshActor);

      world.beginPlay();

      expect(scene.skybox, isNotNull);
      expect(scene.indirectLight, isNotNull);

      // Derive matching sun from environment and spawn directional light
      final sunData = sky.deriveSunLight();
      expect(sunData.direction.length, closeTo(1.0, 1e-3));
      final sunLight = LuminaDirectionalLightComponent(
        intensity: sunData.intensity,
        color: sunData.color,
      );
      final sunActor = LuminaActor(root: sunLight);
      world.persistentLevel.registerActor(sunActor);

      // Run 3 frames simulating day-night rotation
      for (int i = 0; i < 3; i++) {
        sky.rotationDegrees = i * 45.0;
        sky.iblIntensity = 30000.0 - i * 5000.0;
        world.tick(1.0 / 60.0);
      }

      expect(scene.indirectLight!.rotation, isNotNull);

      const testTitle = 'environment_smoke_test: Scenario 01 LuminaSkyComponent ambient illumination and day-night cycle rotation';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
      );
    });

    test('Scenario 02: LuminaReflectionCaptureComponent probe capture, prefiltering, and dynamic IBL reflection swap with real 3D assets', () async {
      final probe = LuminaReflectionCaptureComponent(
        location: Vector3(0.0, 1.0, 0.0),
        resolution: 64,
        specularLevels: 4,
        captureOnRegister: false,
      );

      final probeActor = LuminaActor(root: probe);
      world.persistentLevel.registerActor(probeActor);
      world.beginPlay();

      await probe.capture();
      expect(probe.hasCapture, isTrue);
      expect(scene.indirectLight, isNotNull);

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/roof_aircon_unit_150x150_b.glb',
      ];

      const testTitle = 'environment_smoke_test: Scenario 02 LuminaReflectionCaptureComponent probe capture and dynamic IBL reflections';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
      );
    });

    test('Scenario 03: LuminaSkyBinding realises a level Environment actor as a real Skybox + IndirectLight on a world-free scene', () async {
      // The Lumina Studio viewports render a Filament scene without a
      // LuminaWorld, so they bind the level's sky through LuminaSkyBinding.
      final fallbackIbl = File('example/assets/ibl/default_env/default_env_ibl.ktx').readAsBytesSync();

      final binding = LuminaSkyBinding(engine: engine, scene: scene, fallbackIblKtx: fallbackIbl);
      addTearDown(binding.dispose);

      expect(scene.skybox, isNull);
      expect(scene.indirectLight, isNull);

      // The exact property map the Environment Lighting sub-editor writes onto
      // the `Environment` actor's LuminaSkyComponent.
      final description = LuminaSkyDescription.fromProperties(const {
        'mode': 'color',
        'colorHex': '#5C7FB8',
        'skyIntensity': 30000.0,
        'iblIntensity': 30000.0,
        'rotationDegrees': 0.0,
        'showSun': true,
      });
      binding.apply(description);

      expect(scene.skybox, isNotNull, reason: 'the Environment actor must produce a real skybox');
      expect(scene.indirectLight, isNotNull, reason: 'a colour sky still gets real image-based lighting');
      final skyPtr = scene.skybox!.nativePointer.address;
      final iblPtr = scene.indirectLight!.nativePointer.address;

      // Live edits from the Details panel: ambient intensity and rotation retune
      // the live IndirectLight in place, while colour retunes the skybox in place
      // and updates ambient lighting to match.
      binding.apply(description.copyWith(
        iblIntensity: 12000.0,
        rotationDegrees: 90.0,
      ));
      expect(scene.skybox!.nativePointer.address, skyPtr);
      expect(scene.indirectLight!.nativePointer.address, iblPtr);

      binding.apply(description.copyWith(
        color: LuminaSkyDescription.colorFromHex('#B85C5C'),
        iblIntensity: 12000.0,
        rotationDegrees: 90.0,
      ));
      expect(scene.skybox!.nativePointer.address, skyPtr, reason: 'Skybox retunes in-place via setColor');
      expect(scene.indirectLight, isNotNull, reason: 'IndirectLight updated with matching colour');

      // Hiding the sky keeps the ambient light so meshes never go black.
      binding.apply(description.copyWith(skyVisible: false));
      expect(scene.skybox, isNull);
      expect(scene.indirectLight, isNotNull);

      binding.apply(description);
      expect(scene.skybox, isNotNull);

      final usedAssets = [
        'Props/AC_units/roof_aircon_unit_150x150_a.glb',
        'Props/Barrels/fuel_barrel_red.glb',
        'structures/excavator_cabins/excavator_cabin_a.glb',
      ];
      const testTitle = 'environment_smoke_test: Scenario 03 LuminaSkyBinding realises the Environment actor as a real Skybox and IndirectLight';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
      );

      binding.dispose();
      expect(scene.skybox, isNull);
      expect(scene.indirectLight, isNull);
    });

    test('Scenario 04: LuminaProceduralSkyComponent renders a real atmospheric sky, clouds and ocean across a day cycle', () async {
      // The Procedural Sky & Ocean, rendered headlessly through a real swap
      // chain so the evidence is actual GPU pixels, not a simulated frame.
      const width = SmokeVideo.defaultWidth;
      const height = SmokeVideo.defaultHeight;
      final swapChain = engine.createHeadlessSwapChain(width, height);
      final renderer = engine.createRenderer();
      final view = engine.createView();
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, width, height);
      view.postProcessingEnabled = true;
      // Centimetres, like the world: eye 1.5 m above the water, 4 m back.
      camera.setProjection(fovDegrees: 45, aspect: width / height, near: 10, far: 200000);
      void aim(double yawDegrees) {
        final yaw = yawDegrees * math.pi / 180.0;
        camera.lookAt(
          eyeX: 0,
          eyeY: 150,
          eyeZ: 400,
          centerX: -400 * math.sin(yaw),
          centerY: 100,
          centerZ: 400 - 400 * math.cos(yaw),
        );
      }

      aim(0);
      camera.setExposure(aperture: 16.0, shutterSpeed: 1.0 / 125.0, sensitivity: 100.0);

      final assetsDir = SmokeArtifacts.testAssetsDir;
      final usedAssets = [
        'Props/Barrels/fuel_barrel_red.glb',
        'Props/AC_units/roof_aircon_unit_150x150_a.glb',
      ];

      final sky = LuminaProceduralSkyComponent(
        timeOfDay: 12.0,
        turbidity: 2.5,
        cloudCoverage: 0.55,
        waterStrength: 40.0,
        assetProvider: (key) async => File('assets/sky/${key.split('/').last}').readAsBytes(),
        loadNightSkyTextures: false,
      );
      world.persistentLevel.registerActor(LuminaActor(root: sky));

      // Real props standing in front of the procedural sky.
      final props = <LuminaStaticMeshComponent>[];
      for (final (i, relative) in usedAssets.indexed) {
        final f = File('${assetsDir.path}/$relative');
        if (!f.existsSync()) continue;
        final prop = LuminaStaticMeshComponent(
          meshAssetPath: f.path,
          location: Vector3(i * 150.0 - 75.0, 0.0, 0.0),
        );
        props.add(prop);
        world.persistentLevel.registerActor(LuminaActor(root: prop));
      }

      world.beginPlay();
      await sky.loaded;
      expect(sky.isLoaded, isTrue);
      expect(sky.skyEntity, isNotNull);
      // The render loop below never yields, so the props must be in the scene first.
      await Future.wait(props.map((p) => p.loaded));
      expect(props, hasLength(usedAssets.length));

      // A procedural sky lights nothing: a sun and sky light that follow it
      // light the props, fading out as the sun sets.
      final sunEntity = engine.createEntity();
      LightBuilder(LightType.directional)
          .color(1.0, 0.96, 0.9)
          .intensity(100000.0)
          .direction(0.0, -1.0, 0.0)
          .castShadows(true)
          .build(engine, sunEntity);
      scene.addEntity(sunEntity);
      final skyLight = FilamentIndirectLight.build(
        engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
        intensity: 30000.0,
      );
      scene.setIndirectLight(skyLight);
      final lights = FilamentLightManager(engine);
      void followSun() {
        final d = sky.sunDirection;
        final daylight = math.sqrt(math.max(0.0, d[1]));
        lights.setDirection(sunEntity, -d[0], -d[1], -d[2]);
        lights.setIntensity(sunEntity, 100000.0 * daylight);
        skyLight.setIntensity(1500.0 + 28500.0 * daylight);
      }

      const testTitle = 'environment_smoke_test: Scenario 04 LuminaProceduralSkyComponent atmospheric sky clouds and ocean across a day cycle';
      // Sweep noon -> dusk -> night continuously: 300 frames at 30 fps, the
      // camera panning slowly across the props (>= 10 s, real frames).
      const steps = 300;
      final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: testTitle);
      addTearDown(video.discard);
      Uint8List? firstFrame;
      final skyLuma = <double>[];
      final pixels = Uint8List(width * height * 4);
      for (var step = 0; step < steps; step++) {
        sky.timeOfDay = 12.0 + 12.0 * step / steps;
        aim(-15.0 + 30.0 * step / (steps - 1));
        followSun();
        world.tick(1 / 30);
        var rendered = 0;
        for (var attempt = 0; attempt < 60 && rendered < 2; attempt++) {
          if (renderer.beginFrame(swapChain)) {
            rendered++;
            renderer.render(view);
            if (rendered == 2) {
              renderer.readPixels(x: 0, y: 0, width: width, height: height, outPixels: pixels);
            }
            renderer.endFrame();
          }
        }
        engine.flushAndWait();
        video.addFrame(pixels);
        firstFrame ??= Uint8List.fromList(pixels);
        // Upper band of the frame is pure sky.
        var sum = 0.0;
        var n = 0;
        for (var y = 0; y < height ~/ 4; y++) {
          for (var x = 0; x < width; x++) {
            final i = (y * width + x) * 4;
            sum += 0.2126 * pixels[i] + 0.7152 * pixels[i + 1] + 0.0722 * pixels[i + 2];
            n++;
          }
        }
        skyLuma.add(sum / n);
      }

      // ignore: avoid_print
      print('procedural sky luminance 12:00..24:00 (every 20th frame) = '
          '${[for (var i = 0; i < skyLuma.length; i += 20) skyLuma[i]].map((v) => v.toStringAsFixed(1)).join(', ')}');

      // A real atmosphere: bright at noon, dark after sunset.
      expect(skyLuma.first, greaterThan(40.0), reason: 'the midday sky must be bright');
      expect(skyLuma.last, lessThan(skyLuma.first * 0.6),
          reason: 'the sky must actually darken as the sun sets');

      SmokeArtifacts.saveScreenshot(
        testTitle,
        SmokeArtifacts.encodePng(width, height, firstFrame!),
        usedAssets: usedAssets,
      );
      SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);

      scene.setIndirectLight(null);
      skyLight.dispose();
      scene.removeEntity(sunEntity);
      engine.destroyEntity(sunEntity);
      view.dispose();
      renderer.dispose();
      swapChain.dispose();
      engine.destroyEntity(cameraEntity);
    });

    // The Exponential Height Fog component drives the
    // view's fog through the world's blender: density scrubbed 0 → 0.08 while
    // the camera orbits real props; the far prop fades toward the fog colour.
    test('Scenario 04: LuminaExponentialHeightFogComponent scrubs Filament\'s height fog over real props', () async {
      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'structures/Concrete_slabs/concrete_slabs_3x3.glb',
      ];
      LuminaWorld? fogWorld;
      LuminaExponentialHeightFogComponent? fog;
      final densities = <double>[];
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: 'environment_smoke_test: Scenario 04 LuminaExponentialHeightFogComponent height fog density scrub',
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
        onFrame: (engine, mediaScene, view, camera, assets, frame, total, t) {
          if (fogWorld == null) {
            fogWorld = LuminaWorld(worldType: LuminaWorldType.game)
              ..initializeNativeContext(engine, mediaScene)
              ..attachPostProcessView(view);
            fog = LuminaExponentialHeightFogComponent(
              location: Vector3(0, 0, 0),
              fogDensity: 0.0,
              fogHeightFalloff: 0.5,
              inscatteringColor: Vector3(0.75, 0.8, 0.9),
            );
            fogWorld!.persistentLevel.registerActor(LuminaActor(root: fog!));
            fogWorld!.beginPlay();
          }
          fog!.fogDensity = 0.08 * (frame / (total - 1));
          fogWorld!.tick(1 / 30);
          densities.add(fogWorld!.postProcess.applied.fog.density);
        },
      );
      expect(densities.first, 0.0);
      expect(densities.last, closeTo(0.08 / LuminaUnits.unitsPerMetre, 1e-9), reason: 'per metre → per cm on the view');
      expect(fogWorld!.postProcess.applied.fog.enabled, isTrue);
      fogWorld!.cleanup();
    });

    // The Local Fog Volume's shell is visible from outside,
    // and the global fog scales while the camera is inside, restored outside.
    // The world is built and the shell's GLB awaited in `onSetup`
    // (the frame loop never yields, so an async load cannot finish inside
    // it), the scenario aims the camera itself (the helper's orbit only runs
    // without an `onFrame`), and "inside" is where the camera really is.
    test('Scenario 05: LuminaLocalFogVolumeComponent fog shell + camera-inside global fog scaling', () async {
      final usedAssets = [
        'Props/Banana Bunch/banana_bunch_medium.glb',
        'Props/Access_cards/access_card_blue.glb',
      ];
      final centre = Vector3(0, LuminaUnits.metres(0.6), 0);
      final radius = LuminaUnits.metres(1.2);
      late LuminaWorld fogWorld;
      late LuminaLocalFogVolumeComponent volume;
      final scales = <double>[];
      final inside = <bool>[];
      final beyondBlend = <bool>[];
      var shellLoadedWhileFilming = false;
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: 'environment_smoke_test: Scenario 05 LuminaLocalFogVolumeComponent fog shell approximation',
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
        onSetup: (engine, mediaScene, view, camera, assets) async {
          fogWorld = LuminaWorld(worldType: LuminaWorldType.game)
            ..initializeNativeContext(engine, mediaScene)
            ..attachPostProcessView(view);
          // Baseline fog so the inside scale has something to multiply.
          fogWorld.postProcess.apply(LuminaPostProcessSettings.standard().copyWith(
            fog: LuminaPostProcessSettings.standard().fog.copyWith(enabled: true, density: 0.0005),
          ));
          volume = LuminaLocalFogVolumeComponent(
            location: centre.clone(),
            radius: radius,
            fogDensity: 0.5,
            fogAlbedo: Vector3(0.85, 0.9, 1.0),
          );
          fogWorld.persistentLevel.registerActor(LuminaActor(root: volume));
          fogWorld.beginPlay();
          await volume.shell!.loaded.timeout(const Duration(seconds: 60));
        },
        onFrame: (engine, mediaScene, view, camera, assets, frame, total, t) {
          // Five seconds orbiting at 3.5 m (outside the 1.2 m sphere), one
          // diving to its centre, four looking around from inside it.
          final angle = t * 0.6;
          final distance = t < 5.0 ? LuminaUnits.metres(3.5) : LuminaUnits.metres(3.5) * (1.0 - ((t - 5.0) / 1.0).clamp(0.0, 1.0));
          final eye = centre + Vector3(math.sin(angle), 0.12, math.cos(angle)) * distance;
          final look = distance > 1.0 ? centre : centre - Vector3(math.sin(angle), 0.0, math.cos(angle)) * LuminaUnits.metres(1.0);
          camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: look.x, centerY: look.y, centerZ: look.z);
          fogWorld.postProcessBlender.cameraPositionOverride = eye;
          fogWorld.tick(1 / 30);
          scales.add(fogWorld.postProcess.applied.fog.density / 0.0005);
          inside.add((eye - centre).length < radius);
          // The volume blends in over half its radius outside (its Blend Radius).
          beyondBlend.add((eye - centre).length > radius * 1.5);
          shellLoadedWhileFilming = volume.shell?.isLoaded ?? false;
        },
        onTeardown: () => fogWorld.cleanup(),
      );
      final outsideScales = [for (var i = 0; i < scales.length; i++) if (beyondBlend[i]) scales[i]];
      final insideScales = [for (var i = 0; i < scales.length; i++) if (inside[i]) scales[i]];
      expect(outsideScales, isNotEmpty);
      expect(insideScales, isNotEmpty);
      expect(outsideScales.every((s) => (s - 1.0).abs() < 1e-6), isTrue, reason: 'outside, beyond the blend radius: baseline fog ${outsideScales.toSet()}');
      expect(insideScales.last, closeTo(1 + LuminaLocalFogVolumeComponent.densityScalePerUnit * 0.5, 1e-6),
          reason: 'inside, at the centre: scaled by the volume');
      expect(shellLoadedWhileFilming, isTrue, reason: 'the fog shell renderable is in the scene while filming');
    });
  });
}
