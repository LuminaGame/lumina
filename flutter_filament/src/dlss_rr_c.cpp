/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// DLSS Ray Reconstruction through NVIDIA NGX (feature dlssd), plugged into Filament's
// external upscaler pass at the HDR stage with the view's guide buffers. Compiled with the
// NGX SDK (FLUTTER_FILAMENT_DLSS=1); otherwise every entry point reports "not available".

#include "dlss_rr_c.h"

#include <atomic>
#include <cstring>
#include <mutex>
#include <string>

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

const char* filament_dlss_rr_last_error(void) {
    std::lock_guard<std::mutex> lock(gErrorMutex);
    return gLastError.empty() ? nullptr : gLastError.c_str();
}

#if FLUTTER_FILAMENT_DLSS_ENABLED

#include <filament/Engine.h>
#include <filament/Options.h>
#include <filament/View.h>
#include <backend/ExternalPass.h>

#include <nvsdk_ngx_defs_dlssd.h>
#include <nvsdk_ngx_helpers_vk.h>
#include <nvsdk_ngx_helpers_dlssd_vk.h>
#include <nvsdk_ngx_params_dlssd.h>

#include "gpu_engine_internal.h"

using namespace filament;
using namespace bluevk;
namespace ngx = flutter_filament::ngx;

namespace {

constexpr uint32_t kTimerSlots = 8;

struct OptimalSettings {
    uint32_t width = 0, height = 0, maxWidth = 0, maxHeight = 0, minWidth = 0, minHeight = 0;
};

// NGX_DLSS_GET_OPTIMAL_SETTINGS for the Ray Reconstruction feature (its own callback).
bool queryOptimal(NVSDK_NGX_Parameter* caps, uint32_t outW, uint32_t outH, uint8_t quality,
        OptimalSettings& out, std::string& error) {
    void* callback = nullptr;
    NVSDK_NGX_Parameter_GetVoidPointer(caps, NVSDK_NGX_Parameter_DLSSDOptimalSettingsCallback, &callback);
    if (!callback) {
        error = "the installed Ray Reconstruction runtime offers no optimal settings (out of date)";
        return false;
    }
    NVSDK_NGX_Parameter_SetUI(caps, NVSDK_NGX_Parameter_Width, outW);
    NVSDK_NGX_Parameter_SetUI(caps, NVSDK_NGX_Parameter_Height, outH);
    NVSDK_NGX_Parameter_SetI(caps, NVSDK_NGX_Parameter_PerfQualityValue, ngx::toPerfQuality(quality));
    NVSDK_NGX_Parameter_SetI(caps, NVSDK_NGX_Parameter_RTXValue, false);
    NVSDK_NGX_Result r = reinterpret_cast<PFN_NVSDK_NGX_DLSS_GetOptimalSettingsCallback>(callback)(caps);
    if (NVSDK_NGX_FAILED(r)) {
        error = ngx::describe("DLSSD optimal settings", r);
        return false;
    }
    NVSDK_NGX_Parameter_GetUI(caps, NVSDK_NGX_Parameter_OutWidth, &out.width);
    NVSDK_NGX_Parameter_GetUI(caps, NVSDK_NGX_Parameter_OutHeight, &out.height);
    out.maxWidth = out.minWidth = out.width;
    out.maxHeight = out.minHeight = out.height;
    NVSDK_NGX_Parameter_GetUI(caps, NVSDK_NGX_Parameter_DLSS_Get_Dynamic_Max_Render_Width, &out.maxWidth);
    NVSDK_NGX_Parameter_GetUI(caps, NVSDK_NGX_Parameter_DLSS_Get_Dynamic_Max_Render_Height, &out.maxHeight);
    NVSDK_NGX_Parameter_GetUI(caps, NVSDK_NGX_Parameter_DLSS_Get_Dynamic_Min_Render_Width, &out.minWidth);
    NVSDK_NGX_Parameter_GetUI(caps, NVSDK_NGX_Parameter_DLSS_Get_Dynamic_Min_Render_Height, &out.minHeight);
    if (out.width == 0 || out.height == 0) {
        error = "Ray Reconstruction does not offer this quality mode for the requested output size";
        return false;
    }
    return true;
}

// NGX for the engine plus the Ray Reconstruction availability check.
ngx::Device* acquireDevice(Engine* engine, std::string& error) {
    ngx::Device* device = ngx::acquire(engine, error);
    if (!device) return nullptr;
    int needsDriver = 0;
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_SuperSamplingDenoising_NeedsUpdatedDriver, &needsDriver);
    int available = 0;
    NVSDK_NGX_Parameter_GetI(device->capabilities, NVSDK_NGX_Parameter_SuperSamplingDenoising_Available, &available);
    if (needsDriver || !available) {
        ngx::release(engine);
        error = needsDriver ? "DLSS Ray Reconstruction needs a newer NVIDIA driver"
                            : "DLSS Ray Reconstruction is not available on this GPU (nvngx_dlssd missing or unsupported)";
        return nullptr;
    }
    return device;
}

class RayReconstruction final : public ExternalUpscaler {
public:
    RayReconstruction(Engine* engine, View* view, ngx::Device* ngx, VkPhysicalDevice physicalDevice,
            filament_dlss_rr_options_t options, OptimalSettings optimal)
            : mEngine(engine), mView(view), mNgx(ngx), mOptions(options), mOptimal(optimal) {
        VkPhysicalDeviceProperties props{};
        vkGetPhysicalDeviceProperties(physicalDevice, &props);
        mTimestampPeriod = props.limits.timestampPeriod;
        mSavedGuides = view->getGuideBufferOptions();
        mSavedTaa = view->getTemporalAntiAliasingOptions();
        mSavedDsr = view->getDynamicResolutionOptions();
    }

    void applyToView() {
        GuideBufferOptions guides = mView->getGuideBufferOptions();
        guides.enabled = true;
        mView->setGuideBufferOptions(guides);
        TemporalAntiAliasingOptions taa = mView->getTemporalAntiAliasingOptions();
        taa.enabled = true;
        taa.motionVectors = true;
        mView->setTemporalAntiAliasingOptions(taa);
        DynamicResolutionOptions dsr = mView->getDynamicResolutionOptions();
        dsr.enabled = true;
        dsr.upscaler = Upscaler::EXTERNAL;
        dsr.homogeneousScaling = false;
        dsr.quality = QualityLevel::ULTRA;
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
        mView->setGuideBufferOptions(mSavedGuides);
        mView->setTemporalAntiAliasingOptions(mSavedTaa);
        DynamicResolutionOptions dsr = mSavedDsr;
        if (dsr.upscaler == Upscaler::EXTERNAL) {
            dsr.upscaler = Upscaler::BUILTIN;
            dsr.enabled = false;
        }
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

    uint64_t lastGpuNanos() const { return mLastGpuNanos.load(); }
    uint64_t frameCount() const { return mFrameCount.load(); }

    // The GPU must be idle (the caller waited on the engine).
    void releaseObjects() {
        std::lock_guard<std::mutex> lock(mMutex);
        if (mFeature) {
            NVSDK_NGX_VULKAN_ReleaseFeature(mFeature);
            mFeature = nullptr;
        }
        if (mQueryPool) {
            vkDestroyQueryPool(mNgx->device, mQueryPool, nullptr);
            mQueryPool = VK_NULL_HANDLE;
        }
    }

    Stage stage() const noexcept override { return Stage::HDR; }

    uint32_t guideBuffers() const noexcept override {
        return (1u << uint32_t(GuideBuffer::NORMAL_ROUGHNESS)) | (1u << uint32_t(GuideBuffer::DIFFUSE_ALBEDO)) |
                (1u << uint32_t(GuideBuffer::SPECULAR_ALBEDO)) | (1u << uint32_t(GuideBuffer::SPECULAR_HIT_DISTANCE));
    }

    bool supports(uint32_t renderWidth, uint32_t renderHeight, uint32_t outputWidth,
            uint32_t outputHeight) noexcept override {
        std::lock_guard<std::mutex> lock(mMutex);
        if (mFailed) return false;
        if (outputWidth != mOptions.outputWidth || outputHeight != mOptions.outputHeight) return false;
        return renderWidth >= mOptimal.minWidth && renderWidth <= mOptimal.maxWidth &&
                renderHeight >= mOptimal.minHeight && renderHeight <= mOptimal.maxHeight;
    }

    void evaluate(backend::ExternalPassContext const& context) noexcept override {
        std::lock_guard<std::mutex> lock(mMutex);
        if (mFailed || context.backend != backend::Backend::VULKAN || context.imageCount < 4) return;
        auto cmd = reinterpret_cast<VkCommandBuffer>(context.commandBuffer);
        NVSDK_NGX_Parameter* params = mNgx->capabilities;
        bool const hasGuides = context.imageCount >= 7 && context.images[GUIDE_NORMAL_ROUGHNESS].image &&
                context.images[GUIDE_DIFFUSE_ALBEDO].image && context.images[GUIDE_SPECULAR_ALBEDO].image;
        if (!hasGuides) {
            // Ray Reconstruction cannot run without its guides (MSAA view, other backend)
            mFailed = true;
            setError("DLSS Ray Reconstruction needs the view's guide buffers (single-sampled Vulkan view)");
            return;
        }

        if (!mFeature || mRecreate) {
            if (mFeature) {
                NVSDK_NGX_VULKAN_ReleaseFeature(mFeature);
                mFeature = nullptr;
            }
            setPreset(params);
            NVSDK_NGX_DLSSD_Create_Params create{};
            create.InDenoiseMode = NVSDK_NGX_DLSS_Denoise_Mode_DLUnified;
            create.InRoughnessMode = NVSDK_NGX_DLSS_Roughness_Mode_Packed;
            create.InUseHWDepth = NVSDK_NGX_DLSS_Depth_Type_HW;
            create.InWidth = mOptimal.maxWidth;
            create.InHeight = mOptimal.maxHeight;
            create.InTargetWidth = mOptions.outputWidth;
            create.InTargetHeight = mOptions.outputHeight;
            create.InPerfQualityValue = ngx::toPerfQuality(mOptions.quality);
            create.InFeatureCreateFlags = NVSDK_NGX_DLSS_Feature_Flags_MVLowRes |
                    NVSDK_NGX_DLSS_Feature_Flags_DepthInverted | NVSDK_NGX_DLSS_Feature_Flags_IsHDR |
                    NVSDK_NGX_DLSS_Feature_Flags_AutoExposure;
            create.InEnableOutputSubrects = false;
            NVSDK_NGX_Result r = NGX_VULKAN_CREATE_DLSSD_EXT1(mNgx->device, cmd, 1, 1, &mFeature, params, &create);
            if (NVSDK_NGX_FAILED(r) || !mFeature) {
                mFeature = nullptr;
                mFailed = true;
                setError(ngx::describe("NGX_VULKAN_CREATE_DLSSD_EXT1", r));
                return;
            }
            mRecreate = false;
            mPendingReset = true;
        }
        if (!mQueryPool) {
            VkQueryPoolCreateInfo info{};
            info.sType = VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO;
            info.queryType = VK_QUERY_TYPE_TIMESTAMP;
            info.queryCount = kTimerSlots * 2;
            if (vkCreateQueryPool(mNgx->device, &info, nullptr, &mQueryPool) != VK_SUCCESS) {
                mQueryPool = VK_NULL_HANDLE;
            }
        }
        readTimers();

        auto resource = [](backend::ExternalPassImage const& image, bool readWrite) {
            VkImageSubresourceRange range{};
            range.aspectMask = image.aspect;
            range.levelCount = 1;
            range.layerCount = 1;
            return NVSDK_NGX_Create_ImageView_Resource_VK(reinterpret_cast<VkImageView>(image.imageView),
                    reinterpret_cast<VkImage>(image.image), range, static_cast<VkFormat>(image.format),
                    image.width, image.height, readWrite);
        };
        NVSDK_NGX_Resource_VK color = resource(context.images[COLOR], false);
        NVSDK_NGX_Resource_VK depth = resource(context.images[DEPTH], false);
        NVSDK_NGX_Resource_VK velocity = resource(context.images[VELOCITY], false);
        NVSDK_NGX_Resource_VK output = resource(context.images[OUTPUT], true);
        NVSDK_NGX_Resource_VK normals = resource(context.images[GUIDE_NORMAL_ROUGHNESS], false);
        NVSDK_NGX_Resource_VK diffuse = resource(context.images[GUIDE_DIFFUSE_ALBEDO], false);
        NVSDK_NGX_Resource_VK specular = resource(context.images[GUIDE_SPECULAR_ALBEDO], false);
        bool const hasHitDistance = context.imageCount > GUIDE_SPECULAR_HIT_DISTANCE &&
                context.images[GUIDE_SPECULAR_HIT_DISTANCE].image;
        NVSDK_NGX_Resource_VK hitDistance{};
        if (hasHitDistance) hitDistance = resource(context.images[GUIDE_SPECULAR_HIT_DISTANCE], false);

        float worldToView[16];
        float viewToClip[16];
        std::memcpy(worldToView, context.frame.viewFromWorld, sizeof(worldToView));
        std::memcpy(viewToClip, context.frame.clipFromView, sizeof(viewToClip));

        NVSDK_NGX_VK_DLSSD_Eval_Params eval{};
        eval.pInColor = &color;
        eval.pInOutput = &output;
        eval.pInDepth = &depth;
        eval.pInMotionVectors = &velocity;
        eval.pInNormals = &normals;
        eval.pInDiffuseAlbedo = &diffuse;
        eval.pInSpecularAlbedo = &specular;
        eval.pInRoughness = nullptr;     // packed in normals.w
        if (hasHitDistance) eval.pInSpecularHitDistance = &hitDistance;
        // Filament's jitter is the sub-pixel sample offset; NGX wants the projection offset.
        eval.InJitterOffsetX = -context.frame.jitter[0];
        eval.InJitterOffsetY = -context.frame.jitter[1];
        eval.InRenderSubrectDimensions.Width = context.frame.renderWidth;
        eval.InRenderSubrectDimensions.Height = context.frame.renderHeight;
        eval.InReset = mPendingReset ? 1 : 0;
        eval.InMVScaleX = -1.0f;
        eval.InMVScaleY = -1.0f;
        eval.InPreExposure = 1.0f;
        eval.InExposureScale = 1.0f;
        eval.pInWorldToViewMatrix = worldToView;
        eval.pInViewToClipMatrix = viewToClip;

        uint32_t const slot = uint32_t(mFrame % kTimerSlots);
        if (mQueryPool) {
            vkCmdResetQueryPool(cmd, mQueryPool, slot * 2, 2);
            vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, mQueryPool, slot * 2);
        }
        NVSDK_NGX_Result r = NGX_VULKAN_EVALUATE_DLSSD_EXT(cmd, mFeature, params, &eval);
        if (mQueryPool) {
            vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, mQueryPool, slot * 2 + 1);
            mSlotWritten[slot] = true;
        }
        mPendingReset = false;
        mFrame++;
        mFrameCount.fetch_add(1);
        if (NVSDK_NGX_FAILED(r)) {
            mFailed = true;
            setError(ngx::describe("NGX_VULKAN_EVALUATE_DLSSD_EXT", r));
        }
    }

    Engine* engine() const { return mEngine; }

private:
    void setPreset(NVSDK_NGX_Parameter* params) {
        unsigned const preset = mOptions.preset;
        for (const char* key : { NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_DLAA,
                     NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_Quality,
                     NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_Balanced,
                     NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_Performance,
                     NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_UltraPerformance,
                     NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_UltraQuality }) {
            NVSDK_NGX_Parameter_SetUI(params, key, preset);
        }
    }

    // Reads the timestamps of the oldest slot that has completed (never waits).
    void readTimers() {
        if (!mQueryPool || mFrame < kTimerSlots) return;
        uint32_t const slot = uint32_t((mFrame + 1) % kTimerSlots);
        if (!mSlotWritten[slot]) return;
        uint64_t stamps[2] = {};
        if (vkGetQueryPoolResults(mNgx->device, mQueryPool, slot * 2, 2, sizeof(stamps), stamps,
                    sizeof(uint64_t), VK_QUERY_RESULT_64_BIT) == VK_SUCCESS && stamps[1] > stamps[0]) {
            mLastGpuNanos = uint64_t(double(stamps[1] - stamps[0]) * double(mTimestampPeriod));
        }
    }

    Engine* const mEngine;
    View* const mView;
    ngx::Device* const mNgx;
    filament_dlss_rr_options_t mOptions;
    OptimalSettings mOptimal;
    GuideBufferOptions mSavedGuides;
    TemporalAntiAliasingOptions mSavedTaa;
    DynamicResolutionOptions mSavedDsr;
    NVSDK_NGX_Handle* mFeature = nullptr;
    VkQueryPool mQueryPool = VK_NULL_HANDLE;
    bool mSlotWritten[kTimerSlots] = {};
    float mTimestampPeriod = 1.0f;
    uint64_t mFrame = 0;
    std::atomic<uint64_t> mLastGpuNanos{ 0 };
    std::atomic<uint64_t> mFrameCount{ 0 };
    std::mutex mMutex;
    bool mRecreate = false;
    bool mPendingReset = true;
    bool mFailed = false;
};

} // namespace

bool filament_dlss_rr_available(void) {
    std::lock_guard<std::mutex> lock(ngx::mutex());
    return ngx::hasFeatureLibrary("nvngx_dlssd") && ngx::hasNvidiaVulkanDevice();
}

bool filament_dlss_rr_supported(void* engine) {
    if (!engine || !filament_dlss_rr_available()) return false;
    std::lock_guard<std::mutex> lock(ngx::mutex());
    std::string error;
    auto* fengine = static_cast<Engine*>(engine);
    ngx::Device* device = acquireDevice(fengine, error);
    if (!device) {
        setError(error);
        return false;
    }
    ngx::release(fengine);
    clearError();
    return true;
}

void* filament_dlss_rr_create(void* engine, void* view, const filament_dlss_rr_options_t* opts) {
    if (!engine || !view || !opts) {
        setError("filament_dlss_rr_create: engine, view and options are required");
        return nullptr;
    }
    if (opts->outputWidth == 0 || opts->outputHeight == 0) {
        setError("filament_dlss_rr_create: the output size must be positive");
        return nullptr;
    }
    if (!filament_dlss_rr_available()) {
        setError("DLSS Ray Reconstruction runtime not available: nvngx_dlssd not found next to nvngx_dlss "
                 "(run tool/dlss/fetch_sdk.dart) or no NVIDIA GPU");
        return nullptr;
    }
    std::lock_guard<std::mutex> lock(ngx::mutex());
    std::string error;
    auto* fengine = static_cast<Engine*>(engine);
    ngx::Device* device = acquireDevice(fengine, error);
    if (!device) {
        setError(error);
        return nullptr;
    }
    OptimalSettings optimal;
    if (!queryOptimal(device->capabilities, opts->outputWidth, opts->outputHeight, opts->quality, optimal, error)) {
        ngx::release(fengine);
        setError(error);
        return nullptr;
    }
    void* instance = nullptr;
    void* physicalDevice = nullptr;
    void* vkDevice = nullptr;
    flutter_filament_engine_vulkan_handles(engine, &instance, &physicalDevice, &vkDevice, nullptr);
    auto* rr = new RayReconstruction(fengine, static_cast<View*>(view), device,
            static_cast<VkPhysicalDevice>(physicalDevice), *opts, optimal);
    rr->applyToView();
    clearError();
    return rr;
}

void filament_dlss_rr_get_render_resolution(void* rr, uint32_t* out_w, uint32_t* out_h) {
    if (!out_w || !out_h) return;
    *out_w = 0;
    *out_h = 0;
    if (rr) static_cast<RayReconstruction*>(rr)->renderResolution(out_w, out_h);
}

void filament_dlss_rr_set_quality(void* rr, uint8_t quality) {
    if (!rr) return;
    auto* r = static_cast<RayReconstruction*>(rr);
    r->engine()->flushAndWait();
    std::string error;
    std::lock_guard<std::mutex> lock(ngx::mutex());
    if (!r->setQuality(quality, error)) {
        setError(error);
        return;
    }
    r->applyToView();
    clearError();
}

void filament_dlss_rr_reset_history(void* rr) {
    if (rr) static_cast<RayReconstruction*>(rr)->resetHistory();
}

uint64_t filament_dlss_rr_last_gpu_time_ns(void* rr) {
    return rr ? static_cast<RayReconstruction*>(rr)->lastGpuNanos() : 0;
}

uint64_t filament_dlss_rr_frame_count(void* rr) {
    return rr ? static_cast<RayReconstruction*>(rr)->frameCount() : 0;
}

void filament_dlss_rr_destroy(void* rr) {
    if (!rr) return;
    auto* r = static_cast<RayReconstruction*>(rr);
    r->detachFromView();
    r->engine()->flushAndWait();
    std::lock_guard<std::mutex> lock(ngx::mutex());
    r->releaseObjects();
    ngx::release(r->engine());
    delete r;
    clearError();
}

#else // !FLUTTER_FILAMENT_DLSS_ENABLED

bool filament_dlss_rr_available(void) {
    return false;
}

bool filament_dlss_rr_supported(void* engine) {
    (void) engine;
    return false;
}

void* filament_dlss_rr_create(void* engine, void* view, const filament_dlss_rr_options_t* opts) {
    (void) engine;
    (void) view;
    (void) opts;
    setError("DLSS Ray Reconstruction runtime not available: flutter_filament was built without the NGX SDK "
             "(nvngx_dlssd)");
    return nullptr;
}

void filament_dlss_rr_get_render_resolution(void* rr, uint32_t* out_w, uint32_t* out_h) {
    (void) rr;
    if (out_w) *out_w = 0;
    if (out_h) *out_h = 0;
}

void filament_dlss_rr_set_quality(void* rr, uint8_t quality) {
    (void) rr;
    (void) quality;
}

void filament_dlss_rr_reset_history(void* rr) {
    (void) rr;
}

uint64_t filament_dlss_rr_last_gpu_time_ns(void* rr) {
    (void) rr;
    return 0;
}

uint64_t filament_dlss_rr_frame_count(void* rr) {
    (void) rr;
    return 0;
}

void filament_dlss_rr_destroy(void* rr) {
    (void) rr;
}

#endif // FLUTTER_FILAMENT_DLSS_ENABLED
