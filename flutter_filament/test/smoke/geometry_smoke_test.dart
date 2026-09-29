// geometry smoke: TangentSpaceMesh generates packed tangent frames for a
// quad that is then lit on the GPU; Transcoder expands short3 positions to
// float3 before upload. Both paths render and are asserted on pixels.
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Geometry Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
    });

    tearDown(() => rig.dispose());

    test('Geometry: TangentSpaceMesh tangent frames light a quad', () {
      final positions = Float32List.fromList([-0.7, -0.7, 0, 0.7, -0.7, 0, 0.7, 0.7, 0, -0.7, 0.7, 0]);
      final mesh = (TangentSpaceMeshBuilder()
            ..vertexCount(4)
            ..positions(positions)
            ..uvs(Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]))
            ..normals(Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]))
            ..triangleCount(2)
            ..trianglesUshort(Uint16List.fromList([0, 1, 2, 0, 2, 3]))
            ..algorithm(TsmAlgorithm.mikktspace))
          .build();
      expect(mesh.vertexCount, 4);
      expect(mesh.triangleCount, 2);
      final quats = mesh.getQuatsFloat();
      expect(quats.length, 16);
      for (var v = 0; v < 4; v++) {
        final l = quats[v * 4] * quats[v * 4] + quats[v * 4 + 1] * quats[v * 4 + 1] +
            quats[v * 4 + 2] * quats[v * 4 + 2] + quats[v * 4 + 3] * quats[v * 4 + 3];
        expect(l, closeTo(1, 1e-3), reason: 'unit quaternion');
      }
      final packed = mesh.getQuatsShort4();
      expect(packed.length, 16);
      final tris = mesh.getTrianglesUint32();
      expect(tris, [0, 1, 2, 0, 2, 3]);
      mesh.destroy();

      final vb = FilamentVertexBuffer.create(
        engine: rig.engine, vertexCount: 4, bufferCount: 2,
        attributes: const [
          VertexAttributeDesc(attribute: VertexAttribute.position, bufferIndex: 0, type: AttributeType.float3, byteStride: 12),
          VertexAttributeDesc(attribute: VertexAttribute.tangents, bufferIndex: 1, type: AttributeType.short4, byteStride: 8, normalized: true),
        ],
      );
      vb.setData(positions, bufferIndex: 0);
      vb.setData(packed, bufferIndex: 1);
      final ib = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 6, type: IndexType.ushort);
      ib.setUint16Data(Uint16List.fromList([0, 1, 2, 0, 2, 3]));

      FilamentMaterialBuilder.initEngine();
      final b = FilamentMaterialBuilder.create()
        ..setName('SmokeLit')
        ..setShading(FilamatShading.lit)
        ..requireAttribute(VertexAttribute.position.value)
        ..requireAttribute(VertexAttribute.tangents.value)
        ..setCode('''
          void material(inout MaterialInputs material) {
              prepareMaterial(material);
              material.baseColor.rgb = float3(0.9, 0.9, 0.9);
              material.roughness = 0.6;
              material.metallic = 0.0;
          }
        ''');
      final matBytes = b.build()!;
      b.dispose();
      final material = FilamentMaterial.fromBuffer(engine: rig.engine, filamatBuffer: matBytes);
      final mi = material.createInstance();
      addQuadRenderable(rig, SmokeQuad(vb, ib), mi);

      // Light from the front (+Z) → bright; from behind → dark.
      final sun = rig.engine.createEntity();
      rig.entities.add(sun);
      LightBuilder(LightType.directional)
        ..color(1, 1, 1)
        ..intensity(100000)
        ..direction(0, 0, -1)
        ..build(rig.engine, sun);
      rig.scene.addEntity(sun);
      final front = rig.screenshot('Geometry Smoke Tests Geometry: TangentSpaceMesh tangent frames light a quad');
      final (fr, _, _) = averageColor(front, rig.width, 100, 100, 56, 56);
      final lm = FilamentLightManager(rig.engine);
      lm.setDirection(sun, 0, 0, 1);
      final back = rig.renderFrame();
      final (br, _, _) = averageColor(back, rig.width, 100, 100, 56, 56);
      print('tsm quad brightness front=${fr.toStringAsFixed(1)} back=${br.toStringAsFixed(1)}');
      expect(fr, greaterThan(120), reason: 'lit from the front the normal (0,0,1) faces the light');
      expect(br, lessThan(fr * 0.5), reason: 'normal points away from a back light');

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      ib.dispose();
      vb.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Geometry: Transcoder expands normalized short3 positions for upload', () {
      // short3 normalized: 32767 → 1.0
      final shorts = Int16List.fromList([-16384, -16384, 0, 16384, -16384, 0, 16384, 16384, 0, -16384, 16384, 0]);
      final floats = const Transcoder(TranscoderConfig(componentType: ComponentType.short, normalized: true, componentCount: 3)).run(shorts, 4);
      expect(floats.length, 12);
      expect(floats[0], closeTo(-0.5, 1e-3));
      expect(floats[3], closeTo(0.5, 1e-3));

      final vb = FilamentVertexBuffer.create(
        engine: rig.engine, vertexCount: 4, bufferCount: 1,
        attributes: const [
          VertexAttributeDesc(attribute: VertexAttribute.position, bufferIndex: 0, type: AttributeType.float3, byteStride: 12),
        ],
      );
      vb.setData(floats);
      final ib = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 6, type: IndexType.ushort);
      ib.setUint16Data(Uint16List.fromList([0, 1, 2, 0, 2, 3]));
      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 0.3, 0.9, 0.9);
      addQuadRenderable(rig, SmokeQuad(vb, ib), mi);
      rig.view.postProcessingEnabled = false;
      final px = rig.screenshot('Geometry Smoke Tests Geometry: Transcoder expands normalized short3 positions for upload');
      final fg = countForegroundPixels(px, rig.width);
      print('transcoded quad fg=$fg');
      expect(fg, inInclusiveRange(15000, 18000), reason: 'quad of side 1.0 in a 2.0 ortho frustum = 1/4 of 65536');

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      ib.dispose();
      vb.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
