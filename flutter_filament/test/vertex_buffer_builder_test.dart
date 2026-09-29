import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Generic VertexBuffer & Attribute Builder Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('AttributeType (all 26 values) and VertexAttribute enum audit against C', () {
      for (final type in AttributeType.values) {
        final cVal = c.filament_enum_attribute_type(type.value);
        expect(cVal, equals(type.value),
            reason: 'Mismatch for AttributeType.${type.name}');
      }

      for (final attr in VertexAttribute.values) {
        final cVal = c.filament_enum_vertex_attribute(attr.value);
        expect(cVal, equals(attr.value),
            reason: 'Mismatch for VertexAttribute.${attr.name}');
      }
    });

    test('Single-buffer interleaved layout: pos(float3)@0 + uv(float2)@12 + color(ubyte4, norm)@20 (stride 24)', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        attributes: const [
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

      expect(vb.vertexCount, equals(4));
      expect(vb.bufferCount, equals(1));
      expect(vb.attributes.length, equals(3));

      final vertexData = Uint8List(4 * 24);
      final byteData = ByteData.sublistView(vertexData);

      // Vertex 0: pos=(-1,-1,0), uv=(0,0), color=(255,0,0,255)
      byteData.setFloat32(0, -1.0, Endian.host);
      byteData.setFloat32(4, -1.0, Endian.host);
      byteData.setFloat32(8, 0.0, Endian.host);
      byteData.setFloat32(12, 0.0, Endian.host);
      byteData.setFloat32(16, 0.0, Endian.host);
      vertexData[20] = 255; // R
      vertexData[21] = 0;   // G
      vertexData[22] = 0;   // B
      vertexData[23] = 255; // A

      vb.setData(vertexData, bufferIndex: 0);

      engine.flushAndWait();
      vb.dispose();
      expect(vb.isDisposed, isTrue);
    });

    test('Two-buffer layout: positions in buffer 0 (float3, tight), colors in buffer 1 (float4, tight)', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 2,
        attributes: const [
          VertexAttributeDesc(
            attribute: VertexAttribute.position,
            bufferIndex: 0,
            type: AttributeType.float3,
            byteOffset: 0,
            byteStride: 12,
          ),
          VertexAttributeDesc(
            attribute: VertexAttribute.color,
            bufferIndex: 1,
            type: AttributeType.float4,
            byteOffset: 0,
            byteStride: 16,
          ),
        ],
      );

      expect(vb.vertexCount, equals(4));
      expect(vb.bufferCount, equals(2));

      final posData = Float32List(4 * 3);
      final colData = Float32List(4 * 4);

      vb.setData(posData, bufferIndex: 0);
      vb.setData(colData, bufferIndex: 1);

      engine.flushAndWait();
      vb.dispose();
    });

    test('Non-zero byteOffset within a buffer: 12 padding bytes followed by pos(float3)', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        attributes: const [
          VertexAttributeDesc(
            attribute: VertexAttribute.position,
            bufferIndex: 0,
            type: AttributeType.float3,
            byteOffset: 12, // Preceded by 12 junk bytes
            byteStride: 12,
          ),
        ],
      );

      final data = Uint8List(12 + 4 * 12);
      vb.setData(data, bufferIndex: 0);

      engine.flushAndWait();
      vb.dispose();
    });

    test('Preset constructors: positions, positionsAndColors, positionsAndUvs', () {
      final vbPos = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 3,
      );
      expect(vbPos.vertexCount, equals(3));
      expect(vbPos.bufferCount, equals(1));
      expect(vbPos.attributes.length, equals(1));
      expect(vbPos.attributes[0].attribute, equals(VertexAttribute.position));
      expect(vbPos.attributes[0].type, equals(AttributeType.float3));
      vbPos.dispose();

      final vbCol = FilamentVertexBuffer.positionsAndColors(
        engine: engine,
        vertexCount: 3,
      );
      expect(vbCol.vertexCount, equals(3));
      expect(vbCol.attributes.length, equals(2));
      expect(vbCol.attributes[1].attribute, equals(VertexAttribute.color));
      expect(vbCol.attributes[1].type, equals(AttributeType.ubyte4));
      expect(vbCol.attributes[1].normalized, isTrue);
      vbCol.dispose();

      final vbUv = FilamentVertexBuffer.positionsAndUvs(
        engine: engine,
        vertexCount: 3,
      );
      expect(vbUv.vertexCount, equals(3));
      expect(vbUv.attributes.length, equals(2));
      expect(vbUv.attributes[1].attribute, equals(VertexAttribute.uv0));
      expect(vbUv.attributes[1].type, equals(AttributeType.float2));
      vbUv.dispose();
    });

    test('Stride > 255 validation error on Dart side', () {
      expect(
        () => FilamentVertexBuffer.create(
          engine: engine,
          vertexCount: 4,
          attributes: const [
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
