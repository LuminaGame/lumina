// render_target smoke: an offscreen RenderTarget with colour + depth
// attachments is rendered via the view and read back with
// readPixelsFromRenderTarget; the result is published as the PNG.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('RenderTarget Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('RenderTarget: offscreen colour+depth target renders and reads back', () async {
      const w = 128, h = 96;
      expect(FilamentRenderTarget.supportedColorAttachmentsCount(rig.engine), greaterThanOrEqualTo(1));
      final color = FilamentTexture.create2D(
        engine: rig.engine, width: w, height: h, format: TextureFormat.rgba8,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
      );
      final depth = FilamentTexture.create2D(
        engine: rig.engine, width: w, height: h, format: TextureFormat.depth24,
        usage: TextureUsage.depthAttachment,
      );
      final rt = FilamentRenderTarget.build(
        engine: rig.engine,
        colors: [RenderTargetAttachment(texture: color)],
        depth: RenderTargetAttachment(texture: depth),
      );
      expect(rig.engine.isValidRenderTarget(rt.nativePointer), isTrue);

      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 0.1, 1.0, 0.2);
      final quad = SmokeQuad.create(rig.engine, size: 1.0);
      addQuadRenderable(rig, quad, mi);

      rig.view.renderTarget = rt;
      rig.view.setViewport(0, 0, w, h);
      expect(rig.view.renderTarget, same(rt));
      rig.renderer.setClearOptions(r: 0.3, g: 0.0, b: 0.0, a: 1);

      for (var i = 0; i < 4; i++) {
        if (rig.renderer.beginFrame(rig.swapChain)) {
          rig.renderer.render(rig.view);
          rig.renderer.endFrame();
        }
      }
      final px = await rig.renderer.readPixelsFromRenderTarget(rt, x: 0, y: 0, width: w, height: h);
      expect(px.length, w * h * 4);
      SmokeArtifacts.saveScreenshot('RenderTarget Smoke Tests RenderTarget: offscreen colour+depth target renders and reads back',
          SmokeArtifacts.encodePng(w, h, px, flipY: true));
      final (cr, cg, _) = pixelAt(px, w, w ~/ 2, h ~/ 2);
      final (er, eg, _) = pixelAt(px, w, 2, 2);
      smokeLog('rt centre=($cr,$cg) edge=($er,$eg)');
      expect(cg, greaterThan(180), reason: 'green quad in the middle');
      expect(cr, lessThan(80));
      expect(er, greaterThan(50), reason: 'red clear at the edge');
      expect(eg, lessThan(40));

      rig.view.renderTarget = null;
      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      quad.dispose();
      rt.dispose();
      depth.dispose();
      color.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
