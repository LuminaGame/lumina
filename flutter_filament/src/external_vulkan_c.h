/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// An engine on a Vulkan instance and device someone else created, rendering
/// into swapchain images someone else owns: the OpenXR path
/// (`XR_KHR_vulkan_enable2` creates the device, the compositor owns the
/// images). flutter_filament never links OpenXR; a separate native library
/// (the OpenXR bridge) fills these structs.
///
/// Queue rule: Filament submits from its driver thread on the queue named by
/// `filament_external_vulkan_context::queue_index`. Give it a queue of its own
/// in the family when the device has two (see
/// `filament_external_vulkan_device_info_filament_queue_index`), and the
/// runtime the other one; on a family with a single queue, the provider's
/// `acquire` / `present` (which run on the driver thread) are the only safe
/// place to touch that queue, and everything else must wait for the engine
/// to be idle.

#ifndef FLUTTER_FILAMENT_EXTERNAL_VULKAN_C_H
#define FLUTTER_FILAMENT_EXTERNAL_VULKAN_C_H

#include <stdbool.h>
#include <stdint.h>

#include "engine_c.h"

#ifdef __cplusplus
extern "C" {
#endif

/// The Vulkan objects an external engine adopts (VkInstance,
/// VkPhysicalDevice, VkDevice as pointers), the graphics queue family and
/// the index of Filament's queue in it, and whether the device was created
/// with the multiview feature.
typedef struct filament_external_vulkan_context {
    void* instance;
    void* physical_device;
    void* device;
    uint32_t queue_family;
    uint32_t queue_index;
    bool multiview;
} filament_external_vulkan_context;

/// Swapchain images owned by someone else (an OpenXR swapchain). The
/// callbacks run on Filament's driver thread; Dart never calls them.
typedef struct filament_external_swapchain_provider {
    void* user_data;
    /// Number of colour images, their size, VkFormat and array layers (2 for
    /// a multiview image).
    uint32_t image_count;
    uint32_t width;
    uint32_t height;
    uint32_t color_format;
    uint32_t layer_count;
    /// VkFormat of `depth` from get_images, or of the depth image Filament
    /// makes itself when get_images leaves it 0.
    uint32_t depth_format;
    /// Writes image_count VkImage handles into `colors` and a depth VkImage
    /// (or 0) into `depth`.
    void (*get_images)(void* user_data, uint64_t* colors, uint64_t* depth);
    /// Waits until an image may be rendered (xrAcquireSwapchainImage +
    /// xrWaitSwapchainImage) and writes its index. Returns a VkResult.
    int32_t (*acquire)(void* user_data, uint32_t* index);
    /// The image's commands are submitted (xrReleaseSwapchainImage). Returns
    /// a VkResult.
    int32_t (*present)(void* user_data, uint32_t index);
    /// The swapchain is gone; may be null.
    void (*destroy)(void* user_data);
} filament_external_swapchain_provider;

/// Creates a Vulkan engine on the given objects. `config` may be null. A
/// GPU preference (FILAMENT_GPU, VK_DEVICE_INDEX) does not apply and is
/// ignored with a log line. Returns null on failure.
FFI_PLUGIN_EXPORT void* filament_engine_create_external_vulkan(const filament_external_vulkan_context* context,
        int feature_level, const filament_engine_config_t* config);

/// The Vulkan objects behind a Vulkan [engine] (external or not): instance,
/// physical device, device, the queue family and index Filament submits on,
/// and whether the device supports multiview. False for other backends.
FFI_PLUGIN_EXPORT bool filament_engine_get_vulkan_context(void* engine, filament_external_vulkan_context* out);

/// Whether [engine] was made by filament_engine_create_external_vulkan.
FFI_PLUGIN_EXPORT bool filament_engine_is_external_vulkan(void* engine);

/// A SwapChain whose images come from [provider] (copied; its user_data must
/// stay valid until the SwapChain is destroyed). Only on an engine from
/// filament_engine_create_external_vulkan; null otherwise.
FFI_PLUGIN_EXPORT void* filament_swap_chain_create_external(void* engine,
        const filament_external_swapchain_provider* provider);

/// What Filament needs from a device it will adopt: the features and
/// extensions it would enable itself (multiview when asked and supported),
/// one or two queues of the graphics family, plus a protected queue when the
/// device supports protected memory. The caller passes
/// filament_external_vulkan_device_info_create_info to vkCreateDevice or
/// xrCreateVulkanDeviceKHR. `extra_extensions` are added (unavailable ones
/// are dropped). Returns null when the device has no graphics queue.
FFI_PLUGIN_EXPORT void* filament_external_vulkan_device_info_create(void* instance, void* physical_device,
        bool multiview, const char* const* extra_extensions, uint32_t extra_extension_count);
/// The VkDeviceCreateInfo (valid while the info lives).
FFI_PLUGIN_EXPORT const void* filament_external_vulkan_device_info_create_info(void* info);
FFI_PLUGIN_EXPORT uint32_t filament_external_vulkan_device_info_queue_family(void* info);
/// The queue index Filament should use: 1 when the family offered two queues
/// (index 0 then belongs to the runtime), else 0.
FFI_PLUGIN_EXPORT uint32_t filament_external_vulkan_device_info_filament_queue_index(void* info);
FFI_PLUGIN_EXPORT bool filament_external_vulkan_device_info_multiview(void* info);
FFI_PLUGIN_EXPORT void filament_external_vulkan_device_info_destroy(void* info);

/// A reference provider with no compositor behind it: it creates its own
/// instance and device (through filament_external_vulkan_device_info), and
/// [image_count] RGBA8 images (sRGB-encoded when [srgb], as a headset
/// compositor's usually are) of [width] x [height] with [layer_count]
/// layers that can be read back. Desktop tests and bring-up use it; it
/// records every acquire and present. Returns null when Vulkan is missing.
FFI_PLUGIN_EXPORT void* filament_external_vulkan_offscreen_create(uint32_t width, uint32_t height,
        uint32_t image_count, uint32_t layer_count, bool multiview, bool srgb);
FFI_PLUGIN_EXPORT void filament_external_vulkan_offscreen_context(void* offscreen,
        filament_external_vulkan_context* out);
FFI_PLUGIN_EXPORT void filament_external_vulkan_offscreen_provider(void* offscreen,
        filament_external_swapchain_provider* out);
/// Copies [layer] of image [index] into [out] (width * height * 4 bytes,
/// RGBA8, top row first). Call only while the engine is idle
/// (filament_engine_flush_and_wait). Returns false on failure.
FFI_PLUGIN_EXPORT bool filament_external_vulkan_offscreen_read_pixels(void* offscreen, uint32_t index,
        uint32_t layer, uint8_t* out);
/// Writes up to [capacity] recorded events, oldest first: an acquire of image
/// i is i, a present of image i is 0x100 | i. Returns how many were written.
FFI_PLUGIN_EXPORT uint32_t filament_external_vulkan_offscreen_events(void* offscreen, uint32_t* out,
        uint32_t capacity);
/// Destroys the images, device and instance. Destroy the engine first.
FFI_PLUGIN_EXPORT void filament_external_vulkan_offscreen_destroy(void* offscreen);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_EXTERNAL_VULKAN_C_H
