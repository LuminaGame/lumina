import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('Renderer & Rendering Pipeline API Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('Texture enums and values', () {
      expect(TextureFormat.r8.value, equals(0));
      expect(TextureFormat.rgb8.value, equals(17));
      expect(TextureFormat.rgba8.value, equals(30));
      expect(TextureFormat.srgb8A8.value, equals(31));

      expect(PixelFormat.r.value, equals(0));
      expect(PixelFormat.rgb.value, equals(4));
      expect(PixelFormat.rgba.value, equals(6));

      expect(PixelType.ubyte.value, equals(0));
      expect(PixelType.float.value, equals(7));
    });

    test('FilamentTexture 2D creation and setImage', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 64,
        height: 64,
        format: TextureFormat.rgba8,
      );
      expect(texture.isDisposed, isFalse);
      expect(texture.nativePointer, isNotNull);

      final pixels = Uint8List(64 * 64 * 4);
      expect(
        () => texture.setImage(
          width: 64,
          height: 64,
          pixelData: pixels,
          pixelFormat: PixelFormat.rgba,
          pixelType: PixelType.ubyte,
        ),
        returnsNormally,
      );

      texture.dispose();
      expect(texture.isDisposed, isTrue);
      expect(() => texture.nativePointer, throwsStateError);
      expect(
        () => texture.setImage(
          width: 64,
          height: 64,
          pixelData: pixels,
        ),
        throwsStateError,
      );
    });

    test('FilamentScene addEntity, removeEntity, counts', () {
      final scene = engine.createScene();
      final entity = engine.createEntity();

      expect(scene.isDisposed, isFalse);
      expect(scene.nativePointer, isNotNull);

      expect(() => scene.addEntity(entity), returnsNormally);
      expect(scene.entityCount, greaterThanOrEqualTo(0));
      expect(scene.renderableCount, greaterThanOrEqualTo(0));
      expect(scene.lightCount, greaterThanOrEqualTo(0));

      expect(() => scene.removeEntity(entity), returnsNormally);

      scene.dispose();
      expect(scene.isDisposed, isTrue);
      expect(() => scene.nativePointer, throwsStateError);
      expect(() => scene.addEntity(entity), throwsStateError);
      expect(() => scene.removeEntity(entity), throwsStateError);
      expect(() => scene.entityCount, throwsStateError);
      expect(() => scene.renderableCount, throwsStateError);
      expect(() => scene.lightCount, throwsStateError);

      engine.destroyEntity(entity);
    });

    test('FilamentView settings, scene, camera, viewport', () {
      final view = engine.createView();
      final scene = engine.createScene();
      final entity = engine.createEntity();
      final camera = engine.createCamera(entity);

      expect(view.isDisposed, isFalse);
      expect(view.nativePointer, isNotNull);

      expect(() => view.scene = scene, returnsNormally);
      expect(() => view.camera = camera, returnsNormally);
      expect(() => view.setViewport(0, 0, 800, 600), returnsNormally);
      expect(() => view.name = 'MainView', returnsNormally);
      expect(() => view.shadowingEnabled = true, returnsNormally);
      expect(() => view.postProcessingEnabled = true, returnsNormally);
      expect(() => view.antiAliasing = 1, returnsNormally);
      expect(() => view.screenSpaceRefractionEnabled = false, returnsNormally);
      expect(() => view.setVisibleLayers(0xFF, 0x01), returnsNormally);

      view.dispose();
      expect(view.isDisposed, isTrue);
      expect(() => view.nativePointer, throwsStateError);

      camera.dispose();
      scene.dispose();
      engine.destroyEntity(entity);
    });

    test('ClearOptions roundtrip and beginFrame with vsync', () {
      final renderer = engine.createRenderer();
      final view = engine.createView();
      final swapChain = engine.createHeadlessSwapChain(800, 600);

      expect(renderer.isDisposed, isFalse);

      // Default ClearOptions
      final defaultOpts = renderer.clearOptions;
      expect(defaultOpts.clear, isFalse);
      expect(defaultOpts.discard, isTrue);
      expect(defaultOpts.clearStencil, equals(0));

      // Custom ClearOptions roundtrip
      final customOpts = ClearOptions(
        clearColor: Vector4(0.0, 1.0, 0.0, 1.0),
        clearStencil: 7,
        clear: true,
        discard: false,
      );
      renderer.clearOptions = customOpts;

      final readOpts = renderer.clearOptions;
      expect(readOpts.clearColor.x, closeTo(0.0, 1e-4));
      expect(readOpts.clearColor.y, closeTo(1.0, 1e-4));
      expect(readOpts.clearColor.z, closeTo(0.0, 1e-4));
      expect(readOpts.clearColor.w, closeTo(1.0, 1e-4));
      expect(readOpts.clearStencil, equals(7));
      expect(readOpts.clear, isTrue);
      expect(readOpts.discard, isFalse);

      // beginFrame with vsync = 0
      final ok1 = renderer.beginFrame(swapChain);
      if (ok1) {
        renderer.render(view);
        renderer.endFrame();
      }

      // beginFrame with steadyClockTimeNano
      final ok2 = renderer.beginFrame(
        swapChain,
        vsyncSteadyClockTimeNano: engine.steadyClockTimeNano,
      );
      if (ok2) {
        renderer.render(view);
        renderer.endFrame();
      }

      renderer.dispose();
      swapChain.dispose();
      view.dispose();
    });

    test('DisplayInfo & FrameRateOptions configuration and validation', () {
      final renderer = engine.createRenderer();
      final view = engine.createView();
      final swapChain = engine.createHeadlessSwapChain(800, 600);

      // Valid configurations
      expect(
        () => renderer.displayInfo = const DisplayInfo(refreshRate: 120.0),
        returnsNormally,
      );
      expect(
        () => renderer.frameRateOptions = const FrameRateOptions(
          headRoomRatio: 0.1,
          scaleRate: 0.125,
          history: 15,
          interval: 2,
        ),
        returnsNormally,
      );

      // Render 2 frames to ensure pipeline stability
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }

      // Dart validation assertions
      expect(() => DisplayInfo(refreshRate: 0), throwsA(isA<AssertionError>()));
      expect(() => FrameRateOptions(interval: 0), throwsA(isA<AssertionError>()));
      expect(() => FrameRateOptions(headRoomRatio: 1.5), throwsA(isA<AssertionError>()));
      expect(() => FrameRateOptions(history: 0), throwsA(isA<AssertionError>()));
      expect(() => FrameRateOptions(history: 32), throwsA(isA<AssertionError>()));

      renderer.dispose();
      swapChain.dispose();
      view.dispose();
    });

    test('FrameInfo history querying and capacity bounds', () {
      final renderer = engine.createRenderer();
      final view = engine.createView();
      final swapChain = engine.createHeadlessSwapChain(800, 600);

      expect(renderer.maxFrameHistorySize, greaterThanOrEqualTo(1));

      // Render frames
      for (int i = 0; i < 3; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          renderer.endFrame();
        }
      }
      engine.flushAndWait();

      final history = renderer.getFrameInfoHistory(3);
      expect(history.length, lessThanOrEqualTo(3));

      expect(FrameInfo.invalid, equals(-1));
      expect(FrameInfo.pending, equals(-2));
      expect(FrameInfo.isValidField(100), isTrue);
      expect(FrameInfo.isValidField(FrameInfo.invalid), isFalse);
      expect(FrameInfo.isValidField(FrameInfo.pending), isFalse);

      renderer.dispose();
      swapChain.dispose();
      view.dispose();
    });

    test('renderStandaloneView and RenderTarget readback', () async {
      final renderer = engine.createRenderer();
      final view = engine.createView();

      // Calling standalone view without renderTarget throws ArgumentError
      expect(() => renderer.renderStandaloneView(view), throwsArgumentError);

      final colorTex = FilamentTexture.create2D(
        engine: engine,
        width: 32,
        height: 32,
        format: TextureFormat.rgba8,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable | TextureUsage.blitSrc,
      );

      final renderTarget = FilamentRenderTarget.build(
        engine: engine,
        colors: [
          RenderTargetAttachment(texture: colorTex),
        ],
      );

      view.renderTarget = renderTarget;
      view.setViewport(0, 0, 32, 32);

      expect(() => renderer.renderStandaloneView(view), returnsNormally);
      engine.flushAndWait();

      // Read pixels from render target
      final pixels = await renderer.readPixelsFromRenderTarget(
        renderTarget,
        x: 0,
        y: 0,
        width: 32,
        height: 32,
      );
      expect(pixels.length, equals(32 * 32 * 4));

      renderer.dispose();
      view.dispose();
      renderTarget.dispose();
      colorTex.dispose();
    });

    test('Presentation time, frame skipping and material time epoch', () {
      final renderer = engine.createRenderer();
      final view = engine.createView();
      final swapChain = engine.createHeadlessSwapChain(800, 600);

      expect(renderer.shouldRenderFrame, isTrue);
      expect(renderer.hasGpuFallenBehind, isFalse);

      // Timing setters
      final now = engine.steadyClockTimeNano;
      renderer.vsyncTime = now;
      renderer.presentationTime = now + 16000000;
      renderer.desiredPresentationTime = now + 16000000;
      renderer.renderingDeadline = now + 15000000;
      renderer.frameScheduleTime = now;

      // Skip frame
      expect(() => renderer.skipFrame(vsyncSteadyClockNanos: now), returnsNormally);

      // Skip next frames
      renderer.skipNextFrames(2);
      expect(renderer.frameToSkipCount, greaterThanOrEqualTo(0));

      // Pause render thread test
      expect(() => renderer.pauseRenderThread(const Duration(milliseconds: 1)), returnsNormally);

      // Material time & epoch
      final mTime1 = renderer.materialTime;
      expect(mTime1, greaterThanOrEqualTo(0.0));

      renderer.resetMaterialTimeEpoch();
      final mTime2 = renderer.materialTime;
      expect(mTime2, greaterThanOrEqualTo(0.0));

      // Render a frame
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }

      // Negative argument validation
      expect(() => renderer.vsyncTime = -1, throwsArgumentError);
      expect(() => renderer.presentationTime = -1, throwsArgumentError);
      expect(() => renderer.desiredPresentationTime = -1, throwsArgumentError);
      expect(() => renderer.renderingDeadline = -1, throwsArgumentError);
      expect(() => renderer.frameScheduleTime = -1, throwsArgumentError);
      expect(() => renderer.skipFrame(vsyncSteadyClockNanos: -1), throwsArgumentError);
      expect(() => renderer.skipNextFrames(-1), throwsArgumentError);

      renderer.dispose();
      swapChain.dispose();
      view.dispose();
    });
  });
}
