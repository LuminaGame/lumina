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

#if defined(FLUTTER_FILAMENT_DLSS) && FLUTTER_FILAMENT_DLSS && !defined(__EMSCRIPTEN__) && \
        (defined(_WIN32) || (defined(__linux__) && !defined(__ANDROID__)))
#define FLUTTER_FILAMENT_DLSS_ENABLED 1
#else
#define FLUTTER_FILAMENT_DLSS_ENABLED 0
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

#include "gpu_c.h"
#include "gpu_engine_internal.h"

#if defined(_WIN32)
#include <windows.h>
#else
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#endif

using namespace filament;

namespace {

// Lumina's NGX project id: stable across releases, identifies the integration
// to the driver (no account or registration is attached to it).
constexpr const char* kProjectId = "a1f0c3a0-4e7b-4d4a-9b2e-6c3f1d8e2b11";
constexpr const char* kEngineVersion = "lumina-filament-1.77.2";
constexpr int kBaseFlags =
        NVSDK_NGX_DLSS_Feature_Flags_MVLowRes | NVSDK_NGX_DLSS_Feature_Flags_DepthInverted;

const char* resultName(NVSDK_NGX_Result r) {
    switch (r) {
        case NVSDK_NGX_Result_Success: return "success";
        case NVSDK_NGX_Result_FAIL_FeatureNotSupported: return "feature not supported";
        case NVSDK_NGX_Result_FAIL_PlatformError: return "platform error";
        case NVSDK_NGX_Result_FAIL_FeatureAlreadyExists: return "feature already exists";
        case NVSDK_NGX_Result_FAIL_FeatureNotFound: return "feature not found";
        case NVSDK_NGX_Result_FAIL_InvalidParameter: return "invalid parameter";
        case NVSDK_NGX_Result_FAIL_ScratchBufferTooSmall: return "scratch buffer too small";
        case NVSDK_NGX_Result_FAIL_NotInitialized: return "not initialized";
        case NVSDK_NGX_Result_FAIL_UnsupportedInputFormat: return "unsupported input format";
        case NVSDK_NGX_Result_FAIL_RWFlagMissing: return "read/write flag missing";
        case NVSDK_NGX_Result_FAIL_MissingInput: return "missing input";
        case NVSDK_NGX_Result_FAIL_UnableToInitializeFeature: return "unable to initialize feature";
        case NVSDK_NGX_Result_FAIL_OutOfDate: return "driver or runtime out of date";
        case NVSDK_NGX_Result_FAIL_OutOfGPUMemory: return "out of GPU memory";
        case NVSDK_NGX_Result_FAIL_UnsupportedFormat: return "unsupported format";
        case NVSDK_NGX_Result_FAIL_UnableToWriteToAppDataPath: return "cannot write to the app data path";
        case NVSDK_NGX_Result_FAIL_UnsupportedParameter: return "unsupported parameter";
        case NVSDK_NGX_Result_FAIL_Denied: return "denied";
        case NVSDK_NGX_Result_FAIL_NotImplemented: return "not implemented";
        default: return "unknown NGX error";
    }
}

std::string describe(const char* what, NVSDK_NGX_Result r) {
    char buf[32];
    std::snprintf(buf, sizeof(buf), " (0x%08x)", static_cast<unsigned>(r));
    return std::string(what) + ": " + resultName(r) + buf;
}

bool fileExists(const std::string& path) {
#if defined(_WIN32)
    DWORD attrs = GetFileAttributesA(path.c_str());
    return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
#else
    struct stat st{};
    return ::stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
#endif
}

// Whether `dir` holds the DLSS runtime library itself.
bool hasRuntime(const std::string& dir) {
#if defined(_WIN32)
    return fileExists(dir + "\\nvngx_dlss.dll");
#else
    DIR* d = ::opendir(dir.c_str());
    if (!d) return false;
    bool found = false;
    while (dirent* e = ::readdir(d)) {
        if (std::strncmp(e->d_name, "libnvidia-ngx-dlss.so", 21) == 0) {
            found = true;
            break;
        }
    }
    ::closedir(d);
    return found;
#endif
}

std::string executableDir() {
#if defined(_WIN32)
    char buf[MAX_PATH];
    DWORD n = GetModuleFileNameA(nullptr, buf, MAX_PATH);
    if (n == 0 || n >= MAX_PATH) return {};
    std::string path(buf, n);
    size_t slash = path.find_last_of("\\/");
    return slash == std::string::npos ? std::string() : path.substr(0, slash);
#else
    char buf[4096];
    ssize_t n = ::readlink("/proc/self/exe", buf, sizeof(buf) - 1);
    if (n <= 0) return {};
    std::string path(buf, size_t(n));
    size_t slash = path.find_last_of('/');
    return slash == std::string::npos ? std::string() : path.substr(0, slash);
#endif
}

#if defined(_WIN32)
constexpr const char* kSdkRuntimeSubdir = "\\lib\\Windows_x86_64\\rel";
#else
constexpr const char* kSdkRuntimeSubdir = "/lib/Linux_x86_64/rel";
#endif

std::string workingDir() {
#if defined(_WIN32)
    char buf[MAX_PATH];
    DWORD n = GetCurrentDirectoryA(MAX_PATH, buf);
    return (n == 0 || n >= MAX_PATH) ? std::string() : std::string(buf, n);
#else
    char buf[4096];
    return ::getcwd(buf, sizeof(buf)) ? std::string(buf) : std::string();
#endif
}

// The folder the nvngx_dlss runtime is loaded from: LUMINA_DLSS_DIR (the folder
// itself or an SDK root), the executable's folder, then the fetched SDK under
// the working directory (build/dlss-sdk, where tool/dlss/fetch_sdk.dart puts it).
std::string gRuntimeDirHint;

std::string runtimeDir() {
    std::vector<std::string> candidates;
    if (!gRuntimeDirHint.empty()) {
        candidates.push_back(gRuntimeDirHint);
        candidates.push_back(gRuntimeDirHint + kSdkRuntimeSubdir);
    }
    if (const char* env = std::getenv("LUMINA_DLSS_DIR"); env && *env) {
        candidates.emplace_back(env);
        candidates.emplace_back(std::string(env) + kSdkRuntimeSubdir);
    }
    if (std::string exe = executableDir(); !exe.empty()) {
        candidates.push_back(exe);
    }
    if (std::string cwd = workingDir(); !cwd.empty()) {
#if defined(_WIN32)
        candidates.emplace_back(cwd + "\\build\\dlss-sdk" + kSdkRuntimeSubdir);
#else
        candidates.emplace_back(cwd + "/build/dlss-sdk" + kSdkRuntimeSubdir);
#endif
    }
    for (const auto& c : candidates) {
        if (hasRuntime(c)) return c;
    }
    return {};
}

bool hasNvidiaVulkanDevice() {
    const int count = filament_vulkan_device_count();
    for (int i = 0; i < count; ++i) {
        filament_gpu_info_t info{};
        if (filament_vulkan_device_info(i, &info) && info.vendor_id == 0x10DE) return true;
    }
    return false;
}

std::wstring widen(const std::string& s) {
    std::wstring out;
    out.reserve(s.size());
    for (unsigned char ch : s) out.push_back(static_cast<wchar_t>(ch));
    return out;
}

NVSDK_NGX_PerfQuality_Value toPerfQuality(uint8_t quality) {
    switch (quality) {
        case FILAMENT_DLSS_MAX_PERFORMANCE: return NVSDK_NGX_PerfQuality_Value_MaxPerf;
        case FILAMENT_DLSS_MAX_QUALITY: return NVSDK_NGX_PerfQuality_Value_MaxQuality;
        case FILAMENT_DLSS_ULTRA_PERFORMANCE: return NVSDK_NGX_PerfQuality_Value_UltraPerformance;
        case FILAMENT_DLSS_DLAA: return NVSDK_NGX_PerfQuality_Value_DLAA;
        case FILAMENT_DLSS_BALANCED:
        default: return NVSDK_NGX_PerfQuality_Value_Balanced;
    }
}

// NGX is initialised once per engine (per VkDevice) and shared by that
// engine's DLSS features.
struct NgxDevice {
    VkDevice device = VK_NULL_HANDLE;
    NVSDK_NGX_Parameter* capabilities = nullptr;
    int refs = 0;
};

std::mutex gNgxMutex;
std::unordered_map<Engine*, NgxDevice> gNgxDevices;
std::string gRuntimeDir;
std::wstring gRuntimeDirW;
std::wstring gAppDataPathW;

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

// Initialises NGX for the engine (refcounted) and returns its capability parameters.
NgxDevice* acquireDevice(Engine* engine, std::string& error) {
    auto it = gNgxDevices.find(engine);
    if (it != gNgxDevices.end()) {
        it->second.refs++;
        return &it->second;
    }
    void* instance = nullptr;
    void* physicalDevice = nullptr;
    void* device = nullptr;
    bool hadExtensions = false;
    if (!flutter_filament_engine_vulkan_handles(engine, &instance, &physicalDevice, &device, &hadExtensions)) {
        error = "DLSS needs an engine on the Vulkan backend (desktop Windows or Linux)";
        return nullptr;
    }
    if (!hadExtensions) {
        unsigned instCount = 0, devCount = 0;
        const char** instExts = nullptr;
        const char** devExts = nullptr;
        const char* first = "VK_NVX_binary_import";
        if (NVSDK_NGX_SUCCEED(NVSDK_NGX_VULKAN_RequiredExtensions(&instCount, &instExts, &devCount, &devExts)) &&
                devCount > 0 && devExts && devExts[0]) {
            first = devExts[0];
        }
        error = std::string("the engine was created without the NGX Vulkan extensions (") + first +
                " and others): call filament_dlss_request_extensions() before creating the engine";
        return nullptr;
    }
    if (gRuntimeDir.empty()) {
        gRuntimeDir = runtimeDir();
        if (gRuntimeDir.empty()) {
            error = "DLSS runtime not available: nvngx_dlss not found (LUMINA_DLSS_DIR, the executable folder or the fetched SDK)";
            return nullptr;
        }
        gRuntimeDirW = widen(gRuntimeDir);
        gAppDataPathW = widen(gRuntimeDir);
    }
    const wchar_t* paths[] = { gRuntimeDirW.c_str() };
    NVSDK_NGX_FeatureCommonInfo info{};
    info.PathListInfo.Path = paths;
    info.PathListInfo.Length = 1;
    NVSDK_NGX_Result r = NVSDK_NGX_VULKAN_Init_with_ProjectID(kProjectId, NVSDK_NGX_ENGINE_TYPE_CUSTOM,
            kEngineVersion, gAppDataPathW.c_str(), static_cast<VkInstance>(instance),
            static_cast<VkPhysicalDevice>(physicalDevice), static_cast<VkDevice>(device),
            bluevk::vkGetInstanceProcAddr, bluevk::vkGetDeviceProcAddr, &info, NVSDK_NGX_Version_API);
    if (NVSDK_NGX_FAILED(r)) {
        error = describe("NVSDK_NGX_VULKAN_Init", r);
        return nullptr;
    }
    NVSDK_NGX_Parameter* caps = nullptr;
    r = NVSDK_NGX_VULKAN_GetCapabilityParameters(&caps);
    if (NVSDK_NGX_FAILED(r) || !caps) {
        NVSDK_NGX_VULKAN_Shutdown1(static_cast<VkDevice>(device));
        error = describe("NVSDK_NGX_VULKAN_GetCapabilityParameters", r);
        return nullptr;
    }
    int needsDriver = 0;
    NVSDK_NGX_Parameter_GetI(caps, NVSDK_NGX_Parameter_SuperSampling_NeedsUpdatedDriver, &needsDriver);
    int available = 0;
    NVSDK_NGX_Parameter_GetI(caps, NVSDK_NGX_Parameter_SuperSampling_Available, &available);
    if (needsDriver || !available) {
        NVSDK_NGX_VULKAN_DestroyParameters(caps);
        NVSDK_NGX_VULKAN_Shutdown1(static_cast<VkDevice>(device));
        error = needsDriver ? "DLSS needs a newer NVIDIA driver" : "DLSS Super Resolution is not available on this GPU";
        return nullptr;
    }
    NgxDevice& entry = gNgxDevices[engine];
    entry.device = static_cast<VkDevice>(device);
    entry.capabilities = caps;
    entry.refs = 1;
    return &entry;
}

void releaseDevice(Engine* engine) {
    auto it = gNgxDevices.find(engine);
    if (it == gNgxDevices.end()) return;
    if (--it->second.refs > 0) return;
    NVSDK_NGX_VULKAN_DestroyParameters(it->second.capabilities);
    NVSDK_NGX_VULKAN_Shutdown1(it->second.device);
    gNgxDevices.erase(it);
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
    std::lock_guard<std::mutex> lock(gNgxMutex);
    gRuntimeDirHint = dir ? dir : "";
    if (!gRuntimeDir.empty() && !hasRuntime(gRuntimeDir)) {
        gRuntimeDir.clear();
    }
    if (gRuntimeDir.empty() && !gRuntimeDirHint.empty()) {
        // re-resolve with the hint at the next availability check
    }
}

bool filament_dlss_available(void) {
    std::lock_guard<std::mutex> lock(gNgxMutex);
    if (gRuntimeDir.empty()) {
        gRuntimeDir = runtimeDir();
        if (!gRuntimeDir.empty()) {
            gRuntimeDirW = widen(gRuntimeDir);
            gAppDataPathW = widen(gRuntimeDir);
        }
    }
    return !gRuntimeDir.empty() && hasNvidiaVulkanDevice();
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
    std::lock_guard<std::mutex> lock(gNgxMutex);
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
    std::lock_guard<std::mutex> lock(gNgxMutex);
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
    std::lock_guard<std::mutex> lock(gNgxMutex);
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
