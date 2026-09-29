import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('InstanceBuffer Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('packMatrices column-major order fidelity (pure Dart)', () {
      final t = Matrix4.identity()..setTranslationRaw(1.0, 2.0, 3.0);
      final packed = packMatrices([t]);
      expect(packed.length, equals(16));
      // In column-major layout:
      // Index 12 = tx (1.0), Index 13 = ty (2.0), Index 14 = tz (3.0), Index 15 = 1.0
      expect(packed[12], equals(1.0));
      expect(packed[13], equals(2.0));
      expect(packed[14], equals(3.0));
      expect(packed[15], equals(1.0));
      expect(packed[0], equals(1.0)); // diagonal
      expect(packed[5], equals(1.0)); // diagonal
      expect(packed[10], equals(1.0)); // diagonal
    });

    test('FilamentEngine maxAutomaticInstances getter', () {
      final maxInstances = engine.maxAutomaticInstances;
      expect(maxInstances, isNonZero);
      expect(maxInstances, greaterThanOrEqualTo(1));
    });

    test('InstanceBuffer lifecycle and initial transforms', () {
      final m0 = Matrix4.identity()..setTranslationRaw(0.0, 0.0, 0.0);
      final m1 = Matrix4.identity()..setTranslationRaw(2.0, 0.0, 0.0);
      final m2 = Matrix4.identity()..setTranslationRaw(4.0, 0.0, 0.0);
      final m3 = Matrix4.identity()..setTranslationRaw(6.0, 0.0, 0.0);
      final initialTransforms = packMatrices([m0, m1, m2, m3]);

      final ib = InstanceBuffer.create(
        engine,
        instanceCount: 4,
        localTransforms: initialTransforms,
      );

      expect(ib.isDisposed, isFalse);
      expect(ib.nativePointer, isNotNull);
      expect(ib.instanceCount, equals(4));

      final readT1 = ib.getLocalTransform(1);
      final trans1 = readT1.getTranslation();
      expect(trans1.x, closeTo(2.0, 1e-5));
      expect(trans1.y, closeTo(0.0, 1e-5));
      expect(trans1.z, closeTo(0.0, 1e-5));

      ib.dispose();
      expect(ib.isDisposed, isTrue);
      expect(() => ib.nativePointer, throwsStateError);
    });

    test('InstanceBuffer setLocalTransforms and partial offset update', () {
      final ib = InstanceBuffer.create(
        engine,
        instanceCount: 4,
      );

      final m9 = Matrix4.identity()..setTranslationRaw(9.0, 9.0, 9.0);
      final updateData = packMatrices([m9]);

      ib.setLocalTransforms(updateData, count: 1, offset: 2);

      final readT2 = ib.getLocalTransform(2);
      final trans2 = readT2.getTranslation();
      expect(trans2.x, closeTo(9.0, 1e-5));
      expect(trans2.y, closeTo(9.0, 1e-5));
      expect(trans2.z, closeTo(9.0, 1e-5));

      // Range errors
      expect(
        () => ib.setLocalTransforms(updateData, count: 1, offset: 4),
        throwsRangeError,
      );
      expect(
        () => ib.getLocalTransform(4),
        throwsRangeError,
      );
      expect(
        () => ib.getLocalTransform(-1),
        throwsRangeError,
      );

      ib.dispose();
    });

    test('InstanceBuffer integration with RenderableBuilder', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
      );
      final idxBuffer = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      final ib = InstanceBuffer.create(
        engine,
        instanceCount: 4,
      );

      final rm = FilamentRenderableManager(engine);
      final entity = engine.createEntity();

      RenderableBuilder(1)
        ..boundingBox(-10, -10, -10, 10, 10, 10)
        ..culling(false)
        ..instances(4, ib)
        ..geometry(0, PrimitiveType.triangles, vb, ib: idxBuffer)
        ..build(engine, entity);

      expect(rm.getInstanceCount(entity), equals(4));

      engine.flushAndWait();

      engine.destroyEntity(entity);
      ib.dispose();
      idxBuffer.dispose();
      vb.dispose();
    });
  });
}
