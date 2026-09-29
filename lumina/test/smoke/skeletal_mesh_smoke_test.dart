import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

void main() {
  group('Skeletal Mesh Module Smoke Tests', () {
    test('Scenario 01: SkeletalMesh skeleton creation, FK propagation, and interpolation', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor();
      final skinnedComp = LuminaSkinnedMeshComponent();

      // Setup 3 bones
      final root = BoneNode(id: 0, name: 'root');
      final c1 = BoneNode(id: 1, name: 'spine', parentIndex: 0);
      final c2 = BoneNode(id: 2, name: 'head', parentIndex: 1);
      final skeleton = Skeleton([root, c1, c2]);

      // Set initial local positions
      root.translation.setValues(0, 0, 0);
      root.composeLocal();
      
      c1.translation.setValues(0, 10, 0);
      c1.composeLocal();

      c2.translation.setValues(0, 5, 0);
      c2.composeLocal();

      skinnedComp.setSkeleton(skeleton);
      actor.addComponent(skinnedComp);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      // Tick should trigger FK
      world.tick(1.0 / 60.0);

      // Verify FK
      expect(c2.globalTransform.getTranslation().y, closeTo(15.0, 1e-5));

      // Test transform curve (animation interpolation)
      final times = Float32List.fromList([0.0, 1.0]);
      final trans = [Vector3(0, 10, 0), Vector3(0, 20, 0)];
      final curve = TransformCurve(times, trans, [Quaternion.identity(), Quaternion.identity()], [Vector3.all(1.0), Vector3.all(1.0)]);
      
      curve.sampleInto(0.5, c1);
      c1.composeLocal();
      world.tick(1.0 / 60.0);

      expect(c2.globalTransform.getTranslation().y, closeTo(20.0, 1e-5));

      final usedAssets = [
        'mannequin/SKM_Manny_Simple.glb',
        'Props/Barrels/dented_barrel.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Skeletal Mesh Module Smoke Tests Scenario 01: SkeletalMesh skeleton creation, FK propagation, and interpolation';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
    });

    test('Scenario 02: Skinning buffer native bridge upload', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final scene = engine.createScene();
      
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
      
      final actor = LuminaActor();
      final skinnedComp = LuminaSkinnedMeshComponent();

      // Create 64 bones (will trigger SkinningBuffer 256-bone palette)
      final bones = <BoneNode>[];
      for (int i = 0; i < 64; i++) {
        bones.add(BoneNode(id: i, name: 'bone$i', parentIndex: i > 0 ? i - 1 : -1));
        if (i > 0) {
          bones[i].translation.setValues(0, 10, 0);
        }
        bones[i].composeLocal();
      }
      final skeleton = Skeleton(bones);
      
      skinnedComp.setSkeleton(skeleton);
      actor.addComponent(skinnedComp);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      // Tick 3 frames
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
        engine.flushAndWait();
      }

      final usedAssets = [
        'mannequin/SKM_Manny_Simple.glb',
        'Props/Access_cards/access_card_red.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Skeletal Mesh Module Smoke Tests Scenario 02: Skinning buffer native bridge upload';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
      engine.destroyScene(scene);
      engine.dispose();
    }, tags: ['native']);

    test('Scenario 03: SkeletalMesh Sockets and Follower Updates', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final scene = engine.createScene();
      
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
      
      final actor = LuminaActor();
      final skinnedComp = LuminaSkinnedMeshComponent();
      
      final bones = [
        BoneNode(name: 'root', id: -1)..translation.setValues(0, 0, 0)..composeLocal(),
        BoneNode(name: 'spine', id: 0, parentIndex: 0)..translation.setValues(0, 5, 0)..composeLocal(),
        BoneNode(name: 'hand', id: 1, parentIndex: 1)..translation.setValues(0, 5, 0)..composeLocal(),
      ];
      skinnedComp.setSkeleton(Skeleton(bones));
      actor.addComponent(skinnedComp);
      
      skinnedComp.addSocket(LuminaSocket.at('weapon_socket', 'hand'));
      
      final follower = LuminaSceneComponent();
      skinnedComp.attachToSocket(follower, 'weapon_socket');
      
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      
      // Tick 1
      world.tick(0.016);
      engine.flushAndWait();
      
      // Follower should be at 0, 10, 0 (root + spine + hand)
      expect(follower.worldLocation.y, closeTo(10.0, 1e-5));
      
      // Animate hand
      bones[2].translation.setValues(0, 10, 0);
      bones[2].composeLocal();
      
      // Tick 2
      world.tick(0.016);
      engine.flushAndWait();
      
      expect(follower.worldLocation.y, closeTo(15.0, 1e-5));
      
      // Tick 3
      world.tick(0.016);
      engine.flushAndWait();

      final usedAssets = [
        'mannequin/SKM_Manny_Simple.glb',
        'Props/Access_cards/access_card_red.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Skeletal Mesh Module Smoke Tests Scenario 03: SkeletalMesh Sockets and Follower Updates';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Mannequin at origin
          final mannyAabb = assets[0].getBoundingBox();
          final s0 = mannyAabb.max - mannyAabb.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.8 / max0 : 1.0;
          final mannyMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -mannyAabb.min.y * scale0, 0.0)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, mannyMat.storage.toList());

          // Accessory (Asset 1) attached to hand socket, waving up and down with sine wave
          if (assets.length > 1) {
            final handY = 1.0 + math.sin(timeSeconds * 3.0) * 0.35;
            final handX = 0.4 + math.cos(timeSeconds * 3.0) * 0.15;
            final handZ = 0.3;
            final itemAabb = assets[1].getBoundingBox();
            final s1 = itemAabb.max - itemAabb.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 0.3 / max1 : 1.0;
            final itemMat = Matrix4.identity()
              ..setTranslationRaw(handX, handY, handZ)
              ..rotateZ(math.sin(timeSeconds * 3.0) * 0.5)
              ..scale(scale1, scale1, scale1);
            tm.setTransform(assets[1].rootEntity, itemMat.storage.toList());
          }

          // Orbit camera around Manny
          final camDist = 2.8;
          final camAngle = timeSeconds * 0.4;
          cam.lookAt(
            eyeX: math.sin(camAngle) * camDist,
            eyeY: 1.2,
            eyeZ: math.cos(camAngle) * camDist,
            centerX: 0.0,
            centerY: 0.9,
            centerZ: 0.0,
          );
        },
      );
      
      world.cleanup();
      engine.destroyScene(scene);
      engine.dispose();
    }, tags: ['native']);

    test('Scenario 04: Morph Target Weight Blending Pipeline', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final scene = engine.createScene();
      
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
      
      final actor = LuminaActor();
      final skinnedComp = LuminaSkinnedMeshComponent();

      final entity = EntityManager.get().create();
      final asset = FakeFilamentAsset();
      asset.setEntityTargets(entity, ['smile', 'frown']);
      
      skinnedComp.discoverMorphTargets(asset);
      actor.addComponent(skinnedComp);
      world.persistentLevel.registerActor(actor);
      
      world.beginPlay();
      
      // Set weights
      skinnedComp.setMorphTarget('smile', 0.8);
      skinnedComp.setMorphTarget('frown', 0.2);
      
      // Tick to trigger flush to renderable manager (will execute setMorphWeights natively)
      world.tick(0.016);
      engine.flushAndWait();
      
      expect(skinnedComp.getMorphTarget('smile'), closeTo(0.8, 0.001));
      expect(skinnedComp.getMorphTarget('frown'), closeTo(0.2, 0.001));

      final usedAssets = [
        'mannequin/SKM_Manny_Simple.glb',
        'Props/AC_units/ac_unit_a_300x300.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Skeletal Mesh Module Smoke Tests Scenario 04: Morph Target Weight Blending Pipeline';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Manny at center
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.8 / max0 : 1.0;
          final mannyMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0, 0.0)
            ..scale(scale0, scale0, scale0);
          tm.setTransform(assets[0].rootEntity, mannyMat.storage.toList());

          // Camera close-up tracking Manny's head/face
          final zoom = 0.5 + 0.5 * math.cos(timeSeconds * 0.8);
          final camDist = 1.2 + zoom * 0.8;
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.3) * camDist,
            eyeY: 1.5,
            eyeZ: math.cos(timeSeconds * 0.3) * camDist,
            centerX: 0.0,
            centerY: 1.45,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
      engine.destroyScene(scene);
      engine.dispose();
      EntityManager.get().destroy(entity);
    }, tags: ['native']);
  });
}

class FakeFilamentAsset implements FilamentAsset {
  final Map<int, List<String?>> _entitiesToTargets = {};

  void setEntityTargets(int entity, List<String?> targets) {
    _entitiesToTargets[entity] = targets;
  }

  @override
  int getMorphTargetCountAt(int entity) {
    return _entitiesToTargets[entity]?.length ?? 0;
  }

  @override
  String? getMorphTargetNameAt(int entity, int target) {
    return _entitiesToTargets[entity]?[target];
  }

  @override
  List<int> get entities => _entitiesToTargets.keys.toList();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
