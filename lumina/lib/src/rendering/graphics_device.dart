import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_filament/flutter_filament.dart';

/// A GPU the engine can render on (Vulkan device).
class LuminaGraphicsDevice {
  final String name;
  final String typeLabel;
  final int index;
  final bool isDiscrete;

  const LuminaGraphicsDevice({required this.name, required this.typeLabel, required this.index, required this.isDiscrete});

  /// `NVIDIA RTX PRO 2000 Blackwell · Discrete`.
  String get label => '$name · $typeLabel';
}

/// Which GPU the editor renders on: lists the Vulkan
/// devices, applies the saved choice to every engine created afterwards, and
/// tracks the device the running engine actually uses.
abstract final class LuminaGraphicsDevices {
  /// The device of the most recent engine [reportEngine] saw; null until one
  /// exists (or on a non-Vulkan backend).
  static final ValueNotifier<String?> inUse = ValueNotifier<String?>(null);

  static List<LuminaGraphicsDevice> list() {
    try {
      return [
        for (final d in FilamentGpu.listVulkanDevices())
          LuminaGraphicsDevice(
            name: d.name,
            typeLabel: d.type.label,
            index: d.index,
            isDiscrete: d.type == FilamentGpuType.discrete,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Whether [deviceName] still names one of this machine's devices.
  static bool matches(String deviceName) => list().any((d) => d.name.contains(deviceName));

  /// `FILAMENT_GPU=…` or `VK_DEVICE_INDEX=…` when the environment chooses the
  /// GPU (smoke and CI runs); null otherwise.
  static String? describeOverride(Map<String, String> environment) {
    final gpu = environment['FILAMENT_GPU'];
    if (gpu != null && gpu.isNotEmpty) return 'FILAMENT_GPU=$gpu';
    final index = environment['VK_DEVICE_INDEX'];
    if (index != null && RegExp(r'^\d+$').hasMatch(index)) return 'VK_DEVICE_INDEX=$index';
    return null;
  }

  static String? get environmentOverride => describeOverride(Platform.environment);

  /// Makes [deviceName] (null = automatic) the GPU of every engine created
  /// from now on. An environment override wins: the preference then stays
  /// automatic so flutter_filament reads the environment.
  static void usePreferred(String? deviceName, {Map<String, String>? environment}) {
    final overridden = describeOverride(environment ?? Platform.environment) != null;
    FilamentEngine.defaultGpuPreference = deviceName == null || deviceName.isEmpty || overridden
        ? FilamentGpuPreference.automatic
        : FilamentGpuPreference(deviceName: deviceName);
  }

  /// Records the device [engine] renders on, for the status bar and the
  /// launcher's "(in use)" mark.
  static void reportEngine(FilamentEngine engine) {
    final name = engine.gpuName;
    if (name.isNotEmpty) inUse.value = name;
  }
}
