/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// The NVIDIA NGX runtime shared by the DLSS features (see ngx_internal.h).

#include "ngx_internal.h"

#if FLUTTER_FILAMENT_DLSS_ENABLED

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unordered_map>
#include <vector>

#include <filament/Engine.h>

#include "gpu_c.h"
#include "gpu_engine_internal.h"

#if defined(_WIN32)
#include <windows.h>
#else
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

using namespace filament;

namespace flutter_filament::ngx {

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

NVSDK_NGX_PerfQuality_Value toPerfQuality(uint8_t quality) {
    // filament_dlss_quality: MAX_PERFORMANCE, BALANCED, MAX_QUALITY, ULTRA_PERFORMANCE, DLAA
    switch (quality) {
        case 0: return NVSDK_NGX_PerfQuality_Value_MaxPerf;
        case 2: return NVSDK_NGX_PerfQuality_Value_MaxQuality;
        case 3: return NVSDK_NGX_PerfQuality_Value_UltraPerformance;
        case 4: return NVSDK_NGX_PerfQuality_Value_DLAA;
        case 1:
        default: return NVSDK_NGX_PerfQuality_Value_Balanced;
    }
}

std::mutex& mutex() {
    static std::mutex m;
    return m;
}

namespace {

std::string gRuntimeDirHint;
std::string gRuntimeDir;
std::wstring gRuntimeDirW;
std::unordered_map<Engine*, Device> gDevices;

bool fileExists(const std::string& path) {
#if defined(_WIN32)
    DWORD attrs = GetFileAttributesA(path.c_str());
    return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
#else
    struct stat st{};
    return ::stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
#endif
}

// Whether `dir` holds the runtime library whose Windows name is `<stem>.dll` (on Linux
// libnvidia-ngx-<suffix>.so.*, where the suffix is the stem without "nvngx_").
bool hasLibrary(const std::string& dir, const char* stem) {
#if defined(_WIN32)
    return fileExists(dir + "\\" + stem + ".dll");
#else
    std::string prefix = "libnvidia-ngx-";
    const char* suffix = std::strncmp(stem, "nvngx_", 6) == 0 ? stem + 6 : stem;
    prefix += suffix;
    prefix += ".so";
    DIR* d = ::opendir(dir.c_str());
    if (!d) return false;
    bool found = false;
    while (dirent* e = ::readdir(d)) {
        if (std::strncmp(e->d_name, prefix.c_str(), prefix.size()) == 0) {
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

#if defined(_WIN32)
constexpr const char* kSdkRuntimeSubdir = "\\lib\\Windows_x86_64\\rel";
constexpr const char* kSdkUnderCwd = "\\build\\dlss-sdk";
#else
constexpr const char* kSdkRuntimeSubdir = "/lib/Linux_x86_64/rel";
constexpr const char* kSdkUnderCwd = "/build/dlss-sdk";
#endif

std::string findRuntimeDir() {
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
        candidates.emplace_back(cwd + kSdkUnderCwd + kSdkRuntimeSubdir);
    }
    for (const auto& c : candidates) {
        if (hasLibrary(c, "nvngx_dlss")) return c;
    }
    return {};
}

std::wstring widen(const std::string& s) {
    std::wstring out;
    out.reserve(s.size());
    for (unsigned char ch : s) out.push_back(static_cast<wchar_t>(ch));
    return out;
}

} // namespace

void setRuntimeDirHint(const char* dir) {
    gRuntimeDirHint = dir ? dir : "";
    if (!gRuntimeDir.empty() && !hasLibrary(gRuntimeDir, "nvngx_dlss")) {
        gRuntimeDir.clear();
    }
}

std::string const& runtimeDir() {
    if (gRuntimeDir.empty()) {
        gRuntimeDir = findRuntimeDir();
        gRuntimeDirW = widen(gRuntimeDir);
    }
    return gRuntimeDir;
}

bool hasFeatureLibrary(const char* windowsStem) {
    std::string const& dir = runtimeDir();
    return !dir.empty() && hasLibrary(dir, windowsStem);
}

bool hasNvidiaVulkanDevice() {
    const int count = filament_vulkan_device_count();
    for (int i = 0; i < count; ++i) {
        filament_gpu_info_t info{};
        if (filament_vulkan_device_info(i, &info) && info.vendor_id == 0x10DE) return true;
    }
    return false;
}

Device* acquire(Engine* engine, std::string& error) {
    auto it = gDevices.find(engine);
    if (it != gDevices.end()) {
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
    if (runtimeDir().empty()) {
        error = "DLSS runtime not available: nvngx_dlss not found (LUMINA_DLSS_DIR, the executable folder or the fetched SDK)";
        return nullptr;
    }
    const wchar_t* paths[] = { gRuntimeDirW.c_str() };
    NVSDK_NGX_FeatureCommonInfo info{};
    info.PathListInfo.Path = paths;
    info.PathListInfo.Length = 1;
    NVSDK_NGX_Result r = NVSDK_NGX_VULKAN_Init_with_ProjectID(kProjectId, NVSDK_NGX_ENGINE_TYPE_CUSTOM,
            kEngineVersion, gRuntimeDirW.c_str(), static_cast<VkInstance>(instance),
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
    Device& entry = gDevices[engine];
    entry.device = static_cast<VkDevice>(device);
    entry.capabilities = caps;
    entry.refs = 1;
    return &entry;
}

void release(Engine* engine) {
    auto it = gDevices.find(engine);
    if (it == gDevices.end()) return;
    if (--it->second.refs > 0) return;
    NVSDK_NGX_VULKAN_DestroyParameters(it->second.capabilities);
    NVSDK_NGX_VULKAN_Shutdown1(it->second.device);
    gDevices.erase(it);
}

} // namespace flutter_filament::ngx

#endif // FLUTTER_FILAMENT_DLSS_ENABLED
