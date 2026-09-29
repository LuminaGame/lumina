import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3, Vector4;

/// Sculpts a real terrain: a diagonal ridge, a crater and fractal noise, all
/// written into the payload's own heightmap (no procedural shortcut at draw
/// time — the mesh is built from these samples).
LandscapeData _sculpt({int resolution = 257, double worldSize = 512.0, double maxHeight = 120.0}) {
  final data = LandscapeData.flat(gridResolution: resolution, worldSize: worldSize, maxHeight: maxHeight);
  final half = (resolution - 1) / 2.0;
  final rng = math.Random(20260920);
  final octave = List<double>.generate(64 * 64, (_) => rng.nextDouble());
  double noise(double u, double v) {
    final x = ((u * 0.5 + 0.5) * 63).clamp(0.0, 62.0);
    final y = ((v * 0.5 + 0.5) * 63).clamp(0.0, 62.0);
    final x0 = x.floor(), y0 = y.floor();
    final tx = x - x0, ty = y - y0;
    final a = octave[y0 * 64 + x0] + (octave[y0 * 64 + x0 + 1] - octave[y0 * 64 + x0]) * tx;
    final b = octave[(y0 + 1) * 64 + x0] + (octave[(y0 + 1) * 64 + x0 + 1] - octave[(y0 + 1) * 64 + x0]) * tx;
    return a + (b - a) * ty;
  }

  for (var r = 0; r < resolution; r++) {
    for (var c = 0; c < resolution; c++) {
      final u = (c - half) / half;
      final v = (r - half) / half;
      final ridge = math.exp(-((u - v) * (u - v)) * 5.0) * 55.0;
      final crater = -math.exp(-(((u - 0.45) * (u - 0.45) + (v + 0.4) * (v + 0.4)) * 22.0)) * 28.0;
      final grain = (noise(u, v) - 0.5) * 14.0;
      data.setHeight(c, r, (30.0 + ridge + crater + grain).clamp(0.0, maxHeight));
    }
  }
  return data;
}

/// A ridge along X — a 14 m Gaussian crest with flat ground either side — so
/// a low sun from −Z lights one flank and throws the ridge's shadow across the
/// other side.
LandscapeData _ridgeTerrain({double crestHeight = 14.0, double crestSigma = 7.0}) {
  final data = LandscapeData.flat(gridResolution: 129, worldSize: 128.0, maxHeight: 60.0);
  for (var r = 0; r < 129; r++) {
    final z = data.worldZOf(r);
    for (var c = 0; c < 129; c++) {
      final x = data.worldXOf(c);
      final crest = crestHeight * math.exp(-(z * z) / (2 * crestSigma * crestSigma));
      final swell = 1.2 * math.sin(x * 0.11) * math.cos(z * 0.07);
      data.setHeight(c, r, 3.0 + crest + swell);
    }
  }
  return data;
}

/// A live, lit landscape world on GPU 1: sky + a low shadow-casting sun, the
/// ridge terrain and a layer of real barrels, in a centimetre world.
class _LitLandscapeScene {
  static const u = LuminaUnits.unitsPerMetre;
  final int width = SmokeVideo.defaultWidth;
  final int height = SmokeVideo.defaultHeight;
  late final FilamentEngine engine;
  late final FilamentScene scene;
  late final FilamentView view;
  late final int cameraEntity;
  late final FilamentCamera camera;
  late final FilamentRenderer renderer;
  late final FilamentSwapChain swapChain;
  late final LuminaWorld world;
  late final LuminaCollisionSubsystem collision;
  late final LuminaLandscapeComponent landscape;
  late final LandscapeData data;
  late final Uint8List pixels;


  Future<void> build(String barrelPath, {LandscapeData? terrain}) async {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    view = engine.createView();
    cameraEntity = engine.createEntity();
    camera = engine.createCamera(cameraEntity);
    renderer = engine.createRenderer();
    swapChain = engine.createHeadlessSwapChain(width, height);
    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, width, height);
    camera.setProjection(fovDegrees: 50.0, aspect: width / height, near: 10.0, far: 100000.0, direction: FovDirection.vertical);
    pixels = Uint8List(width * height * 4);

    world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene, view: view);
    // As PIE and a generated game build their world: with collision.
    collision = world.registerSubsystem(LuminaCollisionSubsystem());
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaSkyComponent.color(color: Vector4(0.45, 0.6, 0.8, 1.0), skyIntensity: 30000.0, iblIntensity: 12000.0),
    ));
    // A low sun (≈ 22° elevation) from −Z, shining along +Z across the ridge.
    final sunDir = Vector3(0.35, -0.42, 1.0)..normalize();
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(
        rotation: Quaternion.fromTwoVectors(Vector3(0, 0, -1), sunDir),
        color: Vector3(1.0, 0.96, 0.9),
        intensity: 110000.0,
        castShadows: true,
        isSun: true,
      ),
    ));

    data = terrain ?? _ridgeTerrain();
    final layer = FoliageLayer(meshAssetId: 'fuel_barrel_red', meshAssetPath: barrelPath, name: 'Barrels');
    final rng = math.Random(99);
    // Barrels on the sunlit flat (their shadows fall towards +Z) and in the
    // ridge's shadow beyond the crest.
    for (final (zMin, zMax, n) in const [(-34.0, -18.0, 26), (14.0, 26.0, 14)]) {
      for (var i = 0; i < n; i++) {
        final x = -40.0 + rng.nextDouble() * 80.0;
        final z = zMin + rng.nextDouble() * (zMax - zMin);
        final nrm = data.sampleNormal(x, z);
        layer.addInstance(FoliageInstance(
          x: x,
          y: data.sampleHeight(x, z),
          z: z,
          scaleX: 2.2,
          scaleY: 2.2,
          scaleZ: 2.2,
          yaw: rng.nextDouble() * math.pi * 2,
          nx: nrm.x,
          ny: nrm.y,
          nz: nrm.z,
        ));
      }
    }
    data.layers.add(layer);
    landscape = LuminaLandscapeComponent(data: data);
    world.persistentLevel.registerActor(LuminaActor(root: landscape));
    await landscape.ensureBuilt();
    world.beginPlay();
    world.tick(1 / 30);
  }

  void look(double eyeX, double eyeY, double eyeZ, {double targetY = 6.0}) => camera.lookAt(
        eyeX: eyeX * u,
        eyeY: eyeY * u,
        eyeZ: eyeZ * u,
        centerX: 0.0,
        centerY: targetY * u,
        centerZ: 0.0,
      );

  /// Renders one frame into [pixels] (and returns a copy).
  /// [tick] advances the world 1/30 s first; a scenario that ticks the world
  /// itself passes false.
  Uint8List render({bool tick = true}) {
    if (tick) world.tick(1 / 30);
    if (renderer.beginFrame(swapChain)) {
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: width, height: height, outPixels: pixels);
      renderer.endFrame();
    }
    engine.flushAndWait();
    return Uint8List.fromList(pixels);
  }

  /// Sets the cast-shadow flag of every terrain tile and/or foliage chunk.
  void castShadows({required bool terrain, required bool foliage}) {
    final rm = FilamentRenderableManager(engine);
    final mesh = landscape.terrainMesh!;
    for (var i = 0; i < landscape.totalSectionCount; i++) {
      if (mesh.hasSection(i)) rm.setCastShadows(mesh.sectionEntity(i), terrain);
    }
    for (final chunk in landscape.foliageChunksOf(0)) {
      rm.setCastShadows(chunk.entity, foliage);
    }
  }

  void dispose() {
    world.cleanup();
    view.dispose();
    scene.dispose();
    engine.destroyEntity(cameraEntity);
    camera.dispose();
    renderer.dispose();
    swapChain.dispose();
    engine.dispose();
  }
}

/// Pixels that are at least [delta] darker (luma, 0–255) in [a] than in [b].
int _darkerPixels(Uint8List a, Uint8List b, {int delta = 18}) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    final la = 0.2126 * a[i] + 0.7152 * a[i + 1] + 0.0722 * a[i + 2];
    final lb = 0.2126 * b[i] + 0.7152 * b[i + 1] + 0.0722 * b[i + 2];
    if (lb - la >= delta) n++;
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Landscape Module Smoke Tests', () {
    test(
      'Scenario 01: LuminaLandscapeComponent renders a sculpted 257² heightmap as tiled procedural mesh sections with real instanced foliage in a live Filament world',
      () async {
        const testTitle =
            'Landscape Module Smoke Tests Scenario 01: LuminaLandscapeComponent renders a sculpted 257² heightmap as tiled procedural mesh sections with real instanced foliage in a live Filament world';
        const width = SmokeVideo.defaultWidth;
        const height = SmokeVideo.defaultHeight;
        const fps = 30; // smoke videos play at least 30 real frames per second
        const durationSeconds = 10.0;

        final usedAssets = <String>[
          'Props/Banana Bunch/banana_bunch_medium.glb',
          'Props/Barrels/dented_barrel.glb',
        ];
        final assetsDir = SmokeArtifacts.testAssetsDir;
        final foliageMeshPath = '${assetsDir.path}/${usedAssets[0]}';
        final propMeshPath = '${assetsDir.path}/${usedAssets[1]}';
        expect(File(foliageMeshPath).existsSync(), isTrue, reason: 'real foliage asset required: $foliageMeshPath');

        // --- Author the terrain, exactly as the Landscape sub-editor saves it.
        final data = _sculpt();
        final rng = math.Random(4242);
        for (final entry in [
          (path: foliageMeshPath, id: 'banana_bunch_medium', name: 'Shrubs', count: 220),
          (path: propMeshPath, id: 'dented_barrel', name: 'Debris', count: 90),
        ]) {
          if (!File(entry.path).existsSync()) continue;
          final layer = FoliageLayer(meshAssetId: entry.id, meshAssetPath: entry.path, name: entry.name);
          var placed = 0;
          var attempts = 0;
          while (placed < entry.count && attempts < entry.count * 40) {
            attempts++;
            final x = (rng.nextDouble() * 2 - 1) * (data.worldSize / 2 - 4);
            final z = (rng.nextDouble() * 2 - 1) * (data.worldSize / 2 - 4);
            if (data.sampleSlopeDegrees(x, z) > 32.0) continue;
            final n = data.sampleNormal(x, z);
            // These test-asset GLBs are metre-authored (a banana bunch is
            // 1.2 m tall, a barrel 1.15 m), so a 6–14x instance scale gives
            // tree-sized foliage readable on a 512 m terrain.
            final s = 6.0 + rng.nextDouble() * 8.0;
            layer.addInstance(FoliageInstance(
              x: x,
              y: data.sampleHeight(x, z),
              z: z,
              scaleX: s,
              scaleY: s,
              scaleZ: s,
              yaw: rng.nextDouble() * math.pi * 2,
              nx: n.x,
              ny: n.y,
              nz: n.z,
            ));
            placed++;
          }
          data.layers.add(layer);
        }

        // Persist it as a real `LANDSCAPE` .lmas and load the component from
        // that file — the exact path a placed level actor takes.
        final tempDir = Directory.systemTemp.createTempSync('lumina_landscape_smoke_');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });
        final lmas = File('${tempDir.path}/SmokeTerrain.lmas');
        final asset = LuminaAsset(
          assetId: 'landscape_SmokeTerrain',
          name: 'SmokeTerrain',
          type: AssetType.landscape,
          rawPayload: data.toBytes(),
          references: [
            for (var i = 0; i < data.layers.length; i++)
              AssetReference(
                slotName: 'foliage_$i',
                assetId: data.layers[i].meshAssetId,
                assetPath: data.layers[i].meshAssetPath,
              ),
          ],
        );
        lmas.writeAsBytesSync(asset.toProtoBufferBytes());

        // --- A live Filament world on GPU 1.
        final engine = FilamentEngine.create();
        expect(engine, isNotNull, reason: 'a real Filament engine is required for the landscape smoke run');
        final scene = engine!.createScene();
        final view = engine.createView();
        final cameraEntity = engine.createEntity();
        final camera = engine.createCamera(cameraEntity);
        final renderer = engine.createRenderer();
        final swapChain = engine.createHeadlessSwapChain(width, height);
        view.scene = scene;
        view.camera = camera;
        view.setViewport(0, 0, width, height);
        // The component's world is centimetres: the camera is too.
        const u = LuminaUnits.unitsPerMetre;
        camera.setProjection(
          fovDegrees: 55.0,
          aspect: width / height,
          near: 1.0 * u,
          far: 3000.0 * u,
          direction: FovDirection.vertical,
        );

        final world = LuminaWorld(worldType: LuminaWorldType.game);
        world.initializeNativeContext(engine, scene);

        world.persistentLevel.registerActor(LuminaActor(
          root: LuminaSkyComponent.color(
            color: Vector4(0.44, 0.58, 0.76, 1.0),
            skyIntensity: 32000.0,
            iblIntensity: 32000.0,
          ),
        ));
        world.persistentLevel.registerActor(LuminaActor(
          root: LuminaDirectionalLightComponent(
            color: Vector3(1.0, 0.97, 0.90),
            intensity: 110000.0,
            castShadows: true,
            isSun: true,
          ),
        ));

        final sw = Stopwatch()..start();
        final landscape = LuminaLandscapeComponent(assetPath: lmas.path);
        world.persistentLevel.registerActor(LuminaActor(root: landscape));
        await landscape.ensureBuilt();
        sw.stop();
        world.beginPlay();
        world.tick(1 / 60);

        expect(landscape.loadError, isNull, reason: landscape.loadError ?? '');
        expect(landscape.sectionCount, 16, reason: '257² at 64 quads per tile is a 4×4 tile grid');
        expect(landscape.foliageChunkCount, greaterThan(0), reason: landscape.foliageError ?? 'foliage must mount');
        expect(scene.renderableCount, greaterThanOrEqualTo(landscape.sectionCount + landscape.foliageChunkCount));

        final totalInstances = List.generate(data.layers.length, landscape.foliageInstanceCount)
            .fold<int>(0, (s, c) => s + c);
        // ignore: avoid_print
        print('[landscape smoke] grid=${data.gridResolution}² tiles=${landscape.sectionCount} '
            'foliageInstances=$totalInstances foliageRenderables=${landscape.foliageChunkCount} '
            'payloadBytes=${lmas.lengthSync()} buildMs=${sw.elapsedMilliseconds}');

        // --- Render a real fly-over.
        final totalFrames = (durationSeconds * fps).round();
        final video = SmokeVideoRecorder(
          width: width,
          height: height,
          fps: fps,
          testName: testTitle,
        );
        addTearDown(video.discard);
        final pixels = Uint8List(width * height * 4);
        Uint8List? first;
        Uint8List? middle;
        final frameTimes = <int>[];
        for (var frame = 0; frame < totalFrames; frame++) {
          final t = frame / totalFrames;
          final angle = t * math.pi * 2.0;
          final radius = 180.0 + math.sin(t * math.pi * 2.0) * 60.0;
          final eyeX = math.sin(angle) * radius;
          final eyeZ = math.cos(angle) * radius;
          final eyeY = 70.0 + math.sin(t * math.pi * 4.0) * 25.0;
          camera.lookAt(
            eyeX: eyeX * u,
            eyeY: eyeY * u,
            eyeZ: eyeZ * u,
            centerX: 0.0,
            centerY: 35.0 * u,
            centerZ: 0.0,
          );
          world.tick(1.0 / fps);

          final frameWatch = Stopwatch()..start();
          if (renderer.beginFrame(swapChain)) {
            renderer.render(view);
            renderer.readPixels(x: 0, y: 0, width: width, height: height, outPixels: pixels);
            renderer.endFrame();
          }
          engine.flushAndWait();
          frameWatch.stop();
          frameTimes.add(frameWatch.elapsedMicroseconds);

          video.addFrame(pixels);
          if (frame == 0) first = Uint8List.fromList(pixels);
          if (frame == totalFrames ~/ 2) middle = Uint8List.fromList(pixels);
        }

        // The rendered image must not be a flat background.
        final shot = middle ?? first!;
        final distinct = <int>{};
        for (var i = 0; i < shot.length; i += 4 * 97) {
          distinct.add((shot[i] << 16) | (shot[i + 1] << 8) | shot[i + 2]);
        }
        expect(distinct.length, greaterThan(8),
            reason: 'the captured frame must show real terrain, not an empty sky');

        frameTimes.sort();
        // ignore: avoid_print
        print('[landscape smoke] frames=$totalFrames medianFrameMs='
            '${(frameTimes[frameTimes.length ~/ 2] / 1000.0).toStringAsFixed(2)} '
            'maxFrameMs=${(frameTimes.last / 1000.0).toStringAsFixed(2)}');

        SmokeArtifacts.saveScreenshot(
          testTitle,
          SmokeArtifacts.encodePng(width, height, shot, flipY: false),
          usedAssets: usedAssets,
        );
        SmokeArtifacts.saveVideo(
          testTitle,
          video.finish(),
          extension: 'webm',
          usedAssets: usedAssets,
        );

        world.cleanup();
        view.dispose();
        scene.dispose();
        engine.destroyEntity(cameraEntity);
        camera.dispose();
        renderer.dispose();
        swapChain.dispose();
        engine.dispose();
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );


    test(
      'Scenario 02: a lit, sculpted terrain in a cm world casts sun shadows, and its foliage casts shadows onto it',
      () async {
        const testTitle =
            'Landscape Module Smoke Tests Scenario 02: a lit, sculpted terrain in a cm world casts sun shadows, and its foliage casts shadows onto it';
        const usedAssets = ['Props/Barrels/fuel_barrel_red.glb'];
        final barrel = '${SmokeArtifacts.testAssetsDir.path}/${usedAssets[0]}';
        expect(File(barrel).existsSync(), isTrue, reason: 'real barrel asset required: $barrel');

        final lit = _LitLandscapeScene();
        await lit.build(barrel);
        addTearDown(lit.dispose);
        expect(lit.landscape.foliageError, isNull, reason: lit.landscape.foliageError ?? '');
        expect(lit.landscape.foliageInstanceCount(0), 40);

        // A/B: each shadowed frame must be darker than the same frame with
        // that caster switched off. The ridge's shadow lies on its far side
        // (the sun shines along +Z), so that pose looks back towards the sun;
        // the sunlit barrels are seen from the sun's side.
        lit.look(30.0, 26.0, 75.0, targetY: 4.0);
        lit.render();
        final ridgeLit = lit.render();
        lit.castShadows(terrain: false, foliage: true);
        lit.render();
        final noTerrainShadow = lit.render();
        lit.castShadows(terrain: true, foliage: true);

        lit.look(-38.0, 22.0, -70.0);
        lit.render();
        final withShadows = lit.render();
        lit.castShadows(terrain: true, foliage: false);
        lit.render();
        final noFoliageShadow = lit.render();
        lit.castShadows(terrain: true, foliage: true);

        final total = lit.width * lit.height;
        final ridgeShadow = _darkerPixels(ridgeLit, noTerrainShadow);
        final barrelShadows = _darkerPixels(withShadows, noFoliageShadow);
        // ignore: avoid_print
        print('[landscape smoke 02] ridge-shadow pixels=$ridgeShadow (${(100 * ridgeShadow / total).toStringAsFixed(1)}%) '
            'barrel-shadow pixels=$barrelShadows (${(100 * barrelShadows / total).toStringAsFixed(2)}%)');
        expect(ridgeShadow, greaterThan(total ~/ 50), reason: 'the ridge must throw a visible shadow across the terrain');
        expect(barrelShadows, greaterThan(total ~/ 1000), reason: 'the barrels must throw visible shadows on the ground');

        // The evidence: a 10.5 s orbit at 30 fps.
        const fps = 30;
        const frames = 315;
        final video = SmokeVideoRecorder(width: lit.width, height: lit.height, fps: fps, testName: testTitle);
        addTearDown(video.discard);
        Uint8List? still;
        for (var f = 0; f < frames; f++) {
          final t = f / frames;
          final a = -2.2 + t * 1.6;
          lit.look(math.sin(a) * 75.0, 20.0 + math.sin(t * math.pi) * 8.0, math.cos(a) * 75.0);
          video.addFrame(lit.render());
          if (f == frames ~/ 3) still = Uint8List.fromList(lit.pixels);
        }
        SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(lit.width, lit.height, withShadows, flipY: false), usedAssets: usedAssets);
        SmokeArtifacts.saveScreenshot('$testTitle (ridge shadow)', SmokeArtifacts.encodePng(lit.width, lit.height, ridgeLit, flipY: false), usedAssets: usedAssets);
        SmokeArtifacts.saveScreenshot('$testTitle (orbit)', SmokeArtifacts.encodePng(lit.width, lit.height, still!, flipY: false), usedAssets: usedAssets);
        SmokeArtifacts.saveVideo(testTitle, video.finish(), extension: 'webm', usedAssets: usedAssets);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'Scenario 03: a brush cursor draped on a lit terrain follows a path across a ridge',
      () async {
        const testTitle =
            'Landscape Module Smoke Tests Scenario 03: a brush cursor draped on a lit terrain follows a path across a ridge';
        const usedAssets = ['Props/Barrels/fuel_barrel_red.glb'];
        final barrel = '${SmokeArtifacts.testAssetsDir.path}/${usedAssets[0]}';
        final lit = _LitLandscapeScene();
        await lit.build(barrel);
        addTearDown(lit.dispose);
        const u = LuminaUnits.unitsPerMetre;

        // A/B at one pose: the cursor's pixels are the amber ones it adds.
        lit.look(-30.0, 38.0, -62.0, targetY: 4.0);
        final amber = Vector3(1.0, 0.62, 0.1);
        lit.landscape.showBrushCursor(LandscapeBrushCursor(centerX: -6 * u, centerZ: -4 * u, radius: 12 * u, falloff: 0.5, color: amber));
        lit.render();
        final shown = lit.render();
        lit.landscape.hideBrushCursor();
        lit.render();
        final hidden = lit.render();
        var changed = 0;
        var warm = 0;
        for (var i = 0; i < shown.length; i += 4) {
          final d = (shown[i] - hidden[i]).abs() + (shown[i + 1] - hidden[i + 1]).abs() + (shown[i + 2] - hidden[i + 2]).abs();
          if (d > 24) {
            changed++;
            if (shown[i] > shown[i + 2] + 30) warm++;
          }
        }
        // ignore: avoid_print
        print('[landscape smoke 03] cursor pixels=$changed warm=$warm');
        expect(changed, greaterThan(2000), reason: 'the draped cursor must be visible on the terrain');
        expect(warm / changed, greaterThan(0.8), reason: 'the cursor pixels carry its amber colour');

        // The evidence: the cursor glides across the ridge, growing and
        // changing its falloff, for 10.5 s at 30 fps.
        const fps = 30;
        const frames = 315;
        final video = SmokeVideoRecorder(width: lit.width, height: lit.height, fps: fps, testName: testTitle);
        addTearDown(video.discard);
        Uint8List? still;
        for (var f = 0; f < frames; f++) {
          final t = f / frames;
          final x = -30.0 + 60.0 * t;
          final z = -26.0 + 52.0 * t;
          final radius = 6.0 + 10.0 * (0.5 - 0.5 * math.cos(t * math.pi * 2));
          final falloff = 0.15 + 0.7 * t;
          lit.landscape.showBrushCursor(LandscapeBrushCursor(centerX: x * u, centerZ: z * u, radius: radius * u, falloff: falloff, color: amber));
          video.addFrame(lit.render());
          if (f == frames ~/ 2) still = Uint8List.fromList(lit.pixels);
        }
        SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(lit.width, lit.height, shown, flipY: false), usedAssets: usedAssets);
        SmokeArtifacts.saveScreenshot('$testTitle (on the ridge)', SmokeArtifacts.encodePng(lit.width, lit.height, still!, flipY: false), usedAssets: usedAssets);
        SmokeArtifacts.saveVideo(testTitle, video.finish(), extension: 'webm', usedAssets: usedAssets);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );


    // The landscape is a walkable heightfield collider.
    test(
      'Scenario 04: the mannequin walks across a sculpted landscape without falling through it',
      () async {
        const testTitle =
            'Landscape Module Smoke Tests Scenario 04: the mannequin walks across a sculpted landscape without falling through it';
        const usedAssets = ['Props/Barrels/fuel_barrel_red.glb', LuminaThirdPersonContent.bundledMeshPath];
        final barrel = '${SmokeArtifacts.testAssetsDir.path}/${usedAssets[0]}';
        if (!File(LuminaThirdPersonContent.bundledMeshPath).existsSync()) {
          return markTestSkipped('build tool/build_third_person_content.dart first');
        }
        // A gentler ridge (8 m over σ 9 m ≈ 28° at its steepest) the character
        // can walk over; the walkable limit is 44°.
        final lit = _LitLandscapeScene();
        await lit.build(barrel, terrain: _ridgeTerrain(crestHeight: 8.0, crestSigma: 9.0));
        addTearDown(lit.dispose);
        expect(lit.landscape.collisionComponent, isNotNull, reason: 'the landscape must be a collider');
        const u = LuminaUnits.unitsPerMetre;

        // The Third Person mannequin 30 m south of the crest, walking north
        // (runtime −Z) over it and down the far side.
        const halfHeight = LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight;
        final startZ = 30.0 * u;
        final startY = lit.landscape.sampleHeightAtWorld(0.0, startZ) + halfHeight + 2.0;
        final character = LuminaTemplateCharacter(
          thirdPerson: true,
          meshAssetPath: LuminaThirdPersonContent.bundledMeshPath,
          location: Vector3(0.0, startY, startZ),
        );
        final pc = LuminaPlayerController()..possess(character);
        // The scene has begun play already; a character registered now
        // begins play on the next world tick.
        lit.world.persistentLevel.registerActor(character);
        await character.bodyMesh!.loaded;

        const fps = 30;
        final video = SmokeVideoRecorder(width: lit.width, height: lit.height, fps: fps, testName: testTitle);
        addTearDown(video.discard);
        final walk = LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 1.0, 0.0);
        var maxGap = -double.infinity, minGap = double.infinity, crestY = -double.infinity;
        Uint8List? still;
        // 16 s at 60 Hz, every 2nd tick a video frame (30 fps, real time):
        // 0.5 s standing, then walking north across the ridge — 40 m to
        // z = −10 m at the mannequin's 3 m/s walk, slower up the slope.
        const ticks = 960;
        for (var tick = 0; tick < ticks; tick++) {
          final t = tick / 60;
          if (t >= 0.5) character.onMove(walk);
          pc.onTick(1 / 60);
          lit.world.tick(1 / 60);
          final at = character.actorLocation;
          final gap = (at.y - halfHeight) - lit.landscape.sampleHeightAtWorld(at.x, at.z);
          expect(gap, greaterThan(-3.0), reason: 't=${t.toStringAsFixed(2)} s: the capsule is ${-gap} cm inside the terrain');
          maxGap = math.max(maxGap, gap);
          minGap = math.min(minGap, gap);
          crestY = math.max(crestY, at.y);
          if (tick.isEven) {
            // A three-quarter view that follows the walk.
            lit.camera.lookAt(
              eyeX: at.x + 5.0 * u,
              eyeY: at.y + 3.0 * u,
              eyeZ: at.z + 7.0 * u,
              centerX: at.x,
              centerY: at.y,
              centerZ: at.z - 2.0 * u,
            );
            // The loop ticks the world itself (a second tick per
            // frame would run without the walk input).
            video.addFrame(lit.render(tick: false));
            if (tick == 600) still = Uint8List.fromList(lit.pixels); // climbing to the crest
          }
        }
        final end = character.actorLocation;
        // ignore: avoid_print
        print('[landscape smoke 04] end=(${end.x.toStringAsFixed(0)}, ${end.y.toStringAsFixed(0)}, ${end.z.toStringAsFixed(0)}) '
            'gap min=${minGap.toStringAsFixed(1)} max=${maxGap.toStringAsFixed(1)} crestY=${crestY.toStringAsFixed(0)}');
        expect(end.z, lessThan(-10.0 * u), reason: 'it crossed the crest and walked down the far side (z ${end.z})');
        expect(crestY - halfHeight, greaterThan(6.0 * u), reason: 'it climbed the ridge');
        expect(maxGap, lessThan(15.0), reason: 'it stayed on the surface all the way (max gap $maxGap cm)');
        expect(character.hasBegunPlay, isTrue, reason: 'registered after play began, it began play on the next tick');
        expect(character.characterMovement.isWalking, isTrue);

        SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(lit.width, lit.height, still!, flipY: false),
            usedAssets: usedAssets, metrics: {'endZ': end.z, 'crestFeetY': crestY - halfHeight, 'maxGap': maxGap, 'minGap': minGap});
        SmokeArtifacts.saveVideo(testTitle, video.finish(), extension: 'webm', usedAssets: usedAssets);
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );

    // On a 25 cm-cell heightfield the mannequin walks into a 3 m
    // cliff (one 85° cell) and keeps standing at its foot, walking (idle),
    // instead of hanging in `falling` against the cliff face.
    test(
      'Scenario 05: the mannequin walks into a 3 m landscape cliff and stands walking at its foot',
      () async {
        const testTitle =
            'Landscape Module Smoke Tests Scenario 05: the mannequin walks into a 3 m landscape cliff and stands walking at its foot';
        const usedAssets = ['Props/Barrels/fuel_barrel_red.glb', LuminaThirdPersonContent.bundledMeshPath];
        final barrel = '${SmokeArtifacts.testAssetsDir.path}/${usedAssets[0]}';
        if (!File(LuminaThirdPersonContent.bundledMeshPath).existsSync()) {
          return markTestSkipped('build tool/build_third_person_content.dart first');
        }
        // 25 cm cells: flat south of z = −4 m, then a 3 m cliff.
        final data = LandscapeData.flat(gridResolution: 129, worldSize: 32.0, maxHeight: 10.0);
        for (var r = 0; r < data.gridResolution; r++) {
          final z = data.worldZOf(r);
          for (var c = 0; c < data.gridResolution; c++) {
            data.setHeight(c, r, z > -4 ? 0.0 : 3.0);
          }
        }
        final lit = _LitLandscapeScene();
        await lit.build(barrel, terrain: data);
        addTearDown(lit.dispose);
        const u = LuminaUnits.unitsPerMetre;
        const halfHeight = LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight;
        final character = LuminaTemplateCharacter(
          thirdPerson: true,
          meshAssetPath: LuminaThirdPersonContent.bundledMeshPath,
          location: Vector3(0.0, halfHeight + 2.0, 3.0 * u),
        );
        final pc = LuminaPlayerController()..possess(character);
        // The scene has begun play already: spawn so the character begins too.
        lit.world.spawnActorImmediately(character);
        await character.bodyMesh!.loaded;

        final video = SmokeVideoRecorder(width: lit.width, height: lit.height, fps: 30, testName: testTitle);
        addTearDown(video.discard);
        final walk = LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 1.0, 0.0);
        final notWalking = <String>[];
        Uint8List? atCliff;
        // 11 s at 60 Hz: 0.5 s standing, then walking north (−Z) into the
        // cliff, pushing against it to the end.
        const ticks = 660;
        for (var tick = 0; tick < ticks; tick++) {
          final t = tick / 60;
          if (t >= 0.5) character.onMove(walk);
          pc.onTick(1 / 60);
          lit.world.tick(1 / 60);
          final at = character.actorLocation;
          if (t >= 6.0 && !character.characterMovement.isWalking) {
            notWalking.add('${t.toStringAsFixed(2)}: ${character.characterMovement.movementMode}');
          }
          if (tick.isEven) {
            lit.camera.lookAt(eyeX: at.x + 6.0 * u, eyeY: 2.2 * u, eyeZ: at.z + 2.5 * u, centerX: at.x, centerY: 1.0 * u, centerZ: at.z - 1.5 * u);
            video.addFrame(lit.render(tick: false));
            if (tick == 600) atCliff = Uint8List.fromList(lit.pixels);
          }
        }
        final end = character.actorLocation;
        final feet = end.y - halfHeight;
        expect(end.z, lessThan(-3.0 * u), reason: 'it walked up to the cliff (z ${end.z})');
        expect(end.z, greaterThan(-4.0 * u), reason: 'the cliff stopped it (z ${end.z})');
        expect(feet, closeTo(0.0, 3.0), reason: 'standing on the ground, not hanging on the cliff (feet $feet cm)');
        expect(notWalking, isEmpty, reason: 'walking every tick while pushing into the cliff');

        SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(lit.width, lit.height, atCliff!, flipY: false),
            usedAssets: usedAssets, metrics: {'feetAboveGround': feet, 'endZ': end.z});
        SmokeArtifacts.saveVideo(testTitle, video.finish(), extension: 'webm', usedAssets: usedAssets);
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  });
}
