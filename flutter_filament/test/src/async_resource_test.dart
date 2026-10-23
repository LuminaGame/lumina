import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asynchronous resource creation and uploads: the engine's asynchronous mode,
/// `createAsync` / `setImageAsync` / `setBufferAtAsync` / `setBufferAsync`,
/// cancellation, upload groups and `whenIdle`.
void main() {
  group('EngineConfig.asynchronousMode', () {
    test('defaults to a worker thread and round-trips through the native struct', () {
      expect(const EngineConfig().asynchronousMode, FilamentAsynchronousMode.threadPreferred);
      expect(EngineConfig.defaults().asynchronousMode, FilamentAsynchronousMode.none, reason: "Filament's own default");
      final engine = FilamentEngine.create(
        backend: FilamentBackend.noop,
        config: const EngineConfig(asynchronousMode: FilamentAsynchronousMode.amortization),
      )!;
      addTearDown(engine.dispose);
      expect(engine.config.asynchronousMode, FilamentAsynchronousMode.amortization);
    });
  });

  group('on the noop backend (no asynchronous mode)', () {
    late FilamentEngine engine;
    setUp(() => engine = FilamentEngine.create(backend: FilamentBackend.noop)!);
    tearDown(() => engine.dispose());

    test('the mode is reported off and async calls complete synchronously', () async {
      expect(engine.isAsynchronousModeEnabled, isFalse);
      final texture = await FilamentTexture.createAsync(
        engine: engine,
        desc: const TextureDescriptor(width: 4, height: 4, format: TextureFormat.rgba8),
      );
      addTearDown(texture.dispose);
      expect(texture.isCreationComplete, isTrue);
      final upload = texture.setImageAsync(pixelData: Uint8List(4 * 4 * 4), width: 4, height: 4);
      expect(upload.isAsync, isFalse);
      expect(upload.cancel(), isFalse, reason: 'a synchronous call cannot be cancelled');
      expect(await upload.done, FilamentAsyncStatus.completed);
      expect(engine.cancelAsyncCall(asyncCallSync), isFalse);
    });

    test('vertex and index buffers: createAsync, setBufferAtAsync, setBufferAsync and a group', () async {
      final vb = await FilamentVertexBuffer.createAsync(engine: engine, vertexCount: 3);
      addTearDown(vb.dispose);
      final ib = await FilamentIndexBuffer.createAsync(engine: engine, indexCount: 3);
      addTearDown(ib.dispose);
      expect(vb.isCreationComplete, isTrue);
      expect(ib.isCreationComplete, isTrue);
      final positions = NativeBuffer.fromTypedData(Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]));
      final indices = NativeBuffer.fromTypedData(Uint16List.fromList([0, 1, 2]));
      final uploads = [
        vb.setBufferAtAsync(engine, 0, positions, autoFree: true),
        ib.setBufferAsync(engine, indices, autoFree: true),
      ];
      expect(await FilamentAsyncUpload.allCompleted(uploads), isTrue);
      expect(await FilamentAsyncUpload.group(uploads), everyElement(FilamentAsyncStatus.completed));
    });

    test('whenIdle completes without blocking the isolate', () async {
      final sw = Stopwatch()..start();
      final future = engine.whenIdle();
      expect(sw.elapsedMilliseconds, lessThan(5), reason: 'the call returns at once');
      await future;
    });
  });

  group('on Vulkan (amortized: a few jobs per rendered frame)', () {
    FilamentEngine? engine;
    FilamentRenderer? renderer;
    FilamentSwapChain? swapChain;
    FilamentView? view;
    FilamentScene? scene;
    Timer? frames;
    var framesRendered = 0;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      final e = engine;
      if (e == null) return;
      renderer = e.createRenderer();
      swapChain = e.createHeadlessSwapChain(64, 64);
      view = e.createView();
      scene = e.createScene();
      final cameraEntity = e.createEntity();
      view!.scene = scene!;
      view!.camera = e.createCamera(cameraEntity);
      view!.setViewport(0, 0, 64, 64);
      framesRendered = 0;
      // The frame loop every viewport has: it ticks the driver, which runs the
      // queued asynchronous jobs and delivers their completions.
      frames = Timer.periodic(const Duration(milliseconds: 4), (_) {
        if (renderer!.beginFrame(swapChain!)) {
          renderer!.render(view!);
          renderer!.endFrame();
          framesRendered++;
        }
        e.pumpMessageQueues();
      });
    });
    tearDown(() {
      frames?.cancel();
      final e = engine;
      if (e == null) return;
      e.flushAndWait();
      view?.dispose();
      scene?.dispose();
      renderer?.dispose();
      swapChain?.dispose();
      e.dispose();
    });

    Future<FilamentAsyncStatus> settle(FilamentAsyncUpload upload) => upload.done.timeout(const Duration(seconds: 20));

    test('the mode is on, a 2048² upload returns at once and lands over the next frames', () async {
      if (engine == null) {
        markTestSkipped('no Vulkan device');
        return;
      }
      final e = engine!;
      expect(e.isAsynchronousModeEnabled, isTrue);
      final texture = await FilamentTexture.createAsync(
        engine: e,
        desc: const TextureDescriptor(width: 2048, height: 2048, format: TextureFormat.rgba8),
      ).timeout(const Duration(seconds: 20));
      addTearDown(texture.dispose);
      expect(texture.isCreationComplete, isTrue);
      final pixels = Uint8List(2048 * 2048 * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        pixels[i] = 0x31;
        pixels[i + 1] = 0xA5;
        pixels[i + 2] = 0xDA;
        pixels[i + 3] = 0xFF;
      }
      final sw = Stopwatch()..start();
      final upload = texture.setImageAsync(pixelData: pixels, width: 2048, height: 2048);
      expect(sw.elapsedMilliseconds, lessThan(50), reason: 'the UI isolate only queues the upload');
      expect(upload.isAsync, isTrue);
      final before = framesRendered;
      expect(await settle(upload), FilamentAsyncStatus.completed);
      expect(framesRendered, greaterThan(before), reason: 'the completion arrived with rendered frames');
    });

    test('cancelling a queued upload reports canceled, or completed when it already ran', () async {
      if (engine == null) {
        markTestSkipped('no Vulkan device');
        return;
      }
      final e = engine!;
      final texture = await FilamentTexture.createAsync(
        engine: e,
        desc: const TextureDescriptor(width: 1024, height: 1024, format: TextureFormat.rgba8),
      ).timeout(const Duration(seconds: 20));
      addTearDown(texture.dispose);
      final upload = texture.setImageAsync(pixelData: Uint8List(1024 * 1024 * 4), width: 1024, height: 1024);
      final accepted = upload.cancel();
      final status = await settle(upload);
      expect(status, accepted ? FilamentAsyncStatus.canceled : FilamentAsyncStatus.completed);
    });

    test('a vertex + index + texture group completes once, then the GPU is idle', () async {
      if (engine == null) {
        markTestSkipped('no Vulkan device');
        return;
      }
      final e = engine!;
      final vb = await FilamentVertexBuffer.createAsync(engine: e, vertexCount: 4, withUv: true)
          .timeout(const Duration(seconds: 20));
      addTearDown(vb.dispose);
      final ib = await FilamentIndexBuffer.createAsync(engine: e, indexCount: 6).timeout(const Duration(seconds: 20));
      addTearDown(ib.dispose);
      final texture = await FilamentTexture.createAsync(
        engine: e,
        desc: const TextureDescriptor(width: 64, height: 64, format: TextureFormat.rgba8),
      ).timeout(const Duration(seconds: 20));
      addTearDown(texture.dispose);
      final quad = Float32List.fromList([-1, -1, 0, 0, 1, -1, 1, 0, 1, 1, 1, 1, -1, 1, 0, 1]);
      final uploads = [
        vb.setBufferAtAsync(e, 0, NativeBuffer.fromTypedData(quad), autoFree: true),
        ib.setBufferAsync(e, NativeBuffer.fromTypedData(Uint16List.fromList([0, 1, 2, 0, 2, 3])), autoFree: true),
        texture.setImageAsync(pixelData: Uint8List(64 * 64 * 4), width: 64, height: 64),
      ];
      expect(await FilamentAsyncUpload.allCompleted(uploads).timeout(const Duration(seconds: 20)), isTrue);
      expect(vb.isCreationComplete && ib.isCreationComplete && texture.isCreationComplete, isTrue);
      await e.whenIdle().timeout(const Duration(seconds: 20));
    });
  });
}
