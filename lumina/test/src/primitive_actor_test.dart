import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The template test room is built from Primitive actors. Play-In-
/// Editor needs them as real engine actors with geometry and a collider, or a
/// spawned character falls through the floor.
void main() {
  group('LuminaPrimitiveGeometry', () {
    test('a box has six quads, and its corners sit at half the size', () {
      final geometry = LuminaPrimitiveGeometry.build(LuminaPrimitiveShape.box, Vector3(2.0, 4.0, 6.0));
      expect(geometry.vertexCount, 24, reason: 'four vertices per face, normals unshared');
      expect(geometry.indices.length, 36);

      double maxOf(int offset) {
        var m = 0.0;
        for (var i = offset; i < geometry.positions.length; i += 3) {
          if (geometry.positions[i].abs() > m) m = geometry.positions[i].abs();
        }
        return m;
      }

      expect(maxOf(0), closeTo(1.0, 1e-9));
      expect(maxOf(1), closeTo(2.0, 1e-9));
      expect(maxOf(2), closeTo(3.0, 1e-9));
    });

    test('a plane lies flat at y = 0 and faces up', () {
      final geometry = LuminaPrimitiveGeometry.build(LuminaPrimitiveShape.plane, Vector3(20.0, 0.0, 20.0));
      for (var i = 1; i < geometry.positions.length; i += 3) {
        expect(geometry.positions[i], 0.0);
      }
      for (var i = 1; i < geometry.normals.length; i += 3) {
        expect(geometry.normals[i], closeTo(1.0, 1e-9));
      }
    });

    test('sphere and cylinder are closed and non-degenerate', () {
      for (final shape in [LuminaPrimitiveShape.sphere, LuminaPrimitiveShape.cylinder]) {
        final geometry = LuminaPrimitiveGeometry.build(shape, Vector3(1.0, 1.0, 1.0));
        expect(geometry.vertexCount, greaterThan(24), reason: '$shape');
        expect(geometry.indices.length % 3, 0, reason: '$shape');
        for (final index in geometry.indices) {
          expect(index, lessThan(geometry.vertexCount), reason: '$shape index out of range');
        }
      }
    });

    test('solid colours are one opaque RGBA per vertex', () {
      final geometry = LuminaPrimitiveGeometry.build(LuminaPrimitiveShape.box, Vector3.all(1.0));
      final colors = geometry.solidColors(Vector3(1.0, 0.0, 0.5));
      expect(colors.length, geometry.vertexCount * 4);
      expect(colors[0], 255);
      expect(colors[1], 0);
      expect(colors[2], 128);
      expect(colors[3], 255);
    });
  });

  group('LuminaPrimitiveActor', () {
    test('carries a box collider matching its size, and a thin one for a plane', () {
      final box = LuminaPrimitiveActor(
        shape: LuminaPrimitiveShape.box,
        size: Vector3(200.0, 300.0, 400.0),
        color: Vector3.all(0.5),
      );
      expect(box.collisionComponent.boxExtent.x, closeTo(100.0, 1e-7));
      expect(box.collisionComponent.boxExtent.y, closeTo(150.0, 1e-7));
      expect(box.collisionComponent.objectType, CollisionObjectType.worldStatic);

      final plane = LuminaPrimitiveActor(
        shape: LuminaPrimitiveShape.plane,
        size: Vector3(2000.0, 0.0, 2000.0),
        color: Vector3.all(0.5),
      );
      expect(plane.collisionComponent.boxExtent.y, closeTo(5.0, 1e-7),
          reason: 'a zero-thickness floor cannot be stood on');
      expect(plane.collisionComponent.boxExtent.x, closeTo(1000.0, 1e-7));
    });

    test('reads its shape, size and colour from an editor actor map', () {
      final actor = LuminaPrimitiveActor.fromComponentProperties(const <String, dynamic>{
        'shape': 'sphere',
        'sizeX': 1.2,
        'sizeY': 1.2,
        'sizeZ': 1.2,
        'colorHex': '#4F8FD1',
      });
      expect(actor.shape, LuminaPrimitiveShape.sphere);
      expect(actor.size.x, closeTo(1.2, 1e-9));
      expect(actor.color.x, closeTo(0x4F / 255.0, 1e-6));
      expect(actor.color.z, closeTo(0xD1 / 255.0, 1e-6));
    });

    test('an unknown shape name falls back to a box rather than throwing', () {
      final actor = LuminaPrimitiveActor.fromComponentProperties(const {'shape': 'torus'});
      expect(actor.shape, LuminaPrimitiveShape.box);
    });
  });

  // The section used to have no material, so every primitive was
  // drawn in Filament's default white whatever colour the level authored.
  group('LuminaPrimitiveActor on a native world', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('is drawn in its authored colour, where the actor is', () async {
      final crate = LuminaPrimitiveActor(
        shape: LuminaPrimitiveShape.box,
        size: Vector3(100.0, 100.0, 100.0),
        color: luminaHexToRgb('#B07A45'),
        location: Vector3(1000.0, 50.0, -600.0),
      );
      world.persistentLevel.registerActor(crate);
      world.beginPlay();
      await crate.meshComponent.loaded;
      world.tick(1 / 60);

      final rm = FilamentRenderableManager(engine);
      final renderables = crate.meshComponent.entities.where(rm.hasComponent).toList();
      expect(renderables, isNotEmpty);
      final material = rm.getMaterialInstanceAt(renderables.first, 0)!;
      final (r, g, b, a) = material.getFloat4('baseColorFactor');
      expect(r, closeTo(0xB0 / 255.0, 1e-3));
      expect(g, closeTo(0x7A / 255.0, 1e-3));
      expect(b, closeTo(0x45 / 255.0, 1e-3));
      expect(a, closeTo(1.0, 1e-6));

      final m = FilamentTransformManager(engine).getWorldTransform(renderables.first);
      expect(m[12], closeTo(1000.0, 1e-3));
      expect(m[13], closeTo(50.0, 1e-3));
      expect(m[14], closeTo(-600.0, 1e-3));
      expect(scene.hasEntity(renderables.first), isTrue);
    });

    test('identical primitives share one cached asset', () async {
      LuminaPrimitiveActor crate(double x) => LuminaPrimitiveActor(
            shape: LuminaPrimitiveShape.box,
            size: Vector3.all(100.0),
            color: luminaHexToRgb('#8E6236'),
            location: Vector3(x, 50.0, 0.0),
          );
      final a = crate(0.0);
      final b = crate(200.0);
      world.persistentLevel.registerActor(a);
      world.persistentLevel.registerActor(b);
      world.beginPlay();
      await a.meshComponent.loaded;
      await b.meshComponent.loaded;
      expect(a.meshComponent.meshAssetPath, b.meshComponent.meshAssetPath);
      expect(a.meshComponent.assetInstance!.getAsset(), same(b.meshComponent.assetInstance!.getAsset()));
    });
  });
}
