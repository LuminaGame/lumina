/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// What a device needs so that Filament can adopt it
// (filament_external_vulkan_device_info_*), and a reference swapchain
// provider with no compositor behind it (filament_external_vulkan_offscreen_*)
// that desktop tests and bring-up use. The engine side (the platform that
// adopts the device and calls a provider) is in gpu_engine_c.cpp.

#include "external_vulkan_c.h"

#if !defined(__EMSCRIPTEN__) && (defined(_WIN32) || defined(__linux__))
#define FLUTTER_FILAMENT_EXTERNAL_VULKAN 1
#endif

#if FLUTTER_FILAMENT_EXTERNAL_VULKAN

#include <bluevk/BlueVK.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

using namespace bluevk;

namespace {

struct DeviceInfo {
    std::vector<std::string> extensionNames;
    std::vector<const char*> extensions;
    float priorities[2] = {1.0f, 1.0f};
    VkDeviceQueueCreateInfo queues[2]{};
    VkPhysicalDeviceVulkan11Features vk11{};
    VkPhysicalDeviceFeatures2 features{};
    VkDeviceCreateInfo createInfo{};
    uint32_t family = 0;
    uint32_t filamentQueue = 0;
    bool multiview = false;
};

bool loadVulkan() {
    static const bool loaded = bluevk::initialize();
    return loaded;
}

DeviceInfo* makeDeviceInfo(VkPhysicalDevice physical, bool multiview, const char* const* extra, uint32_t extraCount) {
    uint32_t familyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physical, &familyCount, nullptr);
    std::vector<VkQueueFamilyProperties> families(familyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(physical, &familyCount, families.data());
    uint32_t family = UINT32_MAX;
    for (uint32_t i = 0; i < familyCount; ++i) {
        if (families[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
            family = i;
            break;
        }
    }
    if (family == UINT32_MAX) return nullptr;

    auto* info = new DeviceInfo();
    info->family = family;

    // The features Filament enables when it creates the device itself
    // (VulkanPlatform::createLogicalDeviceAndQueues), as far as supported.
    VkPhysicalDeviceVulkan11Features supported11{};
    supported11.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES;
    VkPhysicalDeviceFeatures2 supported{};
    supported.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
    supported.pNext = &supported11;
    vkGetPhysicalDeviceFeatures2(physical, &supported);

    info->features.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
    info->features.features.depthClamp = supported.features.depthClamp;
    info->features.features.samplerAnisotropy = supported.features.samplerAnisotropy;
    info->features.features.textureCompressionETC2 = supported.features.textureCompressionETC2;
    info->features.features.textureCompressionBC = supported.features.textureCompressionBC;
    info->features.features.shaderClipDistance = supported.features.shaderClipDistance;
    info->vk11.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES;
    info->multiview = multiview && supported11.multiview == VK_TRUE;
    info->vk11.multiview = info->multiview ? VK_TRUE : VK_FALSE;
#if defined(__ANDROID__)
    info->vk11.samplerYcbcrConversion = supported11.samplerYcbcrConversion;
#endif
    // Filament fetches a protected queue whenever the device supports protected memory.
    const bool protectedQueue = supported11.protectedMemory == VK_TRUE &&
            (families[family].queueFlags & VK_QUEUE_PROTECTED_BIT) != 0;
    info->vk11.protectedMemory = protectedQueue ? VK_TRUE : VK_FALSE;
    info->features.pNext = &info->vk11;

    // Two queues when the family has them: index 0 for the runtime (OpenXR's
    // graphics binding), index 1 for Filament's driver thread.
    const uint32_t count = std::min<uint32_t>(families[family].queueCount, 2);
    info->filamentQueue = count >= 2 ? 1 : 0;
    info->queues[0].sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    info->queues[0].queueFamilyIndex = family;
    info->queues[0].queueCount = count;
    info->queues[0].pQueuePriorities = info->priorities;
    info->queues[1] = info->queues[0];
    info->queues[1].flags = VK_DEVICE_QUEUE_CREATE_PROTECTED_BIT;
    info->queues[1].queueCount = 1;

    uint32_t available = 0;
    vkEnumerateDeviceExtensionProperties(physical, nullptr, &available, nullptr);
    std::vector<VkExtensionProperties> offered(available);
    vkEnumerateDeviceExtensionProperties(physical, nullptr, &available, offered.data());
    for (uint32_t i = 0; i < extraCount; ++i) {
        if (!extra || !extra[i]) continue;
        const bool found = std::any_of(offered.begin(), offered.end(),
                [&](const VkExtensionProperties& p) { return std::strcmp(p.extensionName, extra[i]) == 0; });
        if (found) {
            info->extensionNames.emplace_back(extra[i]);
        } else {
            fprintf(stderr, "[flutter_filament] device extension %s is not available; skipped\n", extra[i]);
        }
    }
    for (const auto& name : info->extensionNames) info->extensions.push_back(name.c_str());

    info->createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    info->createInfo.pNext = &info->features;
    info->createInfo.queueCreateInfoCount = protectedQueue ? 2 : 1;
    info->createInfo.pQueueCreateInfos = info->queues;
    info->createInfo.enabledExtensionCount = static_cast<uint32_t>(info->extensions.size());
    info->createInfo.ppEnabledExtensionNames = info->extensions.empty() ? nullptr : info->extensions.data();
    return info;
}

// ---------------------------------------------------------------------------
// The offscreen reference provider.

struct Offscreen {
    VkInstance instance = VK_NULL_HANDLE;
    VkPhysicalDevice physical = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    DeviceInfo* deviceInfo = nullptr;
    VkQueue queue = VK_NULL_HANDLE;  // the "runtime" queue (index 0), used for read-backs
    uint32_t width = 0, height = 0, layers = 1, count = 0;
    VkFormat format = VK_FORMAT_R8G8B8A8_UNORM;
    std::vector<VkImage> images;
    std::vector<VkDeviceMemory> memories;
    VkImage depth = VK_NULL_HANDLE;
    VkDeviceMemory depthMemory = VK_NULL_HANDLE;
    uint32_t next = 0;
    std::mutex eventsMutex;
    std::vector<uint32_t> events;
};

uint32_t memoryType(VkPhysicalDevice physical, uint32_t bits, VkMemoryPropertyFlags flags) {
    VkPhysicalDeviceMemoryProperties props{};
    vkGetPhysicalDeviceMemoryProperties(physical, &props);
    for (uint32_t i = 0; i < props.memoryTypeCount; ++i) {
        if ((bits & (1u << i)) && (props.memoryTypes[i].propertyFlags & flags) == flags) return i;
    }
    return UINT32_MAX;
}

bool makeImage(Offscreen* o, VkFormat format, VkImageUsageFlags usage, VkImage* image, VkDeviceMemory* memory) {
    VkImageCreateInfo ci{};
    ci.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    ci.imageType = VK_IMAGE_TYPE_2D;
    ci.format = format;
    ci.extent = {o->width, o->height, 1};
    ci.mipLevels = 1;
    ci.arrayLayers = o->layers;
    ci.samples = VK_SAMPLE_COUNT_1_BIT;
    ci.tiling = VK_IMAGE_TILING_OPTIMAL;
    ci.usage = usage;
    ci.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    ci.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    if (vkCreateImage(o->device, &ci, nullptr, image) != VK_SUCCESS) return false;
    VkMemoryRequirements req{};
    vkGetImageMemoryRequirements(o->device, *image, &req);
    VkMemoryAllocateInfo ai{};
    ai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    ai.allocationSize = req.size;
    ai.memoryTypeIndex = memoryType(o->physical, req.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    if (ai.memoryTypeIndex == UINT32_MAX || vkAllocateMemory(o->device, &ai, nullptr, memory) != VK_SUCCESS) {
        return false;
    }
    return vkBindImageMemory(o->device, *image, *memory, 0) == VK_SUCCESS;
}

void record(Offscreen* o, uint32_t event) {
    std::lock_guard<std::mutex> lock(o->eventsMutex);
    o->events.push_back(event);
}

void offscreenGetImages(void* user, uint64_t* colors, uint64_t* depth) {
    auto* o = static_cast<Offscreen*>(user);
    for (uint32_t i = 0; i < o->count; ++i) colors[i] = reinterpret_cast<uint64_t>(o->images[i]);
    *depth = reinterpret_cast<uint64_t>(o->depth);
}

int32_t offscreenAcquire(void* user, uint32_t* index) {
    auto* o = static_cast<Offscreen*>(user);
    *index = o->next;
    o->next = (o->next + 1) % o->count;
    record(o, *index);
    return VK_SUCCESS;
}

int32_t offscreenPresent(void* user, uint32_t index) {
    record(static_cast<Offscreen*>(user), 0x100u | index);
    return VK_SUCCESS;
}

/// The device the environment asks for (FILAMENT_GPU names one, as for every
/// other engine), else the first.
VkPhysicalDevice pickDevice(VkInstance instance) {
    uint32_t count = 0;
    vkEnumeratePhysicalDevices(instance, &count, nullptr);
    std::vector<VkPhysicalDevice> devices(count);
    vkEnumeratePhysicalDevices(instance, &count, devices.data());
    if (devices.empty()) return VK_NULL_HANDLE;
    const char* wanted = std::getenv("FILAMENT_GPU");
    if (wanted && *wanted) {
        for (VkPhysicalDevice d : devices) {
            VkPhysicalDeviceProperties props{};
            vkGetPhysicalDeviceProperties(d, &props);
            if (std::strstr(props.deviceName, wanted)) return d;
        }
    }
    return devices.front();
}

void destroyOffscreen(Offscreen* o) {
    if (o->device) {
        vkDeviceWaitIdle(o->device);
        for (size_t i = 0; i < o->images.size(); ++i) {
            if (o->images[i]) vkDestroyImage(o->device, o->images[i], nullptr);
            if (o->memories[i]) vkFreeMemory(o->device, o->memories[i], nullptr);
        }
        if (o->depth) vkDestroyImage(o->device, o->depth, nullptr);
        if (o->depthMemory) vkFreeMemory(o->device, o->depthMemory, nullptr);
        vkDestroyDevice(o->device, nullptr);
    }
    if (o->instance) vkDestroyInstance(o->instance, nullptr);
    delete o->deviceInfo;
    delete o;
}

}  // namespace

void* filament_external_vulkan_device_info_create(void* instance, void* physical_device, bool multiview,
        const char* const* extra_extensions, uint32_t extra_extension_count) {
    if (!instance || !physical_device || !loadVulkan()) return nullptr;
    bluevk::bindInstance(static_cast<VkInstance>(instance));
    return makeDeviceInfo(static_cast<VkPhysicalDevice>(physical_device), multiview, extra_extensions,
            extra_extension_count);
}

const void* filament_external_vulkan_device_info_create_info(void* info) {
    return info ? &static_cast<DeviceInfo*>(info)->createInfo : nullptr;
}

uint32_t filament_external_vulkan_device_info_queue_family(void* info) {
    return info ? static_cast<DeviceInfo*>(info)->family : 0;
}

uint32_t filament_external_vulkan_device_info_filament_queue_index(void* info) {
    return info ? static_cast<DeviceInfo*>(info)->filamentQueue : 0;
}

bool filament_external_vulkan_device_info_multiview(void* info) {
    return info && static_cast<DeviceInfo*>(info)->multiview;
}

void filament_external_vulkan_device_info_destroy(void* info) {
    delete static_cast<DeviceInfo*>(info);
}

void* filament_external_vulkan_offscreen_create(uint32_t width, uint32_t height, uint32_t image_count,
        uint32_t layer_count, bool multiview, bool srgb) {
    if (width == 0 || height == 0 || image_count == 0 || !loadVulkan()) return nullptr;
    auto* o = new Offscreen();
    o->width = width;
    o->height = height;
    o->layers = layer_count == 0 ? 1 : layer_count;
    o->count = image_count;
    o->format = srgb ? VK_FORMAT_R8G8B8A8_SRGB : VK_FORMAT_R8G8B8A8_UNORM;

    VkApplicationInfo app{};
    app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app.pApplicationName = "flutter_filament external swapchain";
    app.apiVersion = VK_API_VERSION_1_2;
    VkInstanceCreateInfo ici{};
    ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ici.pApplicationInfo = &app;
    if (vkCreateInstance(&ici, nullptr, &o->instance) != VK_SUCCESS) {
        destroyOffscreen(o);
        return nullptr;
    }
    bluevk::bindInstance(o->instance);
    o->physical = pickDevice(o->instance);
    if (!o->physical) {
        destroyOffscreen(o);
        return nullptr;
    }
    o->deviceInfo = makeDeviceInfo(o->physical, multiview, nullptr, 0);
    if (!o->deviceInfo || vkCreateDevice(o->physical, &o->deviceInfo->createInfo, nullptr, &o->device) != VK_SUCCESS) {
        destroyOffscreen(o);
        return nullptr;
    }
    vkGetDeviceQueue(o->device, o->deviceInfo->family, 0, &o->queue);

    o->images.assign(image_count, VK_NULL_HANDLE);
    o->memories.assign(image_count, VK_NULL_HANDLE);
    for (uint32_t i = 0; i < image_count; ++i) {
        if (!makeImage(o, o->format,
                    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                            VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                    &o->images[i], &o->memories[i])) {
            destroyOffscreen(o);
            return nullptr;
        }
    }
    if (!makeImage(o, VK_FORMAT_D32_SFLOAT, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                &o->depth, &o->depthMemory)) {
        destroyOffscreen(o);
        return nullptr;
    }
    return o;
}

void filament_external_vulkan_offscreen_context(void* offscreen, filament_external_vulkan_context* out) {
    if (!offscreen || !out) return;
    auto* o = static_cast<Offscreen*>(offscreen);
    out->instance = o->instance;
    out->physical_device = o->physical;
    out->device = o->device;
    out->queue_family = o->deviceInfo->family;
    out->queue_index = o->deviceInfo->filamentQueue;
    out->multiview = o->deviceInfo->multiview;
}

void filament_external_vulkan_offscreen_provider(void* offscreen, filament_external_swapchain_provider* out) {
    if (!offscreen || !out) return;
    auto* o = static_cast<Offscreen*>(offscreen);
    *out = filament_external_swapchain_provider{};
    out->user_data = o;
    out->image_count = o->count;
    out->width = o->width;
    out->height = o->height;
    out->color_format = o->format;
    out->layer_count = o->layers;
    out->depth_format = VK_FORMAT_D32_SFLOAT;
    out->get_images = offscreenGetImages;
    out->acquire = offscreenAcquire;
    out->present = offscreenPresent;
    out->destroy = nullptr;
}

bool filament_external_vulkan_offscreen_read_pixels(void* offscreen, uint32_t index, uint32_t layer, uint8_t* out) {
    if (!offscreen || !out) return false;
    auto* o = static_cast<Offscreen*>(offscreen);
    if (index >= o->count || layer >= o->layers) return false;
    const VkDeviceSize size = VkDeviceSize(o->width) * o->height * 4;

    VkBuffer buffer = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    VkCommandPool pool = VK_NULL_HANDLE;
    bool ok = false;
    do {
        VkBufferCreateInfo bci{};
        bci.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bci.size = size;
        bci.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        if (vkCreateBuffer(o->device, &bci, nullptr, &buffer) != VK_SUCCESS) break;
        VkMemoryRequirements req{};
        vkGetBufferMemoryRequirements(o->device, buffer, &req);
        VkMemoryAllocateInfo ai{};
        ai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        ai.allocationSize = req.size;
        ai.memoryTypeIndex = memoryType(o->physical, req.memoryTypeBits,
                VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
        if (ai.memoryTypeIndex == UINT32_MAX || vkAllocateMemory(o->device, &ai, nullptr, &memory) != VK_SUCCESS) break;
        vkBindBufferMemory(o->device, buffer, memory, 0);

        VkCommandPoolCreateInfo pci{};
        pci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        pci.queueFamilyIndex = o->deviceInfo->family;
        if (vkCreateCommandPool(o->device, &pci, nullptr, &pool) != VK_SUCCESS) break;
        VkCommandBufferAllocateInfo cai{};
        cai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        cai.commandPool = pool;
        cai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        cai.commandBufferCount = 1;
        VkCommandBuffer cmd = VK_NULL_HANDLE;
        if (vkAllocateCommandBuffers(o->device, &cai, &cmd) != VK_SUCCESS) break;
        VkCommandBufferBeginInfo begin{};
        begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        vkBeginCommandBuffer(cmd, &begin);

        // The engine left the image as a colour attachment (it does not transition external
        // images for present), which is also how a compositor takes them back.
        VkImageMemoryBarrier toSrc{};
        toSrc.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        toSrc.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        toSrc.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        toSrc.oldLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        toSrc.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        toSrc.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        toSrc.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        toSrc.image = o->images[index];
        toSrc.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, layer, 1};
        vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0,
                0, nullptr, 0, nullptr, 1, &toSrc);
        VkBufferImageCopy region{};
        region.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, layer, 1};
        region.imageExtent = {o->width, o->height, 1};
        vkCmdCopyImageToBuffer(cmd, o->images[index], VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, buffer, 1, &region);
        VkImageMemoryBarrier back = toSrc;
        back.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        back.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        back.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        back.newLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, 0,
                0, nullptr, 0, nullptr, 1, &back);
        vkEndCommandBuffer(cmd);
        VkSubmitInfo submit{};
        submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submit.commandBufferCount = 1;
        submit.pCommandBuffers = &cmd;
        if (vkQueueSubmit(o->queue, 1, &submit, VK_NULL_HANDLE) != VK_SUCCESS) break;
        vkQueueWaitIdle(o->queue);
        void* mapped = nullptr;
        if (vkMapMemory(o->device, memory, 0, size, 0, &mapped) != VK_SUCCESS) break;
        std::memcpy(out, mapped, static_cast<size_t>(size));
        vkUnmapMemory(o->device, memory);
        ok = true;
    } while (false);
    if (pool) vkDestroyCommandPool(o->device, pool, nullptr);
    if (buffer) vkDestroyBuffer(o->device, buffer, nullptr);
    if (memory) vkFreeMemory(o->device, memory, nullptr);
    return ok;
}

uint32_t filament_external_vulkan_offscreen_events(void* offscreen, uint32_t* out, uint32_t capacity) {
    if (!offscreen) return 0;
    auto* o = static_cast<Offscreen*>(offscreen);
    std::lock_guard<std::mutex> lock(o->eventsMutex);
    const uint32_t n = std::min<uint32_t>(capacity, static_cast<uint32_t>(o->events.size()));
    for (uint32_t i = 0; i < n && out; ++i) out[i] = o->events[i];
    return n;
}

void filament_external_vulkan_offscreen_destroy(void* offscreen) {
    if (offscreen) destroyOffscreen(static_cast<Offscreen*>(offscreen));
}

#else  // no desktop/Android Vulkan (web): every entry point reports "unsupported"

void* filament_external_vulkan_device_info_create(void*, void*, bool, const char* const*, uint32_t) { return nullptr; }
const void* filament_external_vulkan_device_info_create_info(void*) { return nullptr; }
uint32_t filament_external_vulkan_device_info_queue_family(void*) { return 0; }
uint32_t filament_external_vulkan_device_info_filament_queue_index(void*) { return 0; }
bool filament_external_vulkan_device_info_multiview(void*) { return false; }
void filament_external_vulkan_device_info_destroy(void*) {}
void* filament_external_vulkan_offscreen_create(uint32_t, uint32_t, uint32_t, uint32_t, bool, bool) { return nullptr; }
void filament_external_vulkan_offscreen_context(void*, filament_external_vulkan_context*) {}
void filament_external_vulkan_offscreen_provider(void*, filament_external_swapchain_provider*) {}
bool filament_external_vulkan_offscreen_read_pixels(void*, uint32_t, uint32_t, uint8_t*) { return false; }
uint32_t filament_external_vulkan_offscreen_events(void*, uint32_t*, uint32_t) { return 0; }
void filament_external_vulkan_offscreen_destroy(void*) {}

#endif
