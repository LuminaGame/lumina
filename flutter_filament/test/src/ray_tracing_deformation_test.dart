import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import '../smoke/smoke_helper.dart';

/// Skinned and morphed renderables are traced in the pose they render with: a
/// compute pass poses their vertices into their own bottom-level structure,
/// which is refit every frame their bone palette or morph weights change.
void main() {
  group('posed acceleration structures on the RTX GPU (Vulkan)', () {
    SmokeRig? rig;
    final cleanup = <void Function()>[];

    setUp(() {
      if (Platform.environment['FILAMENT_TEST_BACKEND'] == 'opengl') return;
      RayTracing.requestExtensions();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: 64, height: 64);
    });

    tearDown(() {
      if (rig != null) {
        for (final e in rig!.entities) {
          rig!.engine.destroyEntity(e);
        }
        rig!.entities.clear();
      }
      for (final f in cleanup.reversed) {
        f();
      }
      cleanup.clear();
      rig?.dispose();
      rig = null;
      RayTracing.clearExtensionRequest();
    });

    bool skipWithoutRayQuery() {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      if (!rig!.engine.supportsRayQuery) {
        markTestSkipped('this GPU or driver has no Vulkan ray query support');
        return true;
      }
      return false;
    }

    Vector3 translationOf(List<double> m) => Vector3(m[12], m[13], m[14]);

    test('rotating a bone moves the limb into the ray: the hit follows the pose', () async {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final gltf = loadGltfIntoScene(r, 'mannequin/MF_Unarmed_Walk_Fwd.glb', frameCamera: false);
      cleanup.add(() => gltf.dispose(r.scene));
      final asset = gltf.asset;
      final tm = FilamentTransformManager(r.engine);
      final upperArm = asset.getFirstEntityByName('upperarm_r');
      final hand = asset.getFirstEntityByName('hand_r');
      expect(upperArm, isNonZero);
      expect(hand, isNonZero);
      r.scene.rayTracingEnabled = true;
      asset.animator.updateBoneMatrices();
      r.renderFrame(warmup: 1);

      // The arm hangs down. Raised straight up, its forearm passes through a point
      // 80 % of its length above the shoulder: a horizontal ray there, above the
      // head, misses the character in the hanging pose.
      final shoulder = translationOf(tm.getWorldTransform(upperArm));
      final wrist = translationOf(tm.getWorldTransform(hand));
      final length = (wrist - shoulder).length;
      final target = shoulder + Vector3(0, length * 0.8, 0);
      final box = asset.getBoundingBox();
      final ox = box.min.x - 1.0;
      final reach = box.max.x - box.min.x + 2.0;
      Future<RayHit?> probe() => r.scene.traceVisibility(ox, target.y, target.z, 1, 0, 0, maxDistance: reach);

      expect(await probe(), isNull, reason: 'nothing above the head while the arm hangs');

      // Rotate the upper arm about the shoulder so that the shoulder-to-wrist
      // direction points up (+Y), in world space, then re-pose.
      final from = (wrist - shoulder).normalized();
      final rotation = Quaternion.fromTwoVectors(from, Vector3(0, 1, 0));
      final pivot =
          Matrix4.translation(shoulder) *
          Matrix4.compose(Vector3.zero(), rotation, Vector3.all(1)) *
          Matrix4.translation(-shoulder);
      final world = Matrix4.fromList(tm.getWorldTransform(upperArm));
      final parent = tm.getParent(upperArm);
      final parentWorld = parent != 0 ? Matrix4.fromList(tm.getWorldTransform(parent)) : Matrix4.identity();
      final local = Matrix4.inverted(parentWorld) * (pivot as Matrix4) * world;
      tm.setTransform(upperArm, (local as Matrix4).storage.toList());
      asset.animator.updateBoneMatrices();
      final raisedWrist = translationOf(tm.getWorldTransform(hand));
      expect(raisedWrist.y, closeTo(shoulder.y + length, length * 0.05), reason: 'the arm points up');
      r.renderFrame(warmup: 0);
      expect(r.scene.deformedBlasCount, greaterThan(0), reason: 'the new palette re-posed the character');

      final hit = await probe();
      expect(hit, isNotNull, reason: 'the raised forearm is in the ray now');
      expect(ox + hit!.t, closeTo(target.x, length * 0.25), reason: 'hit near the arm, not elsewhere');

      // A frame without a palette change re-poses nothing.
      r.renderFrame(warmup: 0);
      expect(r.scene.deformedBlasCount, 0);
      for (var i = 0; i < 20 && r.scene.lastBlasDeformTime == Duration.zero; i++) {
        asset.animator.updateBoneMatrices();
        r.renderFrame(warmup: 0);
      }
      expect(r.scene.lastBlasDeformTime, greaterThan(Duration.zero), reason: 'the posing pass is timed');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('an animated character is traced in the pose of each frame', () async {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final gltf = loadGltfIntoScene(r, 'mannequin/MF_Unarmed_Walk_Fwd.glb', frameCamera: false);
      cleanup.add(() => gltf.dispose(r.scene));
      final animator = gltf.asset.animator;
      final duration = animator.getAnimationDuration(0);
      final tm = FilamentTransformManager(r.engine);
      final hand = gltf.asset.getFirstEntityByName('hand_l');
      final upperArm = gltf.asset.getFirstEntityByName('upperarm_l');
      final pelvis = gltf.asset.getFirstEntityByName('pelvis');
      r.scene.rayTracingEnabled = true;
      // A horizontal ray from beside the swinging left hand, aimed at the wrist from
      // away from the body, meets the hand first in every frame of the walk.
      for (var i = 0; i < 4; i++) {
        animator.applyAnimation(0, duration * i / 4);
        animator.updateBoneMatrices();
        r.renderFrame(warmup: 0);
        final wrist = translationOf(tm.getWorldTransform(hand));
        final length = (wrist - translationOf(tm.getWorldTransform(upperArm))).length;
        final body = translationOf(tm.getWorldTransform(pelvis));
        final outward = Vector3(wrist.x - body.x, 0, wrist.z - body.z).normalized();
        final origin = wrist + outward * (length * 0.5);
        final hit = await r.scene.traceVisibility(
          origin.x,
          origin.y,
          origin.z,
          -outward.x,
          0,
          -outward.z,
          maxDistance: length,
        );
        expect(hit, isNotNull, reason: 'frame $i: the hand is in the ray');
        expect(hit!.t, closeTo(length * 0.5, length * 0.15), reason: 'frame $i: at the wrist, within its thickness');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('morph weights move a morphed quad for rays', () async {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final quad = SmokeQuad.create(r.engine);
      cleanup.add(quad.dispose);
      final material = buildUnlitMaterial(r.engine);
      cleanup.add(material.dispose);
      final mi = material.createInstance()..setFloat3('baseColor', 0.8, 0.8, 0.8);
      cleanup.add(mi.dispose);
      // one target that pushes every vertex 0.5 along +Z
      final targets = MorphTargetBuffer.create(r.engine, vertexCount: 4, count: 1);
      cleanup.add(targets.dispose);
      targets.setPositionsAt(0, Float32List.fromList([0, 0, 0.5, 0, 0, 0.5, 0, 0, 0.5, 0, 0, 0.5]));
      final e = r.engine.createEntity();
      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..culling(false)
        ..material(0, mi)
        ..geometry(0, PrimitiveType.triangles, quad.vb, ib: quad.ib)
        ..morphing(1)
        ..morphingBuffer(targets)
        ..morphingOffsetAt(0, 0)
        ..build(r.engine, e);
      r.scene.addEntity(e);
      r.entities.add(e);
      final rm = FilamentRenderableManager(r.engine);
      r.scene.rayTracingEnabled = true;

      rm.setMorphWeights(e, Float32List.fromList([0]));
      r.renderFrame(warmup: 1);
      final rest = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1, maxDistance: 20);
      expect(rest, isNotNull);
      expect(rest!.t, closeTo(5.0, 0.01));

      rm.setMorphWeights(e, Float32List.fromList([1]));
      r.renderFrame(warmup: 0);
      expect(r.scene.deformedBlasCount, 1);
      final moved = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1, maxDistance: 20);
      expect(moved, isNotNull);
      expect(moved!.t, closeTo(5.5, 0.01), reason: 'the full target moves the quad 0.5 away');

      rm.setMorphWeights(e, Float32List.fromList([0.5]));
      r.renderFrame(warmup: 0);
      final half = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1, maxDistance: 20);
      expect(half!.t, closeTo(5.25, 0.01));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('posed acceleration structures without a GPU (noop backend)', () {
    test('report no posed structures and no posing time', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final scene = engine.createScene();
      try {
        scene.rayTracingEnabled = true;
        expect(scene.deformedBlasCount, 0);
        expect(scene.lastBlasDeformTime, Duration.zero);
      } finally {
        scene.dispose();
        engine.dispose();
      }
    });
  });
}
