import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// Vulkan device extensions and feature structures requested before an
/// engine exists, intersected by Filament with what the device supports.
void main() {
  tearDown(() => VulkanFeatures.clear());

  test('the noop backend accepts requests and enables nothing', () {
    VulkanFeatures.requestFeature('test', VulkanFeature.shaderSubgroupClock);
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    try {
      expect(
        VulkanFeatures.isFeatureEnabled(
          engine,
          VulkanFeature.shaderSubgroupClock,
        ),
        isFalse,
      );
      expect(
        VulkanFeatures.isExtensionEnabled(engine, 'VK_KHR_shader_clock'),
        isFalse,
      );
    } finally {
      engine.dispose();
    }
  });

  FilamentEngine? vulkanEngine() {
    try {
      return FilamentEngine.create(backend: FilamentBackend.vulkan);
    } catch (_) {
      return null;
    }
  }

  test(
    'a requested feature member the device supports is enabled, and only while requested',
    () {
      VulkanFeatures.requestFeature('test', VulkanFeature.shaderSubgroupClock);
      final engine = vulkanEngine();
      if (engine == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      try {
        expect(
          VulkanFeatures.isExtensionEnabled(engine, 'VK_KHR_shader_clock'),
          isTrue,
        );
        expect(
          VulkanFeatures.isFeatureEnabled(
            engine,
            VulkanFeature.shaderSubgroupClock,
          ),
          isTrue,
        );
        // not requested: stays off even though the device supports it
        expect(
          VulkanFeatures.isFeatureEnabled(
            engine,
            VulkanFeature.shaderDeviceClock,
          ),
          isFalse,
        );
        // Filament's own extensions are reported too
        expect(
          VulkanFeatures.isExtensionEnabled(engine, 'VK_KHR_swapchain'),
          isTrue,
        );
      } finally {
        engine.dispose();
      }

      VulkanFeatures.clear('test');
      final plain = vulkanEngine()!;
      try {
        expect(
          VulkanFeatures.isFeatureEnabled(
            plain,
            VulkanFeature.shaderSubgroupClock,
          ),
          isFalse,
        );
      } finally {
        plain.dispose();
      }
    },
  );

  test(
    'a feature of an extension the device lacks is skipped and the engine still renders',
    () {
      const missing = VulkanFeature(
        name: 'missing',
        sType: 1000181000,
        structSize: 24,
        fieldOffset: 16,
        extension: 'VK_LUMINA_extension_no_driver_offers',
      );
      VulkanFeatures.requestFeature('test', missing);
      final engine = vulkanEngine();
      if (engine == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      final rig = SmokeRig.adopt(engine, width: 64, height: 64);
      try {
        expect(
          VulkanFeatures.isExtensionEnabled(engine, missing.extension),
          isFalse,
        );
        expect(VulkanFeatures.isFeatureEnabled(engine, missing), isFalse);
        expect(rig.renderFrame(warmup: 2).length, 64 * 64 * 4);
      } finally {
        rig.dispose();
      }
    },
  );
}
