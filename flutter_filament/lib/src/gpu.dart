import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// The kind of a Vulkan physical device (`VkPhysicalDeviceType`).
enum FilamentGpuType {
  other,
  integrated,
  discrete,
  virtualGpu,
  cpu;

  static FilamentGpuType fromVulkan(int type) =>
      type >= 0 && type < FilamentGpuType.values.length ? FilamentGpuType.values[type] : FilamentGpuType.other;

  /// A short label for pickers: Discrete, Integrated, Virtual, CPU, Other.
  String get label => switch (this) {
        FilamentGpuType.discrete => 'Discrete',
        FilamentGpuType.integrated => 'Integrated',
        FilamentGpuType.virtualGpu => 'Virtual',
        FilamentGpuType.cpu => 'CPU',
        FilamentGpuType.other => 'Other',
      };
}

/// One Vulkan device, as the system loader enumerates it.
class FilamentGpuInfo {
  final String name;
  final FilamentGpuType type;
  final int vendorId;
  final int deviceId;

  /// Position in the loader's enumeration: the index a
  /// [FilamentGpuPreference] or `VK_DEVICE_INDEX` refers to.
  final int index;

  const FilamentGpuInfo({
    required this.name,
    required this.type,
    required this.vendorId,
    required this.deviceId,
    required this.index,
  });

  @override
  String toString() => 'FilamentGpuInfo($index: $name, ${type.label})';
}

/// Which GPU a Vulkan engine should render on: a device-name substring, an
/// enumeration index, or neither ([automatic], Filament's own choice unless
/// the environment sets `FILAMENT_GPU` / `VK_DEVICE_INDEX`). Other backends
/// ignore it.
class FilamentGpuPreference {
  final String? deviceName;
  final int? index;

  const FilamentGpuPreference({this.deviceName, this.index});

  static const FilamentGpuPreference automatic = FilamentGpuPreference();

  bool get isAutomatic => (deviceName == null || deviceName!.isEmpty) && (index == null || index! < 0);

  @override
  bool operator ==(Object other) =>
      other is FilamentGpuPreference && other.deviceName == deviceName && other.index == index;

  @override
  int get hashCode => Object.hash(deviceName, index);

  @override
  String toString() => isAutomatic ? 'FilamentGpuPreference.automatic' : 'FilamentGpuPreference($deviceName, $index)';
}

/// Lists the GPUs a Vulkan engine can render on.
abstract final class FilamentGpu {
  /// Enumerates the Vulkan devices through the system loader, independently
  /// of any engine. Empty when Vulkan is unavailable (and on the web).
  static List<FilamentGpuInfo> listVulkanDevices() {
    final count = c.filament_vulkan_device_count();
    if (count <= 0) return const [];
    final info = calloc<c.filament_gpu_info_t>();
    try {
      return [
        for (var i = 0; i < count; i++)
          if (c.filament_vulkan_device_info(i, info))
            FilamentGpuInfo(
              name: _string(info.ref.name),
              type: FilamentGpuType.fromVulkan(info.ref.type),
              vendorId: info.ref.vendor_id,
              deviceId: info.ref.device_id,
              index: info.ref.index,
            ),
      ];
    } finally {
      calloc.free(info);
    }
  }

  /// Vulkan platforms alive in this process: one per Vulkan engine not yet
  /// disposed. For leak checks.
  static int get livePlatformCount => c.filament_gpu_live_platform_count();

  static String _string(ffi.Array<ffi.Char> chars) {
    final codes = <int>[];
    for (var i = 0; i < 256; i++) {
      final ch = chars[i];
      if (ch == 0) break;
      codes.add(ch & 0xFF);
    }
    return String.fromCharCodes(codes);
  }
}
