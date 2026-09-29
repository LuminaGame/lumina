// skinning_buffer smoke: a quad whose top edge is bound to bone 1; the bone
// matrix is animated through a SkinningBuffer so the quad shears frame by
// frame (recorded as a WebM), and the deformation is asserted on pixels.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('SkinningBuffer Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      // Square ortho scene (framed as the former 256×256 rig) at video size.
      rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoWidth);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('SkinningBuffer: animated bone matrices deform a skinned quad (video)', () {
      // position float3 | boneIndices ushort4 | boneWeights float4  (stride 36)
      final vb = FilamentVertexBuffer.create(
        engine: rig.engine, vertexCount: 4, bufferCount: 1,
        attributes: const [
          VertexAttributeDesc(attribute: VertexAttribute.position, bufferIndex: 0, type: AttributeType.float3, byteOffset: 0, byteStride: 36),
          VertexAttributeDesc(attribute: VertexAttribute.boneIndices, bufferIndex: 0, type: AttributeType.ushort4, byteOffset: 12, byteStride: 36),
          VertexAttributeDesc(attribute: VertexAttribute.boneWeights, bufferIndex: 0, type: AttributeType.float4, byteOffset: 20, byteStride: 36),
        ],
      );
      final data = ByteData(4 * 36);
      const pos = [-0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5];
      for (var v = 0; v < 4; v++) {
        final o = v * 36;
        data.setFloat32(o, pos[v * 2], Endian.little);
        data.setFloat32(o + 4, pos[v * 2 + 1], Endian.little);
        data.setFloat32(o + 8, 0, Endian.little);
        final bone = v >= 2 ? 1 : 0; // top vertices follow bone 1
        data.setUint16(o + 12, bone, Endian.little);
        data.setUint16(o + 14, 0, Endian.little);
        data.setUint16(o + 16, 0, Endian.little);
        data.setUint16(o + 18, 0, Endian.little);
        data.setFloat32(o + 20, 1, Endian.little);
        data.setFloat32(o + 24, 0, Endian.little);
        data.setFloat32(o + 28, 0, Endian.little);
        data.setFloat32(o + 32, 0, Endian.little);
      }
      vb.setData(data.buffer.asUint8List());
      final ib = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 6, type: IndexType.ushort);
      ib.setUint16Data(Uint16List.fromList([0, 1, 2, 0, 2, 3]));

      final sb = SkinningBuffer.create(rig.engine, boneCount: 2);
      expect(sb.boneCount, 256, reason: 'rounded up to 256');
      final identity = Float32List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
      sb.setBonesFromMatrices(Float32List.fromList([...identity, ...identity]), count: 2);

      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 0.9, 0.5, 0.1);
      final entity = rig.engine.createEntity();
      rig.entities.add(entity);
      RenderableBuilder(1)
        ..boundingBox(-2, -2, -2, 2, 2, 2)
        ..culling(false)
        ..material(0, mi)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..enableSkinningBuffers(true)
        ..skinningBuffer(sb, count: 2, offset: 0)
        ..build(rig.engine, entity);
      rig.scene.addEntity(entity);

      final rest = rig.renderFrame();
      final restFg = countForegroundPixels(rest, rig.width);
      expect(restFg, inInclusiveRange(rig.width * rig.height ~/ 6, rig.width * rig.height ~/ 3));

      final last = rig.video(
        'SkinningBuffer Smoke Tests SkinningBuffer: animated bone matrices deform a skinned quad (video)',
        onFrame: (frame, t) {
          // Bone 1 slides the top edge right and up along a sine.
          final dx = 0.45 * math.sin(t * math.pi);
          final dy = 0.3 * math.sin(t * math.pi);
          final bone1 = Float32List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1]);
          sb.setBonesFromMatrices(Float32List.fromList([...identity, ...bone1]), count: 2);
        },
      );
      // Mid-animation sheared frame differs from rest pose.
      sb.setBonesFromMatrices(Float32List.fromList([...identity, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.45, 0.3, 0, 1]), count: 2);
      final sheared = rig.renderFrame();
      final changed = countChangedPixels(rest, sheared);
      smokeLog('rest fg=$restFg changed=$changed lastFrameFg=${countForegroundPixels(last, rig.width)}');
      expect(changed, greaterThan(2000), reason: 'bone translation must move the top edge');
      // Top-right corner region is covered only when bone 1 has moved the top edge there.
      final probeX = rig.width * 200 ~/ 256, probeY = rig.height * 40 ~/ 256;
      final (r, _, _) = pixelAt(sheared, rig.width, probeX, probeY);
      final (r0, _, _) = pixelAt(rest, rig.width, probeX, probeY);
      expect(r, greaterThan(150));
      expect(r0, lessThan(60));

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      sb.destroy();
      ib.dispose();
      vb.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
