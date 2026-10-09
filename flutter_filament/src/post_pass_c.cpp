/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// A debug external post pass: a compute shader recorded into Filament's command buffer
// through View::setExternalPostPass (Vulkan, desktop). It shows the frame a neural pass would
// receive (colour, motion, history validity) and checks the hook end to end.

#include "post_pass_c.h"

#include <atomic>
#include <mutex>
#include <string>

#if !defined(__EMSCRIPTEN__) && (defined(_WIN32) || (defined(__linux__) && !defined(__ANDROID__)))
#define FLUTTER_FILAMENT_POST_PASS_ENABLED 1
#else
#define FLUTTER_FILAMENT_POST_PASS_ENABLED 0
#endif

namespace {

std::mutex gErrorMutex;
std::string gLastError;

void setError(std::string message) {
    std::lock_guard<std::mutex> lock(gErrorMutex);
    gLastError = std::move(message);
}

void clearError() {
    std::lock_guard<std::mutex> lock(gErrorMutex);
    gLastError.clear();
}

} // namespace

const char* filament_post_pass_last_error(void) {
    std::lock_guard<std::mutex> lock(gErrorMutex);
    return gLastError.empty() ? nullptr : gLastError.c_str();
}

#if FLUTTER_FILAMENT_POST_PASS_ENABLED

#include <bluevk/BlueVK.h>

#include <filament/Engine.h>
#include <filament/View.h>
#include <backend/ExternalPass.h>

#include "gpu_engine_internal.h"
#include "post_pass_debug_spv.h"

using namespace filament;
using namespace bluevk;

namespace {

constexpr uint32_t kDescriptorRing = 16;

class DebugPostPass final : public ExternalPostPass {
public:
    DebugPostPass(Engine* engine, View* view, VkDevice device, uint8_t mode)
            : mEngine(engine), mView(view), mDevice(device), mMode(mode) {}

    bool supports(uint32_t width, uint32_t height) noexcept override {
        return width > 0 && height > 0 && !mFailed.load();
    }

    void evaluate(backend::ExternalPassContext const& context) noexcept override {
        if (context.backend != backend::Backend::VULKAN || context.imageCount < 4) return;
        if (!mPipeline && !createObjects()) {
            mFailed = true;
            return;
        }
        auto cmd = reinterpret_cast<VkCommandBuffer>(context.commandBuffer);
        auto const& color = context.images[COLOR];
        auto const& motion = context.images[MOTION];
        auto const& output = context.images[OUTPUT];

        VkDescriptorSet set = mSets[mFrame % kDescriptorRing];
        VkDescriptorImageInfo colorInfo{ mSampler, reinterpret_cast<VkImageView>(color.imageView),
                static_cast<VkImageLayout>(color.layout) };
        VkDescriptorImageInfo motionInfo{ mSampler, reinterpret_cast<VkImageView>(motion.imageView),
                static_cast<VkImageLayout>(motion.layout) };
        VkDescriptorImageInfo outputInfo{ VK_NULL_HANDLE, reinterpret_cast<VkImageView>(output.imageView),
                static_cast<VkImageLayout>(output.layout) };
        VkWriteDescriptorSet writes[3] = {};
        for (uint32_t i = 0; i < 3; i++) {
            writes[i].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writes[i].dstSet = set;
            writes[i].dstBinding = i;
            writes[i].descriptorCount = 1;
        }
        writes[0].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writes[0].pImageInfo = &colorInfo;
        writes[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writes[1].pImageInfo = &motionInfo;
        writes[2].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writes[2].pImageInfo = &outputInfo;
        vkUpdateDescriptorSets(mDevice, 3, writes, 0, nullptr);

        // The motion image was just rendered as a colour attachment; make it and the colour
        // visible to the compute shader.
        VkMemoryBarrier barrier{};
        barrier.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER;
        barrier.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_SHADER_WRITE_BIT |
                VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        vkCmdPipelineBarrier(cmd,
                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT |
                        VK_PIPELINE_STAGE_TRANSFER_BIT,
                VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &barrier, 0, nullptr, 0, nullptr);

        struct Push {
            int32_t width, height, mode;
            float motionScale;
        } push{ int32_t(color.width), int32_t(color.height), int32_t(mMode.load()), 0.05f };
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, mPipeline);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, mPipelineLayout, 0, 1, &set, 0, nullptr);
        vkCmdPushConstants(cmd, mPipelineLayout, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(push), &push);
        vkCmdDispatch(cmd, (color.width + 7) / 8, (color.height + 7) / 8, 1);

        mLastWidth = color.width;
        mLastHeight = color.height;
        mFrame++;
        mFrameCount.fetch_add(1);
    }

    void setMode(uint8_t mode) { mMode = mode; }
    uint64_t frameCount() const { return mFrameCount.load(); }
    void lastSize(uint32_t* w, uint32_t* h) const {
        *w = mLastWidth.load();
        *h = mLastHeight.load();
    }
    Engine* engine() const { return mEngine; }
    View* view() const { return mView; }
    bool failed() const { return mFailed.load(); }

    // The GPU must be idle (the caller waited on the engine).
    void destroyObjects() {
        if (mPipeline) vkDestroyPipeline(mDevice, mPipeline, nullptr);
        if (mPipelineLayout) vkDestroyPipelineLayout(mDevice, mPipelineLayout, nullptr);
        if (mPool) vkDestroyDescriptorPool(mDevice, mPool, nullptr);
        if (mSetLayout) vkDestroyDescriptorSetLayout(mDevice, mSetLayout, nullptr);
        if (mSampler) vkDestroySampler(mDevice, mSampler, nullptr);
        mPipeline = VK_NULL_HANDLE;
        mPipelineLayout = VK_NULL_HANDLE;
        mPool = VK_NULL_HANDLE;
        mSetLayout = VK_NULL_HANDLE;
        mSampler = VK_NULL_HANDLE;
    }

private:
    bool createObjects() {
        VkSamplerCreateInfo samplerInfo{};
        samplerInfo.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        samplerInfo.magFilter = VK_FILTER_NEAREST;
        samplerInfo.minFilter = VK_FILTER_NEAREST;
        samplerInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        samplerInfo.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        samplerInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        if (vkCreateSampler(mDevice, &samplerInfo, nullptr, &mSampler) != VK_SUCCESS) {
            setError("vkCreateSampler failed");
            return false;
        }
        VkDescriptorSetLayoutBinding bindings[3] = {};
        for (uint32_t i = 0; i < 3; i++) {
            bindings[i].binding = i;
            bindings[i].descriptorCount = 1;
            bindings[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
            bindings[i].descriptorType = i < 2 ? VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
                                               : VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        }
        VkDescriptorSetLayoutCreateInfo layoutInfo{};
        layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
        layoutInfo.bindingCount = 3;
        layoutInfo.pBindings = bindings;
        if (vkCreateDescriptorSetLayout(mDevice, &layoutInfo, nullptr, &mSetLayout) != VK_SUCCESS) {
            setError("vkCreateDescriptorSetLayout failed");
            return false;
        }
        VkPushConstantRange range{ VK_SHADER_STAGE_COMPUTE_BIT, 0, 16 };
        VkPipelineLayoutCreateInfo pipelineLayoutInfo{};
        pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipelineLayoutInfo.setLayoutCount = 1;
        pipelineLayoutInfo.pSetLayouts = &mSetLayout;
        pipelineLayoutInfo.pushConstantRangeCount = 1;
        pipelineLayoutInfo.pPushConstantRanges = &range;
        if (vkCreatePipelineLayout(mDevice, &pipelineLayoutInfo, nullptr, &mPipelineLayout) != VK_SUCCESS) {
            setError("vkCreatePipelineLayout failed");
            return false;
        }
        VkDescriptorPoolSize sizes[2] = {
            { VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 2 * kDescriptorRing },
            { VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, kDescriptorRing },
        };
        VkDescriptorPoolCreateInfo poolInfo{};
        poolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        poolInfo.maxSets = kDescriptorRing;
        poolInfo.poolSizeCount = 2;
        poolInfo.pPoolSizes = sizes;
        if (vkCreateDescriptorPool(mDevice, &poolInfo, nullptr, &mPool) != VK_SUCCESS) {
            setError("vkCreateDescriptorPool failed");
            return false;
        }
        VkDescriptorSetLayout layouts[kDescriptorRing];
        for (auto& l : layouts) l = mSetLayout;
        VkDescriptorSetAllocateInfo allocInfo{};
        allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        allocInfo.descriptorPool = mPool;
        allocInfo.descriptorSetCount = kDescriptorRing;
        allocInfo.pSetLayouts = layouts;
        if (vkAllocateDescriptorSets(mDevice, &allocInfo, mSets) != VK_SUCCESS) {
            setError("vkAllocateDescriptorSets failed");
            return false;
        }
        VkShaderModuleCreateInfo moduleInfo{};
        moduleInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        moduleInfo.codeSize = sizeof(kPostPassDebugSpirv);
        moduleInfo.pCode = kPostPassDebugSpirv;
        VkShaderModule module = VK_NULL_HANDLE;
        if (vkCreateShaderModule(mDevice, &moduleInfo, nullptr, &module) != VK_SUCCESS) {
            setError("vkCreateShaderModule failed");
            return false;
        }
        VkComputePipelineCreateInfo pipelineInfo{};
        pipelineInfo.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        pipelineInfo.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        pipelineInfo.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
        pipelineInfo.stage.module = module;
        pipelineInfo.stage.pName = "main";
        pipelineInfo.layout = mPipelineLayout;
        VkResult const r = vkCreateComputePipelines(mDevice, VK_NULL_HANDLE, 1, &pipelineInfo, nullptr, &mPipeline);
        vkDestroyShaderModule(mDevice, module, nullptr);
        if (r != VK_SUCCESS) {
            mPipeline = VK_NULL_HANDLE;
            setError("vkCreateComputePipelines failed");
            return false;
        }
        return true;
    }

    Engine* const mEngine;
    View* const mView;
    VkDevice const mDevice;
    std::atomic<uint8_t> mMode;
    std::atomic<uint64_t> mFrameCount{ 0 };
    std::atomic<uint32_t> mLastWidth{ 0 };
    std::atomic<uint32_t> mLastHeight{ 0 };
    std::atomic<bool> mFailed{ false };
    uint64_t mFrame = 0;
    VkSampler mSampler = VK_NULL_HANDLE;
    VkDescriptorSetLayout mSetLayout = VK_NULL_HANDLE;
    VkPipelineLayout mPipelineLayout = VK_NULL_HANDLE;
    VkDescriptorPool mPool = VK_NULL_HANDLE;
    VkDescriptorSet mSets[kDescriptorRing] = {};
    VkPipeline mPipeline = VK_NULL_HANDLE;
};

} // namespace

void* filament_post_pass_debug_create(void* engine, void* view, uint8_t mode) {
    if (!engine || !view) {
        setError("filament_post_pass_debug_create: engine and view are required");
        return nullptr;
    }
    void* instance = nullptr;
    void* physicalDevice = nullptr;
    void* device = nullptr;
    if (!flutter_filament_engine_vulkan_handles(engine, &instance, &physicalDevice, &device, nullptr)) {
        setError("the external post pass needs an engine on the desktop Vulkan backend");
        return nullptr;
    }
    auto* pass = new DebugPostPass(static_cast<Engine*>(engine), static_cast<View*>(view),
            static_cast<VkDevice>(device), mode);
    static_cast<View*>(view)->setExternalPostPass(pass);
    clearError();
    return pass;
}

void filament_post_pass_debug_set_mode(void* pass, uint8_t mode) {
    if (pass) static_cast<DebugPostPass*>(pass)->setMode(mode);
}

uint64_t filament_post_pass_debug_frame_count(void* pass) {
    return pass ? static_cast<DebugPostPass*>(pass)->frameCount() : 0;
}

void filament_post_pass_debug_last_size(void* pass, uint32_t* out_w, uint32_t* out_h) {
    if (!out_w || !out_h) return;
    *out_w = 0;
    *out_h = 0;
    if (pass) static_cast<DebugPostPass*>(pass)->lastSize(out_w, out_h);
}

void filament_view_reset_external_post_pass_history(void* view) {
    if (view) static_cast<View*>(view)->resetExternalPostPassHistory();
}

void filament_post_pass_debug_destroy(void* pass) {
    if (!pass) return;
    auto* p = static_cast<DebugPostPass*>(pass);
    if (p->view()->getExternalPostPass() == p) {
        p->view()->setExternalPostPass(nullptr);
    }
    // frames recorded before this call may still run the pass
    p->engine()->flushAndWait();
    p->destroyObjects();
    delete p;
}

#else // !FLUTTER_FILAMENT_POST_PASS_ENABLED

void* filament_post_pass_debug_create(void* engine, void* view, uint8_t mode) {
    (void) engine;
    (void) view;
    (void) mode;
    setError("the external post pass needs an engine on the desktop Vulkan backend");
    return nullptr;
}

void filament_post_pass_debug_set_mode(void* pass, uint8_t mode) {
    (void) pass;
    (void) mode;
}

uint64_t filament_post_pass_debug_frame_count(void* pass) {
    (void) pass;
    return 0;
}

void filament_post_pass_debug_last_size(void* pass, uint32_t* out_w, uint32_t* out_h) {
    (void) pass;
    if (out_w) *out_w = 0;
    if (out_h) *out_h = 0;
}

void filament_view_reset_external_post_pass_history(void* view) {
    (void) view;
}

void filament_post_pass_debug_destroy(void* pass) {
    (void) pass;
}

#endif // FLUTTER_FILAMENT_POST_PASS_ENABLED
