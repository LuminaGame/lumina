import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// A real, sculpted heightmap — a diagonal ridge plus a bowl, so heights,
/// normals and slopes all vary.
LandscapeData _sculptedTerrain({int resolution = 129, double worldSize = 256.0, double maxHeight = 100.0}) {
  final data = LandscapeData.flat(
    gridResolution: resolution,
    worldSize: worldSize,
    maxHeight: maxHeight,
  );
  final half = (resolution - 1) / 2.0;
  for (var r = 0; r < resolution; r++) {
    for (var c = 0; c < resolution; c++) {
      final u = (c - half) / half;
      final v = (r - half) / half;
      final ridge = math.exp(-((u - v) * (u - v)) * 6.0) * 40.0;
      final bowl = -math.exp(-(u * u + v * v) * 3.0) * 18.0;
      data.setHeight(c, r, (25.0 + ridge + bowl).clamp(0.0, maxHeight));
    }
  }
  return data;
}

/// A real `.glb` on disk for foliage instancing (a genuine glTF binary
/// produced by the engine's own primitive factory — no stand-in geometry).
Future<String> _writeFoliageGlb(Directory dir) async {
  final glb = PrimitiveGlbFactory.build(shape: 'cylinder', sizeX: 40.0, sizeY: 180.0, sizeZ: 40.0);
  final file = File('${dir.path}/foliage_shrub.glb');
  await file.writeAsBytes(glb, flush: true);
  return file.path;
}

Future<String> _writeLandscapeAsset(Directory dir, LandscapeData data, {String name = 'TestTerrain'}) async {
  final references = <AssetReference>[];
  for (var i = 0; i < data.layers.length; i++) {
    references.add(AssetReference(
      slotName: 'foliage_$i',
      assetId: data.layers[i].meshAssetId,
      assetPath: data.layers[i].meshAssetPath,
    ));
  }
  final asset = LuminaAsset(
    assetId: 'landscape_$name',
    name: name,
    type: AssetType.landscape,
    rawPayload: data.toBytes(),
    references: references,
  );
  final file = File('${dir.path}/$name.lmas');
  await file.writeAsBytes(asset.toProtoBufferBytes(), flush: true);
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_landscape_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('LuminaLandscapeComponent — terrain', () {
    test('a payload loaded from a real .lmas produces one section per tile and the geometry reaches the scene', () async {
      final data = _sculptedTerrain(resolution: 129);
      final path = await _writeLandscapeAsset(tempDir, data);

      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull, reason: 'a Filament engine is required to prove the tiles reach a scene');
      final scene = engine!.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);

      final entitiesBefore = scene.entityCount;

      final landscape = LuminaLandscapeComponent(assetPath: path);
      final actor = LuminaActor(root: landscape);
      world.persistentLevel.registerActor(actor);
      await landscape.ensureBuilt();

      // 129 samples → 128 quads → 2×2 tiles of 64 quads.
      final map = LandscapeSectionMap(gridResolution: 129);
      expect(map.sectionCount, 4);
      expect(landscape.sectionCount, map.sectionCount);
      for (var i = 0; i < map.sectionCount; i++) {
        expect(landscape.terrainMesh!.hasSection(i), isTrue, reason: 'tile $i must exist');
        expect(
          landscape.terrainMesh!.sectionVertexCount(i),
          map.verticesPerRowOf(i) * map.rowsOf(i),
          reason: 'tile $i must carry a full 65×65 vertex grid',
        );
      }

      // The real assertion: renderables are in the scene, not just in a Dart map.
      expect(
        scene.entityCount - entitiesBefore,
        map.sectionCount,
        reason: 'every terrain tile must be a renderable entity in the Filament scene',
      );
      expect(scene.renderableCount, greaterThanOrEqualTo(map.sectionCount));

      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('height sampled through the component matches the payload within a pixel', () async {
      final data = _sculptedTerrain(resolution: 129);
      final landscape = LuminaLandscapeComponent(data: data);
      final actor = LuminaActor(root: landscape);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.persistentLevel.registerActor(actor);
      await landscape.ensureBuilt();

      // The payload is authored in metres; the world is in centimetres, so
      // world-space queries and results are the payload's ×unitsPerMetre.
      const u = LuminaUnits.unitsPerMetre;
      expect(landscape.unitsPerMetre, u);
      final rng = math.Random(7);
      final half = data.worldSize / 2;
      for (var i = 0; i < 64; i++) {
        final x = (rng.nextDouble() * 2 - 1) * half;
        final z = (rng.nextDouble() * 2 - 1) * half;
        expect(
          landscape.sampleHeightAtWorld(x * u, z * u),
          closeTo(data.sampleHeight(x, z) * u, data.cellSize * 1e-3 * u),
          reason: 'component height at (${x * u}, ${z * u}) must match the payload',
        );
      }

      // The actor's own transform must move the terrain query with it.
      actor.actorLocation = Vector3(1000.0, 500.0, -800.0);
      expect(
        landscape.sampleHeightAtWorld(1000.0, -800.0),
        closeTo(data.sampleHeight(0.0, 0.0) * u + 500.0, 1e-6 * u),
      );
      world.cleanup();
    });

    test('a landscape loaded through LuminaAssets.defaultProvider with external .heights sidecar builds terrain and collider', () async {
      final data = _sculptedTerrain(resolution: 65, worldSize: 128.0, maxHeight: 50.0);
      final sidecarFile = File('${tempDir.path}/bundled.heights');
      await data.writeSidecar(sidecarFile);

      final asset = LuminaAsset(
        assetId: 'landscape_bundled',
        name: 'bundled',
        type: AssetType.landscape,
        rawPayload: data.toBytes(inlineSamples: false),
      );
      final assetBytes = asset.toProtoBufferBytes();
      final sidecarBytes = sidecarFile.readAsBytesSync();

      final previousProvider = LuminaAssets.defaultProvider;
      LuminaAssets.defaultProvider = (key) async {
        if (key == 'contents/landscapes/bundled.lmas') return assetBytes;
        if (key == 'contents/landscapes/bundled.heights') return sidecarBytes;
        throw 'Asset not found: $key';
      };
      addTearDown(() {
        LuminaAssets.defaultProvider = previousProvider;
      });

      final landscape = LuminaLandscapeComponent(assetPath: 'contents/landscapes/bundled.lmas');
      final actor = LuminaActor(root: landscape);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.persistentLevel.registerActor(actor);

      await landscape.ensureBuilt();

      expect(landscape.sectionCount, greaterThan(0));
      const u = LuminaUnits.unitsPerMetre;
      expect(landscape.sampleHeightAtWorld(0.0, 0.0), closeTo(data.sampleHeight(0.0, 0.0) * u, 1e-3 * u));

      world.cleanup();
    });
  });

  group('LuminaLandscapeComponent — foliage', () {
    test('a layer larger than the instancing capacity is chunked, in order, with every instance present', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);
      final scene = engine!.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);

      final meshPath = await _writeFoliageGlb(tempDir);
      final data = _sculptedTerrain(resolution: 65);
      final layer = FoliageLayer(meshAssetId: 'shrub', meshAssetPath: meshPath, name: 'Shrubs');
      const instanceCount = 150;
      final rng = math.Random(11);
      for (var i = 0; i < instanceCount; i++) {
        final x = (rng.nextDouble() * 2 - 1) * (data.worldSize / 2 - 1);
        final z = (rng.nextDouble() * 2 - 1) * (data.worldSize / 2 - 1);
        layer.addInstance(FoliageInstance(
          x: x,
          y: data.sampleHeight(x, z),
          z: z,
          scaleX: 1.0,
          scaleY: 1.0,
          scaleZ: 1.0,
          yaw: i * 0.017,
          nx: 0.0,
          ny: 1.0,
          nz: 0.0,
        ));
      }
      data.layers.add(layer);

      final landscape = LuminaLandscapeComponent(data: data, foliageChunkCapacity: 64);
      final actor = LuminaActor(root: landscape);
      world.persistentLevel.registerActor(actor);
      await landscape.ensureBuilt();

      expect(landscape.foliageError, isNull, reason: landscape.foliageError ?? '');
      expect(landscape.foliageInstanceCount(0), instanceCount);
      final chunks = landscape.foliageChunksOf(0);
      expect(chunks.length, (instanceCount / 64).ceil(),
          reason: 'a 150-instance layer must be split across ceil(150/64) = 3 renderables');
      expect(chunks.fold<int>(0, (s, c) => s + c.instanceCount), instanceCount);

      // Order must be preserved across the chunk boundary.
      for (var i = 0; i < instanceCount; i++) {
        final expected = landscape.foliageMatrixOf(layer.instanceAt(i));
        final actual = landscape.foliageInstanceTransform(0, i);
        for (var k = 0; k < 16; k++) {
          expect(actual.storage[k], closeTo(expected.storage[k], 1e-4),
              reason: 'instance $i element $k must keep its authored transform');
        }
      }

      // Each chunk is its own renderable in the scene.
      for (final chunk in chunks) {
        expect(scene.hasEntity(chunk.entity), isTrue);
      }

      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('foliage meshes are drawn at the asset unit scale', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);
      final scene = engine!.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);

      // The real barrel: 0.77 × 1.15 × 0.77 in glTF metres.
      final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
      final barrel = '$assets/Props/Barrels/fuel_barrel_red.glb';
      expect(File(barrel).existsSync(), isTrue, reason: 'the real test asset must exist');

      final data = _sculptedTerrain(resolution: 65);
      final layer = FoliageLayer(meshAssetId: 'barrel', meshAssetPath: barrel, name: 'Barrels');
      layer.addInstance(FoliageInstance(
        x: 3.0,
        y: data.sampleHeight(3.0, -2.0),
        z: -2.0,
        scaleX: 1.5,
        scaleY: 1.5,
        scaleZ: 1.5,
        yaw: 0.0,
        nx: 0.0,
        ny: 1.0,
        nz: 0.0,
      ));
      data.layers.add(layer);

      // What PIE and the generated level mount: a centimetre world.
      final landscape = LuminaLandscapeComponent(data: data);
      world.persistentLevel.registerActor(LuminaActor(root: landscape));
      await landscape.ensureBuilt();
      expect(landscape.foliageError, isNull, reason: landscape.foliageError ?? '');
      expect(landscape.foliageInstanceCount(0), 1);

      const u = LuminaUnits.unitsPerMetre;
      final m = landscape.foliageInstanceTransform(0, 0);
      final scaleY = Vector3(m.storage[4], m.storage[5], m.storage[6]).length;
      expect(scaleY, closeTo(1.5 * u, 1e-3),
          reason: 'a glTF (metre) mesh in a cm world is drawn × unitsPerMetre, like a static mesh');
      expect(m.storage[12], closeTo(3.0 * u, 1e-3));
      expect(m.storage[14], closeTo(-2.0 * u, 1e-3));

      world.cleanup();
      scene.dispose();
      engine.dispose();
    });
  });

  group('LandscapeMeshBuilder', () {
    test('tile geometry is derived from the real heightmap and seams are duplicated', () {
      final data = _sculptedTerrain(resolution: 129);
      final map = LandscapeSectionMap(gridResolution: 129);
      final a = LandscapeMeshBuilder.buildSection(data, map, map.sectionIndexAt(0, 0));
      final b = LandscapeMeshBuilder.buildSection(data, map, map.sectionIndexAt(1, 0));

      expect(a.verticesPerRow, 65);
      expect(a.rowCount, 65);
      expect(a.triangleCount, 64 * 64 * 2);

      // Column 64 of tile (0,0) and column 0 of tile (1,0) are the same seam.
      for (var r = 0; r < 65; r++) {
        final left = (r * 65 + 64) * 3;
        final right = (r * 65) * 3;
        expect(a.positions[left + 1], closeTo(b.positions[right + 1], 1e-6),
            reason: 'seam row $r must carry the same height in both tiles');
      }

      // Heights really come from the payload.
      expect(a.positions[1], closeTo(data.heightAt(0, 0), 1e-4));
    });
  });
}
