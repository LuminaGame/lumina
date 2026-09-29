import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('LuminaStaticMeshComponent & MeshAssetCache Tests (Task 01)', () {
    late FilamentEngine engine;
    late FilamentMaterialProvider materialProvider;
    late FilamentScene scene;
    late LuminaWorld world;
    late String testGlbPath;

    setUpAll(() {
      final possiblePaths = [
        '${Directory.current.parent.path}/test-assets/structures/excavator_cabins/excavator_cabin_a.glb',
        '../test-assets/structures/excavator_cabins/excavator_cabin_a.glb',
        'test-assets/structures/excavator_cabins/excavator_cabin_a.glb',
      ];
      for (final p in possiblePaths) {
        if (File(p).existsSync()) {
          testGlbPath = p;
          break;
        }
      }
    });

    setUp(() {
      engine = FilamentEngine.create()!;
      materialProvider = FilamentMaterialProvider.ubershader(engine);
      scene = engine.createScene();

      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      materialProvider.dispose();
      engine.dispose();
    });

    test('Spawning actor with StaticMeshComponent loads asset and adds root entity to scene', () async {
      final staticMesh = LuminaStaticMeshComponent(
        meshAssetPath: testGlbPath,
        location: Vector3(1.0, 2.0, 3.0),
      );
      final actor = LuminaActor(root: staticMesh);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      await staticMesh.loaded;
      expect(staticMesh.isLoaded, isTrue);
      expect(staticMesh.rootEntity, isNotNull);
      expect(staticMesh.entities, isNotEmpty);
      expect(scene.hasEntity(staticMesh.rootEntity!), isTrue);

      world.tick(1.0 / 60.0);

      final tm = FilamentTransformManager(engine);
      final transform = tm.getWorldTransform(staticMesh.rootEntity!);
      expect(transform[12], closeTo(1.0, 1e-4));
      expect(transform[13], closeTo(2.0, 1e-4));
      expect(transform[14], closeTo(3.0, 1e-4));
    });

    test('Moving component updates Filament transform on next tick phase 4', () async {
      final staticMesh = LuminaStaticMeshComponent(
        meshAssetPath: testGlbPath,
        location: Vector3(0.0, 0.0, 0.0),
      );
      final actor = LuminaActor(root: staticMesh);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      await staticMesh.loaded;
      world.tick(1.0 / 60.0);

      // Move component
      staticMesh.relativeLocation = Vector3(15.0, -4.0, 8.0);
      world.tick(1.0 / 60.0);

      final tm = FilamentTransformManager(engine);
      final transform = tm.getWorldTransform(staticMesh.rootEntity!);
      expect(transform[12], closeTo(15.0, 1e-4));
      expect(transform[13], closeTo(-4.0, 1e-4));
      expect(transform[14], closeTo(8.0, 1e-4));
    });

    test('Visibility toggles entity presence in FilamentScene without reload', () async {
      final staticMesh = LuminaStaticMeshComponent(meshAssetPath: testGlbPath);
      final actor = LuminaActor(root: staticMesh);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      await staticMesh.loaded;
      expect(scene.hasEntity(staticMesh.rootEntity!), isTrue);

      staticMesh.visible = false;
      expect(scene.hasEntity(staticMesh.rootEntity!), isFalse);
      expect(staticMesh.isLoaded, isTrue);

      staticMesh.visible = true;
      expect(scene.hasEntity(staticMesh.rootEntity!), isTrue);
    });

    test('Shadow properties propagate to renderables', () async {
      final staticMesh = LuminaStaticMeshComponent(
        meshAssetPath: testGlbPath,
        castShadows: false,
        receiveShadows: false,
      );
      final actor = LuminaActor(root: staticMesh);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      await staticMesh.loaded;
      final rm = FilamentRenderableManager(engine);
      for (final entity in staticMesh.entities) {
        if (rm.hasComponent(entity)) {
          expect(rm.isShadowCaster(entity), isFalse);
          expect(rm.isShadowReceiver(entity), isFalse);
        }
      }

      staticMesh.castShadows = true;
      staticMesh.receiveShadows = true;
      for (final entity in staticMesh.entities) {
        if (rm.hasComponent(entity)) {
          expect(rm.isShadowCaster(entity), isTrue);
          expect(rm.isShadowReceiver(entity), isTrue);
        }
      }
    });

    test('Two components with same meshAssetPath share cached parsed asset', () async {
      int providerCalls = 0;
      Future<Uint8List> trackingProvider(String path) async {
        providerCalls++;
        return File(path).readAsBytes();
      }

      final sm1 = LuminaStaticMeshComponent(meshAssetPath: testGlbPath, assetProvider: trackingProvider);
      final sm2 = LuminaStaticMeshComponent(meshAssetPath: testGlbPath, assetProvider: trackingProvider);

      final actor1 = LuminaActor(root: sm1);
      final actor2 = LuminaActor(root: sm2);

      world.persistentLevel.registerActor(actor1);
      world.persistentLevel.registerActor(actor2);
      world.beginPlay();

      await Future.wait([sm1.loaded, sm2.loaded]);

      final root1 = sm1.rootEntity!;
      final root2 = sm2.rootEntity!;

      expect(providerCalls, equals(1));
      expect(root1, isNot(equals(root2)));
      expect(scene.hasEntity(root1), isTrue);
      expect(scene.hasEntity(root2), isTrue);

      // Unregister first component
      world.destroyActor(actor1);
      world.tick(1.0 / 60.0);

      expect(scene.hasEntity(root1), isFalse);
      expect(scene.hasEntity(root2), isTrue);

      // Unregister second component
      world.destroyActor(actor2);
      world.tick(1.0 / 60.0);

      expect(scene.hasEntity(root2), isFalse);
    });

    test('Load failure with bad path completes loaded future with error cleanly without crashing tick', () async {
      final staticMesh = LuminaStaticMeshComponent(meshAssetPath: '/non/existent/model.glb');
      final actor = LuminaActor(root: staticMesh);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      expect(staticMesh.loaded, throwsA(anything));
      expect(() => world.tick(1.0 / 60.0), returnsNormally);
      expect(staticMesh.isLoaded, isFalse);
    });

    // A world cleaned up while a mesh is still loading its resources
    // (a preview tab closed during the load) must release the half-loaded
    // asset; it used to stay alive, so cleanup threw half way through
    // ("Cannot dispose AssetLoader while FilamentAssets are still active")
    // and Filament later aborted the process on its material instances.
    test('cleaning the world up while a textured mesh is still loading releases it', () async {
      final quinn = File('assets/templates/third_person/SKM_Superhero_Female.glb');
      expect(quinn.existsSync(), isTrue, reason: 'the Third Person template ships a textured mannequin');
      final bytes = quinn.readAsBytesSync();
      final staticMesh = LuminaStaticMeshComponent(meshAssetPath: quinn.path, assetProvider: (_) async => bytes);
      world.persistentLevel.registerActor(LuminaActor(root: staticMesh));
      world.beginPlay();

      // Clean up on this very turn, with the mesh's load in flight. A world
      // only closes its view of the engine's mesh cache, so
      // how far the load has got (reading, parsing, decoding textures) takes
      // the same path; waiting for "decoding" made the test race the load
      // (on a busy machine the textures finished first).
      final cache = world.meshAssetCache.shared;
      expect(staticMesh.isLoaded, isFalse, reason: 'the cleanup must land during the load');
      expect(() => world.cleanup(), returnsNormally);
      // The engine cache finishes decoding the textures before the load
      // resolves; a loaded machine can take a while, a hang still fails.
      await staticMesh.loaded.timeout(const Duration(seconds: 60));
      expect(staticMesh.isLoaded, isFalse);
      // The engine cache finished the half-loaded asset and, with no world
      // holding it, destroyed it: one upload, nothing left alive.
      expect(cache.uploadCount, 1);
      expect(cache.liveAssetCount, 0, reason: '${cache.entries}');
    });
  });
}
