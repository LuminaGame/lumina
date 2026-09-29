import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The editor picks the GPU through lumina (backed by flutter_filament's
/// device list).
void main() {
  tearDown(() => LuminaGraphicsDevices.usePreferred(null));

  test('lists the Vulkan devices with a picker label', () {
    final devices = LuminaGraphicsDevices.list();
    expect(devices.length, FilamentGpu.listVulkanDevices().length);
    for (final d in devices) {
      expect(d.label, '${d.name} · ${d.typeLabel}');
    }
  });

  test('a preferred device becomes the default for new engines; null restores automatic', () {
    final devices = LuminaGraphicsDevices.list();
    if (devices.isEmpty || LuminaGraphicsDevices.environmentOverride != null) return;
    final target = devices.last;
    LuminaGraphicsDevices.usePreferred(target.name);
    expect(FilamentEngine.defaultGpuPreference, FilamentGpuPreference(deviceName: target.name));
    final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
    LuminaGraphicsDevices.reportEngine(engine);
    expect(LuminaGraphicsDevices.inUse.value, target.name);
    engine.dispose();
    LuminaGraphicsDevices.usePreferred(null);
    expect(FilamentEngine.defaultGpuPreference, FilamentGpuPreference.automatic);
  });

  test('a name that matches no device is reported stale', () {
    expect(LuminaGraphicsDevices.matches('No Such GPU 9000'), isFalse);
    final devices = LuminaGraphicsDevices.list();
    if (devices.isNotEmpty) expect(LuminaGraphicsDevices.matches(devices.first.name), isTrue);
  });

  test('the environment override is described and wins over a saved choice', () {
    expect(LuminaGraphicsDevices.describeOverride({'FILAMENT_GPU': 'RTX PRO'}), 'FILAMENT_GPU=RTX PRO');
    expect(LuminaGraphicsDevices.describeOverride({'VK_DEVICE_INDEX': '1'}), 'VK_DEVICE_INDEX=1');
    expect(LuminaGraphicsDevices.describeOverride({'FILAMENT_GPU': 'RTX', 'VK_DEVICE_INDEX': '1'}), 'FILAMENT_GPU=RTX');
    expect(LuminaGraphicsDevices.describeOverride({'VK_DEVICE_INDEX': 'x'}), isNull);
    expect(LuminaGraphicsDevices.describeOverride(const {}), isNull);
    // With an override, a saved name must not become an explicit preference
    // (explicit beats the environment in flutter_filament).
    LuminaGraphicsDevices.usePreferred('RTX', environment: {'VK_DEVICE_INDEX': '1'});
    expect(FilamentEngine.defaultGpuPreference, FilamentGpuPreference.automatic);
  });
}
