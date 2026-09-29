import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The terrain is lit with the heightmap's normals, its albedo
/// is derived from the local slope, and terrain tiles and foliage chunks cast
/// and receive the sun's shadows.

String get _assets => Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';

/// A ridge along X: flat ground on both sides, a 60° flank in the middle.
LandscapeData _ridge({int resolution = 129}) {
  final data = LandscapeData.flat(gridResolution: resolution, worldSize: 128.0, maxHeight: 100.0);
  final slope = math.tan(60 * math.pi / 180);
  for (var r = 0; r < resolution; r++) {
    final z = data.worldZOf(r);
    // A tent: 60° flanks rising to 20 m, centred on z = 0.
    final h = (20.0 - z.abs() * slope).clamp(0.0, 20.0);
    for (var c = 0; c < resolution; c++) {
      data.setHeight(c, r, h + 5.0);
    }
  }
  return data;
}

(FilamentEngine, FilamentScene, LuminaWorld) _world() {
  final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
  final scene = engine.createScene();
  final world = LuminaWorld(worldType: LuminaWorldType.game);
  world.initializeNativeContext(engine, scene);
  return (engine, scene, world);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('terrain tiles are lit, declare what the lit material needs, and cast and receive shadows', () async {
    final (engine, scene, world) = _world();
    final landscape = LuminaLandscapeComponent(data: _ridge());
    world.persistentLevel.registerActor(LuminaActor(root: landscape));
    await landscape.ensureBuilt();
    final rm = FilamentRenderableManager(engine);
    final mesh = landscape.terrainMesh!;
    expect(landscape.sectionCount, 4);
    for (var i = 0; i < 4; i++) {
      final e = mesh.sectionEntity(i);
      expect(rm.isShadowCaster(e), isTrue, reason: 'tile $i must cast the sun\'s shadows (a hill shades the ground)');
      expect(rm.isShadowReceiver(e), isTrue, reason: 'tile $i must receive shadows');
      final attrs = rm.getEnabledAttributesAt(e, 0);
      for (final a in [VertexAttribute.position, VertexAttribute.tangents, VertexAttribute.color, VertexAttribute.uv0, VertexAttribute.uv1]) {
        expect(attrs, contains(a), reason: 'tile $i must declare $a for the lit ubershader');
      }
      expect(rm.getMaterialInstanceAt(e, 0)!.material.shading, FilamatShading.lit,
          reason: 'tile $i must be drawn with the lit material');
    }
    world.cleanup();
    scene.dispose();
    engine.dispose();
  });

  test('foliage chunks are lit and cast and receive shadows', () async {
    final (engine, scene, world) = _world();
    final data = _ridge(resolution: 65);
    final layer = FoliageLayer(
      meshAssetId: 'fuel_barrel_red',
      meshAssetPath: '$_assets/Props/Barrels/fuel_barrel_red.glb',
      name: 'Barrels',
    );
    for (var i = 0; i < 70; i++) {
      final x = -40.0 + i * 1.1;
      layer.addInstance(FoliageInstance(
        x: x,
        y: data.sampleHeight(x, 40.0),
        z: 40.0,
        scaleX: 1,
        scaleY: 1,
        scaleZ: 1,
        yaw: 0,
        nx: 0,
        ny: 1,
        nz: 0,
      ));
    }
    data.layers.add(layer);
    final landscape = LuminaLandscapeComponent(data: data);
    world.persistentLevel.registerActor(LuminaActor(root: landscape));
    await landscape.ensureBuilt();
    expect(landscape.foliageError, isNull, reason: landscape.foliageError ?? '');
    final rm = FilamentRenderableManager(engine);
    final chunks = landscape.foliageChunksOf(0);
    expect(chunks, isNotEmpty);
    for (final chunk in chunks) {
      expect(rm.isShadowCaster(chunk.entity), isTrue, reason: 'a barrel must throw a shadow on the ground');
      expect(rm.isShadowReceiver(chunk.entity), isTrue);
      expect(rm.getMaterialInstanceAt(chunk.entity, 0)!.material.shading, FilamatShading.lit);
      expect(rm.getEnabledAttributesAt(chunk.entity, 0), contains(VertexAttribute.uv1),
          reason: 'the lit ubershader requires uv1');
    }
    world.cleanup();
    scene.dispose();
    engine.dispose();
  });
}
