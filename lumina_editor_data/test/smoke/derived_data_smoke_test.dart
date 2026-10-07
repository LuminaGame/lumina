import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/oversized_glb_fixture.dart';
import '../helpers/peak_rss.dart';

/// A project holding oversized source art pays the texture
/// downscale once; a later editor session loads the budgeted GLB from the
/// project's `DerivedDataCache/`.
void main() {
  group('Derived Data Module Smoke Tests', () {
    test('Scenario 01: a second editor session loads the 8K barrel\'s texture-budgeted GLB from DerivedDataCache/ and draws it next to the 8K source', () async {
      const testTitle = 'derived_data_smoke_test: Scenario 01 a second editor session loads the 8K barrel from DerivedDataCache';
      const barrelAsset = 'Props/Barrels/dented_barrel.glb';
      const usedAssets = [barrelAsset];
      final source = File('${SmokeArtifacts.testAssetsDir.path}/$barrelAsset');
      if (!source.existsSync()) return markTestSkipped('test-assets missing: $barrelAsset');

      final temp = Directory.systemTemp.createTempSync('lumina_ddc_smoke_');
      addTearDown(() => temp.deleteSync(recursive: true));
      AssetRepository.clearSanitizedGlbCache();
      addTearDown(AssetRepository.clearSanitizedGlbCache);

      // Pre-existing oversized art: the barrel's 512x256 texture re-encoded as
      // an 8192x4096 PNG (in this temp dir), stored the way an import before
      // the texture budget left a mesh — a payload-less .lmas next to its .entity.glb.
      final project = writeTempProject(temp, 'ddc_smoke');
      final glb8k = oversizedGlbFromTestAsset(source.readAsBytesSync());
      expect(embeddedPngSizes(glb8k), contains((8192, 4096)));
      final lmas = writeMeshAsset(project, 'SM_DentedBarrel_8K', glb8k);
      final companion = lmas.replaceAll('.lmas', '.entity.glb');

      final logs = <String>[];
      final sub = EngineLoggerService().logStream.listen((e) {
        if (e.source == 'DerivedDataCache') logs.add('[${e.level}] ${e.message}');
      });
      addTearDown(sub.cancel);

      // Session 1: the editor opens the project and loads the mesh. Both
      // sessions time a warm editor (the in-budget barrel loaded first), not
      // the isolate's first mesh parse.
      await AssetRepository.loadMeshFromDisk(source.path);
      final conversions = GlbParserService.decodingConversionCount;
      final firstWatch = Stopwatch()..start();
      final first = await AssetRepository.loadMeshFromDisk(lmas);
      firstWatch.stop();
      expect(first, isNotNull);
      expect(GlbParserService.decodingConversionCount, conversions + 1);
      final cache = DerivedDataCache(project.path);
      final entry = cache.entries().single;
      final header = DerivedDataCache.readEntryHeader(entry)!;
      expect(logs.where((l) => l.contains('DDC miss')), hasLength(1), reason: logs.join('\n'));

      // Session 2: a fresh isolate — an empty memo and a converter counter at 0.
      final second = await _freshSession(lmas);
      expect(second.conversions, 0, reason: second.logs.join('\n'));
      expect(second.vertexCount, first!.vertexCount);
      expect(second.logs.where((l) => l.contains('DDC hit')), hasLength(1), reason: second.logs.join('\n'));
      // Timed on the editor's isolate with the memo dropped (a background
      // isolate has no dart:ui for parseGlb's texture decode).
      AssetRepository.clearSanitizedGlbCache();
      final thirdWatch = Stopwatch()..start();
      await AssetRepository.loadMeshFromDisk(lmas);
      thirdWatch.stop();
      expect(GlbParserService.decodingConversionCount, conversions + 1);
      expect(thirdWatch.elapsedMicroseconds, lessThan(firstWatch.elapsedMicroseconds ~/ 3));
      final cached = (await cache.get(DerivedDataCache.sanitizedGlbBucket, header.key))!;
      expect(embeddedPngSizes(cached), contains((2048, 1024)));
      // ignore: avoid_print
      print('[derived_data smoke 01] session 1 ${firstWatch.elapsedMilliseconds} ms (miss, source ${glb8k.length} B), '
          'fresh-isolate session ${second.micros ~/ 1000} ms (hit), memo-cleared load ${thirdWatch.elapsedMilliseconds} ms (hit), '
          'entry ${entry.lengthSync()} B, DDC lines:\n${[...logs, ...second.logs].join('\n')}');

      // Draw both: the 8K source on the left (read from disk as the runtime
      // does), the derived GLB served from the cache on the right.
      const w = 1024, h = 768, fps = 30;
      const seconds = 10.5;
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(w, h);
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      final video = SmokeVideoRecorder(width: w, height: h, fps: fps, testName: testTitle);
      addTearDown(() {
        video.discard();
        world.cleanup();
        view.dispose();
        engine.destroyEntity(cameraEntity);
        camera.dispose();
        renderer.dispose();
        swapChain.dispose();
        scene.dispose();
        engine.dispose();
      });
      view
        ..scene = scene
        ..camera = camera
        ..setViewport(0, 0, w, h);
      camera.setProjection(fovDegrees: 40.0, aspect: w / h, near: 10.0, far: 10000.0, direction: FovDirection.vertical);

      world.persistentLevel.registerActor(LuminaActor(
        root: LuminaSkyComponent.color(color: Vector4(0.44, 0.58, 0.76, 1.0), skyIntensity: 20000.0, iblIntensity: 25000.0),
      ));
      world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(
          intensity: 90000.0,
          castShadows: true,
          rotation: Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 30.0 * math.pi / 180.0) *
              Quaternion.axisAngle(Vector3(1.0, 0.0, 0.0), -50.0 * math.pi / 180.0),
        ),
      ));
      final sourceBarrel = LuminaStaticMeshComponent(meshAssetPath: companion, location: Vector3(-55.0, 0.0, 0.0));
      final cachedBarrel = LuminaStaticMeshComponent(
        meshAssetPath: entry.path,
        assetProvider: (_) async => cached,
        location: Vector3(55.0, 0.0, 0.0),
      );
      world.persistentLevel.registerActor(LuminaActor(root: sourceBarrel));
      world.persistentLevel.registerActor(LuminaActor(root: cachedBarrel));
      world.beginPlay();
      await Future.wait([sourceBarrel.loaded, cachedBarrel.loaded]);
      expect(sourceBarrel.isLoaded && cachedBarrel.isLoaded, isTrue);

      final pixels = Uint8List(w * h * 4);
      Uint8List? middle;
      final frames = (seconds * fps).round();
      for (var f = 0; f < frames; f++) {
        final t = f / fps;
        // Both barrels turn in step, so the same side of each faces the camera.
        final spin = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), t * 0.6);
        sourceBarrel.relativeRotation = spin;
        cachedBarrel.relativeRotation = spin;
        final sway = 0.25 * math.sin(t * 0.5);
        camera.lookAt(
          eyeX: 330.0 * math.sin(sway),
          eyeY: 150.0,
          eyeZ: 330.0 * math.cos(sway),
          centerX: 0.0,
          centerY: 40.0,
          centerZ: 0.0,
        );
        world.tick(1.0 / fps);
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          renderer.readPixels(x: 0, y: 0, width: w, height: h, outPixels: pixels);
          renderer.endFrame();
        }
        engine.flushAndWait();
        video.addFrame(pixels);
        if (f == frames ~/ 2) middle = Uint8List.fromList(pixels);
      }

      // Both barrels are on screen and carry the same texture: the budgeted
      // copy averages to the colour of the 8K source.
      final shot = middle!;
      final sky = _pixelAt(shot, w, 8, 8);
      final left = _meanOfNonSky(shot, w, h, sky, 0, w ~/ 2);
      final right = _meanOfNonSky(shot, w, h, sky, w ~/ 2, w);
      // ignore: avoid_print
      print('[derived_data smoke 01] left (8K source) ${left.count} px mean ${left.rgb}, '
          'right (DDC) ${right.count} px mean ${right.rgb}');
      expect(left.count, greaterThan(8000), reason: 'the 8K source barrel draws');
      expect(right.count, greaterThan(8000), reason: 'the cached barrel draws');
      for (var c = 0; c < 3; c++) {
        expect((left.rgb[c] - right.rgb[c]).abs(), lessThan(12.0), reason: 'channel $c: the budgeted texture looks like the source');
      }

      SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w, h, shot, flipY: false), usedAssets: usedAssets);
      SmokeArtifacts.saveVideo(testTitle, video.finish(), extension: 'webm', usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Scenario 02: the real 8K FaceMesh — first load pays the downscale, a fresh session loads it from DerivedDataCache/', () async {
      final faceMesh = Platform.environment['LUMINA_FACEMESH_GLB'] ?? '';
      final source = File(faceMesh);
      if (faceMesh.isEmpty || !source.existsSync()) {
        return markTestSkipped('SKM_TestChar_FaceMesh.glb not found (set LUMINA_FACEMESH_GLB)');
      }

      final temp = Directory.systemTemp.createTempSync('lumina_ddc_face_');
      addTearDown(() => temp.deleteSync(recursive: true));
      AssetRepository.clearSanitizedGlbCache();
      addTearDown(AssetRepository.clearSanitizedGlbCache);
      final project = writeTempProject(temp, 'ddc_face');
      final dir = '${project.path}/contents/meshes/skeletal';
      source.copySync('$dir/SKM_TestChar_FaceMesh.entity.glb');
      final lmas = '$dir/SKM_TestChar_FaceMesh.lmas';
      File(lmas).writeAsBytesSync(const LuminaAsset(
        assetId: 'mesh_SKM_TestChar_FaceMesh',
        name: 'SKM_TestChar_FaceMesh',
        type: AssetType.filameshSk,
        metadata: {'payload_format': 'glb'},
      ).toProtoBufferBytes());

      final logs = <String>[];
      final sub = EngineLoggerService().logStream.listen((e) {
        if (e.source == 'DerivedDataCache') logs.add('[${e.level}] ${e.message}');
      });
      addTearDown(sub.cancel);

      final warmUp = '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb';
      await AssetRepository.loadMeshFromDisk(warmUp);
      final conversions = GlbParserService.decodingConversionCount;
      final firstWatch = Stopwatch()..start();
      final first = await AssetRepository.loadMeshFromDisk(lmas);
      firstWatch.stop();
      expect(first, isNotNull);
      expect(GlbParserService.decodingConversionCount, conversions + 1);
      final entry = DerivedDataCache(project.path).entries().single;

      // The fresh-isolate session's peak memory, not just its time.
      final peak = PeakRss.start();
      final second = await _freshSession(lmas);
      final secondPeakMb = peak?.grownMb();
      expect(second.conversions, 0, reason: second.logs.join('\n'));
      expect(second.vertexCount, first!.vertexCount);
      expect(second.logs.where((l) => l.contains('DDC hit')), hasLength(1), reason: second.logs.join('\n'));
      AssetRepository.clearSanitizedGlbCache();
      final thirdPeak = PeakRss.start();
      final thirdWatch = Stopwatch()..start();
      await AssetRepository.loadMeshFromDisk(lmas);
      thirdWatch.stop();
      final thirdPeakMb = thirdPeak?.grownMb();
      expect(GlbParserService.decodingConversionCount, conversions + 1);
      expect(thirdWatch.elapsedMicroseconds, lessThan(firstWatch.elapsedMicroseconds ~/ 3));
      // ignore: avoid_print
      print('[derived_data smoke 02] SKM_TestChar_FaceMesh: source ${source.lengthSync()} B, '
          'session 1 ${firstWatch.elapsedMilliseconds} ms (miss), fresh-isolate session ${second.micros ~/ 1000} ms (hit, '
          'peak RSS +${secondPeakMb ?? '?'} MB), '
          'memo-cleared load ${thirdWatch.elapsedMilliseconds} ms (hit, peak RSS +${thirdPeakMb ?? '?'} MB), entry ${entry.lengthSync()} B, '
          '${first.vertexCount} vertices, vertex colour sum ${_sum(first.vertexColors)} (root) / ${second.colorSum} (fresh isolate)\n'
          '${[...logs, ...second.logs].join('\n')}');
      // The fresh isolate bakes the same texture colours as the editor's.
      expect(second.colorSum, _sum(first.vertexColors), reason: 'vertex colours baked on a background isolate');
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('Scenario 03: the budgeted 8K barrel parsed on a background isolate bakes the same texture colours as on the editor isolate, drawn side by side', () async {
      const testTitle = 'derived_data_smoke_test: Scenario 03 a background isolate bakes the barrel texture like the editor isolate';
      const barrelAsset = 'Props/Barrels/dented_barrel.glb';
      const usedAssets = [barrelAsset];
      final source = File('${SmokeArtifacts.testAssetsDir.path}/$barrelAsset');
      if (!source.existsSync()) return markTestSkipped('test-assets missing: $barrelAsset');

      // What a DDC hit hands parseGlb: the 8K fixture after the texture budget
      // (one 2048x1024 PNG).
      final budgeted = GlbParserService.convertGlbTgaToPng(oversizedGlbFromTestAsset(source.readAsBytesSync()));
      expect(embeddedPngSizes(budgeted), contains((2048, 1024)));

      final rootWatch = Stopwatch()..start();
      final onRoot = (await GlbParserService.parseGlb(budgeted))!;
      rootWatch.stop();
      final peak = PeakRss.start();
      final background = await _parseOnBackgroundIsolate(budgeted);
      final peakMb = peak?.grownMb();
      final rootMesh = _ColoredMesh.of(onRoot);
      // ignore: avoid_print
      print('[derived_data smoke 03] budgeted 8K barrel: root isolate ${rootWatch.elapsedMilliseconds} ms, '
          'background isolate ${background.micros ~/ 1000} ms (peak RSS +${peakMb ?? '?'} MB), '
          'vertex colour sum ${_sum(rootMesh.colors)} (root) / ${_sum(background.mesh.colors)} (background)');
      expect(background.mesh.colors, equals(rootMesh.colors), reason: 'the same PNG bakes the same colours on any isolate');
      if (peakMb != null) {
        expect(peakMb, lessThan(512), reason: 'a 2048x1024 texture decodes in megabytes, not a 1.5 GB misread TGA');
      }

      // Draw both bakes: the editor isolate's on the left, the background
      // isolate's on the right, as unlit vertex-coloured procedural meshes.
      const w = 1024, h = 768, fps = 30;
      const seconds = 10.5;
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(w, h);
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      final provider = FilamentMaterialProvider.ubershader(engine);
      final materials = <FilamentMaterialInstance>[];
      final video = SmokeVideoRecorder(width: w, height: h, fps: fps, testName: testTitle);
      addTearDown(() {
        video.discard();
        world.cleanup();
        for (final mi in materials) {
          mi.dispose();
        }
        provider.dispose();
        view.dispose();
        engine.destroyEntity(cameraEntity);
        camera.dispose();
        renderer.dispose();
        swapChain.dispose();
        scene.dispose();
        engine.dispose();
      });
      view
        ..scene = scene
        ..camera = camera
        ..setViewport(0, 0, w, h);
      camera.setProjection(fovDegrees: 40.0, aspect: w / h, near: 10.0, far: 10000.0, direction: FovDirection.vertical);

      world.persistentLevel.registerActor(LuminaActor(
        root: LuminaSkyComponent.color(color: Vector4(0.44, 0.58, 0.76, 1.0), skyIntensity: 20000.0, iblIntensity: 25000.0),
      ));
      world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(
          intensity: 90000.0,
          castShadows: true,
          rotation: Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 30.0 * math.pi / 180.0) *
              Quaternion.axisAngle(Vector3(1.0, 0.0, 0.0), -50.0 * math.pi / 180.0),
        ),
      ));
      final unitScale = Vector3.all(LuminaUnits.unitsPerMetre);
      final left = LuminaProceduralMeshComponent(location: Vector3(-55.0, 0.0, 0.0), scale: unitScale);
      final right = LuminaProceduralMeshComponent(location: Vector3(55.0, 0.0, 0.0), scale: unitScale);
      world.persistentLevel.registerActor(LuminaActor(root: left));
      world.persistentLevel.registerActor(LuminaActor(root: right));
      world.beginPlay();
      for (final (component, mesh) in [(left, rootMesh), (right, background.mesh)]) {
        final mi = provider
            .createMaterialInstance(MaterialKey(unlit: true, doubleSided: true, hasVertexColors: true), label: 'bugs30_vertex_colours')
            .instance!;
        mi.setFloat4('baseColorFactor', 1.0, 1.0, 1.0, 1.0);
        materials.add(mi);
        component.createMeshSection(
          0,
          positions: mesh.positions,
          uv0: mesh.uvs,
          colors: mesh.linearRgba(),
          indices: mesh.indices,
          material: mi,
          // Unlit: no tangent frame, and no remesh that would leave the
          // per-vertex colours behind.
          generateTangents: false,
        );
      }

      final pixels = Uint8List(w * h * 4);
      Uint8List? middle;
      final frames = (seconds * fps).round();
      for (var f = 0; f < frames; f++) {
        final t = f / fps;
        final spin = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), t * 0.6);
        left.relativeRotation = spin;
        right.relativeRotation = spin;
        final sway = 0.25 * math.sin(t * 0.5);
        camera.lookAt(
          eyeX: 330.0 * math.sin(sway),
          eyeY: 150.0,
          eyeZ: 330.0 * math.cos(sway),
          centerX: 0.0,
          centerY: 40.0,
          centerZ: 0.0,
        );
        world.tick(1.0 / fps);
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          renderer.readPixels(x: 0, y: 0, width: w, height: h, outPixels: pixels);
          renderer.endFrame();
        }
        engine.flushAndWait();
        video.addFrame(pixels);
        if (f == frames ~/ 2) middle = Uint8List.fromList(pixels);
      }

      final shot = middle!;
      final sky = _pixelAt(shot, w, 8, 8);
      final leftMean = _meanOfNonSky(shot, w, h, sky, 0, w ~/ 2);
      final rightMean = _meanOfNonSky(shot, w, h, sky, w ~/ 2, w);
      // ignore: avoid_print
      print('[derived_data smoke 03] left (editor isolate) ${leftMean.count} px mean ${leftMean.rgb}, '
          'right (background isolate) ${rightMean.count} px mean ${rightMean.rgb}');
      expect(leftMean.count, greaterThan(8000), reason: 'the editor-isolate bake draws');
      expect(rightMean.count, greaterThan(8000), reason: 'the background-isolate bake draws');
      for (var c = 0; c < 3; c++) {
        expect((leftMean.rgb[c] - rightMean.rgb[c]).abs(), lessThan(6.0), reason: 'channel $c: both bakes carry the barrel texture');
      }

      SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w, h, shot, flipY: false), usedAssets: usedAssets);
      SmokeArtifacts.saveVideo(testTitle, video.finish(), extension: 'webm', usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Scenario 04: asset index keeps scans cheap — a generated 300-asset project is indexed off-thread, rescanned by stat only, and its barrels draw from the index', () async {
      const testTitle = 'derived_data_smoke_test: Scenario 04 asset index keeps scans cheap';
      final usedAssets = AssetProjectFixture.barrels;
      if (!File('${SmokeArtifacts.testAssetsDir.path}/${usedAssets.first}').existsSync()) {
        return markTestSkipped('test-assets missing: ${usedAssets.first}');
      }
      final temp = Directory.systemTemp.createTempSync('lumina_asset_index_smoke_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final project = AssetProjectFixture.write(temp, name: 'IndexSmoke', count: 300);
      addTearDown(() => LuminaAssetIndex.close(project));

      // Before the asset index: every scan decoded every .lmas.
      final fullWatch = Stopwatch()..start();
      var decodedBytes = 0;
      for (final f in Directory('$project/contents').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.lmas'))) {
        final bytes = f.readAsBytesSync();
        decodedBytes += bytes.length;
        LuminaAsset.fromBytes(bytes);
      }
      fullWatch.stop();

      final index = LuminaAssetIndex.open(project);
      final coldWatch = Stopwatch()..start();
      // (A real project's cold index goes off-thread by size; this fixture
      // is small, so the pool is asked for.)
      await index.refresh(offThread: true);
      coldWatch.stop();
      final cold = index.lastRefreshStats;
      final warmWatch = Stopwatch()..start();
      index.refreshSync();
      warmWatch.stop();
      final warm = index.lastRefreshStats;
      final browserWatch = Stopwatch()..start();
      final listed = AssetRepository().scanProjectContents(project);
      browserWatch.stop();
      final registryWatch = Stopwatch()..start();
      final registry = LuminaProjectBlueprintAssets.scan(project);
      registryWatch.stop();

      expect(cold.decoded, 300);
      expect(cold.offThread, isTrue);
      expect(warm.decoded, 0);
      expect(warmWatch.elapsedMilliseconds, lessThan(150));
      expect(listed, hasLength(300));
      expect(listed.where((a) => a.thumbnailBytes != null), hasLength(300));
      expect(registry.classes, isNotEmpty);
      expect(registry.enums, isNotEmpty);
      final metrics = <String, Object?>{
        'assets': 300,
        'lmas_bytes': decodedBytes,
        'full_decode_pass_ms': fullWatch.elapsedMilliseconds,
        'index_cold_build_ms': coldWatch.elapsedMilliseconds,
        'index_cold_decoded': cold.decoded,
        'index_warm_refresh_ms': warmWatch.elapsedMilliseconds,
        'index_warm_decoded': warm.decoded,
        'content_browser_scan_ms': browserWatch.elapsedMilliseconds,
        'blueprint_registry_scan_ms': registryWatch.elapsedMilliseconds,
        'index_file_bytes': index.file.lengthSync(),
      };
      // ignore: avoid_print
      print('[derived_data smoke 04] $metrics');

      // Draw what the index found: one of each barrel mesh asset, loaded
      // from the .lmas paths the index lists, orbited for the video.
      final meshes = <AssetIndexEntry>[];
      final seen = <String>{};
      for (final e in index.byType(AssetType.filamesh)) {
        if (seen.add(e.summary.metadata['source'] ?? e.path)) meshes.add(e);
      }
      expect(meshes, hasLength(usedAssets.length));
      const w = 1024, h = 768, fps = 30;
      const seconds = 10.5;
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(w, h);
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      final video = SmokeVideoRecorder(width: w, height: h, fps: fps, testName: testTitle);
      addTearDown(() {
        video.discard();
        world.cleanup();
        view.dispose();
        engine.destroyEntity(cameraEntity);
        camera.dispose();
        renderer.dispose();
        swapChain.dispose();
        scene.dispose();
        engine.dispose();
      });
      view
        ..scene = scene
        ..camera = camera
        ..setViewport(0, 0, w, h);
      camera.setProjection(fovDegrees: 40.0, aspect: w / h, near: 10.0, far: 10000.0, direction: FovDirection.vertical);
      world.persistentLevel.registerActor(LuminaActor(
        root: LuminaSkyComponent.color(color: Vector4(0.44, 0.58, 0.76, 1.0), skyIntensity: 20000.0, iblIntensity: 25000.0),
      ));
      world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(
          intensity: 90000.0,
          castShadows: true,
          rotation: Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 30.0 * math.pi / 180.0) *
              Quaternion.axisAngle(Vector3(1.0, 0.0, 0.0), -50.0 * math.pi / 180.0),
        ),
      ));
      final components = <LuminaStaticMeshComponent>[];
      for (var i = 0; i < meshes.length; i++) {
        final angle = i / meshes.length * 2 * math.pi;
        final c = LuminaStaticMeshComponent(
          meshAssetPath: meshes[i].absolutePath,
          location: Vector3(160.0 * math.sin(angle), 0.0, 160.0 * math.cos(angle)),
        );
        components.add(c);
        world.persistentLevel.registerActor(LuminaActor(root: c));
      }
      world.beginPlay();
      await Future.wait([for (final c in components) c.loaded]);
      expect(components.every((c) => c.isLoaded), isTrue);

      final pixels = Uint8List(w * h * 4);
      Uint8List? middle;
      final frames = (seconds * fps).round();
      for (var f = 0; f < frames; f++) {
        final t = f / fps;
        final orbit = t * 0.45;
        camera.lookAt(
          eyeX: 520.0 * math.sin(orbit),
          eyeY: 260.0,
          eyeZ: 520.0 * math.cos(orbit),
          centerX: 0.0,
          centerY: 30.0,
          centerZ: 0.0,
        );
        world.tick(1.0 / fps);
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          renderer.readPixels(x: 0, y: 0, width: w, height: h, outPixels: pixels);
          renderer.endFrame();
        }
        engine.flushAndWait();
        video.addFrame(pixels);
        if (f == frames ~/ 2) middle = Uint8List.fromList(pixels);
      }
      final shot = middle!;
      final sky = _pixelAt(shot, w, 8, 8);
      final drawn = _meanOfNonSky(shot, w, h, sky, 0, w);
      expect(drawn.count, greaterThan(20000), reason: 'the barrels the index listed draw');

      SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w, h, shot, flipY: false),
          usedAssets: usedAssets, metrics: metrics);
      SmokeArtifacts.saveVideo(testTitle, video.finish(), extension: 'webm', usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

/// A parsed mesh's combined geometry and baked vertex colours, in the typed
/// arrays a procedural mesh section takes (and an isolate can send back).
class _ColoredMesh {
  final Float32List positions;
  final Float32List? uvs;
  final Uint32List indices;
  final Uint8List colors; // RGB per vertex

  _ColoredMesh(this.positions, this.uvs, this.indices, this.colors);

  factory _ColoredMesh.of(GlbMeshData mesh) {
    final vertexCount = mesh.positions.length ~/ 3;
    return _ColoredMesh(
      Float32List.fromList(mesh.positions),
      mesh.uvs.length == vertexCount * 2 ? Float32List.fromList(mesh.uvs) : null,
      Uint32List.fromList(mesh.indices),
      mesh.vertexColors ?? Uint8List(vertexCount * 3),
    );
  }

  /// The sRGB bytes the parser samples, as the linear RGBA a vertex colour is.
  Uint8List linearRgba() {
    final out = Uint8List(colors.length ~/ 3 * 4);
    for (var v = 0, o = 0; v + 2 < colors.length; v += 3, o += 4) {
      for (var c = 0; c < 3; c++) {
        out[o + c] = (math.pow(colors[v + c] / 255.0, 2.2) * 255.0).round();
      }
      out[o + 3] = 255;
    }
    return out;
  }
}

/// [glb] parsed in a fresh isolate, the way a background worker would.
Future<({_ColoredMesh mesh, int micros})> _parseOnBackgroundIsolate(Uint8List glb) => Isolate.run(() async {
      final watch = Stopwatch()..start();
      final mesh = (await GlbParserService.parseGlb(glb))!;
      watch.stop();
      return (mesh: _ColoredMesh.of(mesh), micros: watch.elapsedMicroseconds);
    });

typedef _Session = ({int vertexCount, int colorSum, int micros, int conversions, List<String> logs});

/// One editor session's load of [lmasPath] in a fresh isolate: an empty memo
/// and a converter counter at 0.
Future<_Session> _freshSession(String lmasPath) => Isolate.run(() => _session(lmasPath));

Future<_Session> _session(String lmasPath) async {
  final logs = <String>[];
  final sub = EngineLoggerService().logStream.listen((e) {
    if (e.source == 'DerivedDataCache') logs.add('[${e.level}] ${e.message}');
  });
  final watch = Stopwatch()..start();
  final mesh = await AssetRepository.loadMeshFromDisk(lmasPath);
  watch.stop();
  await sub.cancel();
  return (
    vertexCount: mesh?.vertexCount ?? -1,
    colorSum: _sum(mesh?.vertexColors),
    micros: watch.elapsedMicroseconds,
    conversions: GlbParserService.decodingConversionCount,
    logs: logs,
  );
}

/// Sum of the baked vertex colour bytes: equal sums on two isolates mean the
/// textures were decoded alike, -1 when there are none.
int _sum(Uint8List? bytes) {
  if (bytes == null) return -1;
  var sum = 0;
  for (final b in bytes) {
    sum += b;
  }
  return sum;
}

List<int> _pixelAt(Uint8List rgba, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2]];
}

/// Mean colour of the pixels in columns [x0, x1) that differ from [sky].
({int count, List<double> rgb}) _meanOfNonSky(Uint8List rgba, int w, int h, List<int> sky, int x0, int x1) {
  var count = 0;
  final sum = [0.0, 0.0, 0.0];
  for (var y = 0; y < h; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * w + x) * 4;
      final d = (rgba[i] - sky[0]).abs() + (rgba[i + 1] - sky[1]).abs() + (rgba[i + 2] - sky[2]).abs();
      if (d < 40) continue;
      count++;
      for (var c = 0; c < 3; c++) {
        sum[c] += rgba[i + c];
      }
    }
  }
  return (count: count, rgb: [for (final s in sum) count == 0 ? 0.0 : s / count]);
}
