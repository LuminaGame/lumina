import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// List the Vulkan devices, create engines on a chosen one, and
/// read back which one Filament picked. Runs on the real Vulkan backend and
/// skips on a host without Vulkan devices.
void main() {
  final devices = FilamentGpu.listVulkanDevices();
  final skip = devices.isEmpty ? 'no Vulkan devices on this host' : null;
  FilamentGpuInfo? named(String part) {
    for (final d in devices) {
      if (d.name.contains(part)) return d;
    }
    return null;
  }

  tearDown(() => FilamentEngine.defaultGpuPreference = FilamentGpuPreference.automatic);

  String gpuOf(FilamentEngine? engine) {
    expect(engine, isNotNull);
    final name = engine!.gpuName;
    engine.dispose();
    return name;
  }

  test('lists the devices in loader order with unique indices', () {
    expect(devices.map((d) => d.index).toSet().length, devices.length);
    for (var i = 0; i < devices.length; i++) {
      expect(devices[i].index, i);
      expect(devices[i].name, isNotEmpty);
    }
    final cpu = named('llvmpipe');
    if (cpu != null) expect(cpu.type, FilamentGpuType.cpu);
    final pro = named('RTX PRO 2000');
    if (pro != null) expect(pro.type, FilamentGpuType.discrete);
  }, skip: skip);

  test('creates an engine on each device, named or indexed', () {
    // Every device by name, so a name that only matches Filament's own
    // default choice cannot pass by accident.
    for (final d in devices) {
      expect(gpuOf(FilamentEngine.create(backend: FilamentBackend.vulkan, gpu: FilamentGpuPreference(deviceName: d.name))), d.name);
      expect(gpuOf(FilamentEngine.create(backend: FilamentBackend.vulkan, gpu: FilamentGpuPreference(index: d.index))), d.name);
    }
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('the process-wide default applies to engines created without a preference', () {
    final cpu = named('llvmpipe');
    if (cpu == null) return;
    FilamentEngine.defaultGpuPreference = const FilamentGpuPreference(deviceName: 'llvmpipe');
    expect(gpuOf(FilamentEngine.create(backend: FilamentBackend.vulkan)), contains('llvmpipe'));
    FilamentEngine.defaultGpuPreference = FilamentGpuPreference.automatic;
    final automatic = gpuOf(FilamentEngine.create(backend: FilamentBackend.vulkan));
    expect(automatic, isNotEmpty);
    expect(automatic, isNot(contains('llvmpipe')), reason: 'Filament prefers a discrete GPU over the CPU device');
  }, skip: skip);

  test('a name that matches nothing falls back to a real device', () {
    final name = gpuOf(FilamentEngine.create(
        backend: FilamentBackend.vulkan, gpu: const FilamentGpuPreference(deviceName: 'No Such GPU 9000')));
    expect(devices.map((d) => d.name), contains(name));
  }, skip: skip);

  test('an out-of-range index is ignored instead of aborting', () {
    final name = gpuOf(FilamentEngine.create(backend: FilamentBackend.vulkan, gpu: const FilamentGpuPreference(index: 99)));
    expect(devices.map((d) => d.name), contains(name));
  }, skip: skip);

  test('VK_DEVICE_INDEX selects the device when nothing is set in code', () async {
    final second = devices.length > 1 ? devices[1] : null;
    if (second == null) return;
    // A fresh process, so the variable is read at engine creation.
    final result = await Process.run(
      'flutter',
      ['test', 'test/src/gpu_env_probe.dart'],
      environment: {'VK_DEVICE_INDEX': '${second.index}', 'FILAMENT_GPU': ''},
    );
    expect('${result.stdout}', contains('GPU_PROBE=${second.name}'), reason: '${result.stdout}\n${result.stderr}');
  },
      // Windows locks a loaded DLL: this process holds
      // build/native_assets/windows/flutter_filament.dll open, so the nested
      // `flutter test` cannot re-bundle it. Run gpu_env_probe.dart directly
      // with VK_DEVICE_INDEX set instead.
      skip: skip ?? (Platform.isWindows ? 'nested flutter test cannot replace the loaded DLL on Windows' : null),
      timeout: const Timeout(Duration(minutes: 4)));

  test('no platform outlives its engine', () {
    // Counted directly: RSS is useless here, since the loader brings up every
    // ICD per VkInstance and NVIDIA's keeps ~10 MB each after destruction.
    final before = FilamentGpu.livePlatformCount;
    final engines = [
      for (var i = 0; i < 5; i++)
        FilamentEngine.create(backend: FilamentBackend.vulkan, gpu: FilamentGpuPreference(index: devices[i % devices.length].index))!,
    ];
    expect(FilamentGpu.livePlatformCount, before + 5);
    for (final e in engines) {
      e.dispose();
    }
    expect(FilamentGpu.livePlatformCount, before);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('non-Vulkan backends report no device and ignore a preference', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop, gpu: const FilamentGpuPreference(deviceName: 'RTX'));
    expect(engine, isNotNull);
    expect(engine!.gpuName, '');
    engine.dispose();
  });
}
