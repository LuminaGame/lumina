import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

class FakeFilamentVertexBuffer implements FilamentVertexBuffer {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFilamentIndexBuffer implements FilamentIndexBuffer {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFilamentMaterialInstance implements FilamentMaterialInstance {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeInstanceBuffer implements InstanceBuffer {
  final int capacity;
  final List<({Float32List data, int count, int offset})> uploads = [];

  FakeInstanceBuffer({required this.capacity});

  @override
  void setLocalTransforms(Float32List transforms, {int? count, int offset = 0}) {
    final actualCount = count ?? (transforms.length ~/ 16);
    uploads.add((
      data: Float32List.fromList(transforms.sublist(0, actualCount * 16)),
      count: actualCount,
      offset: offset,
    ));
  }

  @override
  int get instanceCount => capacity;

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LuminaInstancedStaticMeshComponent', () {
    late FakeFilamentVertexBuffer vb0;
    late FakeFilamentIndexBuffer ib0;
    late FakeFilamentVertexBuffer vb1;
    late FakeFilamentIndexBuffer ib1;
    late FakeFilamentMaterialInstance mat;

    setUp(() {
      vb0 = FakeFilamentVertexBuffer();
      ib0 = FakeFilamentIndexBuffer();
      vb1 = FakeFilamentVertexBuffer();
      ib1 = FakeFilamentIndexBuffer();
      mat = FakeFilamentMaterialInstance();
    });

    test('addInstance ×3 with translations: column-major packing in Float32List staging', () {
      final fakeBuffer = FakeInstanceBuffer(capacity: 128);
      final ismc = LuminaInstancedStaticMeshComponent(
        lods: [
          LuminaStaticMeshLod(vb: vb0, ib: ib0, indexCount: 6, switchDistance: 50.0),
        ],
        material: mat,
        capacity: 128,
        instanceBufferOverride: fakeBuffer,
      );

      final idx0 = ismc.addInstance(Matrix4.translationValues(0.0, 0.0, 0.0));
      final idx1 = ismc.addInstance(Matrix4.translationValues(2.0, 0.0, 0.0));
      final idx2 = ismc.addInstance(Matrix4.translationValues(4.0, 0.0, 0.0));

      expect(idx0, equals(0));
      expect(idx1, equals(1));
      expect(idx2, equals(2));
      expect(ismc.instanceCount, equals(3));

      // Trigger render prep
      ismc.flushTransformsToGpu();

      expect(fakeBuffer.uploads, hasLength(1));
      final upload = fakeBuffer.uploads.first;
      expect(upload.offset, equals(0));
      expect(upload.count, equals(3));

      // Verify translations at column 3 (floats 12..14, 28..30, 44..46)
      expect(upload.data[12], equals(0.0));
      expect(upload.data[28], equals(2.0));
      expect(upload.data[44], equals(4.0));
    });

    test('updateInstanceTransform windowing: single or multi-instance update batched in one upload', () {
      final fakeBuffer = FakeInstanceBuffer(capacity: 128);
      final ismc = LuminaInstancedStaticMeshComponent(
        lods: [
          LuminaStaticMeshLod(vb: vb0, ib: ib0, indexCount: 6, switchDistance: 50.0),
        ],
        material: mat,
        capacity: 128,
        instanceBufferOverride: fakeBuffer,
      );

      ismc.addInstance(Matrix4.identity());
      ismc.addInstance(Matrix4.identity());
      ismc.addInstance(Matrix4.identity());
      ismc.addInstance(Matrix4.identity());
      ismc.flushTransformsToGpu();
      fakeBuffer.uploads.clear();

      // Update slot 1 only
      ismc.updateInstanceTransform(1, Matrix4.translationValues(10.0, 0.0, 0.0));
      ismc.flushTransformsToGpu();

      expect(fakeBuffer.uploads, hasLength(1));
      expect(fakeBuffer.uploads.first.offset, equals(1));
      expect(fakeBuffer.uploads.first.count, equals(1));
      expect(fakeBuffer.uploads.first.data[12], equals(10.0));
      fakeBuffer.uploads.clear();

      // Update slots 1 and 3 in same frame -> windowed upload [1..3] count: 3
      ismc.updateInstanceTransform(1, Matrix4.translationValues(15.0, 0.0, 0.0));
      ismc.updateInstanceTransform(3, Matrix4.translationValues(30.0, 0.0, 0.0));
      ismc.flushTransformsToGpu();

      expect(fakeBuffer.uploads, hasLength(1));
      expect(fakeBuffer.uploads.first.offset, equals(1));
      expect(fakeBuffer.uploads.first.count, equals(3));
      fakeBuffer.uploads.clear();

      // No changes -> zero uploads
      ismc.flushTransformsToGpu();
      expect(fakeBuffer.uploads, isEmpty);
    });

    test('removeInstance with swap-remove: moves last instance to removed slot and zeroes old slot', () {
      final fakeBuffer = FakeInstanceBuffer(capacity: 128);
      int? relocatedFrom;
      int? relocatedTo;

      final ismc = LuminaInstancedStaticMeshComponent(
        lods: [
          LuminaStaticMeshLod(vb: vb0, ib: ib0, indexCount: 6, switchDistance: 50.0),
        ],
        material: mat,
        capacity: 128,
        instanceBufferOverride: fakeBuffer,
        onInstanceRelocated: (from, to) {
          relocatedFrom = from;
          relocatedTo = to;
        },
      );

      ismc.addInstance(Matrix4.translationValues(0.0, 0.0, 0.0));
      ismc.addInstance(Matrix4.translationValues(1.0, 0.0, 0.0));
      ismc.addInstance(Matrix4.translationValues(2.0, 0.0, 0.0));
      ismc.flushTransformsToGpu();
      fakeBuffer.uploads.clear();

      // Remove slot 0 (slot 2 should move into slot 0)
      final removed = ismc.removeInstance(0);
      expect(removed, isTrue);
      expect(ismc.instanceCount, equals(2));
      expect(relocatedFrom, equals(2));
      expect(relocatedTo, equals(0));

      // After removal, instance 0 now has translation 2.0
      expect(ismc.instanceTransform(0).getTranslation().x, equals(2.0));

      ismc.flushTransformsToGpu();
      expect(fakeBuffer.uploads, hasLength(1));
      final upload = fakeBuffer.uploads.first;
      expect(upload.offset, equals(0));
      expect(upload.count, equals(3));

      // Slot 2 was parked at zero-scale (all zeros)
      expect(upload.data[32 + 0], equals(0.0));
      expect(upload.data[32 + 5], equals(0.0));
      expect(upload.data[32 + 10], equals(0.0));
    });

    test('Capacity and constructor validation', () {
      // Exceeding 32767 -> ArgumentError
      expect(
        () => LuminaInstancedStaticMeshComponent(
          lods: [LuminaStaticMeshLod(vb: vb0, ib: ib0, indexCount: 6, switchDistance: 50.0)],
          material: mat,
          capacity: 40000,
        ),
        throwsArgumentError,
      );

      // Non-increasing LOD switch distance -> ArgumentError
      expect(
        () => LuminaInstancedStaticMeshComponent(
          lods: [
            LuminaStaticMeshLod(vb: vb0, ib: ib0, indexCount: 6, switchDistance: 50.0),
            LuminaStaticMeshLod(vb: vb1, ib: ib1, indexCount: 3, switchDistance: 20.0),
          ],
          material: mat,
          capacity: 128,
        ),
        throwsArgumentError,
      );

      final ismc = LuminaInstancedStaticMeshComponent(
        lods: [LuminaStaticMeshLod(vb: vb0, ib: ib0, indexCount: 6, switchDistance: 50.0)],
        material: mat,
        capacity: 2,
      );
      ismc.addInstance(Matrix4.identity());
      ismc.addInstance(Matrix4.identity());

      expect(() => ismc.addInstance(Matrix4.identity()), throwsStateError);
    });

    test('Combined bounds grow-only and recalculateBounds', () {
      final ismc = LuminaInstancedStaticMeshComponent(
        lods: [LuminaStaticMeshLod(vb: vb0, ib: ib0, indexCount: 6, switchDistance: 50.0)],
        material: mat,
        capacity: 128,
      );

      ismc.addInstance(Matrix4.translationValues(0.0, 0.0, 0.0));
      ismc.addInstance(Matrix4.translationValues(100.0, 0.0, 0.0));

      expect(ismc.combinedBounds.min.x, equals(0.0));
      expect(ismc.combinedBounds.max.x, equals(100.0));

      // Remove the instance at 100.0; bounds remain grow-only until recalculateBounds()
      ismc.removeInstance(1);
      expect(ismc.combinedBounds.max.x, equals(100.0));

      ismc.recalculateBounds();
      expect(ismc.combinedBounds.max.x, equals(0.0));
    });
  });
}
