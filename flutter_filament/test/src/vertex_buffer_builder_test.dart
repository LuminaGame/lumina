import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Vertex Buffer Builder Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Interleaved single buffer layout (pos + uv + color)', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        bufferCount: 1,
        vertexCount: 4,
        attributes: [
          VertexAttributeDesc(
            attribute: VertexAttribute.position,
            bufferIndex: 0,
            type: AttributeType.float3,
            byteOffset: 0,
            byteStride: 24,
          ),
          VertexAttributeDesc(
            attribute: VertexAttribute.uv0,
            bufferIndex: 0,
            type: AttributeType.float2,
            byteOffset: 12,
            byteStride: 24,
          ),
          VertexAttributeDesc(
            attribute: VertexAttribute.color,
            bufferIndex: 0,
            type: AttributeType.ubyte4,
            byteOffset: 20,
            byteStride: 24,
            normalized: true,
          ),
        ],
      );

      expect(vb.isDisposed, isFalse);
      expect(vb.bufferCount, 1);
      expect(vb.vertexCount, 4);

      final data = Float32List(4 * (24 ~/ 4));
      vb.setData(data, bufferIndex: 0);
      
      vb.dispose();
    });

    test('Two-buffer layout', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        bufferCount: 2,
        vertexCount: 4,
        attributes: [
          VertexAttributeDesc(
            attribute: VertexAttribute.position,
            bufferIndex: 0,
            type: AttributeType.float3,
            byteOffset: 0,
            byteStride: 12, // tight float3
          ),
          VertexAttributeDesc(
            attribute: VertexAttribute.color,
            bufferIndex: 1,
            type: AttributeType.float4,
            byteOffset: 0,
            byteStride: 16, // tight float4
          ),
        ],
      );

      expect(vb.isDisposed, isFalse);
      
      final posData = Float32List(4 * 3);
      final colData = Float32List(4 * 4);
      
      vb.setData(posData, bufferIndex: 0);
      vb.setData(colData, bufferIndex: 1);

      vb.dispose();
    });

    test('Non-zero byteOffset within a buffer', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        bufferCount: 1,
        vertexCount: 4,
        attributes: [
          VertexAttributeDesc(
            attribute: VertexAttribute.position,
            bufferIndex: 0,
            type: AttributeType.float3,
            byteOffset: 12, // 12 junk bytes
            byteStride: 24,
          ),
        ],
      );

      expect(vb.isDisposed, isFalse);
      vb.dispose();
    });

    test('Preset regression - positions', () {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
      );
      expect(vb.bufferCount, 1);
      expect(vb.attributes.length, 1);
      expect(vb.attributes[0].attribute, VertexAttribute.position);
      expect(vb.attributes[0].type, AttributeType.float3);
      expect(vb.attributes[0].byteStride, 12);
      vb.dispose();
    });

    test('Preset regression - positionsAndColors', () {
      final vb = FilamentVertexBuffer.positionsAndColors(
        engine: engine,
        vertexCount: 4,
      );
      expect(vb.bufferCount, 1);
      expect(vb.attributes.length, 2);
      expect(vb.attributes[0].attribute, VertexAttribute.position);
      expect(vb.attributes[1].attribute, VertexAttribute.color);
      expect(vb.attributes[1].type, AttributeType.ubyte4);
      expect(vb.attributes[1].normalized, isTrue);
      expect(vb.attributes[1].byteOffset, 12);
      vb.dispose();
    });

    test('Preset regression - positionsAndUvs', () {
      final vb = FilamentVertexBuffer.positionsAndUvs(
        engine: engine,
        vertexCount: 4,
      );
      expect(vb.bufferCount, 1);
      expect(vb.attributes.length, 2);
      expect(vb.attributes[0].type, AttributeType.float2);
      expect(vb.attributes[1].attribute, VertexAttribute.uv0);
      expect(vb.attributes[1].byteOffset, 8);
      vb.dispose();
    });

    test('Stride > 255 throws ArgumentError', () {
      expect(
        () => FilamentVertexBuffer.create(
          engine: engine,
          vertexCount: 4,
          attributes: [
            VertexAttributeDesc(
              attribute: VertexAttribute.position,
              type: AttributeType.float3,
              byteStride: 256,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
