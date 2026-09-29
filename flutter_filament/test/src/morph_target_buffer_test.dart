import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('MorphTargetBuffer Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('packTangentFrame quantization fidelity (pure Dart)', () {
      final identityQuat = Quaternion(0.0, 0.0, 0.0, 1.0);
      final packedIdent = packTangentFrame(identityQuat);
      expect(packedIdent[0], equals(0));
      expect(packedIdent[1], equals(0));
      expect(packedIdent[2], equals(0));
      expect(packedIdent[3], equals(32767));

      final testVec = Vector4(-1.0, 1.0, 0.0, 0.5);
      final packedVec = packTangentFrame(testVec);
      expect(packedVec[0], equals(-32767));
      expect(packedVec[1], equals(32767));
      expect(packedVec[2], equals(0));
      expect(packedVec[3], equals(16384));

      // Clamping out of [-1, 1] range
      final packedClamp = packTangentFrame([-2.0, 2.0, 0.0, 1.0]);
      expect(packedClamp[0], equals(-32767));
      expect(packedClamp[1], equals(32767));
    });

    test('MorphTargetBuffer lifecycle and getters', () {
      final mtb = MorphTargetBuffer.create(
        engine,
        vertexCount: 4,
        count: 2,
        withPositions: true,
        withTangents: true,
      );

      expect(mtb.isDisposed, isFalse);
      expect(mtb.nativePointer, isNotNull);
      expect(mtb.vertexCount, equals(4));
      expect(mtb.count, equals(2));
      expect(mtb.hasPositions, isTrue);
      expect(mtb.hasTangents, isTrue);

      mtb.dispose();
      expect(mtb.isDisposed, isTrue);
      expect(() => mtb.nativePointer, throwsStateError);
    });

    test('MorphTargetBuffer setPositionsAt float3 and float4', () {
      final mtb = MorphTargetBuffer.create(
        engine,
        vertexCount: 4,
        count: 2,
      );

      // Target 0 with float3
      final float3Deltas = Float32List(12);
      expect(() => mtb.setPositionsAt(0, float3Deltas), returnsNormally);

      // Target 1 with float4
      final float4Deltas = Float32List(16);
      expect(() => mtb.setPositionsAt(1, float4Deltas, asFloat4: true), returnsNormally);

      // Partial window offset
      final twoVerticesFloat3 = Float32List(6);
      expect(() => mtb.setPositionsAt(0, twoVerticesFloat3, offset: 2), returnsNormally);

      // Range validation: offset + count > vertexCount (3 + 2 > 4)
      expect(
        () => mtb.setPositionsAt(0, twoVerticesFloat3, offset: 3),
        throwsRangeError,
      );

      // Target index out of bounds
      expect(
        () => mtb.setPositionsAt(2, float3Deltas),
        throwsRangeError,
      );
      expect(
        () => mtb.setPositionsAt(-1, float3Deltas),
        throwsRangeError,
      );

      mtb.dispose();
    });

    test('MorphTargetBuffer setTangentsAt and disabled tangents guard', () {
      final mtb = MorphTargetBuffer.create(
        engine,
        vertexCount: 4,
        count: 2,
        withTangents: true,
      );

      final tangents = Int16List(16);
      expect(() => mtb.setTangentsAt(0, tangents), returnsNormally);

      final twoTangents = Int16List(8);
      expect(() => mtb.setTangentsAt(0, twoTangents, offset: 2), returnsNormally);
      expect(() => mtb.setTangentsAt(0, twoTangents, offset: 3), throwsRangeError);

      mtb.dispose();

      // Disabled tangents
      final noTangentsMtb = MorphTargetBuffer.create(
        engine,
        vertexCount: 4,
        count: 2,
        withTangents: false,
      );
      expect(noTangentsMtb.hasTangents, isFalse);
      expect(
        () => noTangentsMtb.setTangentsAt(0, tangents),
        throwsStateError,
      );
      noTangentsMtb.dispose();
    });

    test('MorphTargetBuffer integration with RenderableBuilder and weights', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
      );
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      final mtb = MorphTargetBuffer.create(
        engine,
        vertexCount: 4,
        count: 2,
      );
      mtb.setPositionsAt(0, Float32List(12));
      mtb.setPositionsAt(1, Float32List(12));

      final rm = FilamentRenderableManager(engine);
      final entity = engine.createEntity();

      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..culling(false)
        ..morphing(2)
        ..morphingBuffer(mtb)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..build(engine, entity);

      expect(rm.getMorphTargetCount(entity), equals(2));

      rm.setMorphWeights(entity, Float32List.fromList([0.2, 0.8]));
      engine.flushAndWait();

      engine.destroyEntity(entity);
      mtb.dispose();
      ib.dispose();
      vb.dispose();
    });
  });
}
