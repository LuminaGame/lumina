// The object counts and GPU memory that prove sharing and leaks.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilamentEngine.resourceCounts', () {
    test('each object raises exactly its counter; destroying returns to the baseline', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      addTearDown(engine.dispose);
      final base = engine.resourceCounts;

      final texture = FilamentTexture.create2D(engine: engine, width: 256, height: 256);
      final view = engine.createView();
      final scene = engine.createScene();
      final swapChain = engine.createHeadlessSwapChain(64, 64);
      final light = engine.createEntity();
      LightBuilder(LightType.directional).build(engine, light);
      final vb = FilamentVertexBuffer.create(engine: engine, vertexCount: 3, bufferCount: 1);
      final ib = FilamentIndexBuffer.create(engine: engine, indexCount: 3, type: IndexType.ushort);
      final renderable = engine.createEntity();
      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..build(engine, renderable);

      final grown = engine.resourceCounts - base;
      expect(grown.textures, 1);
      expect(grown.views, 1);
      expect(grown.scenes, 1);
      expect(grown.swapChains, 1);
      expect(grown.lights, 1);
      expect(grown.renderables, 1);
      expect(grown.vertexBuffers, 1);
      expect(grown.indexBuffers, 1);
      // Two of ours; the entity count is process-wide, so others may add.
      expect(grown.entities, greaterThanOrEqualTo(2));
      expect(grown.materials, 0);

      FilamentRenderableManager(engine).destroy(renderable);
      engine.destroyEntity(renderable);
      engine.destroyEntityComponents(light);
      engine.destroyEntity(light);
      vb.dispose();
      ib.dispose();
      swapChain.dispose();
      scene.dispose();
      view.dispose();
      texture.dispose();
      final after = engine.resourceCounts - base;
      expect(after.nonZero, isEmpty, reason: 'left behind: $after');
    });

    test('counts support subtraction, equality and a readable dump', () {
      const a = FilamentEngineResourceCounts(textures: 3, views: 2);
      const b = FilamentEngineResourceCounts(textures: 1, views: 2);
      expect((a - b).textures, 2);
      expect((a - b).nonZero, {'textures': 2});
      expect(a == const FilamentEngineResourceCounts(textures: 3, views: 2), isTrue);
      expect(a.toString(), contains('textures: 3'));
    });
  });

  group('FilamentEngine.gpuMemory', () {
    test('noop engines report none', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      addTearDown(engine.dispose);
      expect(engine.gpuMemory, isNull);
    });

    final vulkan = FilamentGpu.listVulkanDevices().where((d) => d.type == FilamentGpuType.discrete).toList();
    test('Vulkan: a 4096² texture with mips shows up in the process usage', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
      addTearDown(engine.dispose);
      final before = engine.gpuMemory;
      expect(before, isNotNull, reason: '${engine.gpuName} supports VK_EXT_memory_budget');
      expect(before!.heapCount, greaterThan(0));
      expect(before.usageBytes, lessThanOrEqualTo(before.budgetBytes));
      expect(before.budgetBytes, lessThanOrEqualTo(before.heapBytes));

      final texture = FilamentTexture.create2D(engine: engine, width: 4096, height: 4096, levels: 13);
      engine.flushAndWait();
      final loaded = engine.gpuMemory!;
      const mib = 1024 * 1024;
      expect(loaded.usageBytes - before.usageBytes, greaterThanOrEqualTo(64 * mib),
          reason: '4096² RGBA8 is 64 MiB before mips ($before → $loaded)');

      texture.dispose();
      engine.flushAndWait();
      // Filament frees the image after the frames that may use it; render a
      // few empty frames so its deferred destruction runs.
      final swapChain = engine.createHeadlessSwapChain(16, 16);
      final renderer = engine.createRenderer();
      for (var i = 0; i < 6; i++) {
        if (renderer.beginFrame(swapChain)) renderer.endFrame();
        engine.flushAndWait();
      }
      renderer.dispose();
      swapChain.dispose();
      engine.flushAndWait();
      final freed = engine.gpuMemory!;
      expect(freed.usageBytes, lessThan(loaded.usageBytes - 32 * mib), reason: 'most of it is given back ($loaded → $freed)');
    }, skip: vulkan.isEmpty ? 'no discrete Vulkan GPU on this host' : false);
  });
}
