import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('BufferObject & Shared Vertex Arena Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('BufferObject creation, byteCount query, and disposal', () {
      final bo = FilamentBufferObject.create(
        engine: engine,
        byteCount: 96,
        bindingType: BufferObjectBindingType.vertex,
      );

      expect(bo.byteCount, equals(96));
      expect(bo.bindingType, equals(BufferObjectBindingType.vertex));
      expect(bo.isDisposed, isFalse);

      bo.dispose();
      expect(bo.isDisposed, isTrue);
    });

    test('BufferObject binding to VertexBuffer via setBufferObjectAt', () {
      final bo = FilamentBufferObject.create(
        engine: engine,
        byteCount: 4 * 12, // 4 vertices of float3
      );

      final quadPositions = Float32List.fromList([
        -1.0, -1.0, 0.0,
         1.0, -1.0, 0.0,
        -1.0,  1.0, 0.0,
         1.0,  1.0, 0.0,
      ]);
      bo.setData(quadPositions);

      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        enableBufferObjects: true,
        attributes: const [
          VertexAttributeDesc(
            attribute: VertexAttribute.position,
            bufferIndex: 0,
            type: AttributeType.float3,
            byteOffset: 0,
            byteStride: 12,
          ),
        ],
      );

      expect(vb.enableBufferObjects, isTrue);
      vb.setBufferObjectAt(engine, 0, bo);

      engine.flushAndWait();
      vb.dispose();
      bo.dispose();
    });

    test('BufferObject shared between multiple VertexBuffers', () {
      final sharedBo = FilamentBufferObject.create(
        engine: engine,
        byteCount: 4 * 24, // 4 vertices of pos(float3) + uv(float2) + padding
      );

      final vertexData = Float32List(4 * 6);
      sharedBo.setData(vertexData);

      // VertexBuffer A reads positions from offset 0
      final vbA = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        enableBufferObjects: true,
        attributes: const [
          VertexAttributeDesc(
            attribute: VertexAttribute.position,
            bufferIndex: 0,
            type: AttributeType.float3,
            byteOffset: 0,
            byteStride: 24,
          ),
        ],
      );

      // VertexBuffer B reads UVs from offset 12
      final vbB = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        enableBufferObjects: true,
        attributes: const [
          VertexAttributeDesc(
            attribute: VertexAttribute.uv0,
            bufferIndex: 0,
            type: AttributeType.float2,
            byteOffset: 12,
            byteStride: 24,
          ),
        ],
      );

      vbA.setBufferObjectAt(engine, 0, sharedBo);
      vbB.setBufferObjectAt(engine, 0, sharedBo);

      // Single update to shared BufferObject
      final updateData = Float32List.fromList([1.0, 2.0, 3.0]);
      sharedBo.setData(updateData, byteOffset: 0);

      engine.flushAndWait();

      vbA.dispose();
      vbB.dispose();
      sharedBo.dispose();
    });

    test('Calling setBufferAt on enableBufferObjects VertexBuffer throws StateError', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        enableBufferObjects: true,
      );

      final dummy = Float32List(4 * 3);
      expect(
        () => vb.setData(dummy, bufferIndex: 0),
        throwsStateError,
      );

      vb.dispose();
    });

    test('Calling setBufferObjectAt on standard VertexBuffer throws StateError', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        enableBufferObjects: false,
      );

      final bo = FilamentBufferObject.create(
        engine: engine,
        byteCount: 48,
      );

      expect(
        () => vb.setBufferObjectAt(engine, 0, bo),
        throwsStateError,
      );

      vb.dispose();
      bo.dispose();
    });

    test('BufferObject range check on setBuffer throws RangeError on overflow', () {
      final bo = FilamentBufferObject.create(
        engine: engine,
        byteCount: 32,
      );

      final data = Uint8List(16);
      final nativeBuf = NativeBuffer.copy(data);

      // Fits in 32 bytes (offset 0..16)
      bo.setBuffer(engine, nativeBuf, byteOffset: 0);

      // Overflow (offset 20 + 16 = 36 > 32)
      expect(
        () => bo.setBuffer(engine, nativeBuf, byteOffset: 20),
        throwsRangeError,
      );

      nativeBuf.free();
      bo.dispose();
    });
  });
}
