// filamat smoke: a lit material with uniform parameters and a custom vertex
// shader is compiled at runtime by filamat, inspected, applied to a real
// barrel GLB and its vertex displacement animated into a WebM.
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Filamat Smoke Tests', () {
    late SmokeRig rig;
    late FilamentIndirectLight ibl;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight);
      rig.addSun();
      ibl = rig.addIbl();
    });

    tearDown(() {
      rig.scene.setIndirectLight(null);
      ibl.dispose();
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('Filamat: runtime-compiled lit material with vertex displacement on a real GLB (video)', () {
      FilamentMaterialBuilder.initEngine();
      final b = FilamentMaterialBuilder.create()
        ..setName('SmokeWobble')
        ..setShading(FilamatShading.lit)
        ..requireAttribute(VertexAttribute.position.value)
        ..requireAttribute(VertexAttribute.tangents.value)
        ..addParameter('baseColor', UniformType.float3)
        ..addParameter('roughness', UniformType.floatType)
        ..addParameter('metallic', UniformType.floatType)
        ..addParameter('wobble', UniformType.floatType)
        ..vertexDomain(VertexDomain.object)
        ..materialVertex('''
          void materialVertex(inout MaterialVertexInputs material) {
              material.worldPosition.xyz += material.worldNormal * materialParams.wobble;
          }
        ''')
        ..setCode('''
          void material(inout MaterialInputs material) {
              prepareMaterial(material);
              material.baseColor.rgb = materialParams.baseColor;
              material.roughness = materialParams.roughness;
              material.metallic = materialParams.metallic;
          }
        ''');
      final bytes = b.build();
      b.dispose();
      expect(bytes, isNotNull);
      final info = FilamentTools.inspectMaterialJson(bytes!);
      expect(info, isNotNull);
      expect(info, contains('SmokeWobble'));

      final material = FilamentMaterial.fromBuffer(engine: rig.engine, filamatBuffer: bytes);
      expect(material.name, 'SmokeWobble');
      expect(material.shading, FilamatShading.lit);
      expect(material.parameters.map((p) => p.name), containsAll(['baseColor', 'roughness', 'metallic', 'wobble']));
      expect(material.requiredAttributes, contains(VertexAttribute.tangents));
      final mi = material.createInstance()
        ..setFloat3('baseColor', 0.9, 0.35, 0.1)
        ..setFloat('roughness', 0.35)
        ..setFloat('metallic', 0.6)
        ..setFloat('wobble', 0.0);

      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/dented_barrel.glb');
      try {
        final rm = FilamentRenderableManager(rig.engine);
        for (final e in gltf.asset.renderableEntities) {
          for (var p = 0; p < rm.getPrimitiveCount(e); p++) {
            rm.setMaterialInstanceAt(e, p, mi);
          }
        }
        final rest = rig.renderFrame();
        final restFg = countForegroundPixels(rest, rig.width);
        expect(restFg, greaterThan(rig.width * rig.height ~/ 40));
        final (r, g, _) = averageColor(rest, rig.width, rig.width ~/ 2 - 10, rig.height ~/ 2 - 10, 20, 20);
        expect(r, greaterThan(g), reason: 'custom orange baseColor drives the shading');

        final box = gltf.asset.getBoundingBox();
        final amp = (box.max - box.min).length * 0.08;
        final last = rig.video(
          'Filamat Smoke Tests Filamat: runtime-compiled lit material with vertex displacement on a real GLB (video)',
          onFrame: (frame, t) => mi.setFloat('wobble', amp * math.sin(t * 2 * math.pi)),
        );
        mi.setFloat('wobble', amp);
        final inflated = rig.renderFrame();
        final inflatedFg = countForegroundPixels(inflated, rig.width);
        smokeLog('barrel fg rest=$restFg inflated=$inflatedFg');
        expect(inflatedFg, greaterThan((restFg * 1.15).round()), reason: 'vertex shader pushes vertices outward');
        expect(countForegroundPixels(last, rig.width), greaterThan(0));
      } finally {
        gltf.dispose(rig.scene);
        mi.dispose();
        material.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
