import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('Skeleton and FK', () {
    test('3-bone chain root->A->B propagation', () {
      final root = BoneNode(id: 0, name: 'root');
      root.translation.setValues(1, 0, 0);
      root.composeLocal();

      final a = BoneNode(id: 1, name: 'A', parentIndex: 0);
      a.translation.setValues(1, 0, 0);
      a.composeLocal();

      final b = BoneNode(id: 2, name: 'B', parentIndex: 1);
      b.translation.setValues(1, 0, 0);
      b.composeLocal();

      final skeleton = Skeleton([root, a, b]);
      skeleton.updateGlobalTransforms();

      expect(root.globalTransform.getTranslation().x, closeTo(1.0, 1e-6));
      expect(a.globalTransform.getTranslation().x, closeTo(2.0, 1e-6));
      expect(b.globalTransform.getTranslation().x, closeTo(3.0, 1e-6));
    });

    test('Rotation propagation order (G_parent * T_local)', () {
      final root = BoneNode(id: 0, name: 'root');
      // Root rotated 90 degrees around Y axis
      root.rotation.setAxisAngle(Vector3(0, 1, 0), radians(90.0));
      root.composeLocal();

      final a = BoneNode(id: 1, name: 'A', parentIndex: 0);
      a.translation.setValues(1, 0, 0);
      a.composeLocal();

      final skeleton = Skeleton([root, a]);
      skeleton.updateGlobalTransforms();

      // If A is locally at (1,0,0) and parent is rotated 90 deg around Y,
      // A's global translation should be (0, 0, -1).
      final g = a.globalTransform.getTranslation();
      expect(g.x, closeTo(0.0, 1e-5));
      expect(g.y, closeTo(0.0, 1e-5));
      expect(g.z, closeTo(-1.0, 1e-5));
    });

    test('Constructor throws ArgumentError on bad topological order', () {
      final root = BoneNode(id: 0, name: 'root');
      final b = BoneNode(id: 2, name: 'B', parentIndex: 2); // invalid, refers to self or later
      final a = BoneNode(id: 1, name: 'A', parentIndex: 2); // child before parent

      expect(
        () => Skeleton([root, a, b]),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains('Topological order'))),
      );
    });

    test('indexOfBone is O(1) backed by map', () {
      final bones = List.generate(
          10, (i) => BoneNode(id: i, name: 'bone_$i', parentIndex: i > 0 ? i - 1 : -1));
      bones[3] = BoneNode(id: 3, name: 'spine_01', parentIndex: 2); // overriding 3

      final skeleton = Skeleton(bones);
      expect(skeleton.indexOfBone('spine_01'), equals(3));
      expect(skeleton.indexOfBone('nope'), equals(-1));
      
      // Lookups shouldn't crash or take long
      for (int i = 0; i < 1000; i++) {
        skeleton.indexOfBone('spine_01');
      }
    });

    test('Multi-root propagation', () {
      final root1 = BoneNode(id: 0, name: 'root1');
      final child1 = BoneNode(id: 1, name: 'c1', parentIndex: 0);
      final root2 = BoneNode(id: 2, name: 'root2');
      final child2 = BoneNode(id: 3, name: 'c2', parentIndex: 2);
      
      final skeleton = Skeleton([root1, child1, root2, child2]);
      expect(skeleton.rootIndices, equals([0, 2]));
    });

    test('TransformCurve sampling, binary search, clamping', () {
      final times = Float32List.fromList([0.0, 2.0]);
      final translations = [Vector3(0, 0, 0), Vector3(2, 0, 0)];
      final rotations = [Quaternion.identity(), Quaternion.identity()];
      final scales = [Vector3(1, 1, 1), Vector3(1, 1, 1)];

      final curve = TransformCurve(times, translations, rotations, scales);
      final bone = BoneNode(id: 0, name: 'b');
      
      curve.sampleInto(1.0, bone);
      expect(bone.translation.x, closeTo(1.0, 1e-6));

      curve.sampleInto(-1.0, bone);
      expect(bone.translation.x, closeTo(0.0, 1e-6));

      curve.sampleInto(5.0, bone);
      expect(bone.translation.x, closeTo(2.0, 1e-6));
    });

    test('TransformCurve custom rotation slerp double-cover guard', () {
      final times = Float32List.fromList([0.0, 1.0]);
      final translations = [Vector3.zero(), Vector3.zero()];
      final scales = [Vector3.all(1.0), Vector3.all(1.0)];
      
      // 0 to 180 yaw
      final q0 = Quaternion.identity();
      final q1 = Quaternion.axisAngle(Vector3(0, 1, 0), radians(180.0));
      // make q1 antipodal to ensure short-way interpolation
      final q1Antipodal = Quaternion(-q1.x, -q1.y, -q1.z, -q1.w);
      final rotations = [q0, q1Antipodal];
      
      final curve = TransformCurve(times, translations, rotations, scales);
      final bone = BoneNode(id: 0, name: 'b');
      
      curve.sampleInto(0.5, bone);
      
      // Should be 90 degrees yaw
      final rotatedForward = bone.rotation.rotate(Vector3(0, 0, 1));
      expect(rotatedForward.x, closeTo(-1.0, 1e-2)); // Z turned to -X
      expect(rotatedForward.y, closeTo(0.0, 1e-2));
      expect(rotatedForward.z, closeTo(0.0, 1e-2));
    });

    test('Zero allocation pass via mutability check', () {
      final bones = List.generate(
          100, (i) => BoneNode(id: i, name: 'bone_$i', parentIndex: i > 0 ? i - 1 : -1));
      final skeleton = Skeleton(bones);
      
      skeleton.updateGlobalTransforms();
      final transformsAfterFirst = bones.map((b) => b.globalTransform).toList();
      
      bones[50].composeLocal();
      skeleton.updateGlobalTransforms();
      
      for (int i = 0; i < 100; i++) {
        expect(identical(bones[i].globalTransform, transformsAfterFirst[i]), isTrue);
      }
    });

    test('resetToBindPose round-trip', () {
      final bone = BoneNode(id: 0, name: 'b');
      bone.bindTranslation.setValues(5, 5, 5);
      bone.bindRotation.setAxisAngle(Vector3(1, 0, 0), radians(45.0));
      bone.bindScale.setValues(2, 2, 2);
      
      final skeleton = Skeleton([bone]);
      
      // Arbitrary changes
      bone.translation.setValues(0, 0, 0);
      bone.composeLocal();
      skeleton.updateGlobalTransforms();
      
      // Reset
      skeleton.resetToBindPose();
      skeleton.updateGlobalTransforms();
      
      expect(bone.translation.x, equals(5.0));
      expect(bone.scale.x, equals(2.0));
    });
  });
}
