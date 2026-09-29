// vertex_buffer smoke: generic attribute layouts, setBufferAt with byte
// offsets and BufferObject-backed vertex buffers, all rendered on the GPU.
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('VertexBuffer Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('VertexBuffer: descriptor fidelity and partial setBufferAt update renders', () {
      final vb = FilamentVertexBuffer.positionsAndColors(engine: rig.engine, vertexCount: 4);
      expect(vb.vertexCount, 4);
      expect(vb.attributes.map((a) => a.attribute), [VertexAttribute.position, VertexAttribute.color]);
      expect(vb.attributes[1].byteStride, 16);

      // Interleaved: float3 position + ubyte4 colour, all vertices red.
      final bytes = ByteData(4 * 16);
      const pos = [-0.8, -0.8, 0.8, -0.8, 0.8, 0.8, -0.8, 0.8];
      for (var v = 0; v < 4; v++) {
        bytes.setFloat32(v * 16 + 0, pos[v * 2], Endian.little);
        bytes.setFloat32(v * 16 + 4, pos[v * 2 + 1], Endian.little);
        bytes.setFloat32(v * 16 + 8, 0, Endian.little);
        bytes.setUint8(v * 16 + 12, 255);
        bytes.setUint8(v * 16 + 13, 0);
        bytes.setUint8(v * 16 + 14, 0);
        bytes.setUint8(v * 16 + 15, 255);
      }
      vb.setData(bytes.buffer.asUint8List());

      // Partial update: recolour vertices 2 and 3 green via byte offset.
      final patch = ByteData(2 * 16);
      for (var v = 0; v < 2; v++) {
        patch.setFloat32(v * 16 + 0, pos[(v + 2) * 2], Endian.little);
        patch.setFloat32(v * 16 + 4, pos[(v + 2) * 2 + 1], Endian.little);
        patch.setFloat32(v * 16 + 8, 0, Endian.little);
        patch.setUint8(v * 16 + 12, 0);
        patch.setUint8(v * 16 + 13, 255);
        patch.setUint8(v * 16 + 14, 0);
        patch.setUint8(v * 16 + 15, 255);
      }
      vb.setBufferAt(rig.engine, 0, NativeBuffer.copy(patch.buffer.asUint8List()), byteOffset: 32, autoFree: true);

      final ib = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 6, type: IndexType.ushort);
      ib.setUint16Data(Uint16List.fromList([0, 1, 2, 0, 2, 3]));
      final material = buildUnlitMaterial(rig.engine, vertexColor: true);
      final mi = material.createInstance()..setFloat3('baseColor', 1, 1, 1);
      addQuadRenderable(rig, SmokeQuad(vb, ib), mi);

      final px = rig.screenshot('VertexBuffer Smoke Tests VertexBuffer: descriptor fidelity and partial setBufferAt update renders');
      // Bottom edge (vertices 0,1) red; top edge (vertices 2,3) green.
      final (br, bg, _) = pixelAt(px, rig.width, 128, 220);
      final (tr, tg, _) = pixelAt(px, rig.width, 128, 36);
      print('bottom=($br,$bg) top=($tr,$tg)');
      expect(br, greaterThan(180));
      expect(bg, lessThan(60));
      expect(tg, greaterThan(180));
      expect(tr, lessThan(60));

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      ib.dispose();
      vb.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('VertexBuffer: BufferObject-backed vertex buffer renders a quad', () {
      final vb = FilamentVertexBuffer.create(
        engine: rig.engine,
        vertexCount: 4,
        bufferCount: 1,
        enableBufferObjects: true,
        attributes: const [
          VertexAttributeDesc(attribute: VertexAttribute.position, bufferIndex: 0, type: AttributeType.float3, byteOffset: 0, byteStride: 12),
        ],
      );
      expect(vb.enableBufferObjects, isTrue);
      final positions = Float32List.fromList([-0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0]);
      final bo = FilamentBufferObject.create(engine: rig.engine, byteCount: positions.lengthInBytes);
      bo.setData(positions);
      vb.setBufferObjectAt(rig.engine, 0, bo);
      expect(() => vb.setData(positions), throwsStateError, reason: 'BO-backed VB rejects setData');

      final ib = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 6, type: IndexType.ushort);
      ib.setUint16Data(Uint16List.fromList([0, 1, 2, 0, 2, 3]));
      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 0.1, 0.9, 0.9);
      addQuadRenderable(rig, SmokeQuad(vb, ib), mi);

      final px = rig.screenshot('VertexBuffer Smoke Tests VertexBuffer: BufferObject-backed vertex buffer renders a quad');
      final fg = countForegroundPixels(px, rig.width);
      print('bufferObject quad foreground=$fg');
      // Quad spans half the ortho frustum: ~25% of 256x256.
      expect(fg, inInclusiveRange(rig.width * rig.height ~/ 6, rig.width * rig.height ~/ 3));

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      ib.dispose();
      vb.dispose();
      bo.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('VertexBuffer: custom two-buffer layout uploads and disposes cleanly', () {
      // Moved from vertex_index_buffer_smoke_test.dart.
      final vb = FilamentVertexBuffer.create(
        engine: rig.engine, vertexCount: 5, bufferCount: 2,
        attributes: const [
          VertexAttributeDesc(attribute: VertexAttribute.position, bufferIndex: 0, type: AttributeType.float3, byteStride: 12),
          VertexAttributeDesc(attribute: VertexAttribute.uv0, bufferIndex: 1, type: AttributeType.float2, byteStride: 8),
        ],
      );
      expect(vb.vertexCount, 5);
      expect(vb.bufferCount, 2);
      expect(vb.attributes.length, 2);
      vb.setData(Float32List(5 * 3), bufferIndex: 0);
      vb.setData(Float32List(5 * 2), bufferIndex: 1);
      expect(() => vb.setData(Float32List(4), bufferIndex: 2), throwsRangeError);
      rig.engine.flushAndWait();
      rig.engine.pumpMessageQueues();
      vb.dispose();
      expect(vb.isDisposed, isTrue);
    });
  });
}
