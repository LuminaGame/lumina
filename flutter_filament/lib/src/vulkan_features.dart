import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// One `VkBool32` member of a Vulkan device feature structure: the structure's
/// `VkStructureType`, its size, the member's byte offset and the device
/// extension the structure belongs to (empty for core structures).
class VulkanFeature {
  const VulkanFeature({
    required this.name,
    required this.sType,
    required this.structSize,
    required this.fieldOffset,
    this.extension = '',
  });

  /// A readable name, for logs (`shaderSubgroupClock`, ...).
  final String name;
  final int sType;
  final int structSize;
  final int fieldOffset;
  final String extension;

  /// `VkPhysicalDeviceShaderClockFeaturesKHR::shaderSubgroupClock` (VK_KHR_shader_clock).
  static const shaderSubgroupClock = VulkanFeature(
    name: 'shaderSubgroupClock',
    sType: 1000181000,
    structSize: 24,
    fieldOffset: 16,
    extension: 'VK_KHR_shader_clock',
  );

  /// `VkPhysicalDeviceShaderClockFeaturesKHR::shaderDeviceClock` (VK_KHR_shader_clock).
  static const shaderDeviceClock = VulkanFeature(
    name: 'shaderDeviceClock',
    sType: 1000181000,
    structSize: 24,
    fieldOffset: 20,
    extension: 'VK_KHR_shader_clock',
  );

  /// `VkPhysicalDeviceCooperativeMatrixFeaturesKHR::cooperativeMatrix` (VK_KHR_cooperative_matrix).
  static const cooperativeMatrix = VulkanFeature(
    name: 'cooperativeMatrix',
    sType: 1000506000,
    structSize: 24,
    fieldOffset: 16,
    extension: 'VK_KHR_cooperative_matrix',
  );

  /// `VkPhysicalDeviceOpticalFlowFeaturesNV::opticalFlow` (VK_NV_optical_flow), which
  /// DLSS Frame Generation's optical flow uses.
  static const opticalFlow = VulkanFeature(
    name: 'opticalFlow',
    sType: 1000464000,
    structSize: 24,
    fieldOffset: 16,
    extension: 'VK_NV_optical_flow',
  );

  /// `VkPhysicalDeviceShaderFloat8FeaturesEXT::shaderFloat8` (VK_EXT_shader_float8).
  static const shaderFloat8 = VulkanFeature(
    name: 'shaderFloat8',
    sType: 1000567000,
    structSize: 24,
    fieldOffset: 16,
    extension: 'VK_EXT_shader_float8',
  );

  /// `VkPhysicalDeviceFeatures::shaderInt16`, a core feature in the
  /// `VkPhysicalDeviceFeatures2` Filament chains itself: merged into it.
  static const shaderInt16 = VulkanFeature(
    name: 'shaderInt16',
    sType: 1000059000,
    structSize: 240,
    fieldOffset: 180,
  );

  /// `VkPhysicalDevice16BitStorageFeatures::storageBuffer16BitAccess` (Vulkan
  /// 1.1 core): merged into the `VkPhysicalDeviceVulkan11Features` Filament
  /// chains.
  static const storageBuffer16BitAccess = VulkanFeature(
    name: 'storageBuffer16BitAccess',
    sType: 1000083000,
    structSize: 32,
    fieldOffset: 16,
  );

  @override
  String toString() => 'VulkanFeature($name)';
}

/// Vulkan device extensions and feature structures for the engines created
/// from now on (desktop Vulkan only: a device cannot gain them later).
///
/// Requests are kept per requester and united when an engine is created;
/// Filament enables a feature member only when the device supports it, so
/// read the outcome back with [isFeatureEnabled] / [isExtensionEnabled].
/// On the web and other backends the requests are accepted and nothing is
/// enabled.
abstract final class VulkanFeatures {
  /// Asks for a device extension.
  static void requestExtension(String requester, String name) {
    final r = requester.toNativeUtf8();
    final n = name.toNativeUtf8();
    try {
      c.filament_vulkan_request_device_extension(r.cast(), n.cast());
    } finally {
      calloc.free(r);
      calloc.free(n);
    }
  }

  /// Asks for one feature member, and for its extension when it has one.
  static void requestFeature(String requester, VulkanFeature feature) {
    if (feature.extension.isNotEmpty)
      requestExtension(requester, feature.extension);
    final r = requester.toNativeUtf8();
    final e = feature.extension.toNativeUtf8();
    try {
      c.filament_vulkan_request_device_feature(
        r.cast(),
        feature.sType,
        feature.structSize,
        feature.fieldOffset,
        e.cast(),
      );
    } finally {
      calloc.free(r);
      calloc.free(e);
    }
  }

  /// Asks for the Vulkan API version the instance is created with
  /// ([major].[minor], for shaders that need a newer core version: SPIR-V
  /// 1.6 needs 1.3); the highest request wins, capped at what the loader
  /// offers. Filament's default is 1.1. [clear] forgets it.
  static void requestApiVersion(String requester, int major, int minor) {
    final r = requester.toNativeUtf8();
    try {
      c.filament_vulkan_request_api_version(r.cast(), (major << 22) | (minor << 12));
    } finally {
      calloc.free(r);
    }
  }

  /// The Vulkan API version [engine]'s device runs at, as (major, minor);
  /// (0, 0) on other backends.
  static (int, int) apiVersion(FilamentEngine engine) {
    final v = c.filament_vulkan_api_version(engine.nativePointer);
    return ((v >> 22) & 0x7f, (v >> 12) & 0x3ff);
  }

  /// Forgets what [requester] asked for (every requester when null).
  static void clear([String? requester]) {
    if (requester == null) {
      c.filament_vulkan_clear_requests(ffi.nullptr);
      return;
    }
    final r = requester.toNativeUtf8();
    try {
      c.filament_vulkan_clear_requests(r.cast());
    } finally {
      calloc.free(r);
    }
  }

  /// Whether [engine]'s device was created with [feature] enabled.
  static bool isFeatureEnabled(FilamentEngine engine, VulkanFeature feature) =>
      c.filament_vulkan_device_feature_enabled(
        engine.nativePointer,
        feature.sType,
        feature.fieldOffset,
      );

  /// Whether [engine]'s device was created with the extension [name] enabled.
  static bool isExtensionEnabled(FilamentEngine engine, String name) {
    final n = name.toNativeUtf8();
    try {
      return c.filament_vulkan_device_extension_enabled(
        engine.nativePointer,
        n.cast(),
      );
    } finally {
      calloc.free(n);
    }
  }
}
