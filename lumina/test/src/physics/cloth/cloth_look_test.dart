import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../physics_fixture.dart';
import '../ragdoll/ragdoll_fixture.dart';

/// How a cloth looks and folds: a texture on its UVs or a project material
/// drawn instead of the built-in one, and self-collision keeping its own
/// layers apart when it crumples on the floor.
void main() {
  tearDown(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.auto);

  group('look', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    Future<LuminaClothComponent> place(LuminaClothComponent cloth) async {
      world.persistentLevel.registerActor(LuminaActor(root: cloth));
      world.beginPlay();
      await cloth.ready;
      world.tick(1 / 60);
      await cloth.lookReady;
      return cloth;
    }

    final tile = File('${testAssets.path}/Geo/osm_tiles/14/9509/6140.png');

    test('a texture is drawn on the cloth through the built-in material', () async {
      final cloth = await place(LuminaClothComponent(gridColumns: 6, gridRows: 4, baseColorTexture: tile.path, color: Vector3.all(1)));
      expect(cloth.drawsLook, isTrue);
      final material = cloth.drawnMaterial!.material;
      expect(material.parameters.any((p) => p.name == 'baseColorMap' && p.isSampler), isTrue);
      expect(cloth.toProperties()['baseColorTexture'], tile.path);
    }, skip: tile.existsSync() ? false : 'test-assets/Geo/osm_tiles is missing');

    test('a project material is drawn instead of the built-in one', () async {
      FilamentMaterialBuilder.initEngine();
      final builder = FilamentMaterialBuilder.create()
        ..setName('ClothTestMaterial')
        ..setShading(FilamatShading.lit)
        ..materialDomain(MaterialDomain.surface)
        ..blending(BlendingMode.opaque)
        ..culling(CullingMode.none)
        ..setDoubleSided(true)
        ..addParameter('baseColorFactor', UniformType.float4)
        ..platform(MaterialPlatform.desktop)
        ..targetApi(TargetApi.vulkan)
        ..optimization(OptimizationLevel.none)
        ..setCode('void material(inout MaterialInputs material) { prepareMaterial(material); '
            'material.baseColor = materialParams.baseColorFactor; }');
      final Uint8List bytes = builder.build()!;
      builder.dispose();
      final cloth = await place(LuminaClothComponent(
        gridColumns: 6,
        gridRows: 4,
        materialAsset: 'contents/materials/M_Cloth.filamat',
        assetProvider: (_) async => bytes,
      ));
      expect(cloth.drawsLook, isTrue);
      expect(cloth.drawnMaterial!.material.name, 'ClothTestMaterial');
      expect(LuminaClothComponent.fromProperties(cloth.toProperties()).materialAsset, 'contents/materials/M_Cloth.filamat');
    });

    test('a texture that cannot be read leaves the colour', () async {
      final cloth = await place(LuminaClothComponent(gridColumns: 4, gridRows: 4, baseColorTexture: '${Directory.systemTemp.path}/no_such_cloth_texture.png'));
      expect(cloth.drawsLook, isFalse);
      expect(cloth.drawnMaterial, isNotNull);
    });
  });

  group('self-collision on Jolt', () {
    setUp(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.jolt);

    /// Drops a 1.2 m sheet edge-first onto the floor so it crumples, and
    /// returns how close (cm) two of its vertices that are far apart at rest
    /// came, and the step time (µs).
    Future<(double, double)> crumple(bool selfCollision) async {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final cloth = LuminaClothComponent(
        location: Vector3(0, 125, 0),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 0.25),
        gridWidth: 120,
        gridHeight: 120,
        gridColumns: 20,
        gridRows: 20,
        pinning: LuminaClothPinning.none,
        bendStiffness: 0.05,
        selfCollision: selfCollision,
        selfCollisionDistance: 2.0,
      );
      w.world.persistentLevel.registerActor(LuminaActor(root: cloth));
      w.begin();
      await cloth.ready;
      final watch = Stopwatch()..start();
      w.run(3);
      final us = watch.elapsedMicroseconds / (3 * 60 * 2);
      final g = cloth.geometry!;
      final p = cloth.currentSimPositions();
      Vector3 at(int i) => Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2]);
      var closest = double.infinity;
      for (var i = 0; i < g.simVertexCount; i++) {
        for (var j = i + 1; j < g.simVertexCount; j++) {
          if (g.simVertex(i).distanceTo(g.simVertex(j)) < 15) continue;
          closest = math.min(closest, at(i).distanceTo(at(j)));
        }
      }
      return (closest, us);
    }

    test('a sheet crumpling on the floor keeps its layers apart with self-collision', () async {
      final (without, usWithout) = await crumple(false);
      final (with_, us) = await crumple(true);
      // ignore: avoid_print
      print('closest far-apart vertices: without ${without.toStringAsFixed(2)} cm, with ${with_.toStringAsFixed(2)} cm '
          '(${usWithout.toStringAsFixed(0)} → ${us.toStringAsFixed(0)} µs per step, 441 vertices)');
      expect(with_, greaterThan(1.0));
      expect(with_, greaterThan(without));
    });

    test('self-collision and look settings round-trip; self-collision rebuilds the simulation', () async {
      final cloth = LuminaClothComponent.fromProperties({'selfCollision': true, 'selfCollisionDistance': 3.0});
      expect(cloth.selfCollision, isTrue);
      expect(cloth.selfCollisionDistance, 3.0);
      final before = cloth.settingsVersion;
      cloth.selfCollision = false;
      expect(cloth.settingsVersion, before + 1);
      expect(LuminaClothComponent.fromProperties(cloth.toProperties()).selfCollision, isFalse);
      // The editor stores asset references as maps.
      final referenced = LuminaClothComponent.fromProperties({
        'baseColorTexture': {'slot_name': 'baseColorTexture', 'asset_id': 't', 'asset_path': 'contents/textures/T_Flag.lmas'},
        'materialAsset': {'asset_path': ''},
      });
      expect(referenced.baseColorTexture, 'contents/textures/T_Flag.lmas');
      expect(referenced.materialAsset, isNull);
    });
  });
}
