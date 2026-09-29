// renderable_manager smoke (moved from the off-convention
// renderable_smoke_test.dart): raw geometry through RenderableBuilder, then
// RenderableManager queries (AABB, primitive count, layer masks, channels)
// against a real GLB, all rendered on the GPU.
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('RenderableManager Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 400, height: 300);
    });

    tearDown(() {
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('Renderable geometry, bounding box, and material application', () {
      rig.camera.setProjection(fovDegrees: 45, aspect: rig.width / rig.height, near: 0.1, far: 100);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 3, centerX: 0, centerY: 0, centerZ: 0);
      rig.renderer.setClearOptions(r: 0.1, g: 0.2, b: 0.3, a: 1);

      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 1, 0, 0);
      final vb = FilamentVertexBuffer.create(
        engine: rig.engine, vertexCount: 3, bufferCount: 1,
        attributes: const [
          VertexAttributeDesc(attribute: VertexAttribute.position, bufferIndex: 0, type: AttributeType.float3, byteOffset: 0, byteStride: 12),
        ],
      );
      vb.setData(Float32List.fromList([0, 1, 0, -1, -1, 0, 1, -1, 0]));
      final ib = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 3, type: IndexType.ushort);
      ib.setUint16Data(Uint16List.fromList([0, 1, 2]));

      final entity = rig.engine.createEntity();
      rig.entities.add(entity);
      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..culling(false)
        ..material(0, mi)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..build(rig.engine, entity);
      rig.scene.addEntity(entity);

      final rm = FilamentRenderableManager(rig.engine);
      expect(rm.hasComponent(entity), isTrue);
      expect(rm.getPrimitiveCount(entity), 1);
      final box = rm.getAxisAlignedBoundingBox(entity);
      expect(box.halfExtent.x, closeTo(1, 1e-5));
      expect(rm.getMaterialInstanceAt(entity, 0)?.nativePointer.address, mi.nativePointer.address);

      final px = rig.screenshot('RenderableManager Smoke Tests Renderable geometry, bounding box, and material application');
      // Apex (0,1,0) projects to the upper half: a red pixel just below the top-centre.
      final (r, g, b) = pixelAt(px, rig.width, 200, 90);
      smokeLog('apex pixel=($r,$g,$b)');
      expect(r, greaterThan(150));
      expect(g, lessThan(80));
      expect(countForegroundPixels(px, rig.width), greaterThan(rig.width * rig.height ~/ 10));

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      ib.dispose();
      vb.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('RenderableManager: queries and layer mask toggle on a real GLB', () {
      rig.addSun();
      final ibl = rig.addIbl();
      final gltf = loadGltfIntoScene(rig, 'Props/AC_units/ac_unit_a_300x300.glb');
      try {
        final rm = FilamentRenderableManager(rig.engine);
        final renderables = gltf.asset.renderableEntities;
        expect(renderables, isNotEmpty);
        var primitives = 0;
        for (final e in renderables) {
          expect(rm.hasComponent(e), isTrue);
          primitives += rm.getPrimitiveCount(e);
          expect(rm.getEnabledAttributesAt(e, 0), contains(VertexAttribute.position));
          rm.setPriority(e, 3);
          rm.setChannel(e, 2);
          expect(rm.getChannel(e), 2);
          rm.setCastShadows(e, true);
          expect(rm.isShadowCaster(e), isTrue);
        }
        expect(primitives, greaterThan(0));
        final aabb = rm.getAxisAlignedBoundingBox(renderables.first);
        expect(aabb.halfExtent.length, greaterThan(0));

        final visible = rig.screenshot('RenderableManager Smoke Tests RenderableManager: queries and layer mask toggle on a real GLB');
        final fgVisible = countForegroundPixels(visible, rig.width);
        expect(fgVisible, greaterThan(rig.width * rig.height ~/ 40));

        // Move every renderable to layer 2 and hide that layer on the view.
        for (final e in renderables) {
          rm.setLayerMask(e, 0xff, 0x02);
        }
        rig.view.setVisibleLayers(0xff, 0x01);
        final hidden = rig.renderFrame();
        final fgHidden = countForegroundPixels(hidden, rig.width);
        smokeLog('ac_unit primitives=$primitives visible=$fgVisible hidden=$fgHidden');
        expect(fgHidden, lessThan(fgVisible ~/ 10), reason: 'layer mask hides the mesh');
        rig.scene.setIndirectLight(null);
        ibl.dispose();
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
