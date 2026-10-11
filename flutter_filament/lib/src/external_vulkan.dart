/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:typed_data';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// The Vulkan objects an engine adopts ([FilamentEngine.createOnExternalVulkan]):
/// `VkInstance`, `VkPhysicalDevice` and `VkDevice` as addresses, the graphics
/// queue family and the index of Filament's queue in it, and whether the
/// device has the multiview feature enabled.
///
/// Queue rule: Filament submits from its driver thread on [queueIndex]. When
/// the family has two queues, give Filament index 1 and the OpenXR runtime
/// index 0; with a single queue, nothing else may submit while the engine
/// renders, except inside the swapchain provider's own callbacks (they run on
/// the driver thread).
class ExternalVulkanContext {
  const ExternalVulkanContext({
    required this.instance,
    required this.physicalDevice,
    required this.device,
    required this.queueFamily,
    required this.queueIndex,
    this.multiview = false,
  });

  /// The Vulkan objects behind [engine] (any Vulkan engine on desktop or
  /// Android), with Filament's queue family and index; [multiview] tells
  /// whether the engine renders multiview stereo. Null on other backends.
  static ExternalVulkanContext? of(FilamentEngine engine) {
    final out = calloc<c.filament_external_vulkan_context>();
    try {
      if (!c.filament_engine_get_vulkan_context(engine.nativePointer, out)) return null;
      return ExternalVulkanContext(
        instance: out.ref.instance.address,
        physicalDevice: out.ref.physical_device.address,
        device: out.ref.device.address,
        queueFamily: out.ref.queue_family,
        queueIndex: out.ref.queue_index,
        multiview: out.ref.multiview,
      );
    } finally {
      calloc.free(out);
    }
  }

  final int instance;
  final int physicalDevice;
  final int device;
  final int queueFamily;
  final int queueIndex;
  final bool multiview;

  /// Writes this context into the C struct.
  void copyToNative(c.filament_external_vulkan_context out) {
    out
      ..instance = ffi.Pointer.fromAddress(instance)
      ..physical_device = ffi.Pointer.fromAddress(physicalDevice)
      ..device = ffi.Pointer.fromAddress(device)
      ..queue_family = queueFamily
      ..queue_index = queueIndex
      ..multiview = multiview;
  }

  @override
  String toString() => 'ExternalVulkanContext(instance: 0x${instance.toRadixString(16)}, '
      'device: 0x${device.toRadixString(16)}, family $queueFamily, queue $queueIndex, multiview $multiview)';
}

/// The addresses of the `filament_external_vulkan_device_info_*` C
/// functions, for a native library that creates the device itself (an
/// OpenXR bridge passes the info's `VkDeviceCreateInfo` to
/// `xrCreateVulkanDeviceKHR`) without linking flutter_filament.
abstract final class ExternalVulkanDeviceInfoFunctions {
  static ffi.Pointer<ffi.Void> get create => ffi.Native.addressOf<
          ffi.NativeFunction<
              ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, ffi.Bool,
                  ffi.Pointer<ffi.Pointer<ffi.Char>>, ffi.Uint32)>>(c.filament_external_vulkan_device_info_create)
      .cast();

  static ffi.Pointer<ffi.Void> get createInfo =>
      ffi.Native.addressOf<ffi.NativeFunction<ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)>>(
              c.filament_external_vulkan_device_info_create_info)
          .cast();

  static ffi.Pointer<ffi.Void> get queueFamily =>
      ffi.Native.addressOf<ffi.NativeFunction<ffi.Uint32 Function(ffi.Pointer<ffi.Void>)>>(
              c.filament_external_vulkan_device_info_queue_family)
          .cast();

  static ffi.Pointer<ffi.Void> get filamentQueueIndex =>
      ffi.Native.addressOf<ffi.NativeFunction<ffi.Uint32 Function(ffi.Pointer<ffi.Void>)>>(
              c.filament_external_vulkan_device_info_filament_queue_index)
          .cast();

  static ffi.Pointer<ffi.Void> get multiview =>
      ffi.Native.addressOf<ffi.NativeFunction<ffi.Bool Function(ffi.Pointer<ffi.Void>)>>(
              c.filament_external_vulkan_device_info_multiview)
          .cast();

  static ffi.Pointer<ffi.Void> get destroy =>
      ffi.Native.addressOf<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
              c.filament_external_vulkan_device_info_destroy)
          .cast();
}

/// One recorded call of an [ExternalVulkanOffscreen] provider.
class ExternalSwapchainEvent {
  const ExternalSwapchainEvent(this.present, this.index);

  /// Decodes the native event code (`i` for an acquire, `0x100 | i` for a present).
  factory ExternalSwapchainEvent.fromCode(int code) => ExternalSwapchainEvent(code & 0x100 != 0, code & 0xff);

  /// True for a present (the image went back to its owner), false for an acquire.
  final bool present;
  final int index;

  @override
  bool operator ==(Object other) => other is ExternalSwapchainEvent && other.present == present && other.index == index;

  @override
  int get hashCode => Object.hash(present, index);

  @override
  String toString() => '${present ? 'present' : 'acquire'} $index';
}

/// A swapchain provider with no compositor behind it: its own Vulkan
/// instance and device (made with exactly what Filament needs, multiview
/// included when asked and supported) and [imageCount] RGBA8 images (sRGB
/// encoded with `srgb: true`, like a headset compositor's) of
/// [width] x [height] with [layers] array layers, which can be read back. It
/// records every acquire and present. Desktop tests use it to exercise the
/// external path that an OpenXR bridge drives on a headset.
///
/// Dispose the engine (and its swapchain) before this.
class ExternalVulkanOffscreen {
  ExternalVulkanOffscreen._(this._ptr, this.width, this.height, this.imageCount, this.layers);

  /// Creates the instance, device and images; null when Vulkan is missing.
  static ExternalVulkanOffscreen? create({
    required int width,
    required int height,
    int imageCount = 3,
    int layers = 1,
    bool multiview = false,
    bool srgb = false,
  }) {
    final ptr = c.filament_external_vulkan_offscreen_create(width, height, imageCount, layers, multiview, srgb);
    if (ptr == ffi.nullptr) return null;
    return ExternalVulkanOffscreen._(ptr, width, height, imageCount, layers);
  }

  final ffi.Pointer<ffi.Void> _ptr;
  final int width;
  final int height;
  final int imageCount;
  final int layers;
  ffi.Pointer<c.filament_external_swapchain_provider>? _provider;
  bool _disposed = false;

  /// The Vulkan objects to hand to [FilamentEngine.createOnExternalVulkan].
  ExternalVulkanContext get context {
    _check();
    final out = calloc<c.filament_external_vulkan_context>();
    try {
      c.filament_external_vulkan_offscreen_context(_ptr, out);
      return ExternalVulkanContext(
        instance: out.ref.instance.address,
        physicalDevice: out.ref.physical_device.address,
        device: out.ref.device.address,
        queueFamily: out.ref.queue_family,
        queueIndex: out.ref.queue_index,
        multiview: out.ref.multiview,
      );
    } finally {
      calloc.free(out);
    }
  }

  /// The provider struct for [FilamentSwapChain.external] (owned by this
  /// object, valid until [dispose]).
  ffi.Pointer<c.filament_external_swapchain_provider> get provider {
    _check();
    return _provider ??= () {
      final p = calloc<c.filament_external_swapchain_provider>();
      c.filament_external_vulkan_offscreen_provider(_ptr, p);
      return p;
    }();
  }

  /// [layer] of image [index], RGBA8, top row first. Only while the engine is
  /// idle (after [FilamentEngine.flushAndWait]).
  Uint8List? readPixels(int index, {int layer = 0}) {
    _check();
    final size = width * height * 4;
    final out = calloc<ffi.Uint8>(size);
    try {
      if (!c.filament_external_vulkan_offscreen_read_pixels(_ptr, index, layer, out)) return null;
      return Uint8List.fromList(out.asTypedList(size));
    } finally {
      calloc.free(out);
    }
  }

  /// Every acquire and present so far, oldest first.
  List<ExternalSwapchainEvent> get events {
    _check();
    const capacity = 4096;
    final out = calloc<ffi.Uint32>(capacity);
    try {
      final n = c.filament_external_vulkan_offscreen_events(_ptr, out, capacity);
      return [for (var i = 0; i < n; i++) ExternalSwapchainEvent.fromCode(out[i])];
    } finally {
      calloc.free(out);
    }
  }

  /// Destroys the images, device and instance.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_provider != null) calloc.free(_provider!);
    c.filament_external_vulkan_offscreen_destroy(_ptr);
  }

  void _check() {
    if (_disposed) throw StateError('ExternalVulkanOffscreen used after dispose');
  }
}
