/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// DLSS Super Resolution through NVIDIA NGX, plugged into Filament's external
// upscaler pass. Compiled with the NGX SDK (FLUTTER_FILAMENT_DLSS=1, set by
// hook/build.dart when build/dlss-sdk/ exists); otherwise every entry point
// reports "not available".

#include "dlss_c.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <unordered_map>
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

const char* filament_dlss_last_error(void) {
    std::lock_guard<std::mutex> lock(gErrorMutex);
    return gLastError.empty() ? nullptr : gLastError.c_str();
}

#if FLUTTER_FILAMENT_DLSS_ENABLED

#include <bluevk/BlueVK.h>

#include <filament/Engine.h>
#include <filament/Options.h>
#include <filament/View.h>
#include <backend/ExternalPass.h>

#include <nvsdk_ngx.h>
#include <nvsdk_ngx_vk.h>
#include <nvsdk_ngx_helpers.h>
#include <nvsdk_ngx_helpers_vk.h>

#include "gpu_engine_internal.h"

using namespace filament;
namespace ngx = flutter_filament::ngx;

namespace {

constexpr int kBaseFlags =
        NVSDK_NGX_DLSS_Feature_Flags_MVLowRes | NVSDK_NGX_DLSS_Feature_Flags_DepthInverted;

using ngx::describe;
using ngx::toPerfQuality;
using NgxDevice = ngx::Device;

struct OptimalSettings {
    uint32_t width = 0, height = 0, maxWidth = 0, maxHeight = 0, minWidth = 0, minHeight = 0;
    float sharpness = 0.0f;
};

bool queryOptimal(NVSDK_NGX_Parameter* caps, uint32_t outW, uint32_t outH, uint8_t quality,
        OptimalSettings& out, std::string& error) {
    NVSDK_NGX_Result r = NGX_DLSS_GET_OPTIMAL_SETTINGS(caps, outW, outH, toPerfQuality(quality),
            &out.width, &out.height, &out.maxWidth, &out.maxHeight, &out.minWidth, &out.minHeight,
            &out.sharpness);
    if (NVSDK_NGX_FAILED(r)) {
        error = describe("NGX_DLSS_GET_OPTIMAL_SETTINGS", r);
        return false;
    }
    if (out.width == 0 || out.height == 0) {
        error = "DLSS does not offer this quality mode for the requested output size";
        return false;
    }
    return true;
}

// NGX for the engine plus the Super Resolution availability check.
NgxDevice* acquireDevice(Engine* engine, std::string& error) {
    NgxDevice* device = ngx::acquire(engine, error);
    if (!device) return nullptr;
    int needsDriver = 0;
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_SuperSampling_NeedsUpdatedDriver, &needsDriver);
    int available = 0;
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_SuperSampling_Available, &available);
    if (needsDriver || !available) {
        ngx::release(engine);
        error = needsDriver ? "DLSS needs a newer NVIDIA driver" : "DLSS Super Resolution is not available on this GPU";
        return nullptr;
    }
    return device;
}

void releaseDevice(Engine* engine) {
    ngx::release(engine);
}

class DlssUpscaler final : public ExternalUpscaler {
public:
    DlssUpscaler(Engine* engine, View* view, NgxDevice* ngx, filament_dlss_options_t options,
            OptimalSettings optimal)
            : mEngine(engine), mView(view), mNgx(ngx), mOptions(options), mOptimal(optimal) {}

    void applyToView() {
        DynamicResolutionOptions dsr = mView->getDynamicResolutionOptions();
        dsr.enabled = true;
        dsr.upscaler = Upscaler::EXTERNAL;
        dsr.homogeneousScaling = false;
        // Filament's FSR1 is the fallback when the external pass declines.
        dsr.quality = QualityLevel::ULTRA;
        dsr.sharpness = mOptions.sharpness;
        float const sx = float(mOptimal.width) / float(mOptions.outputWidth);
        float const sy = float(mOptimal.height) / float(mOptions.outputHeight);
        dsr.minScale = { sx, sy };
        dsr.maxScale = { sx, sy };
        mView->setDynamicResolutionOptions(dsr);
        mView->setExternalUpscaler(this);
    }

    void detachFromView() {
        if (mView->getExternalUpscaler() == this) {
            mView->setExternalUpscaler(nullptr);
        }
        DynamicResolutionOptions dsr = mView->getDynamicResolutionOptions();
        dsr.enabled = false;
        dsr.upscaler = Upscaler::BUILTIN;
        mView->setDynamicResolutionOptions(dsr);
    }

    bool setQuality(uint8_t quality, std::string& error) {
        OptimalSettings optimal;
        if (!queryOptimal(mNgx->capabilities, mOptions.outputWidth, mOptions.outputHeight, quality, optimal, error)) {
            return false;
        }
        std::lock_guard<std::mutex> lock(mMutex);
        mOptions.quality = quality;
        mOptimal = optimal;
        mRecreate = true;
        mFailed = false;
        return true;
    }

    void resetHistory() {
        std::lock_guard<std::mutex> lock(mMutex);
        mPendingReset = true;
    }

    void renderResolution(uint32_t* w, uint32_t* h) {
        std::lock_guard<std::mutex> lock(mMutex);
        *w = mFailed ? 0 : mOptimal.width;
        *h = mFailed ? 0 : mOptimal.height;
    }

    // Releases the NGX feature; the GPU must be idle (the caller waits on the engine).
    void releaseFeature() {
        std::lock_guard<std::mutex> lock(mMutex);
        if (mFeature) {
            NVSDK_NGX_VULKAN_ReleaseFeature(mFeature);
            mFeature = nullptr;
        }
    }

    bool supports(uint32_t renderWidth, uint32_t renderHeight, uint32_t outputWidth,
            uint32_t outputHeight) noexcept override {
        std::lock_guard<std::mutex> lock(mMutex);
        if (mFailed) return false;
        if (outputWidth != mOptions.outputWidth || outputHeight != mOptions.outputHeight) return false;
        // Filament rounds the scaled viewport; DLSS accepts any size between the
        // mode's minimum and maximum render resolution.
        return renderWidth >= mOptimal.minWidth && renderWidth <= mOptimal.maxWidth &&
                renderHeight >= mOptimal.minHeight && renderHeight <= mOptimal.maxHeight;
    }

    void evaluate(backend::ExternalPassContext const& context) noexcept override {
        std::lock_guard<std::mutex> lock(mMutex);
        if (mFailed || context.backend != backend::Backend::VULKAN || context.imageCount < 4) return;
        auto cmd = reinterpret_cast<VkCommandBuffer>(context.commandBuffer);
        NVSDK_NGX_Parameter* params = mNgx->capabilities;

        if (!mFeature || mRecreate) {
            if (mFeature) {
                // Replacing the feature mid-flight is unsafe; the quality change waited for
                // the GPU on the main thread before setting mRecreate.
                NVSDK_NGX_VULKAN_ReleaseFeature(mFeature);
                mFeature = nullptr;
            }
            NVSDK_NGX_DLSS_Create_Params create{};
            create.Feature.InWidth = mOptimal.maxWidth;
            create.Feature.InHeight = mOptimal.maxHeight;
            create.Feature.InTargetWidth = mOptions.outputWidth;
            create.Feature.InTargetHeight = mOptions.outputHeight;
            create.Feature.InPerfQualityValue = toPerfQuality(mOptions.quality);
            int flags = kBaseFlags;
            if (mOptions.hdr) flags |= NVSDK_NGX_DLSS_Feature_Flags_IsHDR;
            if (mOptions.autoExposure) flags |= NVSDK_NGX_DLSS_Feature_Flags_AutoExposure;
            create.InFeatureCreateFlags = flags;
            create.InEnableOutputSubrects = false;
            NVSDK_NGX_Result r = NGX_VULKAN_CREATE_DLSS_EXT(cmd, 1, 1, &mFeature, params, &create);
            if (NVSDK_NGX_FAILED(r) || !mFeature) {
                mFeature = nullptr;
                mFailed = true;
                setError(describe("NGX_VULKAN_CREATE_DLSS_EXT", r));
                return;
            }
            mRecreate = false;
            mPendingReset = true;
        }

        auto resource = [](backend::ExternalPassImage const& image, bool readWrite) {
            VkImageSubresourceRange range{};
            range.aspectMask = image.aspect;
            range.baseMipLevel = 0;
            range.levelCount = 1;
            range.baseArrayLayer = 0;
            range.layerCount = 1;
            return NVSDK_NGX_Create_ImageView_Resource_VK(reinterpret_cast<VkImageView>(image.imageView),
                    reinterpret_cast<VkImage>(image.image), range, static_cast<VkFormat>(image.format),
                    image.width, image.height, readWrite);
        };
        NVSDK_NGX_Resource_VK color = resource(context.images[COLOR], false);
        NVSDK_NGX_Resource_VK depth = resource(context.images[DEPTH], false);
        NVSDK_NGX_Resource_VK velocity = resource(context.images[VELOCITY], false);
        NVSDK_NGX_Resource_VK output = resource(context.images[OUTPUT], true);

        NVSDK_NGX_VK_DLSS_Eval_Params eval{};
        eval.Feature.pInColor = &color;
        eval.Feature.pInOutput = &output;
        eval.Feature.InSharpness = mOptions.sharpness;
        eval.pInDepth = &depth;
        eval.pInMotionVectors = &velocity;
        // Filament's jitter is the sub-pixel sample offset; NGX wants the offset the
        // projection was translated by, which is its negation. Both in render texels.
        eval.InJitterOffsetX = -context.frame.jitter[0];
        eval.InJitterOffsetY = -context.frame.jitter[1];
        eval.InRenderSubrectDimensions.Width = context.frame.renderWidth;
        eval.InRenderSubrectDimensions.Height = context.frame.renderHeight;
        eval.InReset = mPendingReset ? 1 : 0;
        // Filament's motion vectors are uv_curr - uv_prev in texels; NGX reads
        // prev - curr in pixels, in the images' own row order.
        eval.InMVScaleX = -1.0f;
        eval.InMVScaleY = -1.0f;
        eval.InPreExposure = 1.0f;
        eval.InExposureScale = 1.0f;
        NVSDK_NGX_Result r = NGX_VULKAN_EVALUATE_DLSS_EXT(cmd, mFeature, params, &eval);
        mPendingReset = false;
        if (NVSDK_NGX_FAILED(r)) {
            mFailed = true;
            setError(describe("NGX_VULKAN_EVALUATE_DLSS_EXT", r));
        }
    }

    Engine* engine() const { return mEngine; }
    View* view() const { return mView; }

private:
    Engine* const mEngine;
    View* const mView;
    NgxDevice* const mNgx;
    filament_dlss_options_t mOptions;
    OptimalSettings mOptimal;
    NVSDK_NGX_Handle* mFeature = nullptr;
    std::mutex mMutex;
    bool mRecreate = false;
    bool mPendingReset = true;
    bool mFailed = false;
};

} // namespace

void filament_dlss_set_runtime_dir(const char* dir) {
    std::lock_guard<std::mutex> lock(ngx::mutex());
    ngx::setRuntimeDirHint(dir);
}

bool filament_dlss_available(void) {
    std::lock_guard<std::mutex> lock(ngx::mutex());
    return !ngx::runtimeDir().empty() && ngx::hasNvidiaVulkanDevice();
}

bool filament_dlss_request_extensions(void) {
    if (!filament_dlss_available()) {
        setError("DLSS runtime not available");
        return false;
    }
    unsigned instCount = 0, devCount = 0;
    const char** instExts = nullptr;
    const char** devExts = nullptr;
    NVSDK_NGX_Result r = NVSDK_NGX_VULKAN_RequiredExtensions(&instCount, &instExts, &devCount, &devExts);
    if (NVSDK_NGX_FAILED(r)) {
        setError(describe("NVSDK_NGX_VULKAN_RequiredExtensions", r));
        return false;
    }
    std::vector<std::string> instance, device;
    for (unsigned i = 0; i < instCount; ++i) if (instExts && instExts[i]) instance.emplace_back(instExts[i]);
    for (unsigned i = 0; i < devCount; ++i) if (devExts && devExts[i]) device.emplace_back(devExts[i]);
    flutter_filament_set_extra_vulkan_extensions("dlss", instance, device);
    clearError();
    return true;
}

void filament_dlss_clear_extension_request(void) {
    flutter_filament_set_extra_vulkan_extensions("dlss", {}, {});
}

void* filament_dlss_create(void* engine, void* view, const filament_dlss_options_t* opts) {
    if (!engine || !view || !opts) {
        setError("filament_dlss_create: engine, view and options are required");
        return nullptr;
    }
    if (opts->outputWidth == 0 || opts->outputHeight == 0) {
        setError("filament_dlss_create: the output size must be positive");
        return nullptr;
    }
    std::lock_guard<std::mutex> lock(ngx::mutex());
    std::string error;
    auto* fengine = static_cast<Engine*>(engine);
    NgxDevice* ngx = acquireDevice(fengine, error);
    if (!ngx) {
        setError(error);
        return nullptr;
    }
    OptimalSettings optimal;
    if (!queryOptimal(ngx->capabilities, opts->outputWidth, opts->outputHeight, opts->quality, optimal, error)) {
        releaseDevice(fengine);
        setError(error);
        return nullptr;
    }
    auto* dlss = new DlssUpscaler(fengine, static_cast<View*>(view), ngx, *opts, optimal);
    dlss->applyToView();
    clearError();
    return dlss;
}

void filament_dlss_get_render_resolution(void* dlss, uint32_t* out_w, uint32_t* out_h) {
    if (!out_w || !out_h) return;
    *out_w = 0;
    *out_h = 0;
    if (!dlss) return;
    static_cast<DlssUpscaler*>(dlss)->renderResolution(out_w, out_h);
}

void filament_dlss_set_quality(void* dlss, uint8_t quality) {
    if (!dlss) return;
    auto* d = static_cast<DlssUpscaler*>(dlss);
    // The feature is replaced on the next frame; make sure no frame still uses it.
    d->engine()->flushAndWait();
    std::string error;
    std::lock_guard<std::mutex> lock(ngx::mutex());
    if (!d->setQuality(quality, error)) {
        setError(error);
        return;
    }
    d->applyToView();
    clearError();
}

void filament_dlss_reset_history(void* dlss) {
    if (!dlss) return;
    static_cast<DlssUpscaler*>(dlss)->resetHistory();
}

void filament_dlss_destroy(void* dlss) {
    if (!dlss) return;
    auto* d = static_cast<DlssUpscaler*>(dlss);
    d->detachFromView();
    // Frames recorded before this call may still evaluate the feature.
    d->engine()->flushAndWait();
    std::lock_guard<std::mutex> lock(ngx::mutex());
    d->releaseFeature();
    releaseDevice(d->engine());
    delete d;
    clearError();
}

#else // !FLUTTER_FILAMENT_DLSS_ENABLED

bool filament_dlss_available(void) {
    return false;
}

bool filament_dlss_request_extensions(void) {
    setError("DLSS runtime not available: flutter_filament was built without the NGX SDK");
    return false;
}

void filament_dlss_clear_extension_request(void) {
}

void filament_dlss_set_runtime_dir(const char* dir) {
    (void) dir;
}

void* filament_dlss_create(void* engine, void* view, const filament_dlss_options_t* opts) {
    (void) engine;
    (void) view;
    (void) opts;
    setError("DLSS runtime not available: flutter_filament was built without the NGX SDK");
    return nullptr;
}

void filament_dlss_get_render_resolution(void* dlss, uint32_t* out_w, uint32_t* out_h) {
    (void) dlss;
    if (out_w) *out_w = 0;
    if (out_h) *out_h = 0;
}

void filament_dlss_set_quality(void* dlss, uint8_t quality) {
    (void) dlss;
    (void) quality;
}

void filament_dlss_reset_history(void* dlss) {
    (void) dlss;
}

void filament_dlss_destroy(void* dlss) {
    (void) dlss;
}

#endif // FLUTTER_FILAMENT_DLSS_ENABLED
