/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// DLSS Frame Generation through NVIDIA NGX (feature dlssg) on Vulkan: the probe and an
// interpolator that runs inside Filament's frame (see dlss_fg_c.h). Compiled with the NGX SDK
// (FLUTTER_FILAMENT_DLSS=1); otherwise every entry point reports "not available".

#include "dlss_fg_c.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

#include "ngx_internal.h"

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

const char* filament_dlss_fg_last_error(void) {
    std::lock_guard<std::mutex> lock(gErrorMutex);
    return gLastError.empty() ? nullptr : gLastError.c_str();
}

#if FLUTTER_FILAMENT_DLSS_ENABLED

#include <filament/Engine.h>
#include <filament/View.h>
#include <backend/ExternalPass.h>

#include <math/mat4.h>

#include <nvsdk_ngx_defs_dlssg.h>
#include <nvsdk_ngx_helpers_dlssg_vk.h>
#include <nvsdk_ngx_helpers_vk.h>
#include <nvsdk_ngx_params_dlssg.h>

#include "gpu_engine_internal.h"
#include "vulkan_features_c.h"

using namespace filament;
using namespace bluevk;
namespace ngx = flutter_filament::ngx;

namespace {

constexpr const char* kRequester = "dlss_fg";
constexpr uint32_t kTimerSlots = 8;

NVSDK_NGX_FeatureDiscoveryInfo discoveryInfo(NVSDK_NGX_FeatureCommonInfo& common, const wchar_t*& path,
        std::wstring& pathStorage) {
    std::string const& dir = ngx::runtimeDir();
    pathStorage.assign(dir.begin(), dir.end());
    path = pathStorage.c_str();
    common = {};
    common.PathListInfo.Path = &path;
    common.PathListInfo.Length = 1;
    NVSDK_NGX_FeatureDiscoveryInfo info{};
    info.SDKVersion = NVSDK_NGX_Version_API;
    info.FeatureID = NVSDK_NGX_Feature_FrameGeneration;
    info.Identifier.IdentifierType = NVSDK_NGX_Application_Identifier_Type_Project_Id;
    info.Identifier.v.ProjectDesc.ProjectId = ngx::kProjectId;
    info.Identifier.v.ProjectDesc.EngineType = NVSDK_NGX_ENGINE_TYPE_CUSTOM;
    info.Identifier.v.ProjectDesc.EngineVersion = ngx::kEngineVersion;
    info.ApplicationDataPath = path;
    info.FeatureInfo = &common;
    return info;
}

// A device-local image of our own (the backbuffer copy and the generated frame).
struct OwnImage {
    VkImage image = VK_NULL_HANDLE;
    VkImageView view = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    uint32_t width = 0, height = 0;

    bool create(VkPhysicalDevice physical, VkDevice device, uint32_t w, uint32_t h) {
        width = w;
        height = h;
        VkImageCreateInfo info{};
        info.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        info.imageType = VK_IMAGE_TYPE_2D;
        info.format = VK_FORMAT_R16G16B16A16_SFLOAT;
        info.extent = { w, h, 1 };
        info.mipLevels = 1;
        info.arrayLayers = 1;
        info.samples = VK_SAMPLE_COUNT_1_BIT;
        info.tiling = VK_IMAGE_TILING_OPTIMAL;
        info.usage = VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
        info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        if (vkCreateImage(device, &info, nullptr, &image) != VK_SUCCESS) return false;
        VkMemoryRequirements req{};
        vkGetImageMemoryRequirements(device, image, &req);
        VkPhysicalDeviceMemoryProperties props{};
        vkGetPhysicalDeviceMemoryProperties(physical, &props);
        uint32_t type = UINT32_MAX;
        for (uint32_t i = 0; i < props.memoryTypeCount; i++) {
            if ((req.memoryTypeBits & (1u << i)) &&
                    (props.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) {
                type = i;
                break;
            }
        }
        if (type == UINT32_MAX) return false;
        VkMemoryAllocateInfo alloc{};
        alloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        alloc.allocationSize = req.size;
        alloc.memoryTypeIndex = type;
        if (vkAllocateMemory(device, &alloc, nullptr, &memory) != VK_SUCCESS) return false;
        if (vkBindImageMemory(device, image, memory, 0) != VK_SUCCESS) return false;
        VkImageViewCreateInfo viewInfo{};
        viewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        viewInfo.image = image;
        viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        viewInfo.format = info.format;
        viewInfo.subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };
        return vkCreateImageView(device, &viewInfo, nullptr, &view) == VK_SUCCESS;
    }

    void destroy(VkDevice device) {
        if (view) vkDestroyImageView(device, view, nullptr);
        if (image) vkDestroyImage(device, image, nullptr);
        if (memory) vkFreeMemory(device, memory, nullptr);
        view = VK_NULL_HANDLE;
        image = VK_NULL_HANDLE;
        memory = VK_NULL_HANDLE;
    }
};

void barrier(VkCommandBuffer cmd) {
    VkMemoryBarrier b{};
    b.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER;
    b.srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT;
    b.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
    vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 1, &b, 0,
            nullptr, 0, nullptr);
}

void toGeneral(VkCommandBuffer cmd, VkImage image) {
    VkImageMemoryBarrier b{};
    b.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b.srcAccessMask = 0;
    b.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
    b.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    b.newLayout = VK_IMAGE_LAYOUT_GENERAL;
    b.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    b.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    b.image = image;
    b.subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };
    vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0, nullptr, 0,
            nullptr, 1, &b);
}

void blit(VkCommandBuffer cmd, VkImage src, uint32_t sw, uint32_t sh, VkImage dst, uint32_t dw, uint32_t dh) {
    VkImageBlit region{};
    region.srcSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 };
    region.srcOffsets[1] = { int32_t(sw), int32_t(sh), 1 };
    region.dstSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 };
    region.dstOffsets[1] = { int32_t(dw), int32_t(dh), 1 };
    vkCmdBlitImage(cmd, src, VK_IMAGE_LAYOUT_GENERAL, dst, VK_IMAGE_LAYOUT_GENERAL, 1, &region, VK_FILTER_NEAREST);
}

void copyMat(float out[4][4], math::mat4f const& m) {
    std::memcpy(out, &m, sizeof(float) * 16);
}

// The optional evaluation parameters both frame generation clients send.
void fillOptions(NVSDK_NGX_DLSSG_Opt_Eval_Params& opt, math::mat4f const& clipFromView,
        math::mat4f const& viewFromWorld, math::mat4f const& clipFromWorld, math::mat4f const& prevClipFromWorld,
        backend::ExternalPassImage const& motion, backend::ExternalPassImage const& depth, uint32_t width,
        uint32_t height, bool hdr) {
    math::mat4f const viewFromClip = inverse(clipFromView);
    math::mat4f const prevClipFromClip = prevClipFromWorld * inverse(clipFromWorld);
    copyMat(opt.cameraViewToClip, clipFromView);
    copyMat(opt.clipToCameraView, viewFromClip);
    copyMat(opt.clipToLensClip, math::mat4f());
    copyMat(opt.clipToPrevClip, prevClipFromClip);
    copyMat(opt.prevClipToClip, inverse(prevClipFromClip));
    // motion is uv_curr - uv_prev in texels, y up; NGX wants prev - curr normalised, y down
    opt.mvecScale[0] = -1.0f / float(motion.width);
    opt.mvecScale[1] = 1.0f / float(motion.height);
    math::mat4f const worldFromView = inverse(viewFromWorld);
    for (int k = 0; k < 3; k++) {
        opt.cameraPos[k] = worldFromView[3][k];
        opt.cameraRight[k] = worldFromView[0][k];
        opt.cameraUp[k] = worldFromView[1][k];
        opt.cameraFwd[k] = -worldFromView[2][k];
    }
    // Filament's projection: [1][1] = cot(fov / 2), [0][0] = cot / aspect
    float const p11 = clipFromView[1][1];
    float const p00 = clipFromView[0][0];
    opt.cameraFOV = 2.0f * std::atan(1.0f / p11);
    opt.cameraAspectRatio = p11 / p00;
    opt.cameraNear = 0.1f;
    opt.cameraFar = 1000.0f;
    opt.colorBuffersHDR = hdr;
    opt.depthInverted = true;
    opt.cameraMotionIncluded = true;
    opt.reset = false;
    opt.motionVectorsInvalidValue = 0.0f;
    opt.mvecsSubrectSize = { motion.width, motion.height };
    opt.depthSubrectSize = { depth.width, depth.height };
    opt.backbufferSubrectSize = { width, height };
    opt.outputInterpSubrectSize = { width, height };
}

class Interpolator final : public ExternalPostPass {
public:
    Interpolator(Engine* engine, View* view, ngx::Device* ngx, VkPhysicalDevice physical, uint32_t count,
            uint32_t index)
            : mEngine(engine), mView(view), mNgx(ngx), mPhysical(physical), mCount(count), mIndex(index) {
        VkPhysicalDeviceProperties props{};
        vkGetPhysicalDeviceProperties(physical, &props);
        mTimestampPeriod = props.limits.timestampPeriod;
    }

    bool supports(uint32_t width, uint32_t height) noexcept override {
        return width > 0 && height > 0 && !mFailed.load();
    }

    void evaluate(backend::ExternalPassContext const& context) noexcept override {
        std::lock_guard<std::mutex> lock(mMutex);
        if (context.backend != backend::Backend::VULKAN || context.imageCount < 4 || mFailed) return;
        auto cmd = reinterpret_cast<VkCommandBuffer>(context.commandBuffer);
        auto const& color = context.images[COLOR];
        auto const& depth = context.images[DEPTH];
        auto const& motion = context.images[MOTION];
        auto const& output = context.images[OUTPUT];
        auto const colorImage = reinterpret_cast<VkImage>(color.image);
        auto const outputImage = reinterpret_cast<VkImage>(output.image);

        if (mBack.width != color.width || mBack.height != color.height) {
            if (mFeature) {
                // a resize recreates everything (the GPU finished the frames using them:
                // supports() is asked first and the caller resizes between frames)
                NVSDK_NGX_VULKAN_ReleaseFeature(mFeature);
                mFeature = nullptr;
            }
            mBack.destroy(mNgx->device);
            mInterp.destroy(mNgx->device);
            if (!mBack.create(mPhysical, mNgx->device, color.width, color.height) ||
                    !mInterp.create(mPhysical, mNgx->device, color.width, color.height)) {
                fail("could not allocate the frame generation images", NVSDK_NGX_Result_FAIL_OutOfGPUMemory);
                return;
            }
            toGeneral(cmd, mBack.image);
            toGeneral(cmd, mInterp.image);
            mHavePrevious = false;
        }
        if (!mQueryPool) {
            VkQueryPoolCreateInfo info{};
            info.sType = VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO;
            info.queryType = VK_QUERY_TYPE_TIMESTAMP;
            info.queryCount = kTimerSlots * 2;
            vkCreateQueryPool(mNgx->device, &info, nullptr, &mQueryPool);
        }
        if (!mFeature) {
            NVSDK_NGX_DLSSG_Create_Params create{};
            create.Width = color.width;
            create.Height = color.height;
            create.NativeBackbufferFormat = VK_FORMAT_R16G16B16A16_SFLOAT;
            create.RenderWidth = depth.width;
            create.RenderHeight = depth.height;
            create.DynamicResolutionScaling = false;
            NVSDK_NGX_Result r = NGX_VK_CREATE_DLSSG(cmd, 1, 1, &mFeature, mNgx->capabilities, &create);
            mLastResult = int32_t(r);
            if (NVSDK_NGX_FAILED(r) || !mFeature) {
                mFeature = nullptr;
                fail(ngx::describe("NGX_VK_CREATE_DLSSG", r), r);
                return;
            }
        }

        // the current frame becomes the backbuffer NGX interpolates toward
        barrier(cmd);
        blit(cmd, colorImage, color.width, color.height, mBack.image, mBack.width, mBack.height);
        barrier(cmd);

        math::mat4f const viewFromWorld = math::mat4f(*reinterpret_cast<math::mat4f const*>(context.frame.viewFromWorld));
        math::mat4f const clipFromView = *reinterpret_cast<math::mat4f const*>(context.frame.clipFromView);
        math::mat4f const clipFromWorld = clipFromView * viewFromWorld;
        bool const reset = !mHavePrevious || (context.frame.flags & backend::ExternalPassFrame::FLAG_HISTORY_RESET);

        if (!reset) {
            readTimers();
            auto res = [](VkImage image, VkImageView view, VkFormat format, uint32_t w, uint32_t h, VkImageAspectFlags aspect,
                               bool rw) {
                VkImageSubresourceRange range{ aspect, 0, 1, 0, 1 };
                return NVSDK_NGX_Create_ImageView_Resource_VK(view, image, range, format, w, h, rw);
            };
            NVSDK_NGX_Resource_VK back = res(mBack.image, mBack.view, VK_FORMAT_R16G16B16A16_SFLOAT, mBack.width,
                    mBack.height, VK_IMAGE_ASPECT_COLOR_BIT, false);
            NVSDK_NGX_Resource_VK interp = res(mInterp.image, mInterp.view, VK_FORMAT_R16G16B16A16_SFLOAT,
                    mInterp.width, mInterp.height, VK_IMAGE_ASPECT_COLOR_BIT, true);
            NVSDK_NGX_Resource_VK depthRes = res(reinterpret_cast<VkImage>(depth.image),
                    reinterpret_cast<VkImageView>(depth.imageView), VkFormat(depth.format), depth.width, depth.height,
                    VkImageAspectFlags(depth.aspect), false);
            NVSDK_NGX_Resource_VK mvecs = res(reinterpret_cast<VkImage>(motion.image),
                    reinterpret_cast<VkImageView>(motion.imageView), VkFormat(motion.format), motion.width,
                    motion.height, VK_IMAGE_ASPECT_COLOR_BIT, false);

            NVSDK_NGX_VK_DLSSG_Eval_Params eval{};
            eval.pBackbuffer = &back;
            eval.pDepth = &depthRes;
            eval.pMVecs = &mvecs;
            eval.pOutputInterpFrame = &interp;

            NVSDK_NGX_DLSSG_Opt_Eval_Params opt{};
            fillOptions(opt, clipFromView, viewFromWorld, clipFromWorld, mPrevClipFromWorld, motion, depth,
                    mBack.width, mBack.height, true);
            opt.multiFrameCount = mCount;
            opt.multiFrameIndex = mIndex;

            uint32_t const slot = uint32_t(mFrame % kTimerSlots);
            if (mQueryPool) {
                vkCmdResetQueryPool(cmd, mQueryPool, slot * 2, 2);
                vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, mQueryPool, slot * 2);
            }
            NVSDK_NGX_Result r = NGX_VK_EVALUATE_DLSSG(cmd, mFeature, mNgx->capabilities, &eval, &opt);
            if (mQueryPool) {
                vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, mQueryPool, slot * 2 + 1);
                mSlotWritten[slot] = true;
            }
            mFrame++;
            mLastResult = int32_t(r);
            if (NVSDK_NGX_FAILED(r)) {
                fail(ngx::describe("NGX_VK_EVALUATE_DLSSG", r), r);
                return;
            }
            mFrameCount.fetch_add(1);
            barrier(cmd);
            blit(cmd, mInterp.image, mInterp.width, mInterp.height, outputImage, output.width, output.height);
        } else {
            // nothing to interpolate from: show the frame as it is
            blit(cmd, colorImage, color.width, color.height, outputImage, output.width, output.height);
        }
        mPrevClipFromWorld = clipFromWorld;
        mHavePrevious = true;
    }

    uint64_t frameCount() const { return mFrameCount.load(); }
    int32_t lastResult() const { return mLastResult.load(); }
    uint64_t lastGpuNanos() const { return mLastGpuNanos.load(); }
    Engine* engine() const { return mEngine; }
    View* view() const { return mView; }

    void releaseObjects() {
        std::lock_guard<std::mutex> lock(mMutex);
        if (mFeature) NVSDK_NGX_VULKAN_ReleaseFeature(mFeature);
        mFeature = nullptr;
        mBack.destroy(mNgx->device);
        mInterp.destroy(mNgx->device);
        if (mQueryPool) vkDestroyQueryPool(mNgx->device, mQueryPool, nullptr);
        mQueryPool = VK_NULL_HANDLE;
    }

private:
    void fail(std::string message, NVSDK_NGX_Result r) {
        mFailed = true;
        mLastResult = int32_t(r);
        setError(std::move(message));
    }

    void readTimers() {
        if (!mQueryPool || mFrame < kTimerSlots) return;
        uint32_t const slot = uint32_t((mFrame + 1) % kTimerSlots);
        if (!mSlotWritten[slot]) return;
        uint64_t stamps[2] = {};
        if (vkGetQueryPoolResults(mNgx->device, mQueryPool, slot * 2, 2, sizeof(stamps), stamps, sizeof(uint64_t),
                    VK_QUERY_RESULT_64_BIT) == VK_SUCCESS && stamps[1] > stamps[0]) {
            mLastGpuNanos = uint64_t(double(stamps[1] - stamps[0]) * double(mTimestampPeriod));
        }
    }

    Engine* const mEngine;
    View* const mView;
    ngx::Device* const mNgx;
    VkPhysicalDevice const mPhysical;
    uint32_t const mCount;
    uint32_t const mIndex;
    float mTimestampPeriod = 1.0f;
    std::mutex mMutex;
    NVSDK_NGX_Handle* mFeature = nullptr;
    OwnImage mBack;
    OwnImage mInterp;
    VkQueryPool mQueryPool = VK_NULL_HANDLE;
    bool mSlotWritten[kTimerSlots] = {};
    uint64_t mFrame = 0;
    math::mat4f mPrevClipFromWorld;
    bool mHavePrevious = false;
    std::atomic<bool> mFailed{ false };
    std::atomic<int32_t> mLastResult{ 0 };
    std::atomic<uint64_t> mFrameCount{ 0 };
    std::atomic<uint64_t> mLastGpuNanos{ 0 };
};

// DLSS Frame Generation presenting through Filament's SwapChain: an ExternalFrameGenerator that
// writes `count` generated frames from the final (LDR) frame, depth and motion.
class Generator final : public ExternalFrameGenerator {
public:
    Generator(Engine* engine, View* view, ngx::Device* ngx, VkPhysicalDevice physical, uint32_t count)
            : mEngine(engine), mView(view), mNgx(ngx), mCount(count) {
        VkPhysicalDeviceProperties props{};
        vkGetPhysicalDeviceProperties(physical, &props);
        mTimestampPeriod = props.limits.timestampPeriod;
    }

    uint32_t generatedFrameCount() const noexcept override { return mCount.load(); }

    bool supports(uint32_t width, uint32_t height) noexcept override {
        return width > 0 && height > 0 && !mFailed.load();
    }

    void evaluate(backend::ExternalPassContext const& context) noexcept override {
        std::lock_guard<std::mutex> lock(mMutex);
        uint32_t const count = std::min(context.imageCount - OUTPUT, uint32_t(MAX_GENERATED_FRAMES));
        if (context.backend != backend::Backend::VULKAN || context.imageCount <= OUTPUT || mFailed) return;
        auto cmd = reinterpret_cast<VkCommandBuffer>(context.commandBuffer);
        auto const& color = context.images[COLOR];
        auto const& depth = context.images[DEPTH];
        auto const& motion = context.images[MOTION];
        auto const colorImage = reinterpret_cast<VkImage>(color.image);

        if (mFeature && (mWidth != color.width || mHeight != color.height || mFormat != color.format)) {
            NVSDK_NGX_VULKAN_ReleaseFeature(mFeature);
            mFeature = nullptr;
            mHavePrevious = false;
        }
        if (!mQueryPool) {
            VkQueryPoolCreateInfo info{};
            info.sType = VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO;
            info.queryType = VK_QUERY_TYPE_TIMESTAMP;
            info.queryCount = kTimerSlots * 2;
            vkCreateQueryPool(mNgx->device, &info, nullptr, &mQueryPool);
        }
        if (!mFeature) {
            NVSDK_NGX_DLSSG_Create_Params create{};
            create.Width = color.width;
            create.Height = color.height;
            create.NativeBackbufferFormat = color.format;
            create.RenderWidth = depth.width;
            create.RenderHeight = depth.height;
            create.DynamicResolutionScaling = false;
            NVSDK_NGX_Result r = NGX_VK_CREATE_DLSSG(cmd, 1, 1, &mFeature, mNgx->capabilities, &create);
            mLastResult = int32_t(r);
            if (NVSDK_NGX_FAILED(r) || !mFeature) {
                mFeature = nullptr;
                mFailed = true;
                setError(ngx::describe("NGX_VK_CREATE_DLSSG", r));
                return;
            }
            mWidth = color.width;
            mHeight = color.height;
            mFormat = color.format;
        }

        math::mat4f const viewFromWorld = *reinterpret_cast<math::mat4f const*>(context.frame.viewFromWorld);
        math::mat4f const clipFromView = *reinterpret_cast<math::mat4f const*>(context.frame.clipFromView);
        math::mat4f const clipFromWorld = clipFromView * viewFromWorld;
        bool const reset = !mHavePrevious || (context.frame.flags & backend::ExternalPassFrame::FLAG_HISTORY_RESET);
        mHavePrevious = true;

        barrier(cmd);
        if (reset) {
            // nothing to generate from yet: every present shows this frame
            for (uint32_t i = 0; i < count; i++) {
                auto const& out = context.images[OUTPUT + i];
                blit(cmd, colorImage, color.width, color.height, reinterpret_cast<VkImage>(out.image), out.width,
                        out.height);
            }
            mPrevClipFromWorld = clipFromWorld;
            return;
        }
        readTimers();
        auto res = [](backend::ExternalPassImage const& image, bool rw) {
            VkImageSubresourceRange range{ VkImageAspectFlags(image.aspect), 0, 1, 0, 1 };
            return NVSDK_NGX_Create_ImageView_Resource_VK(reinterpret_cast<VkImageView>(image.imageView),
                    reinterpret_cast<VkImage>(image.image), range, VkFormat(image.format), image.width, image.height,
                    rw);
        };
        NVSDK_NGX_Resource_VK back = res(color, false);
        NVSDK_NGX_Resource_VK depthRes = res(depth, false);
        NVSDK_NGX_Resource_VK mvecs = res(motion, false);

        uint32_t const slot = uint32_t(mFrame % kTimerSlots);
        if (mQueryPool) {
            vkCmdResetQueryPool(cmd, mQueryPool, slot * 2, 2);
            vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, mQueryPool, slot * 2);
        }
        for (uint32_t i = 0; i < count; i++) {
            NVSDK_NGX_Resource_VK interp = res(context.images[OUTPUT + i], true);
            NVSDK_NGX_VK_DLSSG_Eval_Params eval{};
            eval.pBackbuffer = &back;
            eval.pDepth = &depthRes;
            eval.pMVecs = &mvecs;
            eval.pOutputInterpFrame = &interp;
            NVSDK_NGX_DLSSG_Opt_Eval_Params opt{};
            fillOptions(opt, clipFromView, viewFromWorld, clipFromWorld, mPrevClipFromWorld, motion, depth,
                    color.width, color.height, false);
            opt.multiFrameCount = count;
            opt.multiFrameIndex = i + 1;
            NVSDK_NGX_Result r = NGX_VK_EVALUATE_DLSSG(cmd, mFeature, mNgx->capabilities, &eval, &opt);
            mLastResult = int32_t(r);
            if (NVSDK_NGX_FAILED(r)) {
                mFailed = true;
                setError(ngx::describe("NGX_VK_EVALUATE_DLSSG", r));
                return;
            }
        }
        if (mQueryPool) {
            vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, mQueryPool, slot * 2 + 1);
            mSlotWritten[slot] = true;
        }
        mFrame++;
        mFrameCount.fetch_add(1);
        mPrevClipFromWorld = clipFromWorld;
    }

    void setCount(uint32_t count) { mCount = count; }
    uint64_t frameCount() const { return mFrameCount.load(); }
    int32_t lastResult() const { return mLastResult.load(); }
    uint64_t lastGpuNanos() const { return mLastGpuNanos.load(); }
    Engine* engine() const { return mEngine; }
    View* view() const { return mView; }

    void releaseObjects() {
        std::lock_guard<std::mutex> lock(mMutex);
        if (mFeature) NVSDK_NGX_VULKAN_ReleaseFeature(mFeature);
        mFeature = nullptr;
        if (mQueryPool) vkDestroyQueryPool(mNgx->device, mQueryPool, nullptr);
        mQueryPool = VK_NULL_HANDLE;
    }

private:
    void readTimers() {
        if (!mQueryPool || mFrame < kTimerSlots) return;
        uint32_t const slot = uint32_t((mFrame + 1) % kTimerSlots);
        if (!mSlotWritten[slot]) return;
        uint64_t stamps[2] = {};
        if (vkGetQueryPoolResults(mNgx->device, mQueryPool, slot * 2, 2, sizeof(stamps), stamps, sizeof(uint64_t),
                    VK_QUERY_RESULT_64_BIT) == VK_SUCCESS && stamps[1] > stamps[0]) {
            mLastGpuNanos = uint64_t(double(stamps[1] - stamps[0]) * double(mTimestampPeriod));
        }
    }

    Engine* const mEngine;
    View* const mView;
    ngx::Device* const mNgx;
    std::atomic<uint32_t> mCount;
    float mTimestampPeriod = 1.0f;
    std::mutex mMutex;
    NVSDK_NGX_Handle* mFeature = nullptr;
    uint32_t mWidth = 0, mHeight = 0, mFormat = 0;
    VkQueryPool mQueryPool = VK_NULL_HANDLE;
    bool mSlotWritten[kTimerSlots] = {};
    uint64_t mFrame = 0;
    math::mat4f mPrevClipFromWorld;
    bool mHavePrevious = false;
    std::atomic<bool> mFailed{ false };
    std::atomic<int32_t> mLastResult{ 0 };
    std::atomic<uint64_t> mFrameCount{ 0 };
    std::atomic<uint64_t> mLastGpuNanos{ 0 };
};

} // namespace

bool filament_dlss_fg_available(void) {
    std::lock_guard<std::mutex> lock(ngx::mutex());
    return ngx::hasFeatureLibrary("nvngx_dlssg") && ngx::hasNvidiaVulkanDevice();
}

bool filament_dlss_fg_request_extensions(void) {
    if (!filament_dlss_fg_available()) {
        setError("DLSS Frame Generation runtime not available (nvngx_dlssg)");
        return false;
    }
    // Optical flow is what the Vulkan path of Frame Generation runs on; its feature struct
    // must be enabled with the extension.
    filament_vulkan_request_device_extension(kRequester, "VK_NV_optical_flow");
    filament_vulkan_request_device_feature(kRequester, 1000464000 /* OPTICAL_FLOW_FEATURES_NV */, 24, 16,
            "VK_NV_optical_flow");
    filament_vulkan_request_device_extension(kRequester, "VK_KHR_synchronization2");
    filament_vulkan_request_device_feature(kRequester, 1000314007 /* SYNCHRONIZATION_2_FEATURES */, 24, 16,
            "VK_KHR_synchronization2");
    filament_vulkan_request_device_extension(kRequester, "VK_KHR_timeline_semaphore");
    filament_vulkan_request_device_feature(kRequester, 1000207000 /* TIMELINE_SEMAPHORE_FEATURES */, 24, 16,
            "VK_KHR_timeline_semaphore");
    clearError();
    return true;
}

void filament_dlss_fg_clear_extension_request(void) {
    filament_vulkan_clear_requests(kRequester);
}

bool filament_dlss_fg_probe(void* engine, filament_dlss_fg_probe_t* out) {
    if (!out) return false;
    *out = filament_dlss_fg_probe_t{};
    if (!engine || !filament_dlss_fg_available()) {
        setError("DLSS Frame Generation runtime not available (nvngx_dlssg) or no engine");
        return false;
    }
    std::lock_guard<std::mutex> lock(ngx::mutex());
    std::string error;
    auto* fengine = static_cast<Engine*>(engine);
    ngx::Device* device = ngx::acquire(fengine, error);
    if (!device) {
        setError(error);
        return false;
    }
    int available = 0, needsDriver = 0, initResult = 0;
    unsigned major = 0, minor = 0, multiMax = 0;
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_FrameGeneration_Available, &available);
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_FrameGeneration_NeedsUpdatedDriver, &needsDriver);
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_FrameGeneration_FeatureInitResult, &initResult);
    NVSDK_NGX_Parameter_GetUI(device->capabilities, NVSDK_NGX_Parameter_FrameGeneration_MinDriverVersionMajor, &major);
    NVSDK_NGX_Parameter_GetUI(device->capabilities, NVSDK_NGX_Parameter_FrameGeneration_MinDriverVersionMinor, &minor);
    NVSDK_NGX_Parameter_GetUI(device->capabilities, NVSDK_NGX_DLSSG_Parameter_MultiFrameCountMax, &multiMax);
    out->available = available != 0;
    out->needsUpdatedDriver = needsDriver != 0;
    out->featureInitResult = initResult;
    out->minDriverMajor = major;
    out->minDriverMinor = minor;
    out->multiFrameCountMax = multiMax;

    void* instance = nullptr;
    void* physical = nullptr;
    void* vkDevice = nullptr;
    flutter_filament_engine_vulkan_handles(engine, &instance, &physical, &vkDevice, nullptr);
    NVSDK_NGX_FeatureCommonInfo common{};
    const wchar_t* path = nullptr;
    std::wstring pathStorage;
    NVSDK_NGX_FeatureDiscoveryInfo info = discoveryInfo(common, path, pathStorage);
    NVSDK_NGX_FeatureRequirement requirement{};
    if (NVSDK_NGX_SUCCEED(NVSDK_NGX_VULKAN_GetFeatureRequirements(static_cast<VkInstance>(instance),
                static_cast<VkPhysicalDevice>(physical), &info, &requirement))) {
        out->supportFlags = uint32_t(requirement.FeatureSupported);
        out->minHwArchitecture = requirement.MinHWArchitecture;
    }
    uint32_t count = 0;
    VkExtensionProperties* props = nullptr;
    std::string list;
    if (NVSDK_NGX_SUCCEED(NVSDK_NGX_VULKAN_GetFeatureDeviceExtensionRequirements(static_cast<VkInstance>(instance),
                static_cast<VkPhysicalDevice>(physical), &info, &count, &props))) {
        for (uint32_t i = 0; i < count && props; i++) {
            if (!list.empty()) list += ' ';
            list += props[i].extensionName;
        }
    }
    std::strncpy(out->deviceExtensions, list.c_str(), sizeof(out->deviceExtensions) - 1);
    ngx::release(fengine);
    clearError();
    return true;
}

void* filament_dlss_fg_interpolator_create(void* engine, void* view, uint32_t multiFrameCount, uint32_t index) {
    if (!engine || !view || multiFrameCount == 0 || index == 0 || index > multiFrameCount) {
        setError("filament_dlss_fg_interpolator_create: engine, view and 1 <= index <= multiFrameCount are required");
        return nullptr;
    }
    if (!filament_dlss_fg_available()) {
        setError("DLSS Frame Generation runtime not available (nvngx_dlssg)");
        return nullptr;
    }
    std::lock_guard<std::mutex> lock(ngx::mutex());
    std::string error;
    auto* fengine = static_cast<Engine*>(engine);
    ngx::Device* device = ngx::acquire(fengine, error);
    if (!device) {
        setError(error);
        return nullptr;
    }
    int available = 0;
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_FrameGeneration_Available, &available);
    if (!available) {
        ngx::release(fengine);
        setError("DLSS Frame Generation is not available on this GPU or driver (FrameGeneration.Available = 0)");
        return nullptr;
    }
    void* instance = nullptr;
    void* physical = nullptr;
    void* vkDevice = nullptr;
    flutter_filament_engine_vulkan_handles(engine, &instance, &physical, &vkDevice, nullptr);
    auto* interpolator = new Interpolator(fengine, static_cast<View*>(view), device,
            static_cast<VkPhysicalDevice>(physical), multiFrameCount, index);
    static_cast<View*>(view)->setExternalPostPass(interpolator);
    clearError();
    return interpolator;
}

uint64_t filament_dlss_fg_interpolator_frame_count(void* interpolator) {
    return interpolator ? static_cast<Interpolator*>(interpolator)->frameCount() : 0;
}

int32_t filament_dlss_fg_interpolator_last_result(void* interpolator) {
    return interpolator ? static_cast<Interpolator*>(interpolator)->lastResult() : 0;
}

uint64_t filament_dlss_fg_interpolator_last_gpu_time_ns(void* interpolator) {
    return interpolator ? static_cast<Interpolator*>(interpolator)->lastGpuNanos() : 0;
}

void* filament_dlss_fg_create(void* engine, void* view, uint32_t generatedFrames) {
    if (!engine || !view || generatedFrames == 0 || generatedFrames > ExternalFrameGenerator::MAX_GENERATED_FRAMES) {
        setError("filament_dlss_fg_create: engine, view and 1..5 generated frames are required");
        return nullptr;
    }
    if (!filament_dlss_fg_available()) {
        setError("DLSS Frame Generation runtime not available (nvngx_dlssg)");
        return nullptr;
    }
    std::lock_guard<std::mutex> lock(ngx::mutex());
    std::string error;
    auto* fengine = static_cast<Engine*>(engine);
    ngx::Device* device = ngx::acquire(fengine, error);
    if (!device) {
        setError(error);
        return nullptr;
    }
    int available = 0;
    unsigned multiMax = 0;
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_FrameGeneration_Available, &available);
    NVSDK_NGX_Parameter_GetUI(device->capabilities, NVSDK_NGX_DLSSG_Parameter_MultiFrameCountMax, &multiMax);
    if (!available || generatedFrames > std::max(1u, multiMax)) {
        ngx::release(fengine);
        setError(!available ? "DLSS Frame Generation is not available on this GPU or driver"
                            : "this GPU generates at most " + std::to_string(std::max(1u, multiMax)) +
                                      " frames per rendered frame (Multi Frame Generation needs an RTX 50 class GPU)");
        return nullptr;
    }
    void* instance = nullptr;
    void* physical = nullptr;
    void* vkDevice = nullptr;
    flutter_filament_engine_vulkan_handles(engine, &instance, &physical, &vkDevice, nullptr);
    auto* generator = new Generator(fengine, static_cast<View*>(view), device,
            static_cast<VkPhysicalDevice>(physical), generatedFrames);
    static_cast<View*>(view)->setExternalFrameGenerator(generator);
    clearError();
    return generator;
}

void filament_dlss_fg_set_generated_frames(void* generator, uint32_t generatedFrames) {
    if (!generator || generatedFrames == 0 || generatedFrames > ExternalFrameGenerator::MAX_GENERATED_FRAMES) return;
    static_cast<Generator*>(generator)->setCount(generatedFrames);
}

uint64_t filament_dlss_fg_frame_count(void* generator) {
    return generator ? static_cast<Generator*>(generator)->frameCount() : 0;
}

int32_t filament_dlss_fg_last_result(void* generator) {
    return generator ? static_cast<Generator*>(generator)->lastResult() : 0;
}

uint64_t filament_dlss_fg_last_gpu_time_ns(void* generator) {
    return generator ? static_cast<Generator*>(generator)->lastGpuNanos() : 0;
}

void filament_dlss_fg_destroy(void* generator) {
    if (!generator) return;
    auto* g = static_cast<Generator*>(generator);
    if (g->view()->getExternalFrameGenerator() == g) g->view()->setExternalFrameGenerator(nullptr);
    g->engine()->flushAndWait();
    std::lock_guard<std::mutex> lock(ngx::mutex());
    g->releaseObjects();
    ngx::release(g->engine());
    delete g;
}

void filament_dlss_fg_interpolator_destroy(void* interpolator) {
    if (!interpolator) return;
    auto* p = static_cast<Interpolator*>(interpolator);
    if (p->view()->getExternalPostPass() == p) p->view()->setExternalPostPass(nullptr);
    p->engine()->flushAndWait();
    std::lock_guard<std::mutex> lock(ngx::mutex());
    p->releaseObjects();
    ngx::release(p->engine());
    delete p;
}

#else // !FLUTTER_FILAMENT_DLSS_ENABLED

bool filament_dlss_fg_available(void) {
    return false;
}

bool filament_dlss_fg_request_extensions(void) {
    setError("DLSS Frame Generation runtime not available: flutter_filament was built without the NGX SDK");
    return false;
}

void filament_dlss_fg_clear_extension_request(void) {
}

bool filament_dlss_fg_probe(void* engine, filament_dlss_fg_probe_t* out) {
    (void) engine;
    if (out) *out = filament_dlss_fg_probe_t{};
    setError("DLSS Frame Generation runtime not available: flutter_filament was built without the NGX SDK");
    return false;
}

void* filament_dlss_fg_interpolator_create(void* engine, void* view, uint32_t multiFrameCount, uint32_t index) {
    (void) engine;
    (void) view;
    (void) multiFrameCount;
    (void) index;
    setError("DLSS Frame Generation runtime not available: flutter_filament was built without the NGX SDK");
    return nullptr;
}

uint64_t filament_dlss_fg_interpolator_frame_count(void* interpolator) {
    (void) interpolator;
    return 0;
}

int32_t filament_dlss_fg_interpolator_last_result(void* interpolator) {
    (void) interpolator;
    return 0;
}

uint64_t filament_dlss_fg_interpolator_last_gpu_time_ns(void* interpolator) {
    (void) interpolator;
    return 0;
}

void filament_dlss_fg_interpolator_destroy(void* interpolator) {
    (void) interpolator;
}

void* filament_dlss_fg_create(void* engine, void* view, uint32_t generatedFrames) {
    (void) engine;
    (void) view;
    (void) generatedFrames;
    setError("DLSS Frame Generation runtime not available: flutter_filament was built without the NGX SDK");
    return nullptr;
}

void filament_dlss_fg_set_generated_frames(void* generator, uint32_t generatedFrames) {
    (void) generator;
    (void) generatedFrames;
}

uint64_t filament_dlss_fg_frame_count(void* generator) {
    (void) generator;
    return 0;
}

int32_t filament_dlss_fg_last_result(void* generator) {
    (void) generator;
    return 0;
}

uint64_t filament_dlss_fg_last_gpu_time_ns(void* generator) {
    (void) generator;
    return 0;
}

void filament_dlss_fg_destroy(void* generator) {
    (void) generator;
}

#endif // FLUTTER_FILAMENT_DLSS_ENABLED
