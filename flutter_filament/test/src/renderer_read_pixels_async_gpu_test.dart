import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

/// On Vulkan the pixels of a read are copied into the caller's buffer by a
/// worker thread after the GPU finished (started by an engine's first read),
/// so a read completes only once Filament hands that buffer back: every read
/// below sees the cleared frame, none an untouched (zeroed) buffer.
void main() {
  final vulkan = FilamentGpu.listVulkanDevices().isNotEmpty;

  Future<void> readFrames(int count) async {
    final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
    const size = 1024;
    final renderer = engine.createRenderer()
      ..clearOptions = ClearOptions(clearColor: Vector4(1, 0, 0, 1), clear: true, discard: true);
    final scene = engine.createScene();
    final camera = engine.createCamera(engine.createEntity());
    final view = engine.createView()
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, size, size);
    final swapChain = engine.createHeadlessSwapChain(size, size);
    try {
      var reads = 0;
      for (var frame = 0; frame < count * 4 && reads < count; frame++) {
        if (!renderer.beginFrame(swapChain)) {
          await engine.whenIdle();
          continue;
        }
        renderer.render(view);
        final pixels = Uint8List(size * size * 4);
        final read = renderer.readPixelsAsync(x: 0, y: 0, width: size, height: size, outPixels: pixels);
        renderer.endFrame();
        await read;
        reads++;
        for (final at in [0, size * size ~/ 2, size * size - 1]) {
          // The red clear after tone mapping and dithering.
          final px = pixels.sublist(at * 4, at * 4 + 4);
          expect(px[3], greaterThan(200), reason: 'read $reads, pixel $at: $px');
          expect(px[0], greaterThan(200), reason: 'read $reads, pixel $at: $px');
        }
      }
      expect(reads, count);
    } finally {
      engine.flushAndWait();
      renderer.dispose();
      view.dispose();
      swapChain.dispose();
      engine.destroyCamera(camera);
      scene.dispose();
      engine.dispose();
    }
  }

  test('readPixelsAsync completes after the pixels are in the buffer, on fresh engines and frame after frame', () async {
    for (var round = 0; round < 12; round++) {
      await readFrames(round == 0 ? 60 : 3);
    }
  }, skip: vulkan ? false : 'no Vulkan device', timeout: const Timeout(Duration(minutes: 3)));
}
