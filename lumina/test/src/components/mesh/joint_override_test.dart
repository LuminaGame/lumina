import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Joint overrides are multiplied onto the animated joints
/// every frame, after the clip and before the bone matrices, on a real
/// (headless) engine with the Third Person character.
void main() {
  const bundle = LuminaThirdPersonContent.bundledMeshPath;

  group('LuminaAnimatedMeshComponent.setJointOverride', () {
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

    /// The angle (degrees) between two rotations.
    double degreesBetween(Matrix4 a, Matrix4 b) {
      Quaternion rot(Matrix4 m) {
        final r = m.getRotation();
        for (var c = 0; c < 3; c++) {
          final len = math.sqrt(r.entry(0, c) * r.entry(0, c) + r.entry(1, c) * r.entry(1, c) + r.entry(2, c) * r.entry(2, c));
          for (var row = 0; row < 3; row++) {
            r.setEntry(row, c, r.entry(row, c) / len);
          }
        }
        return Quaternion.fromRotation(r)..normalize();
      }

      final d = (rot(a).clone()..inverse()) * rot(b);
      d.normalize();
      final w = d.w.abs().clamp(0.0, 1.0);
      return 2.0 * math.acos(w) * 180.0 / math.pi;
    }

    test("a 30° yaw override on 'Head' turns the head joint's world transform by ≈30° while the idle clip plays; clearing restores it; an unknown bone is ignored", () async {
      if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: bundle);
      world.persistentLevel.registerActor(LuminaActor(root: mesh));
      world.beginPlay();
      await mesh.loaded;
      for (final bone in ['spine_03', 'neck_01', 'Head']) {
        expect(mesh.hasJoint(bone), isTrue, reason: bone);
      }
      expect(mesh.hasJoint('no_such_bone'), isFalse);
      mesh.play(LuminaThirdPersonContent.idleClip);
      world.tick(1 / 60);
      final before = mesh.jointWorldTransform('Head')!;
      final headLocalBefore = mesh.jointLocalTransform('Head')!;

      mesh.setJointOverride('Head', rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 30 * math.pi / 180));
      expect(mesh.jointOverrides.keys, ['Head']);
      world.tick(1 / 60);
      final after = mesh.jointWorldTransform('Head')!;
      expect(degreesBetween(before, after), closeTo(30.0, 1.5), reason: 'the idle clip barely moves the head in a frame');
      expect((after.getTranslation() - before.getTranslation()).length, lessThan(2.0), reason: 'a rotation about the joint origin');
      // The override does not accumulate frame over frame.
      for (var i = 0; i < 10; i++) {
        world.tick(1 / 60);
      }
      expect(degreesBetween(before, mesh.jointWorldTransform('Head')!), closeTo(30.0, 3.0));

      mesh.clearJointOverride('Head');
      expect(mesh.jointOverrides, isEmpty);
      world.tick(1 / 60);
      final restored = mesh.jointWorldTransform('Head')!;
      expect(degreesBetween(before, restored), lessThan(3.0));
      expect(degreesBetween(headLocalBefore, mesh.jointLocalTransform('Head')!), lessThan(3.0));

      // A bone the mesh lacks: logged once (one entry however many frames), no throw, still listed.
      expect(mesh.missingJointOverrideBones, isEmpty);
      mesh.setJointOverride('no_such_bone', rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 0.3));
      world.tick(1 / 60);
      world.tick(1 / 60);
      expect(mesh.jointOverrides.keys, ['no_such_bone']);
      expect(mesh.missingJointOverrideBones, {'no_such_bone'});
      expect(mesh.jointWorldTransform('no_such_bone'), isNull);
    });

    test('an override on a mesh with no clip playing holds against the bind pose', () async {
      if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: bundle);
      world.persistentLevel.registerActor(LuminaActor(root: mesh));
      world.beginPlay();
      await mesh.loaded;
      final before = mesh.jointWorldTransform('neck_01')!;
      mesh.setJointOverride('neck_01', rotation: Quaternion.axisAngle(Vector3(0, 0, 1), 20 * math.pi / 180));
      for (var i = 0; i < 5; i++) {
        world.tick(1 / 60);
      }
      expect(degreesBetween(before, mesh.jointWorldTransform('neck_01')!), closeTo(20.0, 0.5), reason: 'no accumulation without a clip');
      mesh.clearJointOverride('neck_01');
      expect(degreesBetween(before, mesh.jointWorldTransform('neck_01')!), lessThan(0.5), reason: 'restored at once');
    });
  });
}
