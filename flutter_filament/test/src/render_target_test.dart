import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('RenderTarget Builder Tests', () {
    late FilamentEngine engine;
    late FilamentSwapChain swapChain;
    late FilamentRenderer renderer;
    late FilamentView view;
    late FilamentScene scene;
    late FilamentCamera camera;
    late int cameraEntity;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      swapChain = engine.createHeadlessSwapChain(128, 128);
      renderer = engine.createRenderer();
      view = engine.createView();
      scene = engine.createScene();
      cameraEntity = engine.createEntity();
      camera = engine.createCamera(cameraEntity);

      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, 128, 128);
    });

    tearDown(() {
      if (!engine.isDisposed) {
        camera.dispose();
        engine.destroyEntity(cameraEntity);
        scene.dispose();
        view.dispose();
        renderer.dispose();
        swapChain.dispose();
        engine.dispose();
      }
    });

    test('supportedColorAttachmentsCount >= 1', () {
      final count = FilamentRenderTarget.supportedColorAttachmentsCount(engine);
      expect(count, greaterThanOrEqualTo(1));
    });

    test('Single-attachment parity with legacy create', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 128,
        height: 128,
        format: TextureFormat.rgba8,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
      );

      // Legacy path
      final rtLegacy = FilamentRenderTarget.create(
        engine: engine,
        colorTexture: texture,
      );
      expect(rtLegacy.isDisposed, isFalse);

      // New builder path
      final rtBuilder = FilamentRenderTarget.build(
        engine: engine,
        colors: [RenderTargetAttachment(texture: texture)],
      );
      expect(rtBuilder.isDisposed, isFalse);

      rtLegacy.dispose();
      rtBuilder.dispose();
      texture.dispose();
    });

    test('MRT: create an RT with 2 color attachments', () {
      final count = FilamentRenderTarget.supportedColorAttachmentsCount(engine);
      if (count < 2) {
        markTestSkipped('Skipping MRT test as supportedColorAttachmentsCount < 2');
        return;
      }

      final texture0 = FilamentTexture.create2D(
        engine: engine,
        width: 128,
        height: 128,
        format: TextureFormat.rgba8,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
      );

      final texture1 = FilamentTexture.create2D(
        engine: engine,
        width: 128,
        height: 128,
        format: TextureFormat.rgba8,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
      );

      final rt = FilamentRenderTarget.build(
        engine: engine,
        colors: [
          RenderTargetAttachment(texture: texture0),
          RenderTargetAttachment(texture: texture1),
        ],
      );

      expect(rt.isDisposed, isFalse);

      rt.dispose();
      texture0.dispose();
      texture1.dispose();
    });

    test('mipLevel: RT attached to mip 1 of a 2-level 64x64 texture', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 64,
        height: 64,
        format: TextureFormat.rgba8,
        levels: 2,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
      );

      final rt = FilamentRenderTarget.build(
        engine: engine,
        colors: [
          RenderTargetAttachment(texture: texture, mipLevel: 1),
        ],
      );

      expect(rt.isDisposed, isFalse);

      rt.dispose();
      texture.dispose();
    });

    test('samples: 4 offscreen MSAA RT creates without crash', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 128,
        height: 128,
        format: TextureFormat.rgba8,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
      );

      final rt = FilamentRenderTarget.build(
        engine: engine,
        colors: [RenderTargetAttachment(texture: texture)],
        samples: 4,
      );

      expect(rt.isDisposed, isFalse);

      rt.dispose();
      texture.dispose();
    });

    test('Dart validation: more than 8 color attachments throws', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 128,
        height: 128,
        format: TextureFormat.rgba8,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
      );

      final attachments = List.generate(
        9,
        (_) => RenderTargetAttachment(texture: texture),
      );

      expect(
        () => FilamentRenderTarget.build(engine: engine, colors: attachments),
        throwsArgumentError,
      );

      texture.dispose();
    });
  });
}
