import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('SkinningBufferBridge Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      engine.flushAndWait();
      engine.dispose();
    });

    test('Identity globals + identity IBMs test', () {
      final bridge = FilamentSkinningBufferBridge.create(engine, boneCount: 2);
      
      final root = BoneNode(id: 0, name: 'root');
      final c1 = BoneNode(id: 1, name: 'c1', parentIndex: 0);
      final skeleton = Skeleton([root, c1]);
      skeleton.updateGlobalTransforms();

      bridge.updateSkinningMatrices(skeleton);
      final floats = bridge.skinningTransforms;

      // Check first bone
      expect(floats.sublist(0, 16), equals(Matrix4.identity().storage));
      // Check second bone
      expect(floats.sublist(16, 32), equals(Matrix4.identity().storage));
      
      bridge.dispose();
    });

    test('Translation G * IBM order and GC-free multiplication', () {
      final bridge = FilamentSkinningBufferBridge.create(engine, boneCount: 1);
      
      final root = BoneNode(id: 0, name: 'root');
      final skeleton = Skeleton([root]);
      
      root.translation.setValues(1, 2, 3);
      root.composeLocal();
      skeleton.updateGlobalTransforms();
      
      root.inverseBindMatrix.setTranslationRaw(-1, -2, -3);

      bridge.updateSkinningMatrices(skeleton);
      
      // If order is G * IBM, then Translation(1,2,3) * Translation(-1,-2,-3) = Identity
      expect(bridge.skinningTransforms.sublist(0, 16), equals(Matrix4.identity().storage));
      
      bridge.dispose();
    });

    test('Column-major layout validation', () {
      final bridge = FilamentSkinningBufferBridge.create(engine, boneCount: 1);
      final root = BoneNode(id: 0, name: 'root');
      final skeleton = Skeleton([root]);
      
      // Global rotate 90 about Z
      root.rotation.setAxisAngle(Vector3(0, 0, 1), radians(90.0));
      root.composeLocal();
      skeleton.updateGlobalTransforms();

      bridge.updateSkinningMatrices(skeleton);
      
      final floats = bridge.skinningTransforms;
      // column 0
      expect(floats[0], closeTo(0, 1e-6));
      expect(floats[1], closeTo(1, 1e-6)); // sin(90)
      expect(floats[2], closeTo(0, 1e-6));
      expect(floats[3], closeTo(0, 1e-6));
      // column 1
      expect(floats[4], closeTo(-1, 1e-6)); // -sin(90)
      expect(floats[5], closeTo(0, 1e-6));
      expect(floats[6], closeTo(0, 1e-6));
      expect(floats[7], closeTo(0, 1e-6));
      
      bridge.dispose();
    });

    test('Requested vs Palette BoneCount', () {
      final bridge = FilamentSkinningBufferBridge.create(engine, boneCount: 100);
      expect(bridge.requestedBoneCount, equals(100));
      expect(bridge.paletteBoneCount, equals(256));
      
      // Upload should not throw
      bridge.upload();
      
      bridge.dispose();
    });

    test('Float32List view reuse', () {
      final bridge = FilamentSkinningBufferBridge.create(engine, boneCount: 1);
      final root = BoneNode(id: 0, name: 'root');
      final skeleton = Skeleton([root]);
      
      bridge.updateSkinningMatrices(skeleton);
      final list1 = bridge.skinningTransforms;
      
      root.translation.setValues(10, 0, 0);
      root.composeLocal();
      skeleton.updateGlobalTransforms();
      
      bridge.updateSkinningMatrices(skeleton);
      final list2 = bridge.skinningTransforms;
      
      expect(identical(list1, list2), isTrue);
      
      bridge.dispose();
    });

    test('ArgumentError on capacity exceeded', () {
      final bridge = FilamentSkinningBufferBridge.create(engine, boneCount: 2);
      
      final root = BoneNode(id: 0, name: 'r');
      final c1 = BoneNode(id: 1, name: '1', parentIndex: 0);
      final c2 = BoneNode(id: 2, name: '2', parentIndex: 1);
      final skeleton = Skeleton([root, c1, c2]);
      
      expect(() => bridge.updateSkinningMatrices(skeleton), throwsArgumentError);
      
      bridge.dispose();
    });

    test('RangeError on bad upload bounds', () {
      final bridge = FilamentSkinningBufferBridge.create(engine, boneCount: 100);
      // Attempt to upload 100 bones starting at offset 200, which exceeds 256.
      expect(() => bridge.upload(offset: 200), throwsRangeError);
      bridge.dispose();
    });

    test('dispose memory release and double dispose', () {
      final bridge = FilamentSkinningBufferBridge.create(engine, boneCount: 1);
      bridge.dispose();
      
      expect(() => bridge.upload(), throwsStateError);
      
      // Double dispose should be a no-op
      bridge.dispose();
    });
  });
}
